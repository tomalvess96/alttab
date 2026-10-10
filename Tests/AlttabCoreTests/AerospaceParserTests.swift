import Foundation
import Testing
@testable import AlttabCore

@Suite struct AerospaceParserTests {
    let sample = Data("""
    [
      {"app-bundle-id":"com.microsoft.edgemac","app-name":"Microsoft Edge","app-pid":1989,
       "window-id":297,"window-title":"Pontes de acesso — Microsoft Edge","workspace":"10"},
      {"app-bundle-id":"dev.warp.Warp-Stable","app-name":"Warp","app-pid":812,
       "window-id":613,"window-title":"◑ Alt+Tab com visualização de abas","workspace":"4"},
      {"app-bundle-id":"","app-name":"Sem Bundle","app-pid":5,
       "window-id":7,"window-title":"","workspace":""}
    ]
    """.utf8)

    @Test func parsesAllFields() throws {
        let w = try AerospaceParser.windows(from: sample)
        #expect(w.count == 3)
        #expect(w[0] == WindowItem(id: 297, pid: 1989, appName: "Microsoft Edge",
                                   bundleID: "com.microsoft.edgemac",
                                   title: "Pontes de acesso — Microsoft Edge", workspace: "10"))
    }

    @Test func keepsAccentsAndSymbols() throws {
        let w = try AerospaceParser.windows(from: sample)
        #expect(w[1].title == "◑ Alt+Tab com visualização de abas")
    }

    @Test func emptyBundleBecomesNil() throws {
        #expect(try AerospaceParser.windows(from: sample)[2].bundleID == nil)
    }

    @Test func missingOptionalKeysGetDefaults() throws {
        let d = Data(#"[{"app-name":"X","window-id":1}]"#.utf8)
        let w = try AerospaceParser.windows(from: d)[0]
        #expect(w.workspace == "")
        #expect(w.title == "")
        #expect(w.pid == 0)
        #expect(w.bundleID == nil)
    }

    @Test func displayTitleStripsEdgeSuffixAndFallsBackToApp() throws {
        let w = try AerospaceParser.windows(from: sample)
        #expect(w[0].displayTitle == "Pontes de acesso")
        #expect(w[1].displayTitle == "◑ Alt+Tab com visualização de abas")
        #expect(w[2].displayTitle == "Sem Bundle")
    }

    @Test func focusedParsesIDAndWorkspace() throws {
        let f = try AerospaceParser.focused(from: Data(#"[{"window-id":613,"workspace":"4"}]"#.utf8))
        #expect(f == FocusedWindow(id: 613, workspace: "4"))
    }

    @Test func focusedEmptyListIsNil() throws {
        #expect(try AerospaceParser.focused(from: Data("[]".utf8)) == nil)
    }

    @Test func invalidJSONThrows() {
        #expect(throws: (any Error).self) { try AerospaceParser.windows(from: Data("x".utf8)) }
    }
}
