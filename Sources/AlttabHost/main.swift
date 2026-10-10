import AlttabCore
import Foundation

// Ponte iniciada pelo Edge (Native Messaging): stdin/stdout ⇄ socket Unix do app Alttab.
// Sem o app rodando, as mensagens do navegador são descartadas e a conexão é retentada a cada 1 s.

final class BrowserOutput: @unchecked Sendable {
    private let lock = NSLock()
    func send(_ payload: Data) {
        lock.lock()
        defer { lock.unlock() }
        FileHandle.standardOutput.write(NativeMessageCodec.frame(payload))
    }
}

final class AppLink: @unchecked Sendable {
    private let lock = NSLock()
    private var socket: UnixSocket?
    func set(_ newSocket: UnixSocket?) {
        lock.lock()
        socket = newSocket
        lock.unlock()
    }
    /// Escreve com o lock: o socket não fecha no meio da escrita.
    func send(_ payload: Data) {
        lock.lock()
        defer { lock.unlock() }
        try? socket?.write(NativeMessageCodec.frame(payload))
    }
    func closeCurrent(_ target: UnixSocket) {
        lock.lock()
        if socket === target { socket = nil }
        target.close()
        lock.unlock()
    }
}

func runHost() -> Never {
    let browser = BrowserOutput()
    let app = AppLink()
    let hello = (try? BrowserMessage.hello.encode()) ?? Data()

    Thread.detachNewThread {
        while true {
            guard let socket = try? UnixSocket.connect(path: BridgePaths.socket) else {
                Thread.sleep(forTimeInterval: 1)
                continue
            }
            // Só entrega abas e miniaturas ao app Alttab assinado pelo mesmo time.
            guard PeerIdentity.verify(fd: socket.fd, requirement: PeerIdentity.appRequirement) else {
                socket.close()
                Thread.sleep(forTimeInterval: 5)
                continue
            }
            app.set(socket)
            browser.send(hello) // a extensão reenvia abas e miniaturas
            var reader = NativeMessageCodec.Reader()
            while let chunk = try? socket.read(), !chunk.isEmpty {
                reader.append(chunk).forEach(browser.send)
            }
            app.closeCurrent(socket)
            Thread.sleep(forTimeInterval: 1)
        }
    }

    var reader = NativeMessageCodec.Reader()
    while true {
        let chunk = FileHandle.standardInput.availableData
        if chunk.isEmpty { exit(0) } // o Edge fechou a porta
        reader.append(chunk).forEach(app.send)
    }
}

runHost()
