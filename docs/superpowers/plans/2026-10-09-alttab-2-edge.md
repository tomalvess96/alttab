# Alttab — Plano 2: Abas do Edge com miniaturas

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** As abas do Edge aparecem no alternador como itens próprios, com miniatura, ícone do site, áudio e "visto há X", na coluna do workspace do Edge — com o layout do protótipo (até 4 abas: cartões; fora de foco: 3 + "+N"; em foco: destaque grande + grade fixa de miniaturas) — e escolher/fechar uma aba age no Edge.

**Architecture:** Extensão MV3 do Edge (lista abas, fotografa a aba visível, ativa/fecha) ⇄ `alttab-host` (binário iniciado pelo Edge via Native Messaging, stdin/stdout) ⇄ socket Unix ⇄ `BrowserBridge` no app. A lógica pura nova (mensagens, enquadramento, socket, composição janela→abas, layout da coluna do Edge) fica em `AlttabCore` com testes; a extensão tem as funções puras em `lib.js` testadas com `node --test`.

**Tech Stack:** Swift 6.4, SwiftUI/AppKit, sockets POSIX, Swift Testing; JavaScript (MV3, `node:test`), Edge 151.

**Spec:** `docs/superpowers/specs/2026-10-09-alttab-design.md` (seções 3.2 "Coluna do Edge", 4.2, 4.3, 5, 6) · Protótipo: https://claude.ai/artifact/HXkTSRDNCgCbaDYEVJ61fd (quadro "A · com 8 workspaces", ajuste `abasEdge`)

## Global Constraints

- Tudo do Plano 1 continua valendo (macOS 26, Swift 6, sem dependências, pt-BR, SF Symbols, `#FFB547`, commits em português com heredoc, nunca `$(...)` na mensagem).
- Build/teste **sempre** por `./scripts/test.sh` e `./scripts/build-app.sh` (compilam fora do OneDrive).
- Nome do host Native Messaging: `br.inf.brusoft.alttab`. ID fixo da extensão: `npgoecidghckmkdhakalhchnaebjdhlc` (vem da `key` no manifest).
- Socket: `~/Library/Application Support/alttab/browser.sock`. Enquadramento igual nos dois trechos: 4 bytes little-endian com o tamanho + JSON UTF-8.
- Mensagens JSON (campo `type`): extensão→app `tabs` (`tabs: [{id, windowId, title, url, favIconUrl, active, audible, lastAccessed}]`), `thumb` (`tabId, jpegBase64, capturedAt` em ms); app→extensão `hello`, `activate` (`tabId`), `close` (`tabId`).
- Miniatura de aba: JPEG ≤ 480 px de largura.
- Id de item de aba no alternador: `-(tabId + 1)` (negativo, nunca colide com janela do AeroSpace).
- Coluna do Edge: ≤ 4 abas → cartões; fora de foco e sem busca → 3 + "+N"; em foco com > 4 → destaque + grade de 3 (≤ 9), 5 (≤ 20) ou 6 colunas; miniatura da grade = `clamp(26…64, floor(300 / linhas) − 22)`. **A grade nunca se reorganiza ao passar o mouse.**
- Altura do painel fixa por abertura: `min(altura útil da tela − 80, 720)` (corrige o "minor" do Plano 1 em que a coluna em foco crescia depois de medir).

## Review Focus

1. **Edge com várias janelas** (duas janelas com abas diferentes): cada aba vai para o workspace da **sua** janela — teste em Task 2 (`match`).
2. **Option+Tab rápido com o Edge na frente** tem que ir para a janela anterior, **não** para outra aba do mesmo Edge — teste em Task 2 (seleção inicial por janela).
3. **Edge fechado / extensão desligada** no meio do uso: as abas somem e o Edge volta a aparecer como janela comum; nada trava — teste em Task 3 (socket fechado → leitura vazia) + checagem manual em Task 8.
4. **Mensagem truncada ou gigante no socket** (mais de um frame num pedaço, frame partido em dois pedaços, tamanho absurdo): o leitor não trava nem vaza memória — testes em Task 1.
5. **Páginas que não podem ser fotografadas** (`edge://`, PDF interno, página em branco): a aba aparece com o ícone, sem erro — teste em Task 5 (`capturable`).

---

## Estrutura de arquivos

```
alttab/
├── Package.swift                         # + alvo executável AlttabHost
├── Sources/AlttabCore/
│   ├── BrowserTab.swift                  # aba do navegador + TabRef (aba dentro de um item)
│   ├── BrowserMessage.swift              # JSON das mensagens
│   ├── NativeMessageCodec.swift          # enquadramento 4 bytes + leitor incremental
│   ├── UnixSocket.swift                  # socket Unix (servidor e cliente)
│   ├── BridgePaths.swift                 # caminho do socket
│   ├── TabComposer.swift                 # janela do Edge → itens de aba, em ordem MRU
│   ├── EdgeColumnLayout.swift            # modo da coluna do Edge e altura da miniatura
│   ├── WindowItem.swift                  # (mod) + tab: TabRef?
│   └── SwitcherModel.swift               # (mod) seleção inicial por janela; busca no endereço
├── Sources/AlttabHost/main.swift         # ponte stdin/stdout ⇄ socket
├── Sources/AlttabApp/
│   ├── BrowserBridge.swift               # BrowserStore + servidor do socket
│   ├── SwitcherController.swift          # (mod) compõe abas, ativa/fecha aba
│   ├── SwitcherPanel.swift               # (mod) altura fixa
│   ├── AppDelegate.swift                 # (mod) liga a ponte
│   └── Views/
│       ├── Bits.swift                    # (mod) TabIcon, ItemIcon, AudioBars, AgoBadge, Ago
│       ├── EdgeTabsView.swift            # cartões / "+N" / destaque + grade
│       ├── WindowCardView.swift          # (mod) ícone de aba, áudio, "visto há"
│       ├── WorkspaceColumnView.swift     # (mod) separa janelas e abas
│       └── SwitcherView.swift            # (mod) altura fixa, peso da coluna do Edge
├── extension/
│   ├── manifest.json
│   ├── lib.js                            # funções puras
│   ├── lib.test.js                       # node --test
│   └── background.js
├── scripts/build-app.sh                  # (mod) inclui e assina o alttab-host
├── scripts/install.sh                    # (mod) registra o host no Edge
└── Tests/AlttabCoreTests/
    ├── BrowserProtocolTests.swift        # mensagens + enquadramento
    ├── UnixSocketTests.swift
    ├── TabComposerTests.swift
    └── EdgeColumnLayoutTests.swift
```

---

### Task 1: Mensagens e enquadramento

**Files:**
- Create: `Sources/AlttabCore/BrowserTab.swift`, `Sources/AlttabCore/BrowserMessage.swift`, `Sources/AlttabCore/NativeMessageCodec.swift`
- Test: `Tests/AlttabCoreTests/BrowserProtocolTests.swift`

**Interfaces:**
- Produces:
  - `public struct BrowserTab: Equatable, Sendable, Codable { id: Int; windowId: Int; title: String; url: String; favIconUrl: String?; active: Bool; audible: Bool; lastAccessed: Double; var host: String }`
  - `public struct TabRef: Equatable, Hashable, Sendable { tabId: Int; windowID: Int; url: String; host: String; favIconURL: String?; audible: Bool }` (`windowID` = janela do **AeroSpace**)
  - `public enum BrowserMessage: Equatable, Sendable { case tabs([BrowserTab]), thumb(tabId: Int, jpegBase64: String, capturedAt: Double), hello, activate(tabId: Int), close(tabId: Int); static func decode(_: Data) throws -> BrowserMessage; func encode() throws -> Data }`
  - `public enum NativeMessageCodec { static let maxLength: Int; static func frame(_: Data) -> Data; struct Reader { init(); mutating func append(_: Data) -> [Data] } }`

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/BrowserProtocolTests.swift`:

```swift
import Foundation
import Testing
@testable import AlttabCore

@Suite struct BrowserMessageTests {
    @Test func decodesTabsFromExtension() throws {
        let json = #"{"type":"tabs","tabs":[{"id":12,"windowId":3,"title":"Pontes de acesso","url":"https://www.desksoft.brusoft.inf.br/pontes","favIconUrl":null,"active":true,"audible":false,"lastAccessed":1760000000000}]}"#
        let message = try BrowserMessage.decode(Data(json.utf8))
        guard case .tabs(let tabs) = message else { Issue.record("não é tabs"); return }
        #expect(tabs == [BrowserTab(id: 12, windowId: 3, title: "Pontes de acesso",
                                    url: "https://www.desksoft.brusoft.inf.br/pontes", favIconUrl: nil,
                                    active: true, audible: false, lastAccessed: 1_760_000_000_000)])
        #expect(tabs[0].host == "desksoft.brusoft.inf.br")
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
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `./scripts/test.sh --filter "BrowserMessageTests|NativeMessageCodecTests"`
Expected: FAIL — `cannot find 'BrowserMessage'` / `'NativeMessageCodec'` / `'BrowserTab'`.

