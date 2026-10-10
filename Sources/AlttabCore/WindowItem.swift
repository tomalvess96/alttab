public struct WindowItem: Equatable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let pid: Int32
    public let appName: String
    public let bundleID: String?
    public let title: String
    public let workspace: String
    /// Preenchido quando o item é uma aba do navegador (id negativo, ver `TabComposer.itemID`).
    public let tab: TabRef?

    public init(id: Int, pid: Int32, appName: String, bundleID: String?, title: String, workspace: String,
                tab: TabRef? = nil) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.workspace = workspace
        self.tab = tab
    }

    /// Janela do AeroSpace a que o item pertence (a própria, ou a janela do navegador da aba).
    public var windowKey: Int { tab?.windowID ?? id }

    /// Título sem o sufixo do navegador; cai no nome do app (ou no domínio da aba) quando não há título.
    public var displayTitle: String {
        if let tab { return title.isEmpty ? tab.host : title }
        for suffix in [" — Microsoft Edge", " - Microsoft Edge"] where title.hasSuffix(suffix) {
            return String(title.dropLast(suffix.count))
        }
        return title.isEmpty ? appName : title
    }
}

public struct FocusedWindow: Equatable, Sendable {
    public let id: Int
    public let workspace: String

    public init(id: Int, workspace: String) {
        self.id = id
        self.workspace = workspace
    }
}
