import Foundation
import Testing
@testable import AlttabCore

@Suite struct SafeRemoteURLTests {
    @Test(arguments: ["https://lh3.googleusercontent.com/abc=w544-h544", "https://i.ytimg.com/vi/x/hq.jpg",
                      "https://yt3.ggpht.com/a.jpg"])
    func allowsArtworkHosts(_ address: String) {
        #expect(SafeRemoteURL.make(address, allowedHostSuffixes: SafeRemoteURL.artworkHosts) != nil)
    }

    @Test(arguments: [
        "http://lh3.googleusercontent.com/x",       // sem TLS
        "https://0x7f.0.0.1/x",                     // IP em hexadecimal
        "https://127.0.0.1.nip.io/x",               // DNS que aponta para a máquina
        "https://googleusercontent.com.evil.com/x", // sufixo no lugar errado
        "https://evilgoogleusercontent.com/x",      // sem o ponto antes do domínio
        "https://192.168.1.10/x", "https://localhost/x", "file:///etc/passwd", "", "lixo",
    ])
    func rejectsEverythingElse(_ address: String) {
        #expect(SafeRemoteURL.make(address, allowedHostSuffixes: SafeRemoteURL.artworkHosts) == nil)
    }
}

@Suite struct FaviconDataTests {
    @Test func tabCarriesFaviconBytesFromExtension() throws {
        let json = #"{"type":"tabs","tabs":[{"id":1,"windowId":5,"title":"Pontes","url":"https://a.com","favIconUrl":"http://10.0.0.1/f.ico","favIconData":"iVBORw0=","active":true,"audible":false,"lastAccessed":1}]}"#
        guard case .tabs(let tabs) = try BrowserMessage.decode(Data(json.utf8)) else { Issue.record("não é tabs"); return }
        #expect(tabs[0].favIconData == "iVBORw0=")
        let edge = WindowItem(id: 297, pid: 1, appName: "Microsoft Edge", bundleID: TabComposer.edgeBundleID,
                              title: "Pontes — Microsoft Edge", workspace: "10")
        let item = TabComposer.compose(windows: [edge], tabs: tabs)[0]
        #expect(item.tab?.favIconData == "iVBORw0=")
    }
}