- [ ] **Step 3: Implementar**

`Sources/AlttabCore/BrowserTab.swift`:

```swift
import Foundation

/// Aba como a extensão do Edge descreve.
public struct BrowserTab: Equatable, Sendable, Codable {
    public let id: Int
    public let windowId: Int
    public let title: String
    public let url: String
    public let favIconUrl: String?
    public let active: Bool
    public let audible: Bool
    /// Milissegundos desde 1970 (`tab.lastAccessed` do Chromium).
    public let lastAccessed: Double

    public init(id: Int, windowId: Int, title: String, url: String, favIconUrl: String?,
                active: Bool, audible: Bool, lastAccessed: Double) {
        self.id = id
        self.windowId = windowId
        self.title = title
        self.url = url
        self.favIconUrl = favIconUrl
        self.active = active
        self.audible = audible
        self.lastAccessed = lastAccessed
    }

    /// Domínio sem "www."; páginas internas (`edge://newtab`) devolvem o nome da página.
    public var host: String {
        guard let host = URL(string: url)?.host(), !host.isEmpty else { return "" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// Aba dentro de um item do alternador.
public struct TabRef: Equatable, Hashable, Sendable {
    public let tabId: Int
    /// Janela do **AeroSpace** que contém a aba.
    public let windowID: Int
    public let url: String
    public let host: String
    public let favIconURL: String?
    public let audible: Bool

    public init(tabId: Int, windowID: Int, url: String, host: String, favIconURL: String?, audible: Bool) {
        self.tabId = tabId
        self.windowID = windowID
        self.url = url
        self.host = host
        self.favIconURL = favIconURL
        self.audible = audible
    }
}
```

`Sources/AlttabCore/BrowserMessage.swift`:

```swift
import Foundation

public enum BrowserMessage: Equatable, Sendable {
    // extensão → app
    case tabs([BrowserTab])
    case thumb(tabId: Int, jpegBase64: String, capturedAt: Double)
    // app → extensão
    case hello
    case activate(tabId: Int)
    case close(tabId: Int)

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
        }
        return try JSONEncoder().encode(envelope)
    }
}
```

`Sources/AlttabCore/NativeMessageCodec.swift`:

```swift
import Foundation

/// Enquadramento do Native Messaging: 4 bytes little-endian com o tamanho + o JSON.
/// Usado também no socket entre o alttab-host e o app.
public enum NativeMessageCodec {
    public static let maxLength = 64 * 1024 * 1024

    public static func frame(_ payload: Data) -> Data {
        var length = UInt32(payload.count).littleEndian
        var framed = Data(bytes: &length, count: 4)
        framed.append(payload)
        return framed
    }

    public struct Reader: Sendable {
        private var buffer = Data()

        public init() {}

        /// Acumula o pedaço lido e devolve os frames completos.
        /// Um tamanho absurdo descarta o buffer (o próximo frame bem formado volta a funcionar).
        public mutating func append(_ chunk: Data) -> [Data] {
            buffer.append(chunk)
            var payloads: [Data] = []
            while buffer.count >= 4 {
                let length = buffer.prefix(4).withUnsafeBytes { Int(UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self))) }
                guard length <= NativeMessageCodec.maxLength else {
                    buffer.removeAll()
                    break
                }
                guard buffer.count >= 4 + length else { break }
                payloads.append(Data(buffer.dropFirst(4).prefix(length)))
                buffer = Data(buffer.dropFirst(4 + length))
            }
            return payloads
        }
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `./scripts/test.sh --filter "BrowserMessageTests|NativeMessageCodecTests"`
Expected: PASS (11 testes).

- [ ] **Step 5: Commit**

```bash
git add Sources/AlttabCore Tests/AlttabCoreTests/BrowserProtocolTests.swift
git commit -F - <<'EOF'
feat: mensagens e enquadramento da ponte com o Edge

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 2: Abas viram itens do alternador

**Files:**
- Create: `Sources/AlttabCore/TabComposer.swift`
- Modify: `Sources/AlttabCore/WindowItem.swift`, `Sources/AlttabCore/SwitcherModel.swift`
- Test: `Tests/AlttabCoreTests/TabComposerTests.swift`

**Interfaces:**
- Consumes: `BrowserTab`, `TabRef` (Task 1); `WindowItem`, `SwitcherModel` (Plano 1).
- Produces:
  - `WindowItem.init(id:pid:appName:bundleID:title:workspace:tab: TabRef? = nil)`; `WindowItem.tab: TabRef?`; `WindowItem.windowKey: Int` (= `tab?.windowID ?? id`)
  - `public enum TabComposer { static let edgeBundleID: String; static func itemID(forTab: Int) -> Int; static func match(edgeWindows: [WindowItem], tabs: [BrowserTab]) -> [Int: Int]; static func compose(windows: [WindowItem], tabs: [BrowserTab]) -> [WindowItem] }`
  - `SwitcherModel.init`: seleção inicial = primeiro item cuja `windowKey` difere do item 0; `matches` também procura em `tab?.host`.

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/TabComposerTests.swift`:

```swift
import Testing
@testable import AlttabCore

private func win(_ id: Int, _ ws: String, _ title: String, edge: Bool = false) -> WindowItem {
    WindowItem(id: id, pid: edge ? 99 : 1, appName: edge ? "Microsoft Edge" : "Warp",
               bundleID: edge ? TabComposer.edgeBundleID : "dev.warp.Warp-Stable", title: title, workspace: ws)
}

private func tab(_ id: Int, window: Int, _ title: String, active: Bool = false, at: Double, audible: Bool = false) -> BrowserTab {
    BrowserTab(id: id, windowId: window, title: title, url: "https://site\(id).com/x", favIconUrl: nil,
               active: active, audible: audible, lastAccessed: at)
}

@Suite struct TabComposerTests {
    @Test func itemIDIsNegativeAndUnique() {
        #expect(TabComposer.itemID(forTab: 0) == -1)
        #expect(TabComposer.itemID(forTab: 41) == -42)
    }

    @Test func singleEdgeWindowGetsAllTabs() {
        let windows = [win(613, "4", "ALT TAB"), win(297, "10", "Pontes — Microsoft Edge", edge: true)]
        let tabs = [tab(1, window: 5, "Pontes", active: true, at: 30), tab(2, window: 5, "YouTube", at: 20)]
        #expect(TabComposer.match(edgeWindows: [windows[1]], tabs: tabs) == [5: 297])
    }

    @Test func twoEdgeWindowsMatchByActiveTabTitle() {
        let edgeA = win(297, "10", "Pontes de acesso — Microsoft Edge", edge: true)
        let edgeB = win(300, "2", "(107) League - YouTube - Áudio em reprodução — Microsoft Edge", edge: true)
        let tabs = [tab(1, window: 5, "Pontes de acesso", active: true, at: 30),
                    tab(2, window: 8, "(107) League - YouTube", active: true, at: 40),
                    tab(3, window: 8, "Outra", at: 10)]
        #expect(TabComposer.match(edgeWindows: [edgeA, edgeB], tabs: tabs) == [5: 297, 8: 300])
    }

    @Test func composeReplacesEdgeWindowWithTabsInPlaceNewestFirst() {
        let windows = [win(613, "4", "ALT TAB"), win(297, "10", "Pontes — Microsoft Edge", edge: true), win(252, "2", "XML")]
        let tabs = [tab(1, window: 5, "Pontes", active: true, at: 30),
                    tab(2, window: 5, "YouTube", at: 50, audible: true),
                    tab(3, window: 5, "EvoDesk", at: 10)]
        let items = TabComposer.compose(windows: windows, tabs: tabs)
        #expect(items.map(\.id) == [613, -3, -2, -4, 252])
        #expect(items[1].workspace == "10")
        #expect(items[1].tab == TabRef(tabId: 2, windowID: 297, url: "https://site2.com/x", host: "site2.com",
                                       favIconURL: nil, audible: true))
        #expect(items[1].displayTitle == "YouTube")
    }

    @Test func unmatchedEdgeWindowStaysAsWindow() {
        let windows = [win(297, "10", "Algo — Microsoft Edge", edge: true), win(300, "2", "Outra — Microsoft Edge", edge: true)]
        let tabs = [tab(1, window: 5, "Nada a ver", active: true, at: 1)]
        #expect(TabComposer.compose(windows: windows, tabs: tabs).map(\.id) == [297, 300])
    }

    @Test func noTabsKeepsWindows() {
        let windows = [win(613, "4", "ALT TAB"), win(297, "10", "X — Microsoft Edge", edge: true)]
        #expect(TabComposer.compose(windows: windows, tabs: []) == windows)
    }

    @Test func quickSwitchFromEdgeSkipsSiblingTabs() {
        // Edge na frente: os dois primeiros itens são abas da mesma janela.
        let windows = [win(297, "10", "Pontes — Microsoft Edge", edge: true), win(613, "4", "ALT TAB")]
        let tabs = [tab(1, window: 5, "Pontes", active: true, at: 30), tab(2, window: 5, "YouTube", at: 20)]
        let model = SwitcherModel(windows: TabComposer.compose(windows: windows, tabs: tabs), currentWorkspace: "10")
        #expect(model.selectedID == 613)
    }

    @Test func searchFindsTabByHost() {
        let windows = [win(297, "10", "Pontes — Microsoft Edge", edge: true)]
        let tabs = [tab(1, window: 5, "Pontes", active: true, at: 30), tab(2, window: 5, "Vídeo", at: 20)]
        var model = SwitcherModel(windows: TabComposer.compose(windows: windows, tabs: tabs), currentWorkspace: "10")
        model.setQuery("site2")
        #expect(model.visible.map(\.id) == [-3])
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `./scripts/test.sh --filter TabComposerTests`
Expected: FAIL — `cannot find 'TabComposer'` / argumento `tab` inexistente.

- [ ] **Step 3: Implementar**

Em `Sources/AlttabCore/WindowItem.swift`, trocar a struct `WindowItem` inteira por:

```swift
public struct WindowItem: Equatable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let pid: Int32
    public let appName: String
    public let bundleID: String?
    public let title: String
    public let workspace: String
    /// Preenchido quando o item é uma aba do navegador (id negativo, ver `TabComposer.itemID`).
    public let tab: TabRef?

    public init(id: Int, pid: Int32, appName: String, bundleID: String?, title: String, workspace: String,
                tab: TabRef? = nil) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.workspace = workspace
        self.tab = tab
    }

    /// Janela do AeroSpace a que o item pertence (a própria, ou a janela do navegador da aba).
    public var windowKey: Int { tab?.windowID ?? id }

    /// Título sem o sufixo do navegador; cai no nome do app (ou no domínio da aba) quando não há título.
    public var displayTitle: String {
        if let tab { return title.isEmpty ? tab.host : title }
        for suffix in [" — Microsoft Edge", " - Microsoft Edge"] where title.hasSuffix(suffix) {
            return String(title.dropLast(suffix.count))
        }
        return title.isEmpty ? appName : title
    }
}
```

`Sources/AlttabCore/TabComposer.swift`:

```swift
public enum TabComposer {
    public static let edgeBundleID = "com.microsoft.edgemac"

