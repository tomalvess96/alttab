import AlttabCore
import AppKit
import ImageIO
import Observation

@MainActor @Observable
final class BrowserStore {
    private(set) var tabs: [BrowserTab] = []
    /// Miniaturas por `tabId`.
    private(set) var thumbnails: [Int: CGImage] = [:]
    private(set) var capturedAt: [Int: Date] = [:]
    private(set) var connected = false
    private(set) var media: [Int: MediaState] = [:]
    private(set) var mediaReceivedAt: [Int: Date] = [:]
    private(set) var artwork: [String: CGImage] = [:]
    private(set) var artworkColor: [String: AlbumColor.RGB] = [:]
    @ObservationIgnored private var artworkLoading: Set<String> = []

    /// A que está tocando; se nenhuma toca, a última que mudou.
    var currentMedia: MediaState? {
        let all = media.values
        return all.first(where: \.playing) ?? all.max { (mediaReceivedAt[$0.tabId] ?? .distantPast) < (mediaReceivedAt[$1.tabId] ?? .distantPast) }
    }

    func setMedia(tabId: Int, state: MediaState?) {
        media[tabId] = state
        mediaReceivedAt[tabId] = state == nil ? nil : .now
        if let url = state?.artworkUrl { loadArtwork(url) }
    }

    private func loadArtwork(_ url: String) {
        guard artwork[url] == nil, !artworkLoading.contains(url), let address = SafeRemoteURL.make(url, allowedHostSuffixes: SafeRemoteURL.artworkHosts) else { return }
        artworkLoading.insert(url)
        Task {
            defer { artworkLoading.remove(url) }
            guard let (data, _) = try? await ArtworkSession.shared.data(from: address) else { return }
            let decoded = await Task.detached { () -> (CGImage, AlbumColor.RGB)? in
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
                return (image, AlbumColor.clamped(AlbumColor.dominant(in: image)))
            }.value
            guard let (image, color) = decoded else { return }
            artwork[url] = image
            artworkColor[url] = color
        }
    }

    func connectionChanged(_ isConnected: Bool) {
        connected = isConnected
        if !isConnected {
            tabs = []
            media = [:]
            mediaReceivedAt = [:]
        }
    }

    func setTabs(_ newTabs: [BrowserTab]) {
        tabs = newTabs
        let live = Set(newTabs.map(\.id))
        thumbnails = thumbnails.filter { live.contains($0.key) }
        capturedAt = capturedAt.filter { live.contains($0.key) }
    }

    func setThumbnail(tabId: Int, image: CGImage, at date: Date) {
        thumbnails[tabId] = image
        capturedAt[tabId] = date
    }
}

/// Servidor do socket Unix: recebe o alttab-host (um Edge por vez) e repassa comandos.
final class BrowserBridge: @unchecked Sendable {
    private let store: BrowserStore
    private let lock = NSLock()
    private var client: UnixSocket?

    init(store: BrowserStore) {
        self.store = store
    }

    func start() {
        let thread = Thread { [weak self] in self?.serve() }
        thread.name = "alttab.browser-bridge"
        thread.start()
    }

    func send(_ message: BrowserMessage) {
        guard let data = try? message.encode() else { return }
        lock.lock()
        let current = client
        lock.unlock()
        try? current?.write(NativeMessageCodec.frame(data))
    }

    private func onMain(_ work: @escaping @MainActor (BrowserStore) -> Void) {
        let store = self.store
        DispatchQueue.main.async { MainActor.assumeIsolated { work(store) } }
    }

    private func serve() {
        try? FileManager.default.createDirectory(at: BridgePaths.directory, withIntermediateDirectories: true)
        guard let server = try? UnixSocket.listen(path: BridgePaths.socket) else { return }
        while true {
            guard let connection = try? server.accept() else { continue }
            lock.lock()
            client?.close()
            client = connection
            lock.unlock()
            onMain { $0.connectionChanged(true) }

            var reader = NativeMessageCodec.Reader()
            while let chunk = try? connection.read(), !chunk.isEmpty {
                reader.append(chunk).forEach(handle)
            }

            lock.lock()
            let wasCurrent = client === connection
            if wasCurrent { client = nil }
            lock.unlock()
            connection.close()
            if wasCurrent { onMain { $0.connectionChanged(false) } }
        }
    }

    private func handle(_ payload: Data) {
        guard let message = try? BrowserMessage.decode(payload) else { return }
        switch message {
        case .tabs(let tabs):
            onMain { $0.setTabs(tabs) }
        case let .thumb(tabId, jpeg, capturedAt):
            guard let data = Data(base64Encoded: jpeg),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            nonisolated(unsafe) let decoded = image
            let date = Date(timeIntervalSince1970: capturedAt / 1000)
            onMain { $0.setThumbnail(tabId: tabId, image: decoded, at: date) }
        case let .media(tabId, state):
            onMain { $0.setMedia(tabId: tabId, state: state) }
        case .hello, .activate, .close, .mediaControl:
            break
        }
    }
}

/// Download da capa: recusa redirecionamento para fora da lista fechada de domínios.
final class ArtworkSession: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = ArtworkSession()
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await session.data(from: url)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        guard let url = request.url, SafeRemoteURL.isAllowed(url, allowedHostSuffixes: SafeRemoteURL.artworkHosts) else { return nil }
        return request
    }
}
