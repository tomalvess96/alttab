# Alttab — Plano 3: Player do YouTube Music

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quando houver uma aba do YouTube Music, o alternador mostra uma pílula compacta (50 pt) com capa, título, artista, visualizador, anterior/tocar-pausar/próxima e progresso, toda tingida com a cor dominante da capa; brilho só no hover seguindo o mouse; clicar na capa faz ela girar e crescer até o centro (280 pt).

**Architecture:** Um content script em `music.youtube.com` lê o estado (elemento `video` + `navigator.mediaSession.metadata`, com o DOM do player como alternativa) e aperta os botões do player; o service worker repassa `media`/`mediaControl` pela ponte do Plano 2. No app, `AlbumColor` (puro, testado) tira a cor dominante da capa e a clareia/escurece para manter o texto legível; `PlayerBar` desenha a pílula.

**Tech Stack:** Swift 6.4, SwiftUI (TimelineView, rotation3DEffect), Core Graphics, Swift Testing; JavaScript MV3 (content script), `node:test`.

**Spec:** `docs/superpowers/specs/2026-10-09-alttab-design.md` (3.2 "Player do YouTube Music", 4.2, 6 "Capa clara demais", risco 4) · Protótipo: quadro "A · com 8 workspaces".

## Global Constraints

- Tudo dos Planos 1 e 2 continua valendo.
- Mensagens novas: extensão→app `{"type":"media","tabId":N,"media":{tabId,title,artist,album,artworkUrl,playing,position,duration}|null}`; app→extensão `{"type":"mediaControl","tabId":N,"action":"playPause"|"next"|"previous"}`.
- Pílula: altura **50 pt**, capa 36 pt, título 12,5 pt, transição de cor **0,6 s**, sem nada piscando sozinho (o visualizador só anda tocando; parado, as barras ficam baixas).
- Capa ampliada: **280 pt**, giro + crescimento a partir da capa pequena; clicar em qualquer lugar fecha.
- Cor da pílula: cor dominante da capa com brilho limitado a **0,35–0,70** e saturação mínima **0,45** quando a capa é colorida (s > 0,15); capa sem cor fica cinza.
- Sem aba do YouTube Music (ou media `null`), a pílula some.

## Review Focus

1. **Capa branca/amarela clara** deixaria o texto ilegível — teste em Task 2 (`clamped` limita o brilho).
2. **Capa quase toda cinza com um detalhe colorido** deve pegar a cor do detalhe, não o cinza — teste em Task 2.
3. **YouTube Music fechado com música tocando**: a pílula some (media `null` ao remover a aba) — Task 3 (`onRemoved`) + checagem manual.
4. **Seletores do player mudaram**: tocar/pausar continua funcionando pelo `video` (fallback), e o título vem do `mediaSession` — Task 3 + checagem manual em Task 5.
5. **Música sem duração conhecida (ao vivo)**: progresso não divide por zero — Task 4 (`progress` com `duration == 0` → 0).

---

### Task 1: Mensagens de mídia

**Files:**
- Create: `Sources/AlttabCore/MediaState.swift`
- Modify: `Sources/AlttabCore/BrowserMessage.swift`
- Test: `Tests/AlttabCoreTests/MediaMessageTests.swift`

**Interfaces:**
- Produces:
  - `public struct MediaState: Equatable, Sendable, Codable { tabId: Int; title: String; artist: String; album: String; artworkUrl: String?; playing: Bool; position: Double; duration: Double; func progress(at elapsed: Double) -> Double }`
  - `public enum MediaAction: String, Equatable, Sendable, Codable { case playPause, next, previous }`
  - `BrowserMessage.media(tabId: Int, state: MediaState?)`, `BrowserMessage.mediaControl(tabId: Int, action: MediaAction)`

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/MediaMessageTests.swift`:

```swift
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `./scripts/test.sh --filter MediaMessageTests`
Expected: FAIL — `cannot find 'MediaState'`.

- [ ] **Step 3: Implementar**

`Sources/AlttabCore/MediaState.swift`:

