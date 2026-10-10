import Foundation

public enum AerospaceParser {
    /// Formato passado em `aerospace list-windows --json --format`.
    public static let windowFormat = "%{window-id}%{workspace}%{app-name}%{app-bundle-id}%{window-title}%{app-pid}"

    private struct RawWindow: Decodable {
        let id: Int
        let workspace: String?
        let app: String
        let bundle: String?
        let title: String?
        let pid: Int32?

        enum CodingKeys: String, CodingKey {
            case id = "window-id", workspace, app = "app-name", bundle = "app-bundle-id"
            case title = "window-title", pid = "app-pid"
        }
    }

    private struct RawFocused: Decodable {
        let id: Int
        let workspace: String?
        enum CodingKeys: String, CodingKey { case id = "window-id", workspace }
    }

    public static func windows(from data: Data) throws -> [WindowItem] {
        try JSONDecoder().decode([RawWindow].self, from: data).map { raw in
            WindowItem(id: raw.id, pid: raw.pid ?? 0, appName: raw.app,
                       bundleID: (raw.bundle?.isEmpty ?? true) ? nil : raw.bundle,
                       title: raw.title ?? "", workspace: raw.workspace ?? "")
        }
    }

    public static func focused(from data: Data) throws -> FocusedWindow? {
        try JSONDecoder().decode([RawFocused].self, from: data).first.map {
            FocusedWindow(id: $0.id, workspace: $0.workspace ?? "")
        }
    }
}