    public static func itemID(forTab tabId: Int) -> Int { -(tabId + 1) }

    /// Liga cada janela do navegador (windowId da extensão) a uma janela do Edge no AeroSpace.
    /// O título da janela no AeroSpace começa com o título da aba ativa ("… — Microsoft Edge",
    /// às vezes com " - Áudio em reprodução" no meio). Com uma janela de cada lado, liga direto.
    public static func match(edgeWindows: [WindowItem], tabs: [BrowserTab]) -> [Int: Int] {
        let browserWindows = Dictionary(grouping: tabs, by: \.windowId)
        var result: [Int: Int] = [:]
        var free = edgeWindows
        for (browserWindow, windowTabs) in browserWindows {
            guard let active = windowTabs.first(where: \.active) ?? windowTabs.max(by: { $0.lastAccessed < $1.lastAccessed }),
                  !active.title.isEmpty,
                  let index = free.firstIndex(where: { $0.title.hasPrefix(active.title) }) else { continue }
            result[browserWindow] = free.remove(at: index).id
        }
        let unmatched = browserWindows.keys.filter { result[$0] == nil }
        if unmatched.count == 1, free.count == 1 { result[unmatched[0]] = free[0].id }
        return result
    }

    /// Troca cada janela do Edge reconhecida pelas abas dela, na mesma posição da ordem de uso,
    /// da aba usada mais recentemente para a mais antiga.
    public static func compose(windows: [WindowItem], tabs: [BrowserTab]) -> [WindowItem] {
        guard !tabs.isEmpty else { return windows }
        let edgeWindows = windows.filter { $0.bundleID == edgeBundleID }
        let mapping = match(edgeWindows: edgeWindows, tabs: tabs)
        let browserWindowFor = Dictionary(uniqueKeysWithValues: mapping.map { ($1, $0) })
        return windows.flatMap { window -> [WindowItem] in
            guard let browserWindow = browserWindowFor[window.id] else { return [window] }
            return tabs.filter { $0.windowId == browserWindow }
                .sorted { $0.lastAccessed > $1.lastAccessed }
                .map { tab in
                    WindowItem(id: itemID(forTab: tab.id), pid: window.pid, appName: window.appName,
                               bundleID: window.bundleID, title: tab.title, workspace: window.workspace,
                               tab: TabRef(tabId: tab.id, windowID: window.id, url: tab.url, host: tab.host,
                                           favIconURL: tab.favIconUrl, audible: tab.audible))
                }
        }
    }
}
```

Em `Sources/AlttabCore/SwitcherModel.swift`, trocar a linha da seleção inicial no `init`:

```swift
        selectedID = windows.count > 1 ? windows[1].id : windows.first?.id
```

por:

```swift
        // Option+Tab rápido vai para a janela anterior — pula as outras abas da janela atual.
        let current = windows.first?.windowKey
        selectedID = windows.dropFirst().first { $0.windowKey != current }?.id ?? windows.first?.id
```

e, em `matches`, trocar:

```swift
        return [item.displayTitle, item.appName].contains { $0.range(of: q, options: searchOptions) != nil }
```

por:

```swift
        return [item.displayTitle, item.appName, item.tab?.host ?? ""]
            .contains { $0.range(of: q, options: searchOptions) != nil }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `./scripts/test.sh`
Expected: PASS — suíte inteira (as 67 do Plano 1 + 8 novas). A troca da seleção inicial não pode quebrar `initialSelectionIsPreviousWindow` nem `singleWindowSelectsItself`.

- [ ] **Step 5: Commit**

```bash
git add Sources/AlttabCore Tests/AlttabCoreTests/TabComposerTests.swift
git commit -F - <<'EOF'
feat: abas do Edge viram itens do alternador na posição da janela

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 3: Socket Unix e caminho da ponte

**Files:**
- Create: `Sources/AlttabCore/UnixSocket.swift`, `Sources/AlttabCore/BridgePaths.swift`
- Test: `Tests/AlttabCoreTests/UnixSocketTests.swift`

**Interfaces:**
- Produces:
  - `public final class UnixSocket: @unchecked Sendable { static func listen(path: String) throws -> UnixSocket; static func connect(path: String) throws -> UnixSocket; func accept() throws -> UnixSocket; func write(_: Data) throws; func read(max: Int = 65536) throws -> Data /* vazio = fechado */; func close() }`
  - `public enum BridgePaths { static var directory: URL; static var socket: String }`

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/UnixSocketTests.swift`:

```swift
import Foundation
import Testing
@testable import AlttabCore

@Suite(.serialized) struct UnixSocketTests {
    private func tempPath() -> String {
        "/private/tmp/alttab-test-\(UUID().uuidString.prefix(8)).sock"
    }

    @Test func clientFrameArrivesAtServer() throws {
        let path = tempPath()
        let server = try UnixSocket.listen(path: path)
        defer { server.close(); unlink(path) }
        let payload = NativeMessageCodec.frame(Data("ola".utf8))
        DispatchQueue.global().async {
            let client = try? UnixSocket.connect(path: path)
            try? client?.write(payload)
            client?.close()
        }
        let connection = try server.accept()
        defer { connection.close() }
        var reader = NativeMessageCodec.Reader()
        var received: [Data] = []
        while received.isEmpty {
            let chunk = try connection.read()
            if chunk.isEmpty { break }
            received += reader.append(chunk)
        }
        #expect(received == [Data("ola".utf8)])
    }

    @Test func readReturnsEmptyWhenPeerCloses() throws {
        let path = tempPath()
        let server = try UnixSocket.listen(path: path)
        defer { server.close(); unlink(path) }
        DispatchQueue.global().async { (try? UnixSocket.connect(path: path))?.close() }
        let connection = try server.accept()
        defer { connection.close() }
        #expect(try connection.read().isEmpty)
    }

    @Test func connectToMissingSocketThrows() {
        #expect(throws: (any Error).self) { try UnixSocket.connect(path: "/private/tmp/alttab-nao-existe.sock") }
    }

    @Test func listenReplacesStaleSocketFile() throws {
        let path = tempPath()
        FileManager.default.createFile(atPath: path, contents: Data("velho".utf8))
        let server = try UnixSocket.listen(path: path)
        server.close()
        unlink(path)
    }

    @Test func socketPathFitsSunPath() {
        #expect(BridgePaths.socket.utf8.count < 104)
        #expect(BridgePaths.socket.hasSuffix("/Library/Application Support/alttab/browser.sock"))
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `./scripts/test.sh --filter UnixSocketTests`
Expected: FAIL — `cannot find 'UnixSocket'` / `'BridgePaths'`.

- [ ] **Step 3: Implementar**

`Sources/AlttabCore/BridgePaths.swift`:

```swift
import Foundation

