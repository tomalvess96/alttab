import Foundation

public enum BrowserMessage: Equatable, Sendable {
    // extensão → app
    case tabs([BrowserTab])
    case thumb(tabId: Int, jpegBase64: String, capturedAt: Double)
    // app → extensão
    case hello
    case activate(tabId: Int)
    case close(tabId: Int)
    // mídia (YouTube Music)
    case media(tabId: Int, state: MediaState?)
    case mediaControl(tabId: Int, action: MediaAction)

    public enum DecodeError: Error {
        case unknownType(String)
        case missingField(String)
    }

    private struct Envelope: Codable {
        var type: String
        var tabs: [BrowserTab]?
        var tabId: Int?
        var jpegBase64: String?
        var capturedAt: Double?
        var media: MediaState?
        var action: MediaAction?
    }

    public static func decode(_ data: Data) throws -> BrowserMessage {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        switch envelope.type {
        case "tabs":
            return .tabs(envelope.tabs ?? [])
        case "thumb":
            guard let tabId = envelope.tabId, let jpeg = envelope.jpegBase64 else { throw DecodeError.missingField("thumb") }
            return .thumb(tabId: tabId, jpegBase64: jpeg, capturedAt: envelope.capturedAt ?? 0)
        case "hello":
            return .hello
        case "activate":
            guard let tabId = envelope.tabId else { throw DecodeError.missingField("tabId") }
            return .activate(tabId: tabId)
        case "close":
            guard let tabId = envelope.tabId else { throw DecodeError.missingField("tabId") }
            return .close(tabId: tabId)
        case "media":
            guard let tabId = envelope.tabId else { throw DecodeError.missingField("tabId") }
            return .media(tabId: tabId, state: envelope.media)
        case "mediaControl":
            guard let tabId = envelope.tabId, let action = envelope.action else { throw DecodeError.missingField("mediaControl") }
            return .mediaControl(tabId: tabId, action: action)
        default:
            throw DecodeError.unknownType(envelope.type)
        }
    }

    public func encode() throws -> Data {
        let envelope: Envelope
        switch self {
        case .tabs(let tabs):
            envelope = Envelope(type: "tabs", tabs: tabs)
        case let .thumb(tabId, jpeg, capturedAt):
            envelope = Envelope(type: "thumb", tabId: tabId, jpegBase64: jpeg, capturedAt: capturedAt)
        case .hello:
            envelope = Envelope(type: "hello")
        case .activate(let tabId):
            envelope = Envelope(type: "activate", tabId: tabId)
        case .close(let tabId):
            envelope = Envelope(type: "close", tabId: tabId)
        case let .media(tabId, state):
            envelope = Envelope(type: "media", tabId: tabId, media: state)
        case let .mediaControl(tabId, action):
            envelope = Envelope(type: "mediaControl", tabId: tabId, action: action)
        }
        return try JSONEncoder().encode(envelope)
    }
}
