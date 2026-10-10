import Foundation

public enum BridgePaths {
    public static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/alttab", isDirectory: true)
    }

    /// Cria a pasta só com acesso do dono (0700) e corrige a permissão se ela já existir.
    public static func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    public static var socket: String {
        directory.appendingPathComponent("browser.sock").path
    }
}
