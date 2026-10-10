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

    func connectionChanged(_ isConnected: Bool) {
        connected = isConnected
        if !isConnected { tabs = [] }
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
        case .hello, .activate, .close, .media, .mediaControl:
            break
        }
    }
}
