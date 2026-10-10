import Foundation

/// Roda um comando com prazo: se o processo travar, é encerrado e a chamada falha
/// em vez de prender a thread para sempre.
public enum ProcessRunner {
    public enum Failure: Error, CustomStringConvertible {
        case exit(status: Int32, stderr: String)
        case timeout(seconds: Double)

        public var description: String {
            switch self {
            case let .exit(status, stderr): "saiu com \(status): \(stderr)"
            case let .timeout(seconds): "sem resposta em \(seconds)s"
            }
        }
    }

    public static func run(_ executable: String, _ args: [String], timeout: Double) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()

        // Lê em paralelo para o processo não travar com o pipe cheio.
        nonisolated(unsafe) var outData = Data(), errData = Data()
        let readers = DispatchGroup()
        DispatchQueue.global().async(group: readers) { outData = out.fileHandleForReading.readDataToEndOfFile() }
        DispatchQueue.global().async(group: readers) { errData = err.fileHandleForReading.readDataToEndOfFile() }

        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            _ = finished.wait(timeout: .now() + 1)
            throw Failure.timeout(seconds: timeout)
        }
        readers.wait()
        guard process.terminationStatus == 0 else {
            throw Failure.exit(status: process.terminationStatus, stderr: String(decoding: errData, as: UTF8.self))
        }
        return outData
    }
}
