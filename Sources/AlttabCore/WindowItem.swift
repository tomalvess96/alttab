public struct WindowItem: Equatable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let pid: Int32
    public let appName: String
    public let bundleID: String?
    public let title: String
    public let workspace: String

    public init(id: Int, pid: Int32, appName: String, bundleID: String?, title: String, workspace: String) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.workspace = workspace
    }

    /// Título sem o sufixo do navegador; cai no nome do app quando a janela não tem título.
    public var displayTitle: String {
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
