import Testing
@testable import AlttabCore

@Suite struct SafeRemoteURLTests {
    @Test(arguments: ["https://www.google.com/favicon.ico", "https://lh3.googleusercontent.com/abc=w544-h544"])
    func allowsPublicHTTPS(_ address: String) {
        #expect(SafeRemoteURL.make(address) != nil)
    }

    @Test(arguments: [
        "http://site.com/favicon.ico",          // sem TLS
        "file:///etc/passwd",
        "https://localhost/x", "https://127.0.0.1/x", "https://192.168.100.181/x",
        "https://10.0.0.5/x", "https://172.16.0.1/x", "https://[::1]/x", "https://169.254.1.1/x",
        "https://servidor/x",                    // nome sem domínio (rede local)
        "https://evodesk.local/x",
        "", "not a url",
    ])
    func rejectsLocalOrUnsafe(_ address: String) {
        #expect(SafeRemoteURL.make(address) == nil)
    }
}