```swift
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

    /// Fração tocada (0…1) `elapsed` segundos depois do último aviso da extensão.
    public func progress(at elapsed: Double) -> Double {
        guard duration > 0 else { return 0 }
        let now = position + (playing ? elapsed : 0)
        return min(1, max(0, now / duration))
    }
}
```

Em `Sources/AlttabCore/BrowserMessage.swift`:

a) depois de `case close(tabId: Int)` adicionar:

```swift
    // mídia (YouTube Music)
    case media(tabId: Int, state: MediaState?)
    case mediaControl(tabId: Int, action: MediaAction)
```

b) no `Envelope`, depois de `var capturedAt: Double?`, adicionar:

```swift
        var media: MediaState?
        var action: MediaAction?
```

c) no `decode`, antes de `default:`, adicionar:

```swift
        case "media":
            guard let tabId = envelope.tabId else { throw DecodeError.missingField("tabId") }
            return .media(tabId: tabId, state: envelope.media)
        case "mediaControl":
            guard let tabId = envelope.tabId, let action = envelope.action else { throw DecodeError.missingField("mediaControl") }
            return .mediaControl(tabId: tabId, action: action)
```

d) no `encode`, antes do `}` que fecha o `switch`, adicionar:

```swift
        case let .media(tabId, state):
            envelope = Envelope(type: "media", tabId: tabId, media: state)
        case let .mediaControl(tabId, action):
            envelope = Envelope(type: "mediaControl", tabId: tabId, action: action)
```

e) em `Sources/AlttabApp/BrowserBridge.swift`, no `switch` do `handle`, trocar `case .hello, .activate, .close:` por `case .hello, .activate, .close, .media, .mediaControl:` (a Task 4 passa a tratar `.media`).

- [ ] **Step 4: Rodar e ver passar**

Run: `./scripts/test.sh`
Expected: PASS — suíte inteira (Plano 2 + 6 novos).

- [ ] **Step 5: Commit**

```bash
git add Sources Tests/AlttabCoreTests/MediaMessageTests.swift
git commit -F - <<'EOF'
feat: mensagens de mídia do YouTube Music na ponte

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 2: Cor dominante da capa

**Files:**
- Create: `Sources/AlttabCore/AlbumColor.swift`
- Test: `Tests/AlttabCoreTests/AlbumColorTests.swift`

**Interfaces:**
- Produces: `public enum AlbumColor { struct RGB: Equatable, Sendable { r, g, b: Double }; static func dominant(in: CGImage) -> RGB; static func clamped(_: RGB) -> RGB; static func hsb(_: RGB) -> (h: Double, s: Double, b: Double); static func rgb(h: Double, s: Double, b: Double) -> RGB }`

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/AlbumColorTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import AlttabCore

private func image(_ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: 40, height: 40))
    draw(ctx)
    return ctx.makeImage()!
}

private func fill(_ ctx: CGContext, _ r: Double, _ g: Double, _ b: Double, _ rect: CGRect = CGRect(x: 0, y: 0, width: 40, height: 40)) {
    ctx.setFillColor(red: r, green: g, blue: b, alpha: 1)
    ctx.fill(rect)
}

@Suite struct AlbumColorTests {
    @Test func solidRedIsRed() {
        let c = AlbumColor.dominant(in: image { fill($0, 0.9, 0.1, 0.1) })
        #expect(c.r > 0.8 && c.g < 0.2 && c.b < 0.2)
    }

    @Test func grayCoverWithBluePatchPicksBlue() {
        let c = AlbumColor.dominant(in: image {
            fill($0, 0.5, 0.5, 0.5)
            fill($0, 0.1, 0.3, 0.9, CGRect(x: 0, y: 0, width: 20, height: 20))
        })
        #expect(c.b > c.r + 0.3)
    }

    @Test func whiteCoverIsDarkenedAndStaysGray() {
        let c = AlbumColor.clamped(AlbumColor.dominant(in: image { fill($0, 1, 1, 1) }))
        let hsb = AlbumColor.hsb(c)
        #expect(hsb.b <= 0.7001)
        #expect(hsb.s < 0.05)
    }

    @Test func darkNavyIsBrightenedAndSaturated() {
        let hsb = AlbumColor.hsb(AlbumColor.clamped(AlbumColor.RGB(r: 0.02, g: 0.04, b: 0.15)))
        #expect(hsb.b >= 0.3499)
        #expect(hsb.s >= 0.4499)
    }

    @Test func hsbRoundTrips() {
        let original = AlbumColor.RGB(r: 0.88, g: 0.34, b: 0.48)
        let hsb = AlbumColor.hsb(original)
        let back = AlbumColor.rgb(h: hsb.h, s: hsb.s, b: hsb.b)
        #expect(abs(back.r - original.r) < 1e-9 && abs(back.g - original.g) < 1e-9 && abs(back.b - original.b) < 1e-9)
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `./scripts/test.sh --filter AlbumColorTests`
Expected: FAIL — `cannot find 'AlbumColor'`.

- [ ] **Step 3: Implementar**

`Sources/AlttabCore/AlbumColor.swift`:

```swift
import CoreGraphics

