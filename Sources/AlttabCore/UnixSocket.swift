import Darwin
import Foundation

/// Socket Unix bloqueante, mínimo: um servidor no app e um cliente no alttab-host.
public final class UnixSocket: @unchecked Sendable {
    public enum Failure: Error {
        case system(String, Int32)
        case pathTooLong
    }

    public let fd: Int32

    private init(fd: Int32) {
        self.fd = fd
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    }

    private static func address(_ path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw Failure.pathTooLong }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
        return address
    }

    private static func makeSocket() throws -> Int32 {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure.system("socket", errno) }
        return fd
    }

    public static func listen(path: String) throws -> UnixSocket {
        unlink(path)
        let fd = try makeSocket()
        var address = try address(path)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            let error = errno
            Darwin.close(fd)
            throw Failure.system("bind", error)
        }
        guard Darwin.listen(fd, 4) == 0 else {
            let error = errno
            Darwin.close(fd)
            throw Failure.system("listen", error)
        }
        return UnixSocket(fd: fd)
    }

    public static func connect(path: String) throws -> UnixSocket {
        let fd = try makeSocket()
        var address = try address(path)
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            let error = errno
            Darwin.close(fd)
            throw Failure.system("connect", error)
        }
        return UnixSocket(fd: fd)
    }

    public func accept() throws -> UnixSocket {
        let client = Darwin.accept(fd, nil, nil)
        guard client >= 0 else { throw Failure.system("accept", errno) }
        return UnixSocket(fd: client)
    }

    public func write(_ data: Data) throws {
        try data.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let written = Darwin.write(fd, raw.baseAddress! + offset, raw.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw Failure.system("write", errno)
                }
                offset += written
            }
        }
    }

    /// Bloqueia até chegar algo; devolve vazio quando o outro lado fechou.
    public func read(max: Int = 65536) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: max)
        while true {
            let count = Darwin.read(fd, &buffer, max)
            if count < 0 {
                if errno == EINTR { continue }
                throw Failure.system("read", errno)
            }
            return Data(buffer.prefix(count))
        }
    }

    public func close() {
        Darwin.close(fd)
    }
}
