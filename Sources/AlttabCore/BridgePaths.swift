import Foundation

public enum BridgePaths {
    public static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/alttab", isDirectory: true)
    }

    public static var socket: String {
        directory.appendingPathComponent("browser.sock").path
    }
}
