import Foundation

/// Aba como a extensão do Edge descreve.
public struct BrowserTab: Equatable, Sendable, Codable {
    public let id: Int
    public let windowId: Int
    public let title: String
    public let url: String
    public let favIconUrl: String?
    /// Ícone em base64 tirado do cache de favicons do próprio Edge (o app nunca baixa favicon).
    public let favIconData: String?
    public let active: Bool
    public let audible: Bool
    /// Milissegundos desde 1970 (`tab.lastAccessed` do Chromium).
    public let lastAccessed: Double

    public init(id: Int, windowId: Int, title: String, url: String, favIconUrl: String?,
                active: Bool, audible: Bool, lastAccessed: Double, favIconData: String? = nil) {
        self.id = id
        self.windowId = windowId
        self.title = title
        self.url = url
        self.favIconUrl = favIconUrl
        self.favIconData = favIconData
        self.active = active
        self.audible = audible
        self.lastAccessed = lastAccessed
    }

    /// Domínio sem "www."; páginas internas (`edge://newtab`) devolvem o nome da página.
    public var host: String {
        guard let host = URL(string: url)?.host(), !host.isEmpty else { return "" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// Aba dentro de um item do alternador.
public struct TabRef: Equatable, Hashable, Sendable {
    public let tabId: Int
    /// Janela do **AeroSpace** que contém a aba.
    public let windowID: Int
    public let url: String
    public let host: String
    public let favIconData: String?
    public let audible: Bool

    public init(tabId: Int, windowID: Int, url: String, host: String, favIconData: String?, audible: Bool) {
        self.tabId = tabId
        self.windowID = windowID
        self.url = url
        self.host = host
        self.favIconData = favIconData
        self.audible = audible
    }
}
