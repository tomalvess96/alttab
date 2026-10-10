import Foundation
import Testing
@testable import AlttabCore

@Suite(.serialized) struct UnixSocketTests {
    private func tempPath() -> String {
        "/private/tmp/alttab-test-\(UUID().uuidString.prefix(8)).sock"
    }

    @Test func clientFrameArrivesAtServer() throws {
        let path = tempPath()
        let server = try UnixSocket.listen(path: path)
        defer { server.close(); unlink(path) }
        let payload = NativeMessageCodec.frame(Data("ola".utf8))
        DispatchQueue.global().async {
            let client = try? UnixSocket.connect(path: path)
            try? client?.write(payload)
            client?.close()
        }
        let connection = try server.accept()
        defer { connection.close() }
        var reader = NativeMessageCodec.Reader()
        var received: [Data] = []
        while received.isEmpty {
            let chunk = try connection.read()
            if chunk.isEmpty { break }
            received += reader.append(chunk)
        }
        #expect(received == [Data("ola".utf8)])
    }

    @Test func readReturnsEmptyWhenPeerCloses() throws {
        let path = tempPath()
        let server = try UnixSocket.listen(path: path)
        defer { server.close(); unlink(path) }
        DispatchQueue.global().async { (try? UnixSocket.connect(path: path))?.close() }
        let connection = try server.accept()
        defer { connection.close() }
        #expect(try connection.read().isEmpty)
    }

    @Test func connectToMissingSocketThrows() {
        #expect(throws: (any Error).self) { try UnixSocket.connect(path: "/private/tmp/alttab-nao-existe.sock") }
    }

    @Test func listenReplacesStaleSocketFile() throws {
        let path = tempPath()
        FileManager.default.createFile(atPath: path, contents: Data("velho".utf8))
        let server = try UnixSocket.listen(path: path)
        server.close()
        unlink(path)
    }

    @Test func socketPathFitsSunPath() {
        #expect(BridgePaths.socket.utf8.count < 104)
        #expect(BridgePaths.socket.hasSuffix("/Library/Application Support/alttab/browser.sock"))
    }
}
