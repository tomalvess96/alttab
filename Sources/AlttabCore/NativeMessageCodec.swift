import Foundation

/// Enquadramento do Native Messaging: 4 bytes little-endian com o tamanho + o JSON.
/// Usado também no socket entre o alttab-host e o app.
public enum NativeMessageCodec {
    public static let maxLength = 64 * 1024 * 1024

    public static func frame(_ payload: Data) -> Data {
        var length = UInt32(payload.count).littleEndian
        var framed = Data(bytes: &length, count: 4)
        framed.append(payload)
        return framed
    }

    public struct Reader: Sendable {
        private var buffer = Data()

        public init() {}

        /// Acumula o pedaço lido e devolve os frames completos.
        /// Um tamanho absurdo descarta o buffer (o próximo frame bem formado volta a funcionar).
        public mutating func append(_ chunk: Data) -> [Data] {
            buffer.append(chunk)
            var payloads: [Data] = []
            while buffer.count >= 4 {
                let length = buffer.prefix(4).withUnsafeBytes { Int(UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self))) }
                guard length <= NativeMessageCodec.maxLength else {
                    buffer.removeAll()
                    break
                }
                guard buffer.count >= 4 + length else { break }
                payloads.append(Data(buffer.dropFirst(4).prefix(length)))
                buffer = Data(buffer.dropFirst(4 + length))
            }
            return payloads
        }
    }
}
