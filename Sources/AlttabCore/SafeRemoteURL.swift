import Foundation

/// Endereços que a página/extensão manda (favicon, capa do álbum) só são baixados pelo app
/// se forem HTTPS em host público — nada de rede local, IP literal ou arquivo.
public enum SafeRemoteURL {
    public static func make(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string), url.scheme?.lowercased() == "https",
              let host = url.host()?.lowercased(), !host.isEmpty else { return nil }
        let bare = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if bare == "localhost" || bare.hasSuffix(".local") || bare.hasSuffix(".internal") || !bare.contains(".") {
            return nil
        }
        // IP literal (v4 ou v6) nunca: favicon e capa de verdade vêm por nome.
        if bare.contains(":") || bare.split(separator: ".").allSatisfy({ Int($0) != nil }) { return nil }
        return url
    }
}
