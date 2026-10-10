import Foundation

/// Capas guardadas só enquanto alguma aba toca aquela música; falha espera um minuto antes de tentar de novo
/// (a extensão avisa a cada segundo — sem isso, uma capa quebrada seria baixada de novo a cada segundo).
public enum ArtworkCachePolicy {
    public static let retryAfter: TimeInterval = 60

    public static func pruned<Value>(_ cache: [String: Value], keeping referenced: Set<String>) -> [String: Value] {
        cache.filter { referenced.contains($0.key) }
    }

    public static func shouldFetch(cached: Bool, loading: Bool, lastFailure: Date?, now: Date) -> Bool {
        guard !cached, !loading else { return false }
        guard let lastFailure else { return true }
        return now.timeIntervalSince(lastFailure) >= retryAfter
    }
}