public enum BridgePaths {
    public static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/alttab", isDirectory: true)
    }

    public static var socket: String {
        directory.appendingPathComponent("browser.sock").path
    }
}
```

`Sources/AlttabCore/UnixSocket.swift`:

```swift
import Darwin
import Foundation

/// Socket Unix bloqueante, mínimo: um servidor no app e um cliente no alttab-host.
public final class UnixSocket: @unchecked Sendable {
    public enum Failure: Error {
        case system(String, Int32)
        case pathTooLong
    }

    public let fd: Int32

    private init(fd: Int32) {
        self.fd = fd
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    }

    private static func address(_ path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { throw Failure.pathTooLong }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
        return address
    }

    private static func makeSocket() throws -> Int32 {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw Failure.system("socket", errno) }
        return fd
    }

    public static func listen(path: String) throws -> UnixSocket {
        unlink(path)
        let fd = try makeSocket()
        var address = try address(path)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else {
            let error = errno
            Darwin.close(fd)
            throw Failure.system("bind", error)
        }
        guard Darwin.listen(fd, 4) == 0 else {
            let error = errno
            Darwin.close(fd)
            throw Failure.system("listen", error)
        }
        return UnixSocket(fd: fd)
    }

    public static func connect(path: String) throws -> UnixSocket {
        let fd = try makeSocket()
        var address = try address(path)
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            let error = errno
            Darwin.close(fd)
            throw Failure.system("connect", error)
        }
        return UnixSocket(fd: fd)
    }

    public func accept() throws -> UnixSocket {
        let client = Darwin.accept(fd, nil, nil)
        guard client >= 0 else { throw Failure.system("accept", errno) }
        return UnixSocket(fd: client)
    }

    public func write(_ data: Data) throws {
        try data.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let written = Darwin.write(fd, raw.baseAddress! + offset, raw.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw Failure.system("write", errno)
                }
                offset += written
            }
        }
    }

    /// Bloqueia até chegar algo; devolve vazio quando o outro lado fechou.
    public func read(max: Int = 65536) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: max)
        while true {
            let count = Darwin.read(fd, &buffer, max)
            if count < 0 {
                if errno == EINTR { continue }
                throw Failure.system("read", errno)
            }
            return Data(buffer.prefix(count))
        }
    }

    public func close() {
        Darwin.close(fd)
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `./scripts/test.sh --filter UnixSocketTests`
Expected: PASS (5 testes).

- [ ] **Step 5: Commit**

```bash
git add Sources/AlttabCore Tests/AlttabCoreTests/UnixSocketTests.swift
git commit -F - <<'EOF'
feat: socket Unix da ponte entre o Edge e o app

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 4: Layout da coluna do Edge

**Files:**
- Create: `Sources/AlttabCore/EdgeColumnLayout.swift`
- Test: `Tests/AlttabCoreTests/EdgeColumnLayoutTests.swift`

**Interfaces:**
- Produces: `public enum EdgeColumnLayout: Equatable, Sendable { case cards, peek(visible: Int, hidden: Int), heroGrid(columns: Int); static func mode(tabCount: Int, focused: Bool, searching: Bool) -> EdgeColumnLayout; static func miniThumbHeight(tabCount: Int, columns: Int, available: Double = 300) -> Double; static func focusWeight(for: EdgeColumnLayout) -> Double }`

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/EdgeColumnLayoutTests.swift`:

```swift
import Testing
@testable import AlttabCore

@Suite struct EdgeColumnLayoutTests {
    @Test func fourOrLessAreCards() {
        #expect(EdgeColumnLayout.mode(tabCount: 4, focused: true, searching: false) == .cards)
        #expect(EdgeColumnLayout.mode(tabCount: 0, focused: false, searching: false) == .cards)
    }

    @Test func unfocusedShowsThreePlusRest() {
        #expect(EdgeColumnLayout.mode(tabCount: 20, focused: false, searching: false) == .peek(visible: 3, hidden: 17))
    }

    @Test func unfocusedWhileSearchingShowsAllHits() {
        #expect(EdgeColumnLayout.mode(tabCount: 6, focused: false, searching: true) == .cards)
    }

    @Test(arguments: [(5, 3), (9, 3), (10, 5), (20, 5), (21, 6), (40, 6)])
    func focusedGridColumns(count: Int, columns: Int) {
        #expect(EdgeColumnLayout.mode(tabCount: count, focused: true, searching: false) == .heroGrid(columns: columns))
    }

    @Test func miniThumbHeightFollowsPrototype() {
        #expect(EdgeColumnLayout.miniThumbHeight(tabCount: 20, columns: 5) == 53)
        #expect(EdgeColumnLayout.miniThumbHeight(tabCount: 5, columns: 3) == 64)
        #expect(EdgeColumnLayout.miniThumbHeight(tabCount: 40, columns: 6) == 26)
    }

    @Test func focusWeightGrowsWithGrid() {
        #expect(EdgeColumnLayout.focusWeight(for: .cards) == 2.7)
        #expect(abs(EdgeColumnLayout.focusWeight(for: .heroGrid(columns: 5)) - 4.7) < 1e-9)
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `./scripts/test.sh --filter EdgeColumnLayoutTests`
Expected: FAIL — `cannot find 'EdgeColumnLayout'`.

- [ ] **Step 3: Implementar**

`Sources/AlttabCore/EdgeColumnLayout.swift`:

```swift
public enum EdgeColumnLayout: Equatable, Sendable {
    /// Cartões normais (poucas abas, ou resultados de busca numa coluna fora de foco).
    case cards
    /// Fora de foco: as mais recentes + um cartão empilhado "+N".
    case peek(visible: Int, hidden: Int)
    /// Em foco: destaque grande da aba selecionada + grade fixa de miniaturas.
    case heroGrid(columns: Int)

    public static let peekCount = 3

    public static func mode(tabCount: Int, focused: Bool, searching: Bool) -> EdgeColumnLayout {
        guard tabCount > 4 else { return .cards }
        if focused { return .heroGrid(columns: tabCount <= 9 ? 3 : tabCount <= 20 ? 5 : 6) }
        if searching { return .cards }
        return .peek(visible: peekCount, hidden: tabCount - peekCount)
    }

    public static func miniThumbHeight(tabCount: Int, columns: Int, available: Double = 300) -> Double {
        let rows = max(1, (tabCount + max(columns, 1) - 1) / max(columns, 1))
        return min(64, max(26, (available / Double(rows)).rounded(.down) - 22))
    }

    /// Peso da coluna em foco no `ColumnLayout`: a grade precisa de mais largura.
    public static func focusWeight(for mode: EdgeColumnLayout) -> Double {
        if case .heroGrid(let columns) = mode { return 2.2 + Double(columns) * 0.5 }
        return 2.7
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `./scripts/test.sh --filter EdgeColumnLayoutTests`
Expected: PASS (11 testes, contando os 6 casos parametrizados).

- [ ] **Step 5: Commit**

```bash
git add Sources/AlttabCore/EdgeColumnLayout.swift Tests/AlttabCoreTests/EdgeColumnLayoutTests.swift
git commit -F - <<'EOF'
feat: regras de layout da coluna do Edge

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 5: Extensão do Edge

**Files:**
- Create: `extension/manifest.json`, `extension/lib.js`, `extension/lib.test.js`, `extension/background.js`

**Interfaces:**
- Consumes: formato de mensagens das Global Constraints.
- Produces: extensão carregável sem empacotar, ID `npgoecidghckmkdhakalhchnaebjdhlc`, que conversa com o host `br.inf.brusoft.alttab`.

- [ ] **Step 1: Escrever os testes das funções puras**

`extension/lib.test.js`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { tabPayload, tabsMessage, thumbSize, capturable } from "./lib.js";

test("tabPayload normaliza campos que o Chromium pode omitir", () => {
  assert.deepEqual(tabPayload({ id: 3, windowId: 1, active: true }), {
    id: 3, windowId: 1, title: "", url: "", favIconUrl: null, active: true, audible: false, lastAccessed: 0,
  });
});

test("tabPayload usa pendingUrl enquanto a aba carrega", () => {
  assert.equal(tabPayload({ id: 1, windowId: 1, pendingUrl: "https://a.com" }).url, "https://a.com");
});

test("tabsMessage descarta abas sem id válido", () => {
  const message = tabsMessage([{ id: -1, windowId: 1 }, { id: 2, windowId: 1, title: "x" }]);
  assert.equal(message.type, "tabs");
  assert.deepEqual(message.tabs.map((t) => t.id), [2]);
});

test("thumbSize reduz para 480 de largura mantendo a proporção", () => {
  assert.deepEqual(thumbSize(2544, 1393), { width: 480, height: 263 });
  assert.deepEqual(thumbSize(400, 300), { width: 400, height: 300 });
});

test("capturable recusa páginas internas e vazias", () => {
  assert.equal(capturable("https://desk.evotalks.ai/x"), true);
  assert.equal(capturable("file:///tmp/a.html"), true);
  assert.equal(capturable("edge://newtab/"), false);
  assert.equal(capturable("about:blank"), false);
  assert.equal(capturable(undefined), false);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd extension && node --test lib.test.js; cd ..`
Expected: FAIL — `Cannot find module` / `lib.js`.

- [ ] **Step 3: Implementar as funções puras**

`extension/lib.js`:

```js
// Funções puras da extensão (testadas com `node --test`).

export function tabPayload(tab) {
  return {
    id: tab.id,
    windowId: tab.windowId,
    title: tab.title ?? "",
    url: tab.url ?? tab.pendingUrl ?? "",
    favIconUrl: tab.favIconUrl ?? null,
    active: Boolean(tab.active),
    audible: Boolean(tab.audible),
    lastAccessed: tab.lastAccessed ?? 0,
  };
}

export function tabsMessage(tabs) {
  return { type: "tabs", tabs: tabs.filter((t) => Number.isInteger(t.id) && t.id >= 0).map(tabPayload) };
}

export function thumbSize(width, height, maxWidth = 480) {
  if (width <= maxWidth) return { width, height };
  return { width: maxWidth, height: Math.round((height * maxWidth) / width) };
}

/** `captureVisibleTab` falha em páginas internas do navegador; nem tenta. */
export function capturable(url) {
  return /^(https?|file):/.test(url ?? "");
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd extension && node --test lib.test.js; cd ..`
Expected: `# pass 5`, `# fail 0`.

- [ ] **Step 5: Manifest e service worker**

`extension/manifest.json`:

```json
{
  "manifest_version": 3,
  "name": "Alttab",
  "version": "0.1.0",
  "description": "Abas e miniaturas para o alternador Option+Tab.",
  "key": "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwBBCWWI0FTRe4+91A3amXgjubmqnrE9B3XgfzXAV7/fYjqJy+Epqfhbf+AxFQ2ijljmt6UqPSgto9WpZ8x8xutMNnt/bOgEoW4l7FiK5j4FHD9v/cx3DR5kcApfUbIYK4VOLVAD21Fz9Ku2k7wdhJoKTHbgJNgRzeF/0WDwrDDZuP7QoRhykWK2Ee/RkUGS2YDMYFRd9w5g/e14G54yKWK7LRZkmon8+Bqr11dQYrKp87mj+O9lc1EyZeg4N4gMHRpQI8EMCU2QBNUtIHC1UZ/OP3ua9695WarvLT+myPevz06VYfRf3zXMsIhgpQbE2lMO8aEo2MNtNBi4kuV+pKQIDAQAB",
  "permissions": ["tabs", "nativeMessaging"],
  "host_permissions": ["<all_urls>"],
  "background": { "service_worker": "background.js", "type": "module" }
}
```

`extension/background.js`:

```js
import { tabsMessage, thumbSize, capturable } from "./lib.js";

const HOST = "br.inf.brusoft.alttab";
let port = null;
let tabsTimer = null;
const captureTimers = new Map();

function connect() {
  try {
    port = chrome.runtime.connectNative(HOST);
  } catch {
    port = null;
    setTimeout(connect, 5000);
    return;
  }
  port.onMessage.addListener(onCommand);
  port.onDisconnect.addListener(() => {
    port = null;
    setTimeout(connect, 5000);
  });
  sendTabs();
}

function post(message) {
  if (!port) return;
  try {
    port.postMessage(message);
  } catch {
    port = null;
  }
}

function sendTabs() {
  clearTimeout(tabsTimer);
  tabsTimer = setTimeout(async () => post(tabsMessage(await chrome.tabs.query({}))), 150);
}

function scheduleCapture(windowId, delay = 350) {
  clearTimeout(captureTimers.get(windowId));
  captureTimers.set(windowId, setTimeout(() => captureActive(windowId), delay));
}

async function captureActive(windowId) {
  const [tab] = await chrome.tabs.query({ active: true, windowId });
  if (!tab || !capturable(tab.url)) return;
  try {
    const dataUrl = await chrome.tabs.captureVisibleTab(windowId, { format: "jpeg", quality: 70 });
    const bitmap = await createImageBitmap(await (await fetch(dataUrl)).blob());
    const size = thumbSize(bitmap.width, bitmap.height);
    const canvas = new OffscreenCanvas(size.width, size.height);
    canvas.getContext("2d").drawImage(bitmap, 0, 0, size.width, size.height);
    const jpeg = await canvas.convertToBlob({ type: "image/jpeg", quality: 0.72 });
    post({ type: "thumb", tabId: tab.id, jpegBase64: await toBase64(jpeg), capturedAt: Date.now() });
  } catch {
    // Janela minimizada, página protegida ou limite de capturas por segundo: segue sem foto.
  }
}

async function toBase64(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

async function onCommand(message) {
  if (message.type === "hello") {
    sendTabs();
    for (const window of await chrome.windows.getAll()) scheduleCapture(window.id, 50);
  } else if (message.type === "activate") {
    try {
      const tab = await chrome.tabs.update(message.tabId, { active: true });
      await chrome.windows.update(tab.windowId, { focused: true });
    } catch {}
  } else if (message.type === "close") {
    chrome.tabs.remove(message.tabId).catch(() => {});
  }
}

for (const event of [chrome.tabs.onCreated, chrome.tabs.onRemoved, chrome.tabs.onMoved,
                     chrome.tabs.onAttached, chrome.tabs.onDetached]) {
  event.addListener(sendTabs);
}
chrome.tabs.onUpdated.addListener((_id, change, tab) => {
  sendTabs();
  if (change.status === "complete" && tab.active) scheduleCapture(tab.windowId, 400);
});
chrome.tabs.onActivated.addListener(({ windowId }) => {
  sendTabs();
  scheduleCapture(windowId);
});
chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId !== chrome.windows.WINDOW_ID_NONE) scheduleCapture(windowId);
});
chrome.runtime.onStartup.addListener(() => {});
connect();
```

- [ ] **Step 6: Commit**

```bash
git add extension
git commit -F - <<'EOF'
feat: extensão do Edge que envia abas e miniaturas

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 6: `alttab-host`, ponte no app e instalação do host

**Files:**
- Modify: `Package.swift`, `scripts/build-app.sh`, `scripts/install.sh`
- Create: `Sources/AlttabHost/main.swift`, `Sources/AlttabApp/BrowserBridge.swift`
- Modify: `Sources/AlttabApp/AppDelegate.swift`

**Interfaces:**
- Consumes: `UnixSocket`, `NativeMessageCodec`, `BrowserMessage`, `BridgePaths` (Tasks 1, 3).
- Produces:
  - `@MainActor @Observable final class BrowserStore { tabs: [BrowserTab]; thumbnails: [Int: CGImage]; capturedAt: [Int: Date]; connected: Bool }` (chaves = `tabId`)
  - `final class BrowserBridge: @unchecked Sendable { init(store: BrowserStore); func start(); func send(_: BrowserMessage) }`
  - `AppDelegate` passa a ter `let browser = BrowserStore()` e `private lazy var bridge = BrowserBridge(store: browser)`.

- [ ] **Step 1: Alvo do host**

Em `Package.swift`, depois da linha do `AlttabApp`, adicionar:

```swift
        .executableTarget(name: "AlttabHost", dependencies: ["AlttabCore"]),
```

`Sources/AlttabHost/main.swift`:

```swift
import AlttabCore
import Foundation

// Ponte iniciada pelo Edge (Native Messaging): stdin/stdout ⇄ socket Unix do app Alttab.
// Sem o app rodando, as mensagens do navegador são descartadas e a conexão é retentada a cada 1 s.

final class BrowserOutput: @unchecked Sendable {
    private let lock = NSLock()
    func send(_ payload: Data) {
        lock.lock()
        defer { lock.unlock() }
        FileHandle.standardOutput.write(NativeMessageCodec.frame(payload))
    }
}

final class AppLink: @unchecked Sendable {
    private let lock = NSLock()
    private var socket: UnixSocket?
    func set(_ newSocket: UnixSocket?) {
        lock.lock()
        socket = newSocket
        lock.unlock()
    }
    func send(_ payload: Data) {
        lock.lock()
        let current = socket
        lock.unlock()
        try? current?.write(NativeMessageCodec.frame(payload))
    }
}

func runHost() -> Never {
    let browser = BrowserOutput()
    let app = AppLink()
    let hello = (try? BrowserMessage.hello.encode()) ?? Data()

    Thread.detachNewThread {
        while true {
            guard let socket = try? UnixSocket.connect(path: BridgePaths.socket) else {
                Thread.sleep(forTimeInterval: 1)
                continue
            }
            app.set(socket)
            browser.send(hello) // a extensão reenvia abas e miniaturas
            var reader = NativeMessageCodec.Reader()
            while let chunk = try? socket.read(), !chunk.isEmpty {
                reader.append(chunk).forEach(browser.send)
            }
            app.set(nil)
            socket.close()
            Thread.sleep(forTimeInterval: 1)
        }
    }

    var reader = NativeMessageCodec.Reader()
    while true {
        let chunk = FileHandle.standardInput.availableData
        if chunk.isEmpty { exit(0) } // o Edge fechou a porta
        reader.append(chunk).forEach(app.send)
    }
}

runHost()
```

- [ ] **Step 2: Ponte no app**

`Sources/AlttabApp/BrowserBridge.swift`:

```swift
import AlttabCore
import AppKit
import ImageIO
import Observation

@MainActor @Observable
final class BrowserStore {
    private(set) var tabs: [BrowserTab] = []
    /// Miniaturas por `tabId`.
    private(set) var thumbnails: [Int: CGImage] = [:]
    private(set) var capturedAt: [Int: Date] = [:]
    private(set) var connected = false

    func connectionChanged(_ isConnected: Bool) {
        connected = isConnected
        if !isConnected { tabs = [] }
    }

    func setTabs(_ newTabs: [BrowserTab]) {
        tabs = newTabs
        let live = Set(newTabs.map(\.id))
        thumbnails = thumbnails.filter { live.contains($0.key) }
        capturedAt = capturedAt.filter { live.contains($0.key) }
    }

    func setThumbnail(tabId: Int, image: CGImage, at date: Date) {
        thumbnails[tabId] = image
        capturedAt[tabId] = date
    }
}

/// Servidor do socket Unix: recebe o alttab-host (um Edge por vez) e repassa comandos.
final class BrowserBridge: @unchecked Sendable {
    private let store: BrowserStore
    private let lock = NSLock()
    private var client: UnixSocket?

    init(store: BrowserStore) {
        self.store = store
    }

    func start() {
        let thread = Thread { [weak self] in self?.serve() }
        thread.name = "alttab.browser-bridge"
        thread.start()
    }

    func send(_ message: BrowserMessage) {
        guard let data = try? message.encode() else { return }
        lock.lock()
        let current = client
        lock.unlock()
        try? current?.write(NativeMessageCodec.frame(data))
    }

    private func onMain(_ work: @escaping @MainActor (BrowserStore) -> Void) {
        let store = self.store
        DispatchQueue.main.async { MainActor.assumeIsolated { work(store) } }
    }

    private func serve() {
        try? FileManager.default.createDirectory(at: BridgePaths.directory, withIntermediateDirectories: true)
        guard let server = try? UnixSocket.listen(path: BridgePaths.socket) else { return }
        while true {
            guard let connection = try? server.accept() else { continue }
            lock.lock()
            client?.close()
            client = connection
            lock.unlock()
            onMain { $0.connectionChanged(true) }

            var reader = NativeMessageCodec.Reader()
            while let chunk = try? connection.read(), !chunk.isEmpty {
                reader.append(chunk).forEach(handle)
            }

            lock.lock()
            let wasCurrent = client === connection
            if wasCurrent { client = nil }
            lock.unlock()
            connection.close()
            if wasCurrent { onMain { $0.connectionChanged(false) } }
        }
    }

    private func handle(_ payload: Data) {
        guard let message = try? BrowserMessage.decode(payload) else { return }
        switch message {
        case .tabs(let tabs):
            onMain { $0.setTabs(tabs) }
        case let .thumb(tabId, jpeg, capturedAt):
            guard let data = Data(base64Encoded: jpeg),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
            nonisolated(unsafe) let decoded = image
            let date = Date(timeIntervalSince1970: capturedAt / 1000)
            onMain { $0.setThumbnail(tabId: tabId, image: decoded, at: date) }
        case .hello, .activate, .close:
            break
        }
    }
}
```

- [ ] **Step 3: Ligar no AppDelegate**

Em `Sources/AlttabApp/AppDelegate.swift`, trocar:

```swift
    private lazy var controller = SwitcherController(store: store, thumbs: thumbs)
```

por:

```swift
    let browser = BrowserStore()
    private lazy var bridge = BrowserBridge(store: browser)
    private lazy var controller = SwitcherController(store: store, thumbs: thumbs, browser: browser, bridge: bridge)
```

e, logo antes de `hotkey.onInput = …`, adicionar:

```swift
        bridge.start()
```

e em `menuNeedsUpdate`, depois da linha das janelas/erro do AeroSpace:

```swift
        menu.addItem(disabled(browser.connected ? "Edge: \(browser.tabs.count) abas" : "Edge: extensão desconectada"))
```

(O `SwitcherController` com os parâmetros novos chega na Task 7; nesta task, para compilar, adicionar já em `SwitcherController` as propriedades e o `init` novo:)

```swift
    private let browser: BrowserStore
    private let bridge: BrowserBridge

    init(store: WindowStore, thumbs: WindowThumbs, browser: BrowserStore, bridge: BrowserBridge) {
        self.store = store
        self.thumbs = thumbs
        self.browser = browser
        self.bridge = bridge
        store.onFocusChange = { [weak thumbs] id in
            thumbs?.capture(ids: [id]) { _, _ in }
        }
    }
```

(substituindo o `init(store:thumbs:)` antigo).

- [ ] **Step 4: Build inclui e assina o host**

Em `scripts/build-app.sh`, trocar:

```bash
swift build -c release --product AlttabApp --scratch-path "$SCRATCH"
```

por:

```bash
swift build -c release --product AlttabApp --scratch-path "$SCRATCH"
swift build -c release --product AlttabHost --scratch-path "$SCRATCH"
```

e trocar:

```bash
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --options runtime --timestamp=none --sign "$SIGN_ID" "$APP"
```

por:

```bash
cp "$SCRATCH/release/AlttabHost" "$APP/Contents/MacOS/alttab-host"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --options runtime --timestamp=none --sign "$SIGN_ID" "$APP/Contents/MacOS/alttab-host"
codesign --force --options runtime --timestamp=none --sign "$SIGN_ID" "$APP"
```

- [ ] **Step 5: Instalação registra o host no Edge**

Em `scripts/install.sh`, antes de `open "$HOME/Applications/Alttab.app"`, adicionar:

```bash
HOSTS_DIR="$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
mkdir -p "$HOSTS_DIR"
cat > "$HOSTS_DIR/br.inf.brusoft.alttab.json" <<JSON
{
  "name": "br.inf.brusoft.alttab",
  "description": "Ponte do Alttab com o Edge",
  "path": "$HOME/Applications/Alttab.app/Contents/MacOS/alttab-host",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://npgoecidghckmkdhakalhchnaebjdhlc/"]
}
JSON
```

e no fim:

```bash
echo "Extensão: edge://extensions → Modo de desenvolvedor → Carregar sem compactação → $(pwd)/extension"
```

- [ ] **Step 6: Verificar a ponte sem o Edge**

Run: `./scripts/test.sh 2>&1 | tail -1 && ./scripts/install.sh 2>&1 | tail -2`
Expected: suíte verde; `instalado em ~/Applications/Alttab.app`; arquivo `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/br.inf.brusoft.alttab.json` existe.

Simular o Edge com o próprio host (um `tabs` e ler o `hello` de volta):

```bash
python3 -I - <<'PY'
import json, struct, subprocess, time, os
host = os.path.expanduser("~/Applications/Alttab.app/Contents/MacOS/alttab-host")
p = subprocess.Popen([host], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
size = struct.unpack("<I", p.stdout.read(4))[0]
print("do app:", p.stdout.read(size).decode())
msg = json.dumps({"type": "tabs", "tabs": [{"id": 1, "windowId": 1, "title": "Teste", "url": "https://a.com", "favIconUrl": None, "active": True, "audible": False, "lastAccessed": 1}]}).encode()
p.stdin.write(struct.pack("<I", len(msg)) + msg); p.stdin.flush()
time.sleep(0.5); p.stdin.close(); p.wait(timeout=3); print("host saiu:", p.returncode)
PY
```

Expected: `do app: {"type":"hello"}` e `host saiu: 0`; o menu do Alttab mostra "Edge: 1 abas" enquanto o host está vivo e "Edge: extensão desconectada" depois.

- [ ] **Step 7: Commit**

```bash
git add Package.swift Sources scripts
git commit -F - <<'EOF'
feat: alttab-host e ponte do app com a extensão do Edge

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 7: Abas no alternador (controlador + telas)

**Files:**
- Modify: `Sources/AlttabApp/SwitcherController.swift`, `Sources/AlttabApp/SwitcherPanel.swift`
- Modify: `Sources/AlttabApp/Views/Bits.swift`, `Sources/AlttabApp/Views/WindowCardView.swift`, `Sources/AlttabApp/Views/WorkspaceColumnView.swift`, `Sources/AlttabApp/Views/SwitcherView.swift`
- Create: `Sources/AlttabApp/Views/EdgeTabsView.swift`

**Interfaces:**
- Consumes: `TabComposer`, `EdgeColumnLayout`, `TabRef`, `WindowItem.tab` (Tasks 2, 4); `BrowserStore`, `BrowserBridge` (Task 6).
- Produces: `SwitcherState.browser: BrowserStore?`, `SwitcherState.thumbnail(for:)`, `SwitcherState.capturedAt(for:)`, `SwitcherController.select(_:)`; `SwitcherView(state:controller:width:height:)`; `SwitcherPanel.present(width:height:)`.

- [ ] **Step 1: Controlador**

Em `Sources/AlttabApp/SwitcherController.swift`:

a) Na classe `SwitcherState`, adicionar depois de `var openCount = 0`:

```swift
    /// Fonte das abas do Edge (miniaturas e "visto há" chegam ao vivo enquanto o painel está aberto).
    var browser: BrowserStore?

    func thumbnail(for item: WindowItem) -> CGImage? {
        if let tab = item.tab { return browser?.thumbnails[tab.tabId] }
        return thumbnails[item.id]
    }

    func capturedAt(for item: WindowItem) -> Date? {
        item.tab.flatMap { browser?.capturedAt[$0.tabId] }
    }
```

b) No fim do `init(store:thumbs:browser:bridge:)` (Task 6), adicionar:

```swift
        state.browser = browser
```

c) Adicionar o método:

```swift
    /// Janelas do AeroSpace com as janelas do Edge trocadas pelas abas (se a extensão estiver ligada).
    private func currentItems() -> [WindowItem] {
        browser.connected ? TabComposer.compose(windows: store.mruOrdered, tabs: browser.tabs) : store.mruOrdered
    }

    func select(_ id: Int) {
        state.model.select(id)
    }
```

d) Em `open()`, trocar:

