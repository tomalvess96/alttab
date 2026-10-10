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
    @ObservationIgnored private var artworkFailedAt: [String: Date] = [:]

    /// A que está tocando; se nenhuma toca, a última que mudou.
    var currentMedia: MediaState? {
        let all = media.values
        return all.first(where: \.playing) ?? all.max { (mediaReceivedAt[$0.tabId] ?? .distantPast) < (mediaReceivedAt[$1.tabId] ?? .distantPast) }
    }

    func setMedia(tabId: Int, state: MediaState?) {
        media[tabId] = state
        mediaReceivedAt[tabId] = state == nil ? nil : .now
        let inUse = Set(media.values.compactMap(\.artworkUrl))
        artwork = ArtworkCachePolicy.pruned(artwork, keeping: inUse)
        artworkColor = ArtworkCachePolicy.pruned(artworkColor, keeping: inUse)
        artworkFailedAt = ArtworkCachePolicy.pruned(artworkFailedAt, keeping: inUse)
        if let url = state?.artworkUrl { loadArtwork(url) }
    }

    private func loadArtwork(_ url: String) {
        guard ArtworkCachePolicy.shouldFetch(cached: artwork[url] != nil, loading: artworkLoading.contains(url),
                                             lastFailure: artworkFailedAt[url], now: .now),
              let address = SafeRemoteURL.make(url, allowedHostSuffixes: SafeRemoteURL.artworkHosts) else { return }
        artworkLoading.insert(url)
        Task {
            defer { artworkLoading.remove(url) }
            guard let (data, _) = try? await ArtworkSession.shared.data(from: address) else {
                artworkFailedAt[url] = .now
                return
            }
            let decoded = await Task.detached { () -> (CGImage, AlbumColor.RGB)? in
                guard let image = SafeImage.decode(data, maxPixelSize: 600) else { return nil }
                return (image, AlbumColor.clamped(AlbumColor.dominant(in: image)))
            }.value
            guard let (image, color) = decoded else {
                artworkFailedAt[url] = .now
                return
            }
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

    /// Fila própria: escrever no socket pode bloquear (Edge parado) e nunca pode prender a thread
    /// principal, que é a mesma do tap de teclado.
    private let sendQueue = DispatchQueue(label: "alttab.browser-bridge.send")

    func send(_ message: BrowserMessage) {
        guard let data = try? message.encode() else { return }
        sendQueue.async { [self] in
            // Escreve com o lock: o socket não pode ser fechado (e o número reaproveitado) no meio da escrita.
            lock.lock()
            defer { lock.unlock() }
            try? client?.write(NativeMessageCodec.frame(data))
        }
    }

    private func onMain(_ work: @escaping @MainActor (BrowserStore) -> Void) {
        let store = self.store
        DispatchQueue.main.async { MainActor.assumeIsolated { work(store) } }
    }

    private func serve() {
        try? BridgePaths.prepareDirectory()
        guard let server = try? UnixSocket.listen(path: BridgePaths.socket) else {
            NSLog("Alttab: não consegui abrir o socket da ponte em %@", BridgePaths.socket)
            return
        }
        while true {
            guard let connection = try? server.accept() else {
                Thread.sleep(forTimeInterval: 0.5) // erro permanente (ex.: sem descritores) não vira 100% de CPU
                continue
            }
            // Só o alttab-host assinado pelo mesmo time conversa com o app.
            guard PeerIdentity.verify(fd: connection.fd, requirement: PeerIdentity.hostRequirement) else {
                connection.close()
                continue
            }
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
            connection.close()
            lock.unlock()
            if wasCurrent { onMain { $0.connectionChanged(false) } }
        }
    }

    private func handle(_ payload: Data) {
        guard let message = try? BrowserMessage.decode(payload) else { return }
        switch message {
        case .tabs(let tabs):
            onMain { $0.setTabs(tabs) }
        case let .thumb(tabId, jpeg, capturedAt):
            guard let data = Data(base64Encoded: jpeg), let image = SafeImage.decode(data, maxPixelSize: 480) else { return }
            // CGImage é imutável; passar para a main é seguro.
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
    private var session: URLSession!

    override init() {
        super.init()
        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await session.data(from: url)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        guard let url = request.url, SafeRemoteURL.isAllowed(url, allowedHostSuffixes: SafeRemoteURL.artworkHosts) else { return nil }
        return request
    }
}
