import AppKit
import Carbon

enum SecureInput {
    /// Nome do app que está segurando o Secure Input, ou nil se ninguém estiver.
    static func holder() -> String? {
        guard IsSecureEventInputEnabled() else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-l", "-w", "0", "-d", "1"]
        let pipe = Pipe()
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return "desconhecido" }
        let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard let range = text.range(of: #""kCGSSessionSecureInputPID"=(\d+)"#, options: .regularExpression),
              let pid = Int32(text[range].split(separator: "=").last ?? "") else { return "desconhecido" }
        return NSRunningApplication(processIdentifier: pid)?.localizedName ?? "processo \(pid)"
    }
}