```swift
        state.model = SwitcherModel(windows: store.mruOrdered, currentWorkspace: store.currentWorkspace)
```

por:

```swift
        state.model = SwitcherModel(windows: currentItems(), currentWorkspace: store.currentWorkspace)
```

trocar:

```swift
        thumbs.capture(ids: state.model.windows.map(\.id)) { [weak self] id, image in
```

por:

```swift
        thumbs.capture(ids: state.model.windows.filter { $0.tab == nil }.map(\.id)) { [weak self] id, image in
```

e trocar:

```swift
            state.model.update(windows: store.mruOrdered)
```

por:

```swift
            state.model.update(windows: currentItems())
```

e trocar a criação/apresentação do painel:

```swift
        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1280
        panelWidth = min(1232, screenWidth - 48)
        if panel == nil {
            panel = SwitcherPanel(rootView: SwitcherView(state: state, controller: self, width: panelWidth))
        }
        panel?.present(width: panelWidth)
```

por:

```swift
        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        panelWidth = min(1232, visible.width - 48)
        let panelHeight = min(visible.height - 80, 720)
        if panel == nil {
            panel = SwitcherPanel(rootView: SwitcherView(state: state, controller: self, width: panelWidth, height: panelHeight))
        }
        panel?.present(width: panelWidth, height: panelHeight)
```

