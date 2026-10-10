public enum MediaAction: String, Equatable, Sendable, Codable {
    case playPause, next, previous
}

/// O que está tocando numa aba do YouTube Music.
public struct MediaState: Equatable, Sendable, Codable {
    public let tabId: Int
    public let title: String
    public let artist: String
    public let album: String
    public let artworkUrl: String?
    public let playing: Bool
    /// Segundos.
    public let position: Double
    /// Segundos; 0 quando desconhecida (ao vivo).
    public let duration: Double

    public init(tabId: Int, title: String, artist: String, album: String, artworkUrl: String?,
                playing: Bool, position: Double, duration: Double) {
        self.tabId = tabId
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkUrl = artworkUrl
        self.playing = playing
        self.position = position
        self.duration = duration
    }

    /// Segundos tocados `elapsed` segundos depois do último aviso (sem passar da duração conhecida).
    public func elapsed(at elapsed: Double) -> Double {
        let now = position + (playing ? elapsed : 0)
        return duration > 0 ? min(duration, max(0, now)) : max(0, now)
    }

    /// "1:12", "1:02:05".
    public static func timeText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let (h, m, s) = (total / 3600, (total % 3600) / 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// Fração tocada (0…1) `elapsed` segundos depois do último aviso da extensão.
    public func progress(at elapsed: Double) -> Double {
        guard duration > 0 else { return 0 }
        let now = position + (playing ? elapsed : 0)
        return min(1, max(0, now / duration))
    }
}
