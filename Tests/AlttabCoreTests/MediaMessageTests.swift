import Foundation
import Testing
@testable import AlttabCore

@Suite struct MediaMessageTests {
    @Test func decodesMediaFromExtension() throws {
        let json = #"{"type":"media","tabId":7,"media":{"tabId":7,"title":"Música","artist":"Artista","album":"Álbum","artworkUrl":"https://lh3.googleusercontent.com/x=w544","playing":true,"position":72.5,"duration":228}}"#
        #expect(try BrowserMessage.decode(Data(json.utf8)) == .media(tabId: 7, state: MediaState(
            tabId: 7, title: "Música", artist: "Artista", album: "Álbum",
            artworkUrl: "https://lh3.googleusercontent.com/x=w544", playing: true, position: 72.5, duration: 228)))
    }

    @Test func decodesMediaGone() throws {
        #expect(try BrowserMessage.decode(Data(#"{"type":"media","tabId":7,"media":null}"#.utf8)) == .media(tabId: 7, state: nil))
    }

    @Test func encodesMediaControl() throws {
        let object = try JSONSerialization.jsonObject(with: BrowserMessage.mediaControl(tabId: 7, action: .next).encode()) as? [String: Any]
        #expect(object?["type"] as? String == "mediaControl")
        #expect(object?["tabId"] as? Int == 7)
        #expect(object?["action"] as? String == "next")
    }

    @Test func mediaControlRoundTrips() throws {
        let message = BrowserMessage.mediaControl(tabId: 3, action: .playPause)
        #expect(try BrowserMessage.decode(message.encode()) == message)
    }

    @Test func progressExtrapolatesWhilePlayingAndClamps() {
        let playing = MediaState(tabId: 1, title: "t", artist: "", album: "", artworkUrl: nil,
                                 playing: true, position: 50, duration: 100)
        #expect(playing.progress(at: 10) == 0.6)
        #expect(playing.progress(at: 500) == 1)
        let paused = MediaState(tabId: 1, title: "t", artist: "", album: "", artworkUrl: nil,
                                playing: false, position: 50, duration: 100)
        #expect(paused.progress(at: 10) == 0.5)
    }

    @Test func liveStreamWithoutDurationHasZeroProgress() {
        let live = MediaState(tabId: 1, title: "t", artist: "", album: "", artworkUrl: nil,
                              playing: true, position: 50, duration: 0)
        #expect(live.progress(at: 10) == 0)
    }
}

@Suite struct MediaTimeTextTests {
    @Test(arguments: [(0.0, "0:00"), (9.9, "0:09"), (72.5, "1:12"), (600, "10:00"), (3725, "1:02:05"), (-3, "0:00")])
    func formats(seconds: Double, expected: String) {
        #expect(MediaState.timeText(seconds) == expected)
    }

    @Test func elapsedFollowsProgressAndClamps() {
        let m = MediaState(tabId: 1, title: "t", artist: "", album: "", artworkUrl: nil, playing: true, position: 50, duration: 100)
        #expect(m.elapsed(at: 10) == 60)
        #expect(m.elapsed(at: 500) == 100)
    }
}