e) Trocar o método `commit()` inteiro por:

```swift
    private func commit() {
        let item = state.model.selected
        hide()
        guard let item else { return }
        store.noteFocused(item.windowKey)
        if let tab = item.tab { bridge.send(.activate(tabId: tab.tabId)) }
        let client = self.client
        let windowID = item.windowKey
        Task.detached {
            do {
                try client.focus(windowID: windowID)
            } catch {
                await self.store.refresh()
            }
        }
    }
```

f) Trocar o método `closeWindow(_:)` inteiro por:

```swift
    func closeWindow(_ id: Int) {
        guard let item = state.model.windows.first(where: { $0.id == id }) else { return }
        state.closingID = id
        if let tab = item.tab {
            bridge.send(.close(tabId: tab.tabId))
        } else {
            let client = self.client
            Task.detached { try? client.close(windowID: id) }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(240))
            state.model.remove(id)
            state.closingID = nil
        }
    }
```

- [ ] **Step 2: Painel com altura fixa**

Em `Sources/AlttabApp/SwitcherPanel.swift`, trocar o método `present(width:)` inteiro por:

```swift
    /// Altura fixa por abertura: o conteúdo cresce (coluna em foco, grade do Edge) sem recalcular a janela.
    func present(width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let frame = NSRect(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.midY - height / 2,
                           width: width, height: height)
        setFrame(frame, display: true)
        orderFrontRegardless()
    }
```

