import AlttabCore
import Foundation

enum AerospaceError: Error, CustomStringConvertible {
    case failed(args: [String], stderr: String)
    var description: String {
        switch self {
        case let .failed(args, stderr): "aerospace \(args.joined(separator: " ")): \(stderr)"
        }
    }
}

struct AerospaceClient: Sendable {
    var executable = "/opt/homebrew/bin/aerospace"

    func run(_ args: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AerospaceError.failed(args: args, stderr: String(decoding: errData, as: UTF8.self))
        }
        return data
    }

    func windows() throws -> [WindowItem] {
        try AerospaceParser.windows(from: run(["list-windows", "--all", "--json", "--format", AerospaceParser.windowFormat]))
    }

    func focused() throws -> FocusedWindow? {
        try AerospaceParser.focused(from: run(["list-windows", "--focused", "--json", "--format", "%{window-id}%{workspace}"]))
    }

    func focusedWorkspace() throws -> String {
        String(decoding: try run(["list-workspaces", "--focused"]), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func focus(windowID: Int) throws {
        _ = try run(["focus", "--window-id", String(windowID)])
    }

    func close(windowID: Int) throws {
        _ = try run(["close", "--window-id", String(windowID)])
    }
}
