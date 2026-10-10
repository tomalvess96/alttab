import Foundation

/// O app só baixa algo que a página/extensão indicou (capa do álbum) se for HTTPS num domínio
/// de uma lista fechada. Lista fechada em vez de "bloquear rede local": IP em hexadecimal,
/// DNS apontando para 127.0.0.1 e redirecionamentos driblam qualquer lista de bloqueio.
public enum SafeRemoteURL {
    /// Onde o YouTube Music guarda as capas.
    public static let artworkHosts = ["googleusercontent.com", "ytimg.com", "ggpht.com"]

    public static func make(_ string: String?, allowedHostSuffixes: [String]) -> URL? {
        guard let string, let url = URL(string: string) else { return nil }
        return isAllowed(url, allowedHostSuffixes: allowedHostSuffixes) ? url : nil
    }

    public static func isAllowed(_ url: URL, allowedHostSuffixes: [String]) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host()?.lowercased(), !host.isEmpty else { return false }
        return allowedHostSuffixes.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