- [ ] **Step 3: Peças visuais das abas**

Acrescentar no fim de `Sources/AlttabApp/Views/Bits.swift`:

```swift
struct TabIcon: View {
    let tab: TabRef
    let size: CGFloat

    var body: some View {
        AsyncImage(url: tab.favIconURL.flatMap(URL.init(string:))) { phase in
            if let image = phase.image {
                image.resizable().interpolation(.high)
            } else {
                Text(String(tab.host.prefix(1)).uppercased())
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.32))
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.25))
    }
}

/// Ícone do app para janela; favicon para aba.
struct ItemIcon: View {
    let item: WindowItem
    let size: CGFloat

    var body: some View {
        if let tab = item.tab {
            TabIcon(tab: tab, size: size)
        } else {
            AppIcon(item: item).frame(width: size, height: size)
        }
    }
}

struct AudioBars: View {
    @State private var phase = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 2, height: phase ? [10, 4, 8][index] : [4, 10, 5][index])
                    .animation(.easeInOut(duration: 0.4 + Double(index) * 0.1).repeatForever(autoreverses: true), value: phase)
            }
        }
        .frame(height: 10, alignment: .bottom)
        .onAppear { phase = true }
        .accessibilityLabel("Tocando áudio")
    }
}

struct AgoBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, design: .monospaced))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(.black.opacity(0.55), in: .rect(cornerRadius: 4))
    }
}

enum Ago {
    static func text(_ date: Date?) -> String? {
        guard let date else { return nil }
        if Date.now.timeIntervalSince(date) < 60 { return "agora" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
```

- [ ] **Step 4: Cartão de janela entende aba**

Em `Sources/AlttabApp/Views/WindowCardView.swift`:

a) Depois de `let thumbnail: CGImage?`, adicionar:

```swift
    var capturedAt: Date? = nil
```

b) Trocar a linha do rótulo:

```swift
                AppIcon(item: item).frame(width: 16, height: 16)
```

por:

```swift
                ItemIcon(item: item, size: 16)
```

e, logo depois do `HighlightedText(...)...lineLimit(1)` desse `HStack`, adicionar:

```swift
                if item.tab?.audible == true {
                    Spacer(minLength: 0)
                    AudioBars()
                }
```

c) No placeholder sem miniatura, trocar:

```swift
                AppIcon(item: item).frame(width: 28, height: 28).opacity(0.85)
```

por:

```swift
                ItemIcon(item: item, size: 28).opacity(0.85)
```

d) Logo depois de `.clipShape(.rect(cornerRadius: Theme.thumbRadius))` do `thumb`, adicionar:

```swift
                .overlay(alignment: .bottomTrailing) {
                    if let ago = Ago.text(capturedAt) { AgoBadge(text: ago).padding(5) }
                }
```

- [ ] **Step 5: Coluna do Edge**

`Sources/AlttabApp/Views/EdgeTabsView.swift`:

