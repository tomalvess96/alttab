import Foundation
import Testing
@testable import AlttabCore

@Suite struct ProcessRunnerTests {
    @Test func returnsStdout() throws {
        let data = try ProcessRunner.run("/bin/echo", ["oi"], timeout: 2)
        #expect(String(decoding: data, as: UTF8.self) == "oi\n")
    }

    @Test func nonZeroExitThrows() {
        #expect(throws: ProcessRunner.Failure.self) { try ProcessRunner.run("/bin/sh", ["-c", "echo ruim >&2; exit 3"], timeout: 2) }
    }

    @Test func hangingProcessTimesOutQuickly() {
        let start = Date()
        #expect(throws: ProcessRunner.Failure.self) { try ProcessRunner.run("/bin/sleep", ["5"], timeout: 0.3) }
        #expect(Date().timeIntervalSince(start) < 2)
    }
}