/// Cor da pílula do player tirada da capa do álbum.
public enum AlbumColor {
    public struct RGB: Equatable, Sendable {
        public let r: Double
        public let g: Double
        public let b: Double

        public init(r: Double, g: Double, b: Double) {
            self.r = r
            self.g = g
            self.b = b
        }
    }

    /// Cor dominante: agrupa pixels coloridos por matiz (12 faixas, peso = saturação × brilho)
    /// e devolve a média da faixa mais pesada. Capa sem cor devolve a média geral.
    public static func dominant(in image: CGImage) -> RGB {
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return RGB(r: 0.5, g: 0.5, b: 0.5) }

        var weight = [Double](repeating: 0, count: 12)
        var sums = [(Double, Double, Double)](repeating: (0, 0, 0), count: 12)
        var all = (0.0, 0.0, 0.0)
        var count = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] > 0 {
            let color = RGB(r: Double(pixels[i]) / 255, g: Double(pixels[i + 1]) / 255, b: Double(pixels[i + 2]) / 255)
            all = (all.0 + color.r, all.1 + color.g, all.2 + color.b)
            count += 1
            let (h, s, v) = hsb(color)
            guard s > 0.25, v > 0.2 else { continue }
            let bucket = min(11, Int(h * 12))
            let w = s * v
            weight[bucket] += w
            sums[bucket] = (sums[bucket].0 + color.r * w, sums[bucket].1 + color.g * w, sums[bucket].2 + color.b * w)
        }
        if let best = weight.indices.max(by: { weight[$0] < weight[$1] }), weight[best] > 1 {
            let w = weight[best]
            return RGB(r: sums[best].0 / w, g: sums[best].1 / w, b: sums[best].2 / w)
        }
        guard count > 0 else { return RGB(r: 0.5, g: 0.5, b: 0.5) }
        return RGB(r: all.0 / count, g: all.1 / count, b: all.2 / count)
    }

    /// Mantém o texto branco legível: brilho entre 0,35 e 0,70; capa colorida ganha saturação mínima 0,45.
    public static func clamped(_ color: RGB) -> RGB {
        let (h, s, b) = hsb(color)
        let saturation = s > 0.15 ? max(s, 0.45) : s
        return rgb(h: h, s: saturation, b: min(0.7, max(0.35, b)))
    }

    public static func hsb(_ c: RGB) -> (h: Double, s: Double, b: Double) {
        let maxV = max(c.r, c.g, c.b), minV = min(c.r, c.g, c.b)
        let delta = maxV - minV
        var hue = 0.0
        if delta > 0 {
            if maxV == c.r {
                hue = ((c.g - c.b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxV == c.g {
                hue = (c.b - c.r) / delta + 2
            } else {
                hue = (c.r - c.g) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maxV == 0 ? 0 : delta / maxV, maxV)
    }

    public static func rgb(h: Double, s: Double, b: Double) -> RGB {
        let c = b * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c
        let (r, g, bl): (Double, Double, Double)
        switch Int(h * 6) % 6 {
        case 0: (r, g, bl) = (c, x, 0)
        case 1: (r, g, bl) = (x, c, 0)
        case 2: (r, g, bl) = (0, c, x)
        case 3: (r, g, bl) = (0, x, c)
        case 4: (r, g, bl) = (x, 0, c)
        default: (r, g, bl) = (c, 0, x)
        }
        return RGB(r: r + m, g: g + m, b: bl + m)
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `./scripts/test.sh --filter AlbumColorTests`
Expected: PASS (5 testes).

- [ ] **Step 5: Commit**

```bash
git add Sources/AlttabCore/AlbumColor.swift Tests/AlttabCoreTests/AlbumColorTests.swift
git commit -F - <<'EOF'
feat: cor dominante da capa com limite de brilho para leitura

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 3: Extensão lê e controla o YouTube Music

**Files:**
- Create: `extension/content.js`
- Modify: `extension/lib.js`, `extension/lib.test.js`, `extension/background.js`, `extension/manifest.json`

**Interfaces:**
- Consumes: mensagens das Global Constraints.
- Produces: `lib.js` → `pickArtwork(list) -> string|null`, `mediaKey(state) -> string`; content script que responde a `{action: "playPause"|"next"|"previous"|"report"}`.

- [ ] **Step 1: Testes novos**

Acrescentar em `extension/lib.test.js` (e incluir `pickArtwork, mediaKey` no `import` da primeira linha):

```js
test("pickArtwork escolhe a maior capa declarada", () => {
  assert.equal(pickArtwork([{ src: "a", sizes: "60x60" }, { src: "b", sizes: "544x544" }, { src: "c", sizes: "226x226" }]), "b");
  assert.equal(pickArtwork([{ src: "só" }]), "só");
  assert.equal(pickArtwork([]), null);
  assert.equal(pickArtwork(undefined), null);
});

test("mediaKey ignora frações de segundo para não repetir aviso", () => {
  const base = { title: "t", artist: "a", album: "", artworkUrl: null, playing: true, duration: 200 };
  assert.equal(mediaKey({ ...base, position: 10.2 }), mediaKey({ ...base, position: 10.9 }));
  assert.notEqual(mediaKey({ ...base, position: 10.2 }), mediaKey({ ...base, position: 11.1 }));
  assert.notEqual(mediaKey({ ...base, position: 10 }), mediaKey({ ...base, playing: false, position: 10 }));
  assert.equal(mediaKey(null), "null");
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd extension && node --test lib.test.js; cd ..`
Expected: FAIL — `pickArtwork` não exportado (SyntaxError de import).

- [ ] **Step 3: Implementar em `lib.js`**

Acrescentar em `extension/lib.js`:

```js
/** Maior imagem declarada em `MediaMetadata.artwork` (sizes "LxA"). */
export function pickArtwork(list) {
  if (!Array.isArray(list) || list.length === 0) return null;
  const area = (a) => {
    const [w, h] = String(a.sizes ?? "0x0").split("x").map(Number);
    return (w || 0) * (h || 0);
  };
  return [...list].sort((a, b) => area(b) - area(a))[0].src ?? null;
}

/** Chave para só avisar o app quando algo visível mudou (posição em segundos inteiros). */
export function mediaKey(state) {
  if (!state) return "null";
  return JSON.stringify({ ...state, position: Math.floor(state.position ?? 0) });
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd extension && node --test lib.test.js; cd ..`
Expected: `ℹ pass 7`, `ℹ fail 0`.

- [ ] **Step 5: Content script, manifest e repasse**

`extension/content.js` (script clássico — content scripts não aceitam `import`; a lógica testável fica duplicada em linha mínima):

```js
// Lê o player do YouTube Music e aperta os botões dele. Fonte principal: <video> + mediaSession;
// seletores do DOM só como alternativa (mudam com frequência).
(() => {
  const PLAY = ["#play-pause-button", "ytmusic-player-bar .play-pause-button"];
  const NEXT = ["ytmusic-player-bar .next-button", '[aria-label="Next"]', '[aria-label="Próxima"]', '[aria-label="Próximo"]'];
  const PREV = ["ytmusic-player-bar .previous-button", '[aria-label="Previous"]', '[aria-label="Anterior"]'];

  const find = (selectors) => selectors.map((s) => document.querySelector(s)).find(Boolean) ?? null;
  const area = (a) => String(a.sizes ?? "0x0").split("x").map(Number).reduce((x, y) => (x || 0) * (y || 0), 1);

  function snapshot() {
    const video = document.querySelector("video");
    const meta = navigator.mediaSession?.metadata;
    const title = meta?.title || document.querySelector("ytmusic-player-bar .title")?.textContent?.trim() || "";
    if (!video || !title) return null;
    const artwork = meta?.artwork?.length
      ? [...meta.artwork].sort((a, b) => area(b) - area(a))[0].src
      : document.querySelector("ytmusic-player-bar img")?.src ?? null;
    return {
      title,
      artist: meta?.artist || "",
      album: meta?.album || "",
      artworkUrl: artwork,
      playing: !video.paused,
      position: video.currentTime || 0,
      duration: Number.isFinite(video.duration) ? video.duration : 0,
    };
  }

  let lastKey = "";
  function report(force = false) {
    const state = snapshot();
    const key = state ? JSON.stringify({ ...state, position: Math.floor(state.position) }) : "null";
    if (!force && key === lastKey) return;
    lastKey = key;
    chrome.runtime.sendMessage({ type: "media", media: state }).catch(() => {});
  }

  setInterval(report, 1000);
  document.addEventListener("play", () => report(), true);
  document.addEventListener("pause", () => report(), true);

  chrome.runtime.onMessage.addListener((message) => {
    const video = document.querySelector("video");
    if (message.action === "playPause") {
      const button = find(PLAY);
      if (button) button.click();
      else if (video) video.paused ? video.play() : video.pause();
    } else if (message.action === "next") {
      find(NEXT)?.click();
    } else if (message.action === "previous") {
      find(PREV)?.click();
    }
    setTimeout(() => report(true), 300);
  });
})();
```

Em `extension/manifest.json`, depois da linha `"background": …`, adicionar (lembrando a vírgula na linha anterior):

```json
  "content_scripts": [
    { "matches": ["https://music.youtube.com/*"], "js": ["content.js"], "run_at": "document_idle" }
  ]
```

Em `extension/background.js`:

a) no fim do arquivo, antes de `connect();`, adicionar:

```js
chrome.runtime.onMessage.addListener((message, sender) => {
  if (message.type !== "media" || !sender.tab) return;
  const tabId = sender.tab.id;
  post({ type: "media", tabId, media: message.media ? { tabId, ...message.media } : null });
});
chrome.tabs.onRemoved.addListener((tabId) => post({ type: "media", tabId, media: null }));
```

b) em `onCommand`, depois do ramo `close`, adicionar:

```js
  } else if (message.type === "mediaControl") {
    chrome.tabs.sendMessage(message.tabId, { action: message.action }).catch(() => {});
```

c) no ramo `hello` de `onCommand`, depois do `for` das capturas, adicionar:

```js
    for (const tab of await chrome.tabs.query({ url: "https://music.youtube.com/*" })) {
      chrome.tabs.sendMessage(tab.id, { action: "report" }).catch(() => {});
    }
```

- [ ] **Step 6: Conferir sintaxe e commitar**

Run: `node --check extension/background.js && node --check extension/content.js && python3 -I -c "import json;json.load(open('extension/manifest.json'))" && echo ok`
Expected: `ok`.

```bash
git add extension
git commit -F - <<'EOF'
feat: extensão lê e controla o player do YouTube Music

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 4: Estado da mídia no app

**Files:**
- Modify: `Sources/AlttabApp/BrowserBridge.swift`, `Sources/AlttabApp/SwitcherController.swift`

**Interfaces:**
- Consumes: `MediaState`, `MediaAction`, `AlbumColor` (Tasks 1–2).
- Produces:
  - `BrowserStore.media: [Int: MediaState]`, `BrowserStore.mediaReceivedAt: [Int: Date]`, `BrowserStore.artwork: [String: CGImage]`, `BrowserStore.artworkColor: [String: AlbumColor.RGB]`, `BrowserStore.currentMedia: MediaState?`
  - `SwitcherController.mediaControl(_ action: MediaAction)`; `SwitcherState.coverOpen: Bool`

- [ ] **Step 1: Store e download da capa**

Em `Sources/AlttabApp/BrowserBridge.swift`, dentro de `BrowserStore`, depois de `private(set) var connected = false`, adicionar:

```swift
    private(set) var media: [Int: MediaState] = [:]
    private(set) var mediaReceivedAt: [Int: Date] = [:]
    private(set) var artwork: [String: CGImage] = [:]
    private(set) var artworkColor: [String: AlbumColor.RGB] = [:]
    @ObservationIgnored private var artworkLoading: Set<String> = []

    /// A que está tocando; se nenhuma toca, a última que mudou.
    var currentMedia: MediaState? {
        let all = media.values
        return all.first(where: \.playing) ?? all.max { (mediaReceivedAt[$0.tabId] ?? .distantPast) < (mediaReceivedAt[$1.tabId] ?? .distantPast) }
    }

    func setMedia(tabId: Int, state: MediaState?) {
        media[tabId] = state
        mediaReceivedAt[tabId] = state == nil ? nil : .now
        if let url = state?.artworkUrl { loadArtwork(url) }
    }

    private func loadArtwork(_ url: String) {
        guard artwork[url] == nil, !artworkLoading.contains(url), let address = SafeRemoteURL.make(url) else { return }
        artworkLoading.insert(url)
        Task {
            defer { artworkLoading.remove(url) }
            guard let (data, _) = try? await URLSession.shared.data(from: address) else { return }
            let decoded = await Task.detached { () -> (CGImage, AlbumColor.RGB)? in
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
                return (image, AlbumColor.clamped(AlbumColor.dominant(in: image)))
            }.value
            guard let (image, color) = decoded else { return }
            artwork[url] = image
            artworkColor[url] = color
        }
    }
```

e em `connectionChanged`, trocar `if !isConnected { tabs = [] }` por:

```swift
        if !isConnected {
            tabs = []
            media = [:]
            mediaReceivedAt = [:]
        }
```

e no `handle` do `BrowserBridge`, trocar `case .hello, .activate, .close, .media, .mediaControl:` por:

```swift
        case let .media(tabId, state):
            onMain { $0.setMedia(tabId: tabId, state: state) }
        case .hello, .activate, .close, .mediaControl:
```

- [ ] **Step 2: Controle no controlador**

Em `Sources/AlttabApp/SwitcherController.swift`:

a) Em `SwitcherState`, depois de `var browser: BrowserStore?`, adicionar:

```swift
    /// Capa do álbum ampliada no centro do painel.
    var coverOpen = false
```

b) Adicionar o método em `SwitcherController`:

```swift
    func mediaControl(_ action: MediaAction) {
        guard let media = browser.currentMedia else { return }
        bridge.send(.mediaControl(tabId: media.tabId, action: action))
    }
```

c) Em `open()`, depois de `state.closingID = nil`, adicionar:

```swift
        state.coverOpen = false
```

- [ ] **Step 3: Compilar**

Run: `./scripts/test.sh 2>&1 | tail -1 && ./scripts/build-app.sh 2>&1 | grep -E "error|ok:"`
Expected: suíte verde; `ok: …/Alttab.app`.

- [ ] **Step 4: Commit**

```bash
git add Sources/AlttabApp
git commit -F - <<'EOF'
feat: app guarda o que toca no YouTube Music e a cor da capa

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 5: Pílula do player e capa ampliada

**Files:**
- Create: `Sources/AlttabApp/Views/PlayerBar.swift`
- Modify: `Sources/AlttabApp/Views/SwitcherView.swift`

**Interfaces:**
- Consumes: `BrowserStore.currentMedia/artwork/artworkColor/mediaReceivedAt`, `SwitcherController.mediaControl`, `SwitcherState.coverOpen` (Task 4).
- Produces: `struct PlayerBar: View`, `struct CoverOverlay: View`.

- [ ] **Step 1: Views**

`Sources/AlttabApp/Views/PlayerBar.swift`:

```swift
import AlttabCore
import SwiftUI

extension AlbumColor.RGB {
    var color: Color { Color(red: r, green: g, blue: b) }
}

struct PlayerBar: View {
    let media: MediaState
    let receivedAt: Date
    let artwork: CGImage?
    let tint: Color
    let onControl: (MediaAction) -> Void
    let onCover: () -> Void

    @State private var hover: CGPoint?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCover) { cover }
                .buttonStyle(.plain)
                .accessibilityLabel("Ampliar capa do álbum")
            VStack(alignment: .leading, spacing: 1) {
                Text(media.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .id(media.title)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                Text(media.artist.isEmpty ? "YouTube Music" : "\(media.artist) · YouTube Music")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.text.opacity(0.72))
                    .lineLimit(1)
            }
            .frame(width: 190, alignment: .leading)
            Visualizer(playing: media.playing, tint: tint)
                .frame(width: 46, height: 18)
            HStack(spacing: 2) {
                control("backward.end.fill", "Música anterior", .previous, size: 30)
                Button { onControl(.playPause) } label: {
                    Image(systemName: media.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(tint))
                        .shadow(color: tint.opacity(0.4), radius: 7)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(media.playing ? "Pausar" : "Tocar")
                control("forward.end.fill", "Próxima música", .next, size: 30)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 50)
        .background(tint.opacity(0.18), in: .rect(cornerRadius: 14))
        .overlay(glow)
        .overlay(alignment: .bottom) { progress }
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.33)))
        .clipShape(.rect(cornerRadius: 14))
        .shadow(color: tint.opacity(0.19), radius: 14, y: 8)
        .animation(.easeInOut(duration: 0.6), value: tint)
        .animation(.spring(response: 0.35), value: media.title)
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hover = point
            case .ended: hover = nil
            }
        }
    }

    private var cover: some View {
        Group {
            if let artwork {
                Image(decorative: artwork, scale: 1).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [tint, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
        .id(media.title)
        .transition(.asymmetric(insertion: .modifier(active: FlipModifier(angle: 90, scale: 0.8), identity: FlipModifier(angle: 0, scale: 1)),
                                removal: .opacity))
    }

    private func control(_ symbol: String, _ label: String, _ action: MediaAction, size: CGFloat) -> some View {
        Button { onControl(action) } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }

    private var glow: some View {
        RadialGradient(colors: [tint.opacity(0.33), .clear],
                       center: .init(x: (hover?.x ?? 0) / 520, y: (hover?.y ?? 0) / 50),
                       startRadius: 0, endRadius: 220)
            .opacity(hover == nil ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: hover == nil)
            .allowsHitTesting(false)
    }

    private var progress: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !media.playing)) { context in
            let fraction = media.progress(at: context.date.timeIntervalSince(receivedAt))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.08))
                    Rectangle().fill(tint).frame(width: geo.size.width * fraction)
                    Circle().fill(.white).frame(width: 6, height: 6)
                        .shadow(color: tint, radius: 4)
                        .offset(x: geo.size.width * fraction - 3)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 12)
        }
    }
}