```swift
import AlttabCore
import SwiftUI

/// Seção de abas de uma coluna: cartões, "+N" ou destaque + grade fixa.
struct EdgeTabsView: View {
    let tabs: [WindowItem]
    let mode: EdgeColumnLayout
    let isFocused: Bool
    let firstIndex: Int
    let state: SwitcherState
    let controller: SwitcherController

    var body: some View {
        switch mode {
        case .cards:
            VStack(spacing: 9) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { offset, tab in card(tab, offset) }
            }
        case let .peek(visible, hidden):
            VStack(spacing: 9) {
                ForEach(Array(tabs.prefix(visible).enumerated()), id: \.element.id) { offset, tab in card(tab, offset) }
                MorePileView(count: hidden) { controller.select(tabs[visible].id) }
            }
        case .heroGrid(let columns):
            let hero = tabs.first { $0.id == state.model.selectedID } ?? tabs[0]
            VStack(alignment: .leading, spacing: 10) {
                TabHeroView(item: hero, thumbnail: state.thumbnail(for: hero), capturedAt: state.capturedAt(for: hero),
                            isClosing: hero.id == state.closingID,
                            onClick: { controller.click(hero.id) }, onClose: { controller.closeWindow(hero.id) })
                    .id(hero.id)
                    .transition(.opacity)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
                    ForEach(tabs) { tab in
                        MiniTabCard(item: tab, isSelected: tab.id == state.model.selectedID,
                                    thumbnail: state.thumbnail(for: tab),
                                    height: EdgeColumnLayout.miniThumbHeight(tabCount: tabs.count, columns: columns),
                                    onHover: { controller.hover(tab.id) }, onClick: { controller.click(tab.id) })
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: state.model.selectedID)
        }
    }

    private func card(_ tab: WindowItem, _ offset: Int) -> some View {
        WindowCardView(
            item: tab,
            isSelected: tab.id == state.model.selectedID,
            isWide: isFocused,
            isClosing: tab.id == state.closingID,
            thumbnail: state.thumbnail(for: tab),
            capturedAt: state.capturedAt(for: tab),
            query: state.model.query,
            appearDelay: Double(firstIndex + offset) * 0.03,
            onHover: { controller.hover(tab.id) },
            onClick: { controller.click(tab.id) },
            onClose: { controller.closeWindow(tab.id) })
    }
}

struct TabHeroView: View {
    let item: WindowItem
    let thumbnail: CGImage?
    let capturedAt: Date?
    let isClosing: Bool
    let onClick: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let thumbnail {
                    Image(decorative: thumbnail, scale: 1).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color(white: 0.12)
                        ItemIcon(item: item, size: 36)
                    }
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: 9))
            .overlay(alignment: .bottomTrailing) {
                if let ago = Ago.text(capturedAt) { AgoBadge(text: ago).padding(8) }
            }
            .overlay(alignment: .topTrailing) { CloseButton(action: onClose).padding(8) }
            HStack(alignment: .top, spacing: 9) {
                ItemIcon(item: item, size: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayTitle)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                    Text(item.tab?.host ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                if item.tab?.audible == true { AudioBars() }
            }
        }
        .padding(8)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.accent))
        .shadow(color: Theme.accent.opacity(0.2), radius: 8)
        .opacity(isClosing ? 0 : 1)
        .scaleEffect(isClosing ? 0.9 : 1)
        .animation(.easeIn(duration: 0.24), value: isClosing)
        .contentShape(.rect)
        .onTapGesture(perform: onClick)
    }
}

struct MiniTabCard: View {
    let item: WindowItem
    let isSelected: Bool
    let thumbnail: CGImage?
    let height: Double
    let onHover: () -> Void
    let onClick: () -> Void

    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let thumbnail {
                    Image(decorative: thumbnail, scale: 1).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color(white: 0.14)
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            ItemIcon(item: item, size: 15).shadow(radius: 2).padding(5)
            if item.tab?.audible == true {
                AudioBars().padding(5).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .clipShape(.rect(cornerRadius: 7))
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(isSelected ? 0.08 : 0.035)))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .strokeBorder(isSelected ? Theme.accent : (hovering ? Color.white.opacity(0.22) : Theme.cardStroke)))
        .onContinuousHover { phase in
            switch phase {
            case .active:
                hovering = true
                onHover()
            case .ended:
                hovering = false
            }
        }
        .onTapGesture(perform: onClick)
        .help(item.displayTitle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.displayTitle)
        .accessibilityAddTraits(.isButton)
    }
}

struct MorePileView: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.2)).padding(.horizontal, 16).offset(y: 8)
                RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.24)).padding(.horizontal, 8).offset(y: 4)
                RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.28))
                    .overlay(Text("+\(count)").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text))
            }
            .frame(height: 58)
            .padding(7)
            .background(RoundedRectangle(cornerRadius: Theme.cardRadius).fill(Theme.cardFill))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.cardStroke))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mais \(count) abas")
    }
}
```

Reescrever `Sources/AlttabApp/Views/WorkspaceColumnView.swift`:

```swift
import AlttabCore
import SwiftUI

struct WorkspaceColumnView: View {
    let column: WorkspaceColumn
    let isFocused: Bool
    let isCurrent: Bool
    let firstIndex: Int
    let state: SwitcherState
    let controller: SwitcherController

    var body: some View {
        let windows = column.items.filter { $0.tab == nil }
        let tabs = column.items.filter { $0.tab != nil }
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Text(column.id.isEmpty ? "–" : column.id)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(isCurrent ? Color.black : Theme.text)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(isCurrent ? Theme.accent : .white.opacity(isFocused ? 0.18 : 0.08),
                                in: .rect(cornerRadius: 7))
                Text(caption(windows: windows.count, tabs: tabs.count))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
            ForEach(Array(windows.enumerated()), id: \.element.id) { offset, item in
                WindowCardView(
                    item: item,
                    isSelected: item.id == state.model.selectedID,
                    isWide: isFocused,
                    isClosing: item.id == state.closingID,
                    thumbnail: state.thumbnail(for: item),
                    query: state.model.query,
                    appearDelay: Double(firstIndex + offset) * 0.03,
                    onHover: { controller.hover(item.id) },
                    onClick: { controller.click(item.id) },
                    onClose: { controller.closeWindow(item.id) })
            }
            if !tabs.isEmpty {
                EdgeTabsView(tabs: tabs,
                             mode: EdgeColumnLayout.mode(tabCount: tabs.count, focused: isFocused,
                                                         searching: !state.model.query.isEmpty),
                             isFocused: isFocused, firstIndex: firstIndex + windows.count,
                             state: state, controller: controller)
            }
        }
    }

    private func caption(windows: Int, tabs: Int) -> String {
        if isCurrent { return "atual" }
        if tabs > 0 { return "Edge · \(tabs) abas" }
        return "\(windows) jan."
    }
}
```

- [ ] **Step 6: Raiz com altura fixa e peso da coluna do Edge**

Em `Sources/AlttabApp/Views/SwitcherView.swift`:

a) Depois de `let width: CGFloat`, adicionar:

```swift
    let height: CGFloat
```

b) Trocar:

```swift
            columns
            footer
        }
        .padding(padding)
        .frame(width: width)
```

por:

```swift
            columns
            Spacer(minLength: 0)
            footer
        }
        .padding(padding)
        .frame(width: width, height: height, alignment: .top)
```

c) Trocar:

```swift
            let widths = ColumnLayout.widths(count: cols.count, focusedIndex: focusedIndex,
                                             total: Double(width - padding * 2), spacing: Double(spacing),
                                             caps: state.model.query.isEmpty ? nil : (340, 190))
```

por:

```swift
            let focusedTabs = focusedIndex.map { cols[$0].items.filter { $0.tab != nil }.count } ?? 0
            let focusMode = EdgeColumnLayout.mode(tabCount: focusedTabs, focused: true, searching: false)
            let widths = ColumnLayout.widths(count: cols.count, focusedIndex: focusedIndex,
                                             total: Double(width - padding * 2), spacing: Double(spacing),
                                             focusWeight: EdgeColumnLayout.focusWeight(for: focusMode),
                                             caps: state.model.query.isEmpty ? nil : (340, 190))
```

- [ ] **Step 7: Compilar e instalar**

Run: `./scripts/test.sh 2>&1 | tail -1 && ./scripts/install.sh 2>&1 | tail -2`
Expected: suíte verde; instalado; sem erros de compilação.

- [ ] **Step 8: Commit**

```bash
git add Sources/AlttabApp
git commit -F - <<'EOF'
feat: abas do Edge no alternador com destaque e grade de miniaturas

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 8: Carregar a extensão e checklist com o Edge real

**Files:**
- Modify: `docs/superpowers/spikes/2026-10-09-resultados.md`

- [ ] **Step 1: Carregar a extensão (Tom)**

Pedir ao Tom: `edge://extensions` → ligar **Modo de desenvolvedor** → **Carregar sem compactação** → escolher a pasta `extension` do repositório. Conferir que o ID mostrado é `npgoecidghckmkdhakalhchnaebjdhlc`.

- [ ] **Step 2: Conferir a conexão**

Run: abrir o menu do Alttab (System Events, como no Plano 1).
Expected: "Edge: N abas" com N = número de abas abertas.

- [ ] **Step 3: Checklist (anotar no arquivo de resultados, seção "Checklist do Plano 2")**

1. Option+Tab: a coluna do workspace do Edge mostra as abas (não a janela), com ícone do site e áudio na que toca.
2. Miniatura aparece nas abas já visitadas desde que a extensão ligou; aba nunca vista mostra o ícone.
3. Fora de foco com > 4 abas: 3 + "+N"; clicar no "+N" abre a coluna com destaque + grade.
4. Em foco: passar o mouse pela grade troca o destaque **sem a grade se mexer**.
5. Escolher uma aba (soltar Option ou clique) vai para o Edge **naquela aba**.
6. Option+W / X numa aba descartável fecha a aba no Edge.
7. Busca pelo domínio ("evotalks") acha a aba.
8. Option+Tab rápido com o Edge na frente volta para a janela anterior (não para outra aba).
9. Fechar o Edge: o menu passa a "extensão desconectada" e nada trava; reabrir o Edge reconecta sozinho.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/spikes
git commit -F - <<'EOF'
docs: checklist do Plano 2 com o Edge real

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

## Cobertura da spec neste plano

| Spec | Onde |
|---|---|
| 3.2 coluna do Edge: 3 + "+N", destaque + grade fixa 3/5/6, sem rolagem, sem mexer no hover | Tasks 4, 7 |
| 3.2 busca pelo endereço | Task 2 |
| 3.2 fechar aba | Tasks 5, 7 |
| 4.2 extensão: listar, ativar, fechar, foto ao ficar visível, ≤ 480 px | Task 5 |
| 4.3 `alttab-host` + socket | Tasks 3, 6 |
| 5 fluxo: retrato em cache, ativar aba + focar janela | Tasks 6, 7 |
| 6 extensão desconectada → Edge como janela comum | Tasks 6, 7, 8 |
| Player do YouTube Music | **Plano 3** |
