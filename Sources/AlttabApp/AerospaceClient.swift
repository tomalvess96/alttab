import AlttabCore
import Foundation

struct AerospaceClient: Sendable {
    var executable = "/opt/homebrew/bin/aerospace"

    /// Prazo curto: se o servidor do AeroSpace travar, a chamada falha em vez de prender a thread.
    func run(_ args: [String]) throws -> Data {
        try ProcessRunner.run(executable, args, timeout: 1.5)
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
