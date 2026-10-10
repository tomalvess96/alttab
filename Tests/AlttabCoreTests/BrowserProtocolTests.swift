import Foundation
import Testing
@testable import AlttabCore

@Suite struct BrowserMessageTests {
    @Test func decodesTabsFromExtension() throws {
        let json = #"{"type":"tabs","tabs":[{"id":12,"windowId":3,"title":"Pontes de acesso","url":"https://www.example.com/pontes","favIconUrl":null,"active":true,"audible":false,"lastAccessed":1760000000000}]}"#
        let message = try BrowserMessage.decode(Data(json.utf8))
        guard case .tabs(let tabs) = message else { Issue.record("não é tabs"); return }
        #expect(tabs == [BrowserTab(id: 12, windowId: 3, title: "Pontes de acesso",
                                    url: "https://www.example.com/pontes", favIconUrl: nil,
                                    active: true, audible: false, lastAccessed: 1_760_000_000_000)])
        #expect(tabs[0].host == "example.com")
    }

    @Test func decodesThumb() throws {
        let json = #"{"type":"thumb","tabId":12,"jpegBase64":"AAEC","capturedAt":5}"#
        #expect(try BrowserMessage.decode(Data(json.utf8)) == .thumb(tabId: 12, jpegBase64: "AAEC", capturedAt: 5))
    }

    @Test func roundTripsCommands() throws {
        for message in [BrowserMessage.hello, .activate(tabId: 7), .close(tabId: 9)] {
            #expect(try BrowserMessage.decode(message.encode()) == message)
        }
    }

    @Test func encodesTypeField() throws {
        let object = try JSONSerialization.jsonObject(with: BrowserMessage.activate(tabId: 7).encode()) as? [String: Any]
        #expect(object?["type"] as? String == "activate")
        #expect(object?["tabId"] as? Int == 7)
    }

    @Test func unknownTypeThrows() {
        #expect(throws: (any Error).self) { try BrowserMessage.decode(Data(#"{"type":"xyz"}"#.utf8)) }
    }

    @Test func thumbWithoutImageThrows() {
        #expect(throws: (any Error).self) { try BrowserMessage.decode(Data(#"{"type":"thumb","tabId":1}"#.utf8)) }
    }

    @Test func hostWithoutSchemeFallsBackToURL() {
        let tab = BrowserTab(id: 1, windowId: 1, title: "", url: "edge://newtab/", favIconUrl: nil,
                             active: false, audible: false, lastAccessed: 0)
        #expect(tab.host == "newtab")
        let blank = BrowserTab(id: 1, windowId: 1, title: "", url: "", favIconUrl: nil,
                               active: false, audible: false, lastAccessed: 0)
        #expect(blank.host == "")
    }
}

@Suite struct NativeMessageCodecTests {
    @Test func frameIsLittleEndianLengthPlusPayload() {
        let framed = NativeMessageCodec.frame(Data("oi".utf8))
        #expect(Array(framed) == [2, 0, 0, 0, 0x6F, 0x69])
    }

    @Test func readerSplitsTwoFramesInOneChunk() {
        var reader = NativeMessageCodec.Reader()
        let chunk = NativeMessageCodec.frame(Data("a".utf8)) + NativeMessageCodec.frame(Data("bc".utf8))
        #expect(reader.append(chunk) == [Data("a".utf8), Data("bc".utf8)])
    }

    @Test func readerWaitsForPartialFrame() {
        var reader = NativeMessageCodec.Reader()
        let framed = NativeMessageCodec.frame(Data("hello".utf8))
        #expect(reader.append(framed.prefix(3)).isEmpty)
        #expect(reader.append(framed.dropFirst(3).prefix(4)).isEmpty)
        #expect(reader.append(framed.dropFirst(7)) == [Data("hello".utf8)])
    }

    @Test func readerDropsAbsurdLengthAndRecovers() {
        var reader = NativeMessageCodec.Reader()
        #expect(reader.append(Data([0xFF, 0xFF, 0xFF, 0x7F, 1, 2, 3])).isEmpty)
        #expect(reader.append(NativeMessageCodec.frame(Data("ok".utf8))) == [Data("ok".utf8)])
    }
}