/// Barrinhas que só andam tocando; pausado ficam baixas e paradas.
struct Visualizer: View {
    let playing: Bool
    let tint: Color

    var body: some View {
        TimelineView(.animation(paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<9, id: \.self) { index in
                    let speed = 0.5 + Double((index * 37) % 5) / 10
                    let level = playing ? 0.25 + 0.75 * abs(sin(t * .pi / speed + Double(index) * 0.7)) : 0.2
                    Capsule().fill(tint).frame(height: 18 * level)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

struct FlipModifier: ViewModifier {
    let angle: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(scale)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Capa grande no centro do painel: gira e cresce a partir da pequena; clique fecha.
struct CoverOverlay: View {
    let media: MediaState
    let artwork: CGImage?
    let tint: Color
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.55)).background(.ultraThinMaterial)
            VStack(spacing: 16) {
                Group {
                    if let artwork {
                        Image(decorative: artwork, scale: 1).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            LinearGradient(colors: [tint, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Image(systemName: "music.note").font(.system(size: 84, weight: .light)).foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 280, height: 280)
                .clipShape(.rect(cornerRadius: 22))
                .shadow(color: tint.opacity(0.4), radius: 40, y: 20)
                .transition(.modifier(active: FlipModifier(angle: 180, scale: 0.14), identity: FlipModifier(angle: 0, scale: 1)))
                VStack(spacing: 4) {
                    Text(media.title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text)
                    Text([media.artist, media.album].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.72))
                }
            }
        }
        .clipShape(.rect(cornerRadius: Theme.panelRadius))
        .contentShape(.rect)
        .onTapGesture(perform: onClose)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Fechar capa ampliada")
    }
}
```

- [ ] **Step 2: Encaixar no painel**

Em `Sources/AlttabApp/Views/SwitcherView.swift`:

a) Trocar:

```swift
            columns
            Spacer(minLength: 0)
            footer
        }
```

por:

```swift
            columns
            Spacer(minLength: 0)
            player
            footer
        }
```

b) Logo depois de `.glassEffect(...)` (a linha `.glassEffect(.regular.tint(.black.opacity(0.35)), in: .rect(cornerRadius: Theme.panelRadius))`), adicionar:

```swift
        .overlay {
            if state.coverOpen, let browser = state.browser, let media = browser.currentMedia {
                CoverOverlay(media: media, artwork: media.artworkUrl.flatMap { browser.artwork[$0] },
                             tint: tint(browser, media),
                             onClose: { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { state.coverOpen = false } })
            }
        }
```

c) Adicionar os membros:

```swift
    @ViewBuilder private var player: some View {
        if let browser = state.browser, let media = browser.currentMedia {
            PlayerBar(media: media,
                      receivedAt: browser.mediaReceivedAt[media.tabId] ?? .now,
                      artwork: media.artworkUrl.flatMap { browser.artwork[$0] },
                      tint: tint(browser, media),
                      onControl: { controller.mediaControl($0) },
                      onCover: { withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) { state.coverOpen = true } })
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func tint(_ browser: BrowserStore, _ media: MediaState) -> Color {
        media.artworkUrl.flatMap { browser.artworkColor[$0] }?.color ?? Theme.accent
    }
```

- [ ] **Step 3: Compilar e instalar**

Run: `./scripts/test.sh 2>&1 | tail -1 && ./scripts/install.sh 2>&1 | tail -2`
Expected: suíte verde; instalado.

- [ ] **Step 4: Commit**

```bash
git add Sources/AlttabApp/Views
git commit -F - <<'EOF'
feat: pílula do player com cor da capa e capa ampliada com giro

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 6: Checklist com o YouTube Music real

**Files:**
- Modify: `docs/superpowers/spikes/2026-10-09-resultados.md`

- [ ] **Step 1: Recarregar a extensão (Tom)** — `edge://extensions` → Alttab → recarregar (o content script novo só entra em abas abertas depois, então recarregar a aba do YouTube Music também).

- [ ] **Step 2: Checklist (seção "Checklist do Plano 3")**
1. Com música tocando, Option+Tab mostra a pílula com capa, título e artista certos.
2. A cor da pílula combina com a capa e muda devagar ao trocar de música.
3. Tocar/pausar, próxima e anterior funcionam (se próxima/anterior não funcionarem, anotar o `aria-label`/classe dos botões no DevTools e atualizar `NEXT`/`PREV` em `content.js`).
4. Barrinhas andam só tocando; progresso avança e para ao pausar.
5. Hover acende o brilho seguindo o mouse; nada pisca sozinho.
6. Clicar na capa: gira e cresce até o centro; clicar fecha.
7. Fechar a aba do YouTube Music: a pílula some.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/spikes
git commit -F - <<'EOF'
docs: checklist do Plano 3 com o YouTube Music real

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

## Cobertura da spec neste plano

| Spec | Onde |
|---|---|
| 3.2 pílula 50 pt, capa, título, artista, visualizador, controles, progresso | Tasks 1, 4, 5 |
| 3.2 tingida pela cor dominante, transição 0,6 s | Tasks 2, 5 |
| 3.2 brilho só no hover, nada piscando | Task 5 |
| 3.2 flip da capa até 280 pt | Task 5 |
| 4.2 content script do YouTube Music (DOM + mediaSession) | Task 3 |
| 6 capa clara demais | Task 2 |
| 8 risco 4 (DOM muda) | Task 3 (fallbacks) + Task 6 |
