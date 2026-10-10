# Alttab — Plano 1: Fundação (alternador de janelas do AeroSpace)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App de barra de menu que abre em Option+Tab um painel de vidro com as janelas do AeroSpace agrupadas por workspace, com miniatura, busca, fechar e as animações do protótipo — e troca para a janela escolhida.

**Architecture:** Pacote Swift com dois alvos: `AlttabCore` (lógica pura e testável: parser do AeroSpace, ordem de uso, modelo do alternador, máquina de estados do teclado, layout) e `AlttabApp` (AppKit + SwiftUI: tap de teclado, painel, captura de miniaturas, cliente do AeroSpace). Um script monta e assina o `.app`. Abas do Edge e player ficam para os Planos 2 e 3 — aqui o Edge aparece como uma janela comum.

**Tech Stack:** Swift 6.4 (tools 6.2), SwiftUI + AppKit, ScreenCaptureKit, CoreGraphics (CGEventTap), Swift Testing, CLI do AeroSpace 0.21.

**Spec:** `docs/superpowers/specs/2026-10-09-alttab-design.md` · Protótipo: https://claude.ai/artifact/HXkTSRDNCgCbaDYEVJ61fd (quadro "A · com 8 workspaces")

**Próximos planos (fora deste):** Plano 2 — extensão do Edge + `alttab-host` + coluna do Edge (destaque + grade de miniaturas, "+N"). Plano 3 — player do YouTube Music (cor da capa, flip).

## Global Constraints

- Deployment target: **macOS 26** (`.macOS(.v26)`); máquina alvo roda macOS 27.0.
- `swift-tools-version: 6.2`, modo de linguagem Swift 6. **Sem dependências de terceiros.**
- Bundle id: `br.inf.brusoft.alttab`. Nome do executável no bundle: `Alttab`. App sem ícone no Dock (`LSUIElement`).
- AeroSpace CLI em `/opt/homebrew/bin/aerospace` (versão 0.21.3-Beta).
- Assinar com o certificado **Apple Development** (`C081393AF63E6A78FE2343B68E2DAE3855D328A1`) — **nunca** ad-hoc com hardened runtime (já quebrou outro app deste Mac). Assinatura estável também mantém as permissões de Acessibilidade/Gravação de Tela entre builds.
- Textos da interface em **pt-BR**. Ícones só **SF Symbols**, nunca emoji.
- Cor de destaque: `#FFB547`. Cantos do painel: 22 pt. Cartão: 12 pt. Miniatura: 8 pt.
- Inclinação 3D no hover: **8°**. Seleção pelo mouse só após movimento **≥ 14 pt** desde a última seleção.
- Coluna em foco: peso **2,7** contra 1 das outras. Com busca ativa: larguras máximas **340 pt** (foco) / **190 pt** (outras), colunas centralizadas.
- Commits em português, convencionais (`feat:`, `fix:`, `test:`, `docs:`, `chore:`), terminando com as linhas `Co-Authored-By`/`Claude-Session` da sessão. Trabalho na branch `feat/fundacao`, nunca na `main`.
- **Nunca usar `$(...)` dentro de mensagem de commit** — sempre `git commit -F -` com heredoc entre aspas simples.

## Review Focus

1. **Títulos com acento, emoji e símbolos** (`✳ APP DESKSOFT`, `◑ Alt+Tab…`, `Áudio em reprodução`): a busca acha "audio" em "Áudio" e nada quebra — teste em Task 4.
2. **Janela fechada entre abrir o painel e escolher** (id velho): o alternador não trava; ao remover, a seleção vai para a vizinha — teste em Task 4 (`remove`).
3. **Zero ou uma janela aberta**: Option+Tab abre sem crash; com uma só, ela é a seleção; `next()` sem janelas não explode — teste em Task 4.
4. **Workspaces "10" e nomes não numéricos**: "10" vem depois de "9", não depois de "1"; nomes como "web" vão para o fim — teste em Task 4.
5. **Mouse parado em cima de um cartão quando o painel abre** não pode roubar a seleção (Option+Tab rápido tem que voltar para a janela anterior) — teste em Task 6 (`HoverGate`) + checagem manual em Task 9.

---

## Estrutura de arquivos

```
alttab/
├── Package.swift
├── .gitignore
├── Resources/Info.plist
├── scripts/build-app.sh            # compila release, monta e assina build/Alttab.app
├── scripts/install.sh              # copia para ~/Applications e abre
├── spikes/                         # descartável (Task 1), apagado no fim da Task 1
├── Sources/AlttabCore/
│   ├── WindowItem.swift            # modelo de janela + título de exibição
│   ├── AerospaceParser.swift       # JSON do AeroSpace → WindowItem / FocusedWindow
│   ├── MRUTracker.swift            # ordem de uso recente
│   ├── SwitcherModel.swift         # colunas, seleção, navegação, busca, remoção
│   ├── HotkeyStateMachine.swift    # teclas → ações (abrir, próximo, confirmar…)
│   ├── HoverGate.swift             # seleção pelo mouse só com movimento real
│   ├── ColumnLayout.swift          # larguras das colunas
│   ├── Greeting.swift              # Bom dia / Boa tarde / Boa noite
│   └── ImageBlankness.swift        # detecta miniatura vazia
├── Sources/AlttabApp/
│   ├── main.swift                  # ponto de entrada
│   ├── AppDelegate.swift           # barra de menu, permissões, login
│   ├── AerospaceClient.swift       # roda a CLI do AeroSpace
│   ├── WindowStore.swift           # retrato das janelas + MRU (polling)
│   ├── SecureInput.swift           # detecta Secure Input e quem segura
│   ├── HotkeyMonitor.swift         # CGEventTap
│   ├── SwitcherController.swift    # liga teclado ↔ modelo ↔ painel ↔ AeroSpace
│   ├── SwitcherPanel.swift         # NSPanel flutuante
│   ├── WindowThumbs.swift          # ScreenCaptureKit + cache
│   └── Views/
│       ├── Theme.swift             # cores e medidas
│       ├── SwitcherView.swift      # raiz: cabeçalho, colunas, rodapé
│       ├── HeaderView.swift        # busca, título da seleção, saudação + foto
│       ├── WorkspaceColumnView.swift
│       ├── WindowCardView.swift    # cartão com inclinação, brilho e X
│       └── Bits.swift              # AppIcon, HighlightedText, CloseButton, Kbd
└── Tests/AlttabCoreTests/
    ├── AerospaceParserTests.swift
    ├── MRUTrackerTests.swift
    ├── SwitcherModelTests.swift
    ├── HotkeyStateMachineTests.swift
    └── UIHelpersTests.swift        # HoverGate, ColumnLayout, Greeting, ImageBlankness
```

---

### Task 1: Spikes de risco (descartável) — Option+Tab e miniatura de janela escondida

Responde às duas perguntas que podem mudar o desenho **antes** de qualquer código de produto. Nada daqui fica no repositório.

**Files:**
- Create (temporário): `spikes/hotkey.swift`, `spikes/capture.swift`
- Create: `docs/superpowers/spikes/2026-10-09-resultados.md`

**Interfaces:**
- Consumes: nada.
- Produces: o arquivo de resultados, que decide (a) se o tap de sessão engole Option+Tab mesmo com o atalho do AeroSpace ativo e (b) se dá para capturar janelas de workspaces escondidos ou se o cache "última imagem visível" é obrigatório.

- [ ] **Step 1: Criar a branch de trabalho**

```bash
cd "/Users/macmini/Library/CloudStorage/OneDrive-BrusoftSoluçõesemInformática/##PROJETOS/alttab"
git checkout -b feat/fundacao
```

- [ ] **Step 2: Escrever o spike do teclado**

`spikes/hotkey.swift`:

```swift
import Cocoa
import Carbon

var optionHeld = false
let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        print("tap desligado pelo sistema:", type.rawValue)
        return Unmanaged.passUnretained(event)
    }
    if type == .flagsChanged {
        let held = event.flags.contains(.maskAlternate)
        if held != optionHeld {
            optionHeld = held
            print(held ? "option ↓" : "option ↑")
        }
        return Unmanaged.passUnretained(event)
    }
    let code = event.getIntegerValueField(.keyboardEventKeycode)
    if optionHeld && code == 48 {
        print("OPTION+TAB visto e ENGOLIDO")
        return nil
    }
    return Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                  options: .defaultTap, eventsOfInterest: CGEventMask(mask),
                                  callback: callback, userInfo: nil) else {
    print("Sem permissão de Acessibilidade para este terminal (Ajustes > Privacidade > Acessibilidade)")
    exit(1)
}
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("Secure Input ativo agora?", IsSecureEventInputEnabled())
print("Aperte Option+Tab algumas vezes. Ctrl+C para sair.")
CFRunLoopRun()
```

- [ ] **Step 3: Rodar o spike do teclado e anotar**

Run: `swift spikes/hotkey.swift`
Expected: cada Option+Tab imprime `OPTION+TAB visto e ENGOLIDO`.
Anotar em `docs/superpowers/spikes/2026-10-09-resultados.md`, seção "Teclado":
- O tap viu o Option+Tab? (sim/não)
- O AeroSpace **ainda** trocou de workspace (o `alt-tab` dele continua ativo)? Se trocou, o tap **não** chega antes do atalho do AeroSpace → a remoção do atalho na instalação (Task 10) passa a ser obrigatória e não só limpeza. **Não** remover o atalho agora.
- Valor de `Secure Input ativo agora?`.

- [ ] **Step 4: Escrever o spike de captura**

`spikes/capture.swift`:

```swift
import AppKit
import Foundation
import ScreenCaptureKit

struct W: Decodable {
    let id: Int, ws: String, app: String
    enum CodingKeys: String, CodingKey { case id = "window-id", ws = "workspace", app = "app-name" }
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let p = Process()
p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/aerospace")
p.arguments = ["list-windows", "--all", "--json", "--format", "%{window-id}%{workspace}%{app-name}"]
let pipe = Pipe()
p.standardOutput = pipe
try p.run()
let data = pipe.fileHandleForReading.readDataToEndOfFile()
p.waitUntilExit()
let windows = try JSONDecoder().decode([W].self, from: data)

let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
for w in windows {
    guard let scw = content.windows.first(where: { Int($0.windowID) == w.id }) else {
        print("\(w.id) ws\(w.ws) \(w.app): SEM SCWindow (window-id do AeroSpace ≠ CGWindowID?)")
        continue
    }
    let cfg = SCStreamConfiguration()
    cfg.width = 480
    cfg.height = max(1, Int(480 * scw.frame.height / max(scw.frame.width, 1)))
    do {
        let img = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: scw), configuration: cfg)
        let png = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!
        try png.write(to: outDir.appendingPathComponent("ws\(w.ws)-\(w.id).png"))
        print("\(w.id) ws\(w.ws) \(w.app): ok frame=\(scw.frame) onScreen=\(scw.isOnScreen)")
    } catch {
        print("\(w.id) ws\(w.ws) \(w.app): ERRO \(error)")
    }
}
```

- [ ] **Step 5: Rodar o spike de captura e anotar**

Run: `swift spikes/capture.swift /private/tmp/claude-501/alttab-spike`
(primeira vez o macOS pede **Gravação de Tela** para o terminal; conceder e rodar de novo)
Expected: uma linha por janela e PNGs na pasta. Abrir os PNGs (`open /private/tmp/claude-501/alttab-spike`).
Anotar na seção "Captura":
- `window-id` do AeroSpace bate com `CGWindowID`? (alguma linha "SEM SCWindow"?)
- Janelas de workspaces **não visíveis** vieram com conteúdo, em branco/preto, ou com erro?
- Decisão: se vierem vazias, a Task 8 mantém a estratégia "capturar ao ganhar foco + guardar a última imagem boa" (já é o plano); se vierem boas, a mesma estratégia continua válida (só fica mais completa no primeiro uso).

- [ ] **Step 6: Apagar os spikes e commitar só os resultados**

```bash
rm -rf spikes
git add docs/superpowers/spikes/2026-10-09-resultados.md
git commit -F - <<'EOF'
docs: resultados dos spikes de teclado e captura de janela

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

**Gate:** se o tap **não** viu o Option+Tab de jeito nenhum (nem com o atalho do AeroSpace temporariamente desligado com aprovação do Tom), parar e reabrir o desenho com o Tom antes da Task 2.

---

### Task 2: Pacote Swift + modelo de janela + parser do AeroSpace

**Files:**
- Create: `Package.swift`, `.gitignore`
- Create: `Sources/AlttabCore/WindowItem.swift`, `Sources/AlttabCore/AerospaceParser.swift`
- Create: `Sources/AlttabApp/main.swift` (placeholder mínimo para o pacote compilar)
- Test: `Tests/AlttabCoreTests/AerospaceParserTests.swift`

**Interfaces:**
- Produces:
  - `public struct WindowItem: Equatable, Hashable, Sendable, Identifiable { id: Int; pid: Int32; appName: String; bundleID: String?; title: String; workspace: String; var displayTitle: String }`
  - `public struct FocusedWindow: Equatable, Sendable { id: Int; workspace: String }`
  - `public enum AerospaceParser { static let windowFormat: String; static func windows(from: Data) throws -> [WindowItem]; static func focused(from: Data) throws -> FocusedWindow? }`

- [ ] **Step 1: Criar o pacote**

`Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Alttab",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "AlttabCore"),
        .executableTarget(name: "AlttabApp", dependencies: ["AlttabCore"]),
        .testTarget(name: "AlttabCoreTests", dependencies: ["AlttabCore"]),
    ]
)
```

`.gitignore`:

```
.build/
build/
.swiftpm/
*.xcodeproj
.DS_Store
```

`Sources/AlttabApp/main.swift` (substituído na Task 7):

```swift
print("alttab")
```

- [ ] **Step 2: Escrever os testes do parser**

`Tests/AlttabCoreTests/AerospaceParserTests.swift`:

```swift
import Foundation
import Testing
@testable import AlttabCore

@Suite struct AerospaceParserTests {
    let sample = Data("""
    [
      {"app-bundle-id":"com.microsoft.edgemac","app-name":"Microsoft Edge","app-pid":1989,
       "window-id":297,"window-title":"Pontes de acesso — Microsoft Edge","workspace":"10"},
      {"app-bundle-id":"dev.warp.Warp-Stable","app-name":"Warp","app-pid":812,
       "window-id":613,"window-title":"◑ Alt+Tab com visualização de abas","workspace":"4"},
      {"app-bundle-id":"","app-name":"Sem Bundle","app-pid":5,
       "window-id":7,"window-title":"","workspace":""}
    ]
    """.utf8)

    @Test func parsesAllFields() throws {
        let w = try AerospaceParser.windows(from: sample)
        #expect(w.count == 3)
        #expect(w[0] == WindowItem(id: 297, pid: 1989, appName: "Microsoft Edge",
                                   bundleID: "com.microsoft.edgemac",
                                   title: "Pontes de acesso — Microsoft Edge", workspace: "10"))
    }

    @Test func keepsAccentsAndSymbols() throws {
        let w = try AerospaceParser.windows(from: sample)
        #expect(w[1].title == "◑ Alt+Tab com visualização de abas")
    }

    @Test func emptyBundleBecomesNil() throws {
        #expect(try AerospaceParser.windows(from: sample)[2].bundleID == nil)
    }

    @Test func missingOptionalKeysGetDefaults() throws {
        let d = Data(#"[{"app-name":"X","window-id":1}]"#.utf8)
        let w = try AerospaceParser.windows(from: d)[0]
        #expect(w.workspace == "")
        #expect(w.title == "")
        #expect(w.pid == 0)
        #expect(w.bundleID == nil)
    }

    @Test func displayTitleStripsEdgeSuffixAndFallsBackToApp() throws {
        let w = try AerospaceParser.windows(from: sample)
        #expect(w[0].displayTitle == "Pontes de acesso")
        #expect(w[1].displayTitle == "◑ Alt+Tab com visualização de abas")
        #expect(w[2].displayTitle == "Sem Bundle")
    }

    @Test func focusedParsesIDAndWorkspace() throws {
        let f = try AerospaceParser.focused(from: Data(#"[{"window-id":613,"workspace":"4"}]"#.utf8))
        #expect(f == FocusedWindow(id: 613, workspace: "4"))
    }

    @Test func focusedEmptyListIsNil() throws {
        #expect(try AerospaceParser.focused(from: Data("[]".utf8)) == nil)
    }

    @Test func invalidJSONThrows() {
        #expect(throws: (any Error).self) { try AerospaceParser.windows(from: Data("x".utf8)) }
    }
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `swift test --filter AerospaceParserTests`
Expected: FAIL — `cannot find 'AerospaceParser' in scope` / `WindowItem`.

- [ ] **Step 4: Implementar**

`Sources/AlttabCore/WindowItem.swift`:

```swift
public struct WindowItem: Equatable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let pid: Int32
    public let appName: String
    public let bundleID: String?
    public let title: String
    public let workspace: String

    public init(id: Int, pid: Int32, appName: String, bundleID: String?, title: String, workspace: String) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.workspace = workspace
    }

    /// Título sem o sufixo do navegador; cai no nome do app quando a janela não tem título.
    public var displayTitle: String {
        for suffix in [" — Microsoft Edge", " - Microsoft Edge"] where title.hasSuffix(suffix) {
            return String(title.dropLast(suffix.count))
        }
        return title.isEmpty ? appName : title
    }
}

public struct FocusedWindow: Equatable, Sendable {
    public let id: Int
    public let workspace: String

    public init(id: Int, workspace: String) {
        self.id = id
        self.workspace = workspace
    }
}
```

`Sources/AlttabCore/AerospaceParser.swift`:

```swift
import Foundation

public enum AerospaceParser {
    /// Formato passado em `aerospace list-windows --json --format`.
    public static let windowFormat = "%{window-id}%{workspace}%{app-name}%{app-bundle-id}%{window-title}%{app-pid}"

    private struct RawWindow: Decodable {
        let id: Int
        let workspace: String?
        let app: String
        let bundle: String?
        let title: String?
        let pid: Int32?

        enum CodingKeys: String, CodingKey {
            case id = "window-id", workspace, app = "app-name", bundle = "app-bundle-id"
            case title = "window-title", pid = "app-pid"
        }
    }

    private struct RawFocused: Decodable {
        let id: Int
        let workspace: String?
        enum CodingKeys: String, CodingKey { case id = "window-id", workspace }
    }

    public static func windows(from data: Data) throws -> [WindowItem] {
        try JSONDecoder().decode([RawWindow].self, from: data).map { raw in
            WindowItem(id: raw.id, pid: raw.pid ?? 0, appName: raw.app,
                       bundleID: (raw.bundle?.isEmpty ?? true) ? nil : raw.bundle,
                       title: raw.title ?? "", workspace: raw.workspace ?? "")
        }
    }

    public static func focused(from data: Data) throws -> FocusedWindow? {
        try JSONDecoder().decode([RawFocused].self, from: data).first.map {
            FocusedWindow(id: $0.id, workspace: $0.workspace ?? "")
        }
    }
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `swift test --filter AerospaceParserTests`
Expected: PASS (8 testes).

- [ ] **Step 6: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -F - <<'EOF'
feat: pacote Swift e parser das janelas do AeroSpace

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 3: Ordem de uso recente (MRU)

**Files:**
- Create: `Sources/AlttabCore/MRUTracker.swift`
- Test: `Tests/AlttabCoreTests/MRUTrackerTests.swift`

**Interfaces:**
- Consumes: `WindowItem` (Task 2).
- Produces: `public struct MRUTracker: Sendable { init(); var order: [Int] { get }; mutating func touch(_ id: Int); mutating func prune(keeping: Set<Int>); func sorted(_ items: [WindowItem]) -> [WindowItem] }`

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/MRUTrackerTests.swift`:

```swift
import Testing
@testable import AlttabCore

private func w(_ id: Int) -> WindowItem {
    WindowItem(id: id, pid: 1, appName: "A", bundleID: nil, title: "t\(id)", workspace: "1")
}

@Suite struct MRUTrackerTests {
    @Test func touchMovesToFront() {
        var m = MRUTracker()
        m.touch(1); m.touch(2); m.touch(3); m.touch(1)
        #expect(m.order == [1, 3, 2])
    }

    @Test func touchSameIdTwiceKeepsSingleEntry() {
        var m = MRUTracker()
        m.touch(5); m.touch(5)
        #expect(m.order == [5])
    }

    @Test func pruneDropsClosedWindows() {
        var m = MRUTracker()
        m.touch(1); m.touch(2); m.touch(3)
        m.prune(keeping: [1, 3])
        #expect(m.order == [3, 1])
    }

    @Test func sortedPutsKnownFirstThenUnknownInInputOrder() {
        var m = MRUTracker()
        m.touch(2); m.touch(4)
        let ids = m.sorted([w(1), w(2), w(3), w(4)]).map(\.id)
        #expect(ids == [4, 2, 1, 3])
    }

    @Test func sortedIgnoresIdsNotInInput() {
        var m = MRUTracker()
        m.touch(99); m.touch(1)
        #expect(m.sorted([w(1), w(2)]).map(\.id) == [1, 2])
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter MRUTrackerTests`
Expected: FAIL — `cannot find 'MRUTracker'`.

- [ ] **Step 3: Implementar**

`Sources/AlttabCore/MRUTracker.swift`:

```swift
public struct MRUTracker: Sendable {
    public private(set) var order: [Int] = []

    public init() {}

    public mutating func touch(_ id: Int) {
        order.removeAll { $0 == id }
        order.insert(id, at: 0)
    }

    public mutating func prune(keeping ids: Set<Int>) {
        order.removeAll { !ids.contains($0) }
    }

    public func sorted(_ items: [WindowItem]) -> [WindowItem] {
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        let known = items.filter { rank[$0.id] != nil }.sorted { rank[$0.id]! < rank[$1.id]! }
        let unknown = items.filter { rank[$0.id] == nil }
        return known + unknown
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test --filter MRUTrackerTests`
Expected: PASS (5 testes).

- [ ] **Step 5: Commit**

```bash
git add Sources/AlttabCore/MRUTracker.swift Tests/AlttabCoreTests/MRUTrackerTests.swift
git commit -F - <<'EOF'
feat: rastreia a ordem de uso recente das janelas

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 4: Modelo do alternador (colunas, seleção, busca, remoção)

**Files:**
- Create: `Sources/AlttabCore/SwitcherModel.swift`
- Test: `Tests/AlttabCoreTests/SwitcherModelTests.swift`

**Interfaces:**
- Consumes: `WindowItem` (Task 2). Recebe as janelas **já em ordem MRU** (quem ordena é `MRUTracker.sorted`).
- Produces:
  - `public struct WorkspaceColumn: Equatable, Sendable, Identifiable { id: String; items: [WindowItem] }`
  - `public struct SwitcherModel: Equatable, Sendable` com:
    `init(windows: [WindowItem], currentWorkspace: String)`, `windows`, `currentWorkspace`, `query`, `selectedID: Int?`,
    `visible: [WindowItem]`, `columns: [WorkspaceColumn]`, `selected: WindowItem?`, `focusedColumnID: String?`,
    `mutating select(_:)`, `next()`, `previous()`, `moveColumn(_ delta: Int)`, `moveInColumn(_ delta: Int)`,
    `jump(toWorkspace: String)`, `setQuery(_:)`, `remove(_ id: Int)`,
    `static workspaceOrder(_:_:) -> Bool`, `static matches(_:query:) -> Bool`, `static highlight(in:query:) -> Range<String.Index>?`

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/SwitcherModelTests.swift`:

```swift
import Testing
@testable import AlttabCore

private func w(_ id: Int, _ ws: String, _ title: String = "", app: String = "Warp") -> WindowItem {
    WindowItem(id: id, pid: 1, appName: app, bundleID: nil, title: title.isEmpty ? "janela \(id)" : title, workspace: ws)
}

@Suite struct SwitcherModelTests {
    // MRU: 1 é a janela atual, 2 a anterior…
    let mru = [w(1, "4", "Alt+Tab com abas"), w(2, "4", "EVODESK"), w(3, "3", "DESKSOFT"),
               w(4, "10", "YouTube - Áudio em reprodução", app: "Microsoft Edge"), w(5, "3", "SAMAE")]

    @Test func initialSelectionIsPreviousWindow() {
        #expect(SwitcherModel(windows: mru, currentWorkspace: "4").selectedID == 2)
    }

    @Test func singleWindowSelectsItself() {
        #expect(SwitcherModel(windows: [w(9, "1")], currentWorkspace: "1").selectedID == 9)
    }

    @Test func noWindowsIsSafe() {
        var m = SwitcherModel(windows: [], currentWorkspace: "1")
        #expect(m.selectedID == nil)
        m.next(); m.previous(); m.moveColumn(1); m.moveInColumn(1); m.jump(toWorkspace: "2")
        #expect(m.selectedID == nil)
        #expect(m.columns.isEmpty)
    }

    @Test func nextAndPreviousWrapInMRUOrder() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.next(); #expect(m.selectedID == 3)
        m.next(); m.next(); m.next(); #expect(m.selectedID == 1)
        m.previous(); #expect(m.selectedID == 5)
    }

    @Test func workspaceOrderIsNumericThenNames() {
        let names = ["web", "10", "2", "9", ""]
        #expect(names.sorted(by: SwitcherModel.workspaceOrder) == ["2", "9", "10", "", "web"])
    }

    @Test func columnsGroupByWorkspaceKeepingMRUInside() {
        let cols = SwitcherModel(windows: mru, currentWorkspace: "4").columns
        #expect(cols.map(\.id) == ["3", "4", "10"])
        #expect(cols[0].items.map(\.id) == [3, 5])
        #expect(cols[1].items.map(\.id) == [1, 2])
    }

    @Test func focusedColumnFollowsSelection() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        #expect(m.focusedColumnID == "4")
        m.select(4)
        #expect(m.focusedColumnID == "10")
    }

    @Test func moveColumnSelectsFirstOfNeighborAndClamps() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.moveColumn(1); #expect(m.selectedID == 4)
        m.moveColumn(1); #expect(m.selectedID == 4)
        m.moveColumn(-2); #expect(m.selectedID == 3)
        m.moveColumn(-1); #expect(m.selectedID == 3)
    }

    @Test func moveInColumnClamps() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.select(3)
        m.moveInColumn(1); #expect(m.selectedID == 5)
        m.moveInColumn(1); #expect(m.selectedID == 5)
        m.moveInColumn(-5); #expect(m.selectedID == 3)
    }

    @Test func jumpToWorkspace() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.jump(toWorkspace: "3"); #expect(m.selectedID == 3)
        m.jump(toWorkspace: "7"); #expect(m.selectedID == 3)
    }

    @Test func queryIsAccentAndCaseInsensitive() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("audio")
        #expect(m.visible.map(\.id) == [4])
        #expect(m.selectedID == 4)
    }

    @Test func queryMatchesAppName() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("edge")
        #expect(m.visible.map(\.id) == [4])
    }

    @Test func querySnapsSelectionToFirstHitAndHidesEmptyColumns() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("desk")
        #expect(m.visible.map(\.id) == [2, 3])
        #expect(m.selectedID == 2)
        #expect(m.columns.map(\.id) == ["3", "4"])
    }

    @Test func queryWithoutHitsClearsSelection() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("zzz")
        #expect(m.selectedID == nil)
        m.next()
        #expect(m.selectedID == nil)
    }

    @Test func selectIgnoresHiddenWindow() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("samae")
        m.select(1)
        #expect(m.selectedID == 5)
    }

    @Test func highlightFindsRangeIgnoringAccents() {
        let t = "YouTube - Áudio em reprodução"
        let r = SwitcherModel.highlight(in: t, query: "audio")
        #expect(r.map { String(t[$0]) } == "Áudio")
        #expect(SwitcherModel.highlight(in: t, query: "") == nil)
    }

    @Test func removeSelectedMovesToNextVisible() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.remove(2)
        #expect(m.selectedID == 3)
        #expect(!m.windows.contains { $0.id == 2 })
    }

    @Test func removeLastSelectedMovesToPrevious() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.select(5)
        m.remove(5)
        #expect(m.selectedID == 4)
    }

    @Test func removeOtherKeepsSelection() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.remove(4)
        #expect(m.selectedID == 2)
    }

    @Test func removeEverythingClearsSelection() {
        var m = SwitcherModel(windows: [w(1, "1"), w(2, "1")], currentWorkspace: "1")
        m.remove(2); m.remove(1)
        #expect(m.selectedID == nil)
        #expect(m.columns.isEmpty)
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter SwitcherModelTests`
Expected: FAIL — `cannot find 'SwitcherModel'`.

- [ ] **Step 3: Implementar**

`Sources/AlttabCore/SwitcherModel.swift`:

```swift
import Foundation

public struct WorkspaceColumn: Equatable, Sendable, Identifiable {
    public let id: String
    public let items: [WindowItem]
}

public struct SwitcherModel: Equatable, Sendable {
    /// Janelas em ordem de uso recente (índice 0 = janela atual).
    public private(set) var windows: [WindowItem]
    public let currentWorkspace: String
    public private(set) var query = ""
    public private(set) var selectedID: Int?

    public init(windows: [WindowItem], currentWorkspace: String) {
        self.windows = windows
        self.currentWorkspace = currentWorkspace
        selectedID = windows.count > 1 ? windows[1].id : windows.first?.id
    }

    public var visible: [WindowItem] {
        query.isEmpty ? windows : windows.filter { Self.matches($0, query: query) }
    }

    public var columns: [WorkspaceColumn] {
        let groups = Dictionary(grouping: visible, by: \.workspace)
        return groups.keys.sorted(by: Self.workspaceOrder).map { WorkspaceColumn(id: $0, items: groups[$0]!) }
    }

    public var selected: WindowItem? { visible.first { $0.id == selectedID } }

    public var focusedColumnID: String? { selected?.workspace }

    public mutating func select(_ id: Int) {
        if visible.contains(where: { $0.id == id }) { selectedID = id }
    }

    public mutating func next() { step(1) }
    public mutating func previous() { step(-1) }

    private mutating func step(_ delta: Int) {
        let v = visible
        guard !v.isEmpty else { selectedID = nil; return }
        guard let i = v.firstIndex(where: { $0.id == selectedID }) else { selectedID = v[0].id; return }
        selectedID = v[(i + delta % v.count + v.count) % v.count].id
    }

    public mutating func moveColumn(_ delta: Int) {
        let cols = columns
        guard !cols.isEmpty else { return }
        let current = cols.firstIndex { $0.id == focusedColumnID } ?? 0
        let target = min(max(current + delta, 0), cols.count - 1)
        selectedID = cols[target].items.first?.id
    }

    public mutating func moveInColumn(_ delta: Int) {
        guard let col = columns.first(where: { $0.id == focusedColumnID }),
              let i = col.items.firstIndex(where: { $0.id == selectedID }) else { return }
        selectedID = col.items[min(max(i + delta, 0), col.items.count - 1)].id
    }

    public mutating func jump(toWorkspace workspace: String) {
        if let col = columns.first(where: { $0.id == workspace }) { selectedID = col.items.first?.id }
    }

    public mutating func setQuery(_ newQuery: String) {
        query = newQuery
        let v = visible
        if !newQuery.trimmingCharacters(in: .whitespaces).isEmpty || !v.contains(where: { $0.id == selectedID }) {
            selectedID = v.first?.id
        }
    }

    public mutating func remove(_ id: Int) {
        let before = visible
        let index = before.firstIndex { $0.id == id }
        windows.removeAll { $0.id == id }
        guard selectedID == id else { return }
        let after = visible
        if after.isEmpty {
            selectedID = nil
        } else if let index {
            selectedID = after[min(index, after.count - 1)].id
        } else {
            selectedID = after.first?.id
        }
    }

    // MARK: - Regras puras

    public static func workspaceOrder(_ a: String, _ b: String) -> Bool {
        switch (Int(a), Int(b)) {
        case let (x?, y?): return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return a.localizedStandardCompare(b) == .orderedAscending
        }
    }

    private static let searchOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    public static func matches(_ item: WindowItem, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return [item.displayTitle, item.appName].contains { $0.range(of: q, options: searchOptions) != nil }
    }

    public static func highlight(in text: String, query: String) -> Range<String.Index>? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return nil }
        return text.range(of: q, options: searchOptions)
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test --filter SwitcherModelTests`
Expected: PASS (20 testes).

- [ ] **Step 5: Commit**

```bash
git add Sources/AlttabCore/SwitcherModel.swift Tests/AlttabCoreTests/SwitcherModelTests.swift
git commit -F - <<'EOF'
feat: modelo do alternador com colunas, navegação e busca

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 5: Máquina de estados do teclado

Traduz teclas em ações sem depender de AppKit. Regras que **completam a spec** (o conflito entre "digitar filtra" e "Option+W fecha"):
- Ao digitar a primeira letra o painel entra em **modo fixo**: soltar o Option **não** confirma mais; Enter confirma, Esc cancela.
- **Option+W fecha** só enquanto nada foi digitado; depois de começar a busca, W é letra.
- Números **pulam para o workspace** enquanto nada foi digitado; depois, entram na busca.

**Files:**
- Create: `Sources/AlttabCore/HotkeyStateMachine.swift`
- Test: `Tests/AlttabCoreTests/HotkeyStateMachineTests.swift`
- Modify: `docs/superpowers/specs/2026-10-09-alttab-design.md` (tabela 3.1)

**Interfaces:**
- Produces:
  - `public enum KeyInput: Equatable, Sendable { case optionDown, optionUp, tab(shift: Bool), left, right, up, down, escape, enter, backspace, digit(Int), character(String), other }`
  - `public enum SwitcherAction: Equatable, Sendable { case open, next, previous, left, right, up, down, commit, cancel, closeSelected, jump(String), type(String), backspace }`
  - `public struct HotkeyStateMachine: Sendable { init(); var isOpen: Bool { get }; var isSticky: Bool { get }; mutating func handle(_: KeyInput) -> (actions: [SwitcherAction], swallow: Bool); mutating func close() }`

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/HotkeyStateMachineTests.swift`:

```swift
import Testing
@testable import AlttabCore

@Suite struct HotkeyStateMachineTests {
    private func opened() -> HotkeyStateMachine {
        var m = HotkeyStateMachine()
        _ = m.handle(.optionDown)
        _ = m.handle(.tab(shift: false))
        return m
    }

    @Test func optionTabOpensAndSwallows() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.optionDown) == ([], false))
        #expect(m.handle(.tab(shift: false)) == ([.open], true))
        #expect(m.isOpen)
    }

    @Test func tabWithoutOptionPassesThrough() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.tab(shift: false)) == ([], false))
        #expect(!m.isOpen)
    }

    @Test func quickTapCommitsOnOptionUp() {
        var m = opened()
        #expect(m.handle(.optionUp) == ([.commit], false))
        #expect(!m.isOpen)
    }

    @Test func optionUpWhenClosedDoesNothing() {
        var m = HotkeyStateMachine()
        _ = m.handle(.optionDown)
        #expect(m.handle(.optionUp) == ([], false))
    }

    @Test func shiftTabOpensOnLastItem() {
        var m = HotkeyStateMachine()
        _ = m.handle(.optionDown)
        #expect(m.handle(.tab(shift: true)) == ([.open, .previous, .previous], true))
    }

    @Test func tabWhileOpenCycles() {
        var m = opened()
        #expect(m.handle(.tab(shift: false)) == ([.next], true))
        #expect(m.handle(.tab(shift: true)) == ([.previous], true))
    }

    @Test func arrowsMap() {
        var m = opened()
        #expect(m.handle(.left) == ([.left], true))
        #expect(m.handle(.right) == ([.right], true))
        #expect(m.handle(.up) == ([.up], true))
        #expect(m.handle(.down) == ([.down], true))
    }

    @Test func escapeCancelsAndCloses() {
        var m = opened()
        #expect(m.handle(.escape) == ([.cancel], true))
        #expect(!m.isOpen)
        #expect(m.handle(.optionUp) == ([], false))
    }

    @Test func optionWClosesSelectedWhileNothingTyped() {
        var m = opened()
        #expect(m.handle(.character("w")) == ([.closeSelected], true))
        #expect(m.isOpen)
    }

    @Test func typingMakesStickyAndWBecomesLetter() {
        var m = opened()
        #expect(m.handle(.character("x")) == ([.type("x")], true))
        #expect(m.isSticky)
        #expect(m.handle(.character("w")) == ([.type("w")], true))
        #expect(m.handle(.optionUp) == ([], false))
        #expect(m.isOpen)
        #expect(m.handle(.enter) == ([.commit], true))
        #expect(!m.isOpen)
    }

    @Test func digitsJumpUntilSomethingIsTyped() {
        var m = opened()
        #expect(m.handle(.digit(3)) == ([.jump("3")], true))
        _ = m.handle(.character("a"))
        #expect(m.handle(.digit(3)) == ([.type("3")], true))
    }

    @Test func backspaceEmptiesQueryAndRestoresDigitJump() {
        var m = opened()
        _ = m.handle(.character("a"))
        #expect(m.handle(.backspace) == ([.backspace], true))
        #expect(m.handle(.digit(2)) == ([.jump("2")], true))
    }

    @Test func otherKeysSwallowedOnlyWhileOpen() {
        var closed = HotkeyStateMachine()
        #expect(closed.handle(.other) == ([], false))
        var m = opened()
        #expect(m.handle(.other) == ([], true))
    }

    @Test func closeResetsStateForNextOpen() {
        var m = opened()
        _ = m.handle(.character("a"))
        m.close()
        #expect(!m.isOpen && !m.isSticky)
        _ = m.handle(.optionDown)
        _ = m.handle(.tab(shift: false))
        #expect(m.handle(.character("w")) == ([.closeSelected], true))
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter HotkeyStateMachineTests`
Expected: FAIL — `cannot find 'HotkeyStateMachine'`.

- [ ] **Step 3: Implementar**

`Sources/AlttabCore/HotkeyStateMachine.swift`:

```swift
public enum KeyInput: Equatable, Sendable {
    case optionDown, optionUp
    case tab(shift: Bool)
    case left, right, up, down
    case escape, enter, backspace
    case digit(Int)
    case character(String)
    case other
}

public enum SwitcherAction: Equatable, Sendable {
    case open, next, previous, left, right, up, down
    case commit, cancel, closeSelected
    case jump(String)
    case type(String)
    case backspace
}

public struct HotkeyStateMachine: Sendable {
    public private(set) var isOpen = false
    public private(set) var isSticky = false
    private var optionHeld = false
    private var queryLength = 0

    public init() {}

    public mutating func close() {
        isOpen = false
        isSticky = false
        queryLength = 0
    }

    public mutating func handle(_ input: KeyInput) -> (actions: [SwitcherAction], swallow: Bool) {
        switch input {
        case .optionDown:
            optionHeld = true
            return ([], false)
        case .optionUp:
            optionHeld = false
            guard isOpen, !isSticky else { return ([], false) }
            close()
            return ([.commit], false)
        default:
            break
        }

        guard isOpen else {
            guard case .tab(let shift) = input, optionHeld else { return ([], false) }
            isOpen = true
            return (shift ? [.open, .previous, .previous] : [.open], true)
        }

        switch input {
        case .tab(let shift): return ([shift ? .previous : .next], true)
        case .left: return ([.left], true)
        case .right: return ([.right], true)
        case .up: return ([.up], true)
        case .down: return ([.down], true)
        case .escape:
            close()
            return ([.cancel], true)
        case .enter:
            close()
            return ([.commit], true)
        case .backspace:
            queryLength = max(0, queryLength - 1)
            return ([.backspace], true)
        case .digit(let n):
            guard queryLength > 0 else { return ([.jump(String(n))], true) }
            queryLength += 1
            return ([.type(String(n))], true)
        case .character(let c):
            if c.lowercased() == "w", optionHeld, queryLength == 0 { return ([.closeSelected], true) }
            queryLength += 1
            isSticky = true
            return ([.type(c)], true)
        case .other:
            return ([], true)
        case .optionDown, .optionUp:
            return ([], false)
        }
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test --filter HotkeyStateMachineTests`
Expected: PASS (14 testes).

- [ ] **Step 5: Atualizar a spec (tabela 3.1)**

Em `docs/superpowers/specs/2026-10-09-alttab-design.md`, trocar as linhas de "Digitar qualquer letra", "**Option+W**" e "Soltar Option" por:

```markdown
| Digitar qualquer letra | Filtra; o painel fica **fixo** (soltar Option não confirma mais — Enter confirma, Esc cancela) |
| **Option+W** | Fecha a janela/aba selecionada (só enquanto nada foi digitado; depois W vira letra da busca) |
| Soltar Option | Vai para a seleção e fecha o painel (se nada foi digitado) |
```

e a linha "1–9" por:

```markdown
| 1–9 | Pula para o workspace (enquanto nada foi digitado; depois entra na busca) |
```

- [ ] **Step 6: Commit**

```bash
git add Sources/AlttabCore/HotkeyStateMachine.swift Tests/AlttabCoreTests/HotkeyStateMachineTests.swift docs/superpowers/specs
git commit -F - <<'EOF'
feat: máquina de estados do Option+Tab com modo fixo ao digitar

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 6: Auxiliares de interface (mouse, larguras, saudação, miniatura vazia)

**Files:**
- Create: `Sources/AlttabCore/HoverGate.swift`, `Sources/AlttabCore/ColumnLayout.swift`, `Sources/AlttabCore/Greeting.swift`, `Sources/AlttabCore/ImageBlankness.swift`
- Test: `Tests/AlttabCoreTests/UIHelpersTests.swift`

**Interfaces:**
- Produces:
  - `public struct HoverGate: Sendable { init(minDistance: Double = 14); mutating func reset(x: Double, y: Double); mutating func shouldSelect(x: Double, y: Double) -> Bool }`
  - `public enum ColumnLayout { static func widths(count: Int, focusedIndex: Int?, total: Double, spacing: Double, focusWeight: Double = 2.7, caps: (focused: Double, other: Double)? = nil) -> [Double] }`
  - `public enum Greeting { static func text(hour: Int) -> String }`
  - `public enum ImageBlankness { static func isBlank(_ image: CGImage, threshold: Double = 0.02) -> Bool }`

- [ ] **Step 1: Escrever os testes**

`Tests/AlttabCoreTests/UIHelpersTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import AlttabCore

@Suite struct HoverGateTests {
    @Test func restingMouseAfterOpenDoesNotSelect() {
        var g = HoverGate()
        g.reset(x: 100, y: 100)
        #expect(!g.shouldSelect(x: 100, y: 100))
        #expect(!g.shouldSelect(x: 105, y: 103))
    }

    @Test func realMovementSelectsAndMovesAnchor() {
        var g = HoverGate()
        g.reset(x: 0, y: 0)
        #expect(g.shouldSelect(x: 20, y: 0))
        #expect(!g.shouldSelect(x: 25, y: 0))
        #expect(g.shouldSelect(x: 40, y: 0))
    }

    @Test func withoutResetFirstMoveSelects() {
        var g = HoverGate()
        #expect(g.shouldSelect(x: 1, y: 1))
    }
}

@Suite struct ColumnLayoutTests {
    @Test func emptyIsEmpty() {
        #expect(ColumnLayout.widths(count: 0, focusedIndex: nil, total: 1000, spacing: 10).isEmpty)
    }

    @Test func equalWithoutFocusAndFillsSpace() {
        let w = ColumnLayout.widths(count: 4, focusedIndex: nil, total: 1030, spacing: 10)
        #expect(w == [250, 250, 250, 250])
    }

    @Test func focusedGetsWeight() {
        let w = ColumnLayout.widths(count: 3, focusedIndex: 1, total: 1020, spacing: 10, focusWeight: 2)
        #expect(w == [250, 500, 250])
    }

    @Test func capsLimitWidthsDuringSearch() {
        let w = ColumnLayout.widths(count: 2, focusedIndex: 0, total: 1184, spacing: 10, caps: (340, 190))
        #expect(w == [340, 190])
    }
}

@Suite struct GreetingTests {
    @Test(arguments: [(4, "Boa noite"), (5, "Bom dia"), (11, "Bom dia"), (12, "Boa tarde"),
                      (17, "Boa tarde"), (18, "Boa noite"), (23, "Boa noite"), (0, "Boa noite")])
    func byHour(hour: Int, expected: String) {
        #expect(Greeting.text(hour: hour) == expected)
    }
}

@Suite struct ImageBlanknessTests {
    private func image(_ draw: (CGContext) -> Void) -> CGImage {
        let ctx = CGContext(data: nil, width: 64, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.clear(CGRect(x: 0, y: 0, width: 64, height: 40))
        draw(ctx)
        return ctx.makeImage()!
    }

    @Test func transparentIsBlank() {
        #expect(ImageBlankness.isBlank(image { _ in }))
    }

    @Test func solidBlackIsBlank() {
        #expect(ImageBlankness.isBlank(image { $0.setFillColor(gray: 0, alpha: 1); $0.fill(CGRect(x: 0, y: 0, width: 64, height: 40)) }))
    }

    @Test func darkWithLightTextIsNotBlank() {
        let img = image {
            $0.setFillColor(gray: 0.05, alpha: 1); $0.fill(CGRect(x: 0, y: 0, width: 64, height: 40))
            $0.setFillColor(gray: 0.9, alpha: 1); $0.fill(CGRect(x: 4, y: 30, width: 40, height: 4))
        }
        #expect(!ImageBlankness.isBlank(img))
    }
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter "HoverGateTests|ColumnLayoutTests|GreetingTests|ImageBlanknessTests"`
Expected: FAIL — tipos não encontrados.

- [ ] **Step 3: Implementar**

`Sources/AlttabCore/HoverGate.swift`:

```swift
/// Só deixa o mouse trocar a seleção depois de um movimento real.
/// Evita que o cartão embaixo de um mouse parado roube a seleção quando o painel abre
/// ou quando o layout muda embaixo do ponteiro.
public struct HoverGate: Sendable {
    private var anchor: (x: Double, y: Double)?
    public let minDistance: Double

    public init(minDistance: Double = 14) {
        self.minDistance = minDistance
    }

    public mutating func reset(x: Double, y: Double) {
        anchor = (x, y)
    }

    public mutating func shouldSelect(x: Double, y: Double) -> Bool {
        if let a = anchor, ((x - a.x) * (x - a.x) + (y - a.y) * (y - a.y)).squareRoot() < minDistance {
            return false
        }
        anchor = (x, y)
        return true
    }
}
```

`Sources/AlttabCore/ColumnLayout.swift`:

```swift
public enum ColumnLayout {
    public static func widths(count: Int, focusedIndex: Int?, total: Double, spacing: Double,
                              focusWeight: Double = 2.7,
                              caps: (focused: Double, other: Double)? = nil) -> [Double] {
        guard count > 0 else { return [] }
        let usable = max(0, total - spacing * Double(count - 1))
        let weights = (0..<count).map { $0 == focusedIndex ? focusWeight : 1 }
        let sum = weights.reduce(0, +)
        return weights.enumerated().map { index, weight in
            let width = usable * weight / sum
            guard let caps else { return width }
            return min(width, index == focusedIndex ? caps.focused : caps.other)
        }
    }
}
```

`Sources/AlttabCore/Greeting.swift`:

```swift
public enum Greeting {
    public static func text(hour: Int) -> String {
        switch hour {
        case 5..<12: "Bom dia"
        case 12..<18: "Boa tarde"
        default: "Boa noite"
        }
    }
}
```

`Sources/AlttabCore/ImageBlankness.swift`:

```swift
import CoreGraphics

/// Uma captura "vazia" (transparente ou de uma cor só) não deve substituir uma miniatura boa do cache.
public enum ImageBlankness {
    public static func isBlank(_ image: CGImage, threshold: Double = 0.02) -> Bool {
        let w = 16, h = 16
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return true }
        var minLuma = 255, maxLuma = 0, maxAlpha = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let luma = (Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])) / 3
            minLuma = min(minLuma, luma)
            maxLuma = max(maxLuma, luma)
            maxAlpha = max(maxAlpha, Int(pixels[i + 3]))
        }
        return maxAlpha < 8 || Double(maxLuma - minLuma) / 255 < threshold
    }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test`
Expected: PASS — todas as suítes (parser, MRU, modelo, teclado, auxiliares).

- [ ] **Step 5: Commit**

```bash
git add Sources/AlttabCore Tests/AlttabCoreTests/UIHelpersTests.swift
git commit -F - <<'EOF'
feat: auxiliares de mouse, larguras, saudação e miniatura vazia

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 7: App de barra de menu + cliente do AeroSpace + build assinado

Primeiro app rodando de verdade: ícone na barra de menu mostrando quantas janelas o AeroSpace vê, aviso de Secure Input e permissões. Ainda sem painel.

**Files:**
- Modify: `Sources/AlttabApp/main.swift`
- Create: `Sources/AlttabApp/AppDelegate.swift`, `Sources/AlttabApp/AerospaceClient.swift`, `Sources/AlttabApp/WindowStore.swift`, `Sources/AlttabApp/SecureInput.swift`
- Create: `Resources/Info.plist`, `scripts/build-app.sh`

**Interfaces:**
- Consumes: `AerospaceParser`, `WindowItem`, `FocusedWindow`, `MRUTracker` (Tasks 2–3).
- Produces:
  - `struct AerospaceClient: Sendable { func windows() throws -> [WindowItem]; func focused() throws -> FocusedWindow?; func focusedWorkspace() throws -> String; func focus(windowID: Int) throws; func close(windowID: Int) throws }`
  - `@MainActor @Observable final class WindowStore { windows: [WindowItem]; currentWorkspace: String; lastError: String?; mruOrdered: [WindowItem]; var onFocusChange: (@MainActor (Int) -> Void)?; func start(); func refresh() async; func noteFocused(_ id: Int) }`
  - `enum SecureInput { static func holder() -> String? }` — `nil` quando ninguém segura.
  - `@MainActor final class AppDelegate: NSObject, NSApplicationDelegate` com `let store: WindowStore`.

- [ ] **Step 1: Info.plist e script de build**

`Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>br.inf.brusoft.alttab</string>
    <key>CFBundleName</key><string>Alttab</string>
    <key>CFBundleDisplayName</key><string>Alttab</string>
    <key>CFBundleExecutable</key><string>Alttab</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
```

`scripts/build-app.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

SIGN_ID="${ALTTAB_SIGN_ID:-C081393AF63E6A78FE2343B68E2DAE3855D328A1}"
APP="build/Alttab.app"

swift build -c release --product AlttabApp
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/AlttabApp "$APP/Contents/MacOS/Alttab"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --options runtime --timestamp=none --sign "$SIGN_ID" "$APP"
codesign --verify --strict "$APP"
echo "ok: $APP"
```

Run: `chmod +x scripts/build-app.sh`

- [ ] **Step 2: Cliente do AeroSpace**

`Sources/AlttabApp/AerospaceClient.swift`:

```swift
import AlttabCore
import Foundation

enum AerospaceError: Error, CustomStringConvertible {
    case failed(args: [String], stderr: String)
    var description: String {
        switch self {
        case let .failed(args, stderr): "aerospace \(args.joined(separator: " ")): \(stderr)"
        }
    }
}

struct AerospaceClient: Sendable {
    var executable = "/opt/homebrew/bin/aerospace"

    func run(_ args: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AerospaceError.failed(args: args, stderr: String(decoding: errData, as: UTF8.self))
        }
        return data
    }

    func windows() throws -> [WindowItem] {
        try AerospaceParser.windows(from: run(["list-windows", "--all", "--json", "--format", AerospaceParser.windowFormat]))
    }

    func focused() throws -> FocusedWindow? {
        try AerospaceParser.focused(from: run(["list-windows", "--focused", "--json", "--format", "%{window-id}%{workspace}"]))
    }

    func focusedWorkspace() throws -> String {
        String(decoding: try run(["list-workspaces", "--focused"]), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func focus(windowID: Int) throws {
        _ = try run(["focus", "--window-id", String(windowID)])
    }

    func close(windowID: Int) throws {
        _ = try run(["close", "--window-id", String(windowID)])
    }
}
```

- [ ] **Step 3: Retrato das janelas com polling**

`Sources/AlttabApp/WindowStore.swift`:

```swift
import AlttabCore
import Foundation
import Observation

@MainActor @Observable
final class WindowStore {
    private(set) var windows: [WindowItem] = []
    private(set) var currentWorkspace = ""
    private(set) var lastError: String?
    /// Chamado quando outra janela ganha foco (usado para atualizar a miniatura dela).
    @ObservationIgnored var onFocusChange: (@MainActor (Int) -> Void)?

    @ObservationIgnored private var mru = MRUTracker()
    @ObservationIgnored private let client: AerospaceClient
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var lastFocused: Int?

    init(client: AerospaceClient = AerospaceClient()) {
        self.client = client
    }

    var mruOrdered: [WindowItem] { mru.sorted(windows) }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                await self?.poll(full: tick % 8 == 0)
                tick += 1
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func refresh() async {
        await poll(full: true)
    }

    func noteFocused(_ id: Int) {
        mru.touch(id)
    }

    private func poll(full: Bool) async {
        let client = self.client
        let result = await Task.detached { () -> Result<(FocusedWindow?, String, [WindowItem]?), Error> in
            Result {
                let focused = try client.focused()
                let workspace = try focused?.workspace ?? client.focusedWorkspace()
                return (focused, workspace, full ? try client.windows() : nil)
            }
        }.value

        switch result {
        case .failure(let error):
            lastError = String(describing: error)
        case .success(let (focused, workspace, list)):
            lastError = nil
            currentWorkspace = workspace
            if let focused {
                mru.touch(focused.id)
                if focused.id != lastFocused {
                    lastFocused = focused.id
                    onFocusChange?(focused.id)
                }
            }
            if let list {
                mru.prune(keeping: Set(list.map(\.id)))
                windows = list
            }
        }
    }
}
```

- [ ] **Step 4: Secure Input**

`Sources/AlttabApp/SecureInput.swift`:

```swift
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
```

- [ ] **Step 5: Barra de menu**

`Sources/AlttabApp/main.swift`:

```swift
import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
```

`Sources/AlttabApp/AppDelegate.swift`:

```swift
import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = WindowStore()
    private var statusItem: NSStatusItem!
    private var secureTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(warning: false)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        store.start()
        secureTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.setIcon(warning: SecureInput.holder() != nil) }
        }
    }

    private func setIcon(warning: Bool) {
        let name = warning ? "exclamationmark.triangle" : "rectangle.on.rectangle"
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Alttab")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let error = store.lastError {
            menu.addItem(disabled("AeroSpace não respondeu: \(error.prefix(80))"))
        } else {
            menu.addItem(disabled("\(store.windows.count) janelas · workspace \(store.currentWorkspace)"))
        }
        if let holder = SecureInput.holder() {
            menu.addItem(disabled("Option+Tab bloqueado: Secure Input ativo em \(holder)"))
        }
        if !AXIsProcessTrusted() {
            menu.addItem(action("Conceder Acessibilidade…", #selector(openAccessibility)))
        }
        if !CGPreflightScreenCaptureAccess() {
            menu.addItem(action("Conceder Gravação de Tela…", #selector(openScreenCapture)))
        }
        menu.addItem(.separator())
        let login = action("Iniciar com o Mac", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(action("Sair", #selector(quit)))
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func openScreenCapture() {
        _ = CGRequestScreenCaptureAccess()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 6: Compilar, montar e rodar**

Run: `swift build && ./scripts/build-app.sh && open build/Alttab.app`
Expected: `ok: build/Alttab.app`; aparece o ícone de dois retângulos na barra de menu; abrir o menu mostra "N janelas · workspace 4" com N igual a `aerospace list-windows --all | wc -l`. Trocar de workspace e reabrir o menu: o número do workspace muda.

Verificação do aviso de Secure Input: abrir um campo de senha (ex.: Ajustes > Usuários > senha) e esperar 2 s — o ícone vira triângulo e o menu mostra o app. Fechar o campo — volta ao normal.

- [ ] **Step 7: Commit**

```bash
git add Sources/AlttabApp Resources scripts
git commit -F - <<'EOF'
feat: app de barra de menu lendo as janelas do AeroSpace

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 8: Option+Tab de ponta a ponta + miniaturas

Liga teclado → modelo → painel → AeroSpace, com uma tela provisória simples (lista de colunas em texto) e a captura de miniaturas. O visual final vem na Task 9.

**Files:**
- Create: `Sources/AlttabApp/HotkeyMonitor.swift`, `Sources/AlttabApp/SwitcherController.swift`, `Sources/AlttabApp/SwitcherPanel.swift`, `Sources/AlttabApp/WindowThumbs.swift`, `Sources/AlttabApp/Views/SwitcherView.swift`
- Modify: `Sources/AlttabApp/AppDelegate.swift`

**Interfaces:**
- Consumes: `HotkeyStateMachine`, `KeyInput`, `SwitcherAction`, `SwitcherModel`, `HoverGate`, `ImageBlankness` (Tasks 4–6); `WindowStore`, `AerospaceClient` (Task 7).
- Produces:
  - `@MainActor final class HotkeyMonitor { var onInput: ((KeyInput) -> Bool)?; func start() -> Bool }`
  - `@MainActor @Observable final class SwitcherState { var model: SwitcherModel; var thumbnails: [Int: CGImage]; var closingID: Int?; var openCount: Int }`
  - `@MainActor final class SwitcherController { let state: SwitcherState; init(store:thumbs:); func handle(_: KeyInput) -> Bool; func hover(_ id: Int); func click(_ id: Int); func closeWindow(_ id: Int) }`
  - `@MainActor final class WindowThumbs { var cache: [Int: CGImage]; func capture(ids: [Int], update: @escaping @MainActor (Int, CGImage) -> Void) }`
  - `final class SwitcherPanel: NSPanel { init<V: View>(rootView: V); func present(width: CGFloat); func dismiss() }`
  - `struct SwitcherView: View { init(state: SwitcherState, controller: SwitcherController, width: CGFloat) }` (provisória aqui, reescrita na Task 9 com a mesma assinatura)

- [ ] **Step 1: Tap de teclado**

`Sources/AlttabApp/HotkeyMonitor.swift`:

```swift
import AlttabCore
import AppKit

@MainActor
final class HotkeyMonitor {
    /// Recebe a tecla traduzida e devolve se o evento deve ser engolido.
    var onInput: ((KeyInput) -> Bool)?
    private var tap: CFMachPort?
    private var optionWasHeld = false

    private static let digitKeycodes: [Int64: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9, 29: 0]

    func start() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: hotkeyCallback, userInfo: refcon) else {
            return false
        }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    fileprivate func process(type: CGEventType, event: CGEvent) -> Bool {
        guard let input = translate(type: type, event: event) else { return false }
        return onInput?(input) ?? false
    }

    private func translate(type: CGEventType, event: CGEvent) -> KeyInput? {
        if type == .flagsChanged {
            let held = event.flags.contains(.maskAlternate)
            defer { optionWasHeld = held }
            if held && !optionWasHeld { return .optionDown }
            if !held && optionWasHeld { return .optionUp }
            return nil
        }
        guard type == .keyDown else { return nil }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        switch code {
        case 48: return .tab(shift: event.flags.contains(.maskShift))
        case 123: return .left
        case 124: return .right
        case 125: return .down
        case 126: return .up
        case 53: return .escape
        case 36, 76: return .enter
        case 51: return .backspace
        default: break
        }
        if let digit = Self.digitKeycodes[code] { return .digit(digit) }
        if let chars = NSEvent(cgEvent: event)?.charactersIgnoringModifiers, let first = chars.first,
           first.isLetter || first.isNumber || first.isPunctuation || first == " " {
            return .character(String(first))
        }
        return .other
    }
}

private func hotkeyCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                            refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
    let swallow = MainActor.assumeIsolated { () -> Bool in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            monitor.reenable()
            return false
        }
        return monitor.process(type: type, event: event)
    }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
```

- [ ] **Step 2: Miniaturas**

`Sources/AlttabApp/WindowThumbs.swift`:

```swift
import AlttabCore
import CoreGraphics
@preconcurrency import ScreenCaptureKit

@MainActor
final class WindowThumbs {
    private(set) var cache: [Int: CGImage] = [:]

    /// Captura as janelas pedidas e só substitui o cache quando a imagem nova não é vazia
    /// (janelas escondidas pelo AeroSpace podem voltar em branco — ver spike da Task 1).
    func capture(ids: [Int], update: @escaping @MainActor (Int, CGImage) -> Void) {
        Task {
            guard CGPreflightScreenCaptureAccess(),
                  let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            else { return }
            for id in ids {
                guard let window = content.windows.first(where: { Int($0.windowID) == id }),
                      let image = try? await Self.snapshot(window),
                      !ImageBlankness.isBlank(image) else { continue }
                cache[id] = image
                update(id, image)
            }
        }
    }

    nonisolated private static func snapshot(_ window: SCWindow) async throws -> CGImage {
        let config = SCStreamConfiguration()
        config.width = 480
        config.height = max(1, Int(480 * window.frame.height / max(window.frame.width, 1)))
        config.showsCursor = false
        return try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
    }
}
```

- [ ] **Step 3: Painel**

`Sources/AlttabApp/SwitcherPanel.swift`:

```swift
import AppKit
import SwiftUI

final class SwitcherPanel: NSPanel {
    private let hosting: NSHostingView<AnyView>

    init<V: View>(rootView: V) {
        hosting = NSHostingView(rootView: AnyView(rootView))
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present(width: CGFloat) {
        guard let screen = NSScreen.main else { return }
        hosting.layoutSubtreeIfNeeded()
        let height = min(hosting.fittingSize.height, screen.visibleFrame.height - 48)
        let frame = NSRect(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.midY - height / 2,
                           width: width, height: height)
        setFrame(frame, display: true)
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
    }
}
```

- [ ] **Step 4: Controlador**

`Sources/AlttabApp/SwitcherController.swift`:

```swift
import AlttabCore
import AppKit
import Observation
import SwiftUI

@MainActor @Observable
final class SwitcherState {
    var model = SwitcherModel(windows: [], currentWorkspace: "")
    var thumbnails: [Int: CGImage] = [:]
    var closingID: Int?
    /// Muda a cada abertura para reiniciar as animações de entrada.
    var openCount = 0
}

@MainActor
final class SwitcherController {
    let state = SwitcherState()
    private let store: WindowStore
    private let thumbs: WindowThumbs
    private let client = AerospaceClient()
    private var machine = HotkeyStateMachine()
    private var hoverGate = HoverGate()
    private var panel: SwitcherPanel?
    private var panelWidth: CGFloat = 1232

    init(store: WindowStore, thumbs: WindowThumbs) {
        self.store = store
        self.thumbs = thumbs
        store.onFocusChange = { [weak thumbs] id in
            thumbs?.capture(ids: [id]) { _, _ in }
        }
    }

    func handle(_ input: KeyInput) -> Bool {
        let (actions, swallow) = machine.handle(input)
        actions.forEach(perform)
        return swallow
    }

    private func perform(_ action: SwitcherAction) {
        switch action {
        case .open: open()
        case .next: state.model.next()
        case .previous: state.model.previous()
        case .left: state.model.moveColumn(-1)
        case .right: state.model.moveColumn(1)
        case .up: state.model.moveInColumn(-1)
        case .down: state.model.moveInColumn(1)
        case .jump(let workspace): state.model.jump(toWorkspace: workspace)
        case .type(let text): state.model.setQuery(state.model.query + text)
        case .backspace: state.model.setQuery(String(state.model.query.dropLast()))
        case .commit: commit()
        case .cancel: hide()
        case .closeSelected: if let id = state.model.selectedID { closeWindow(id) }
        }
    }

    private func open() {
        state.model = SwitcherModel(windows: store.mruOrdered, currentWorkspace: store.currentWorkspace)
        state.thumbnails = thumbs.cache
        state.closingID = nil
        state.openCount += 1
        let mouse = NSEvent.mouseLocation
        hoverGate.reset(x: mouse.x, y: mouse.y)

        let screenWidth = NSScreen.main?.visibleFrame.width ?? 1280
        panelWidth = min(1232, screenWidth - 48)
        if panel == nil {
            panel = SwitcherPanel(rootView: SwitcherView(state: state, controller: self, width: panelWidth))
        }
        panel?.present(width: panelWidth)

        thumbs.capture(ids: state.model.windows.map(\.id)) { [weak self] id, image in
            self?.state.thumbnails[id] = image
        }
        Task { await store.refresh() }
    }

    private func commit() {
        let id = state.model.selectedID
        hide()
        guard let id else { return }
        store.noteFocused(id)
        let client = self.client
        Task.detached {
            do {
                try client.focus(windowID: id)
            } catch {
                await self.store.refresh()
            }
        }
    }

    private func hide() {
        machine.close()
        panel?.dismiss()
    }

    func hover(_ id: Int) {
        let mouse = NSEvent.mouseLocation
        guard id != state.model.selectedID, hoverGate.shouldSelect(x: mouse.x, y: mouse.y) else { return }
        state.model.select(id)
    }

    func click(_ id: Int) {
        state.model.select(id)
        commit()
    }

    func closeWindow(_ id: Int) {
        state.closingID = id
        let client = self.client
        Task {
            _ = await Task.detached { try? client.close(windowID: id) }.value
            try? await Task.sleep(for: .milliseconds(240))
            state.model.remove(id)
            state.closingID = nil
        }
    }
}
```

- [ ] **Step 5: Tela provisória**

`Sources/AlttabApp/Views/SwitcherView.swift` (substituída na Task 9):

```swift
import AlttabCore
import SwiftUI

struct SwitcherView: View {
    let state: SwitcherState
    let controller: SwitcherController
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(state.model.query.isEmpty ? "Alternar para" : "Busca: \(state.model.query)")
                .font(.headline)
            HStack(alignment: .top, spacing: 16) {
                ForEach(state.model.columns) { column in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(column.id.isEmpty ? "–" : column.id).font(.caption.monospaced())
                        ForEach(column.items) { item in
                            Text(item.displayTitle)
                                .lineLimit(1)
                                .padding(4)
                                .background(item.id == state.model.selectedID ? Color.orange.opacity(0.4) : .clear)
                                .onTapGesture { controller.click(item.id) }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: width, alignment: .leading)
        .background(.black.opacity(0.85), in: .rect(cornerRadius: 22))
    }
}
```

- [ ] **Step 6: Ligar no AppDelegate**

Em `Sources/AlttabApp/AppDelegate.swift`, adicionar as propriedades abaixo de `let store = WindowStore()`:

```swift
    private let thumbs = WindowThumbs()
    private lazy var controller = SwitcherController(store: store, thumbs: thumbs)
    private let hotkey = HotkeyMonitor()
    private var hotkeyActive = false
```

e no fim de `applicationDidFinishLaunching`:

```swift
        hotkey.onInput = { [weak self] input in self?.controller.handle(input) ?? false }
        hotkeyActive = hotkey.start()
        if !hotkeyActive { openAccessibility() }
```

e em `menuNeedsUpdate`, logo depois do bloco de `SecureInput.holder()`:

```swift
        if !hotkeyActive {
            menu.addItem(disabled("Option+Tab desligado: conceda Acessibilidade e reabra o app"))
        }
```

- [ ] **Step 7: Rodar e verificar de ponta a ponta**

Run: `swift test && ./scripts/build-app.sh && open build/Alttab.app`
(na primeira vez: conceder Acessibilidade e Gravação de Tela ao **Alttab**, sair pelo menu e abrir de novo)

Expected (manual, anotar cada item):
1. Option+Tab abre a lista com as colunas por workspace e a **janela anterior** destacada.
2. Option segurado + Tab anda pela ordem de uso; soltar Option vai para a janela destacada (o AeroSpace troca de workspace se precisar).
3. Option+Tab rápido (apertar e soltar) volta para a janela anterior; repetir alterna entre as duas.
4. Setas mudam coluna/linha; 3 pula para o workspace 3; Esc fecha sem trocar.
5. Digitar "desk" filtra; soltar Option **não** fecha; Enter vai.
6. Option+W fecha a janela destacada (testar numa janela descartável do Warp).
7. Nenhuma tecla vaza para o app da frente enquanto a lista está aberta.
8. Com o atalho `alt-tab` do AeroSpace ainda ativo: anotar se o AeroSpace também reage (resultado do spike).

- [ ] **Step 8: Commit**

```bash
git add Sources/AlttabApp
git commit -F - <<'EOF'
feat: Option+Tab de ponta a ponta com miniaturas em cache

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 9: Visual completo (vidro, cabeçalho, colunas, cartões, animações)

Reproduz o quadro "A · com 8 workspaces" do protótipo, sem a coluna especial do Edge e sem o player (Planos 2 e 3).

**Files:**
- Create: `Sources/AlttabApp/Views/Theme.swift`, `Sources/AlttabApp/Views/Bits.swift`, `Sources/AlttabApp/Views/HeaderView.swift`, `Sources/AlttabApp/Views/WorkspaceColumnView.swift`, `Sources/AlttabApp/Views/WindowCardView.swift`
- Modify: `Sources/AlttabApp/Views/SwitcherView.swift` (reescrita completa, mesma assinatura)

**Interfaces:**
- Consumes: `SwitcherState`, `SwitcherController.hover/click/closeWindow` (Task 8); `ColumnLayout`, `Greeting`, `SwitcherModel.highlight` (Tasks 4 e 6).
- Produces: nada novo para outras tasks (só views).

- [ ] **Step 1: Tema e peças pequenas**

`Sources/AlttabApp/Views/Theme.swift`:

```swift
import SwiftUI

enum Theme {
    static let accent = Color(red: 1.0, green: 0.71, blue: 0.28) // #FFB547
    static let text = Color(red: 0.925, green: 0.929, blue: 0.937)
    static let muted = Color(red: 0.61, green: 0.63, blue: 0.67)
    static let cardFill = Color.white.opacity(0.035)
    static let cardStroke = Color.white.opacity(0.08)
    static let panelRadius: CGFloat = 22
    static let cardRadius: CGFloat = 12
    static let thumbRadius: CGFloat = 8
    static let spring = Animation.spring(response: 0.34, dampingFraction: 0.86)
}
```

`Sources/AlttabApp/Views/Bits.swift`:

```swift
import AlttabCore
import AppKit
import Collaboration
import SwiftUI

struct AppIcon: View {
    let item: WindowItem
    var body: some View {
        Image(nsImage: Self.icon(for: item))
            .resizable()
            .interpolation(.high)
    }

    static func icon(for item: WindowItem) -> NSImage {
        if let app = NSRunningApplication(processIdentifier: item.pid), let icon = app.icon { return icon }
        if let id = item.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil) ?? NSImage()
    }
}

struct HighlightedText: View {
    let text: String
    let query: String
    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        if let range = SwitcherModel.highlight(in: text, query: query),
           let lower = AttributedString.Index(range.lowerBound, within: result),
           let upper = AttributedString.Index(range.upperBound, within: result) {
            result[lower..<upper].backgroundColor = Theme.accent.opacity(0.25)
        }
        return result
    }
}

struct CloseButton: View {
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 24, height: 24)
                .background(Circle().fill(hovering ? Color.red : Color(white: 0.17).opacity(0.92)))
                .overlay(Circle().strokeBorder(.white.opacity(0.18)))
                .scaleEffect(hovering ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .accessibilityLabel("Fechar janela")
    }
}

struct Kbd: View {
    let keys: String
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Text(keys)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 5))
            Text(label).foregroundStyle(Theme.muted)
        }
        .font(.system(size: 12))
    }
}

enum UserProfile {
    static var name: String { UserDefaults.standard.string(forKey: "greetingName") ?? "Tom" }

    static let photo: NSImage? = {
        let identity = CBIdentity(name: NSUserName(), authority: CBIdentityAuthority.local()) as? CBUserIdentity
        return identity?.image
    }()
}
```

- [ ] **Step 2: Cabeçalho**

`Sources/AlttabApp/Views/HeaderView.swift`:

```swift
import AlttabCore
import SwiftUI

struct HeaderView: View {
    let state: SwitcherState

    var body: some View {
        HStack(spacing: 16) {
            searchField
            if let selected = state.model.selected {
                HStack(spacing: 10) {
                    AppIcon(item: selected)
                        .frame(width: 28, height: 28)
                        .id(selected.appName)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                    Text(selected.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                }
                .animation(.spring(response: 0.25), value: selected.appName)
            }
            Spacer(minLength: 12)
            greeting
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            Text(state.model.query.isEmpty ? "digite pra filtrar…" : state.model.query)
                .foregroundStyle(state.model.query.isEmpty ? Theme.muted : Theme.text)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(countLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.muted)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 12)
        .frame(width: 330, height: 40)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11)
            .strokeBorder(state.model.query.isEmpty ? Color.white.opacity(0.1) : Theme.accent.opacity(0.55)))
        .animation(.easeOut(duration: 0.2), value: state.model.query.isEmpty)
    }

    private var countLabel: String {
        let total = state.model.windows.count
        return state.model.query.isEmpty ? "\(total) itens" : "\(state.model.visible.count) de \(total)"
    }

    private var greeting: some View {
        HStack(spacing: 10) {
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(Greeting.text(hour: Calendar.current.component(.hour, from: .now))), \(UserProfile.name)")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.abbreviated).hour().minute()
                    .locale(Locale(identifier: "pt_BR")))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            Group {
                if let photo = UserProfile.photo {
                    Image(nsImage: photo).resizable().scaledToFill()
                } else {
                    Text(String(UserProfile.name.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.accent)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 1.5).padding(-2))
            .accessibilityLabel("Foto de \(UserProfile.name)")
        }
        .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 4)
        .background(.white.opacity(0.04), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
    }
}
```

- [ ] **Step 3: Cartão de janela**

`Sources/AlttabApp/Views/WindowCardView.swift`:

```swift
import AlttabCore
import SwiftUI

struct WindowCardView: View {
    let item: WindowItem
    let isSelected: Bool
    let isWide: Bool
    let isClosing: Bool
    let thumbnail: CGImage?
    let query: String
    let appearDelay: Double
    let onHover: () -> Void
    let onClick: () -> Void
    let onClose: () -> Void

    @State private var hoverPoint: CGPoint?
    @State private var size: CGSize = .zero
    @State private var appeared = false

    private let tiltMax = 8.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumb
                .frame(height: isWide ? 112 : 58)
                .clipShape(.rect(cornerRadius: Theme.thumbRadius))
                .overlay(alignment: .topTrailing) {
                    if isSelected && !isClosing {
                        CloseButton(action: onClose)
                            .padding(6)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
            HStack(spacing: 6) {
                AppIcon(item: item).frame(width: 16, height: 16)
                HighlightedText(text: item.displayTitle, query: query)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius)
            .fill(isSelected ? Color.white.opacity(0.07) : Theme.cardFill))
        .overlay(glow)
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius)
            .strokeBorder(isSelected ? Theme.accent : Theme.cardStroke, lineWidth: 1))
        .shadow(color: isSelected ? Theme.accent.opacity(0.22) : .clear, radius: 8)
        .rotation3DEffect(.degrees(tilt.x), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(tilt.y), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .scaleEffect(hoverPoint == nil ? 1 : 1.03)
        .offset(y: hoverPoint == nil ? 0 : -3)
        .opacity(isClosing ? 0 : (appeared ? 1 : 0))
        .scaleEffect(isClosing ? 0.8 : (appeared ? 1 : 0.94))
        .blur(radius: isClosing ? 3 : 0)
        .animation(.easeOut(duration: 0.12), value: hoverPoint)
        .animation(.easeIn(duration: 0.24), value: isClosing)
        .animation(Theme.spring, value: isSelected)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onContinuousHover { phase in
            switch phase {
            case .active(let point):
                hoverPoint = point
                onHover()
            case .ended:
                hoverPoint = nil
            }
        }
        .onTapGesture(perform: onClick)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8).delay(appearDelay)) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var tilt: (x: Double, y: Double) {
        guard let p = hoverPoint, size.width > 0, size.height > 0 else { return (0, 0) }
        let px = p.x / size.width, py = p.y / size.height
        return ((0.5 - py) * tiltMax, (px - 0.5) * tiltMax * 1.2)
    }

    @ViewBuilder private var thumb: some View {
        if let thumbnail {
            Image(decorative: thumbnail, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            ZStack {
                Color(red: 0.055, green: 0.063, blue: 0.075)
                AppIcon(item: item).frame(width: 28, height: 28).opacity(0.85)
            }
        }
    }

    private var glow: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius)
            .fill(RadialGradient(colors: [Theme.accent.opacity(0.18), .clear],
                                 center: UnitPoint(x: (hoverPoint?.x ?? 0) / max(size.width, 1),
                                                   y: (hoverPoint?.y ?? 0) / max(size.height, 1)),
                                 startRadius: 0, endRadius: 180))
            .opacity(hoverPoint == nil ? 0 : 1)
            .allowsHitTesting(false)
    }
}
```

- [ ] **Step 4: Coluna de workspace**

`Sources/AlttabApp/Views/WorkspaceColumnView.swift`:

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
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Text(column.id.isEmpty ? "–" : column.id)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(isCurrent ? Color.black : Theme.text)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(isCurrent ? Theme.accent : .white.opacity(isFocused ? 0.18 : 0.08),
                                in: .rect(cornerRadius: 7))
                Text(isCurrent ? "atual" : "\(column.items.count) jan.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
            ForEach(Array(column.items.enumerated()), id: \.element.id) { offset, item in
                WindowCardView(
                    item: item,
                    isSelected: item.id == state.model.selectedID,
                    isWide: isFocused,
                    isClosing: item.id == state.closingID,
                    thumbnail: state.thumbnails[item.id],
                    query: state.model.query,
                    appearDelay: Double(firstIndex + offset) * 0.03,
                    onHover: { controller.hover(item.id) },
                    onClick: { controller.click(item.id) },
                    onClose: { controller.closeWindow(item.id) })
            }
        }
    }
}
```

- [ ] **Step 5: Raiz com vidro e larguras animadas**

Reescrever `Sources/AlttabApp/Views/SwitcherView.swift`:

```swift
import AlttabCore
import SwiftUI

struct SwitcherView: View {
    let state: SwitcherState
    let controller: SwitcherController
    let width: CGFloat

    private let padding: CGFloat = 24
    private let spacing: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeaderView(state: state)
            columns
            footer
        }
        .padding(padding)
        .frame(width: width)
        .glassEffect(.regular.tint(.black.opacity(0.35)), in: .rect(cornerRadius: Theme.panelRadius))
        .id(state.openCount)
        .transition(.scale(scale: 0.97).combined(with: .opacity))
    }

    @ViewBuilder private var columns: some View {
        let cols = state.model.columns
        if cols.isEmpty {
            Text(state.model.query.isEmpty ? "Nenhuma janela aberta." : "Nenhuma janela com esse nome.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else {
            let focusedIndex = cols.firstIndex { $0.id == state.model.focusedColumnID }
            let widths = ColumnLayout.widths(count: cols.count, focusedIndex: focusedIndex,
                                             total: Double(width - padding * 2), spacing: Double(spacing),
                                             caps: state.model.query.isEmpty ? nil : (340, 190))
            let starts = startIndices(cols)
            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(cols.enumerated()), id: \.element.id) { index, column in
                    WorkspaceColumnView(column: column, isFocused: index == focusedIndex,
                                        isCurrent: column.id == state.model.currentWorkspace,
                                        firstIndex: starts[index], state: state, controller: controller)
                        .frame(width: CGFloat(widths[index]), alignment: .top)
                        .opacity(focusedIndex == nil || index == focusedIndex ? 1 : 0.78)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(Theme.spring, value: state.model.focusedColumnID)
            .animation(Theme.spring, value: cols.map(\.id))
        }
    }

    /// Posição global do primeiro cartão de cada coluna (para a cascata de entrada).
    private func startIndices(_ cols: [WorkspaceColumn]) -> [Int] {
        var result: [Int] = []
        var running = 0
        for column in cols {
            result.append(running)
            running += column.items.count
        }
        return result
    }

    private var footer: some View {
        HStack(spacing: 18) {
            Kbd(keys: "← →", label: "workspace")
            Kbd(keys: "↑ ↓", label: "janela")
            Kbd(keys: "1–9", label: "pula pro workspace")
            Kbd(keys: "⌥ W", label: "fecha a selecionada")
            Kbd(keys: "esc", label: "cancela")
        }
    }
}
```

- [ ] **Step 6: Compilar, rodar e conferir contra o protótipo**

Run: `swift test && ./scripts/build-app.sh && open build/Alttab.app`
Expected (manual, lado a lado com o quadro "A · com 8 workspaces" do protótipo):
1. Painel de vidro translúcido, cantos de 22 pt, a área de trabalho aparece desfocada atrás.
2. Cabeçalho: busca à esquerda com contador; ícone do app + título da seleção (o ícone troca com animação); "Boa noite, Tom" (conforme a hora), data e a foto da conta.
3. Coluna da seleção abre mais larga com mola suave ao trocar de workspace; as outras esmaecem.
4. Cartões entram em cascata (~30 ms entre eles) a cada abertura.
5. Mouse por cima: o cartão inclina seguindo o ponteiro e acende o brilho âmbar; o painel aberto com o mouse parado **não** troca a seleção (Review Focus 5).
6. X no canto de cima à direita da miniatura do selecionado; ao fechar, o cartão encolhe, desfoca e some.
7. Busca: só ficam as janelas que batem, colunas centralizadas e estreitas, trecho destacado em âmbar.
8. Clique num cartão vai para a janela (se o clique não funcionar no painel não ativo, anotar — ajuste: subclasse de `NSHostingView` com `acceptsFirstMouse(for:) -> true`).

- [ ] **Step 7: Commit**

```bash
git add Sources/AlttabApp/Views
git commit -F - <<'EOF'
feat: visual do alternador com vidro, colunas animadas e cartões inclináveis

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

### Task 10: Instalação e troca do atalho do AeroSpace

**Files:**
- Create: `scripts/install.sh`
- Modify (fora do repo, com confirmação do Tom): `~/.aerospace.toml` linha 159

**Interfaces:**
- Consumes: `scripts/build-app.sh` (Task 7).

- [ ] **Step 1: Script de instalação**

`scripts/install.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
pkill -x Alttab || true
rm -rf "$HOME/Applications/Alttab.app"
mkdir -p "$HOME/Applications"
cp -R build/Alttab.app "$HOME/Applications/Alttab.app"
open "$HOME/Applications/Alttab.app"
echo "instalado em ~/Applications/Alttab.app"
```

Run: `chmod +x scripts/install.sh && ./scripts/install.sh`
Expected: `instalado em ~/Applications/Alttab.app`; ícone na barra de menu. Se o macOS pedir de novo as permissões (caminho novo), conceder ao app em `~/Applications`.

- [ ] **Step 2: Iniciar com o Mac**

No menu do Alttab, marcar "Iniciar com o Mac".
Expected: o item fica marcado; `launchctl print gui/$(id -u) | grep -i alttab` mostra o serviço.

- [ ] **Step 3: Remover o atalho do AeroSpace (confirmar com o Tom antes)**

Perguntar ao Tom: "O alternador está funcionando; posso remover agora o `alt-tab = 'workspace-back-and-forth'` do `~/.aerospace.toml`?" Só seguir com o "sim".

```bash
cp ~/.aerospace.toml ~/.aerospace.toml.bak-alttab
grep -n "alt-tab = 'workspace-back-and-forth'" ~/.aerospace.toml
sed -i '' "/alt-tab = 'workspace-back-and-forth'/d" ~/.aerospace.toml
grep -c "alt-tab" ~/.aerospace.toml || true
aerospace reload-config
```

Expected: o primeiro `grep` mostra a linha 159; o segundo mostra `0`; `reload-config` sem erro. Option+Tab agora só abre o Alttab.

- [ ] **Step 4: Checklist final com o setup real**

Anotar resultado de cada item em `docs/superpowers/spikes/2026-10-09-resultados.md`, seção "Checklist do Plano 1":
1. 8 workspaces ocupados: colunas cabem, coluna em foco legível.
2. Option+Tab rápido repetido alterna entre as duas últimas janelas.
3. Janela fechada por fora enquanto o painel está aberto → escolher ela não trava o app.
4. AeroSpace parado (`pkill AeroSpace`): menu mostra "AeroSpace não respondeu"; Option+Tab não trava o teclado. Religar o AeroSpace depois.
5. Secure Input ligado (campo de senha): ícone vira triângulo e o menu diz quem segura.
6. Miniaturas de janelas em workspaces escondidos: aparecem depois que a janela ganhou foco uma vez.

- [ ] **Step 5: Commit**

```bash
git add scripts/install.sh docs/superpowers/spikes
git commit -F - <<'EOF'
chore: script de instalação e checklist do Plano 1

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V6rSUJX2XBghGow4Gqp53P
EOF
```

---

## Cobertura da spec neste plano

| Spec | Onde |
|---|---|
| 3.1 atalhos (Option+Tab, Tab, setas, 1–9, digitar, Option+W, soltar, Esc, mouse ≥14 pt) | Tasks 5, 6, 8 |
| 3.2 topo (busca, ícone + título, saudação, foto) | Task 9 |
| 3.2 colunas por workspace, foco 2,7, atual em destaque | Tasks 4, 6, 9 |
| 3.2 cartão com inclinação 8° e brilho | Task 9 |
| 3.2 busca só com o que bate, destaque, seleção no primeiro | Tasks 4, 9 |
| 3.2 fechar com X / animação, sem forçar confirmação | Tasks 8, 9 (`aerospace close` deixa o app perguntar) |
| 3.2 vidro | Task 9 |
| 4.1 HotkeyMonitor, WindowSource, WindowThumbs, MRUTracker, SwitcherModel, SwitcherPanel, UserGreeting, login, assinatura | Tasks 3–9 |
| 6 erros: sem Acessibilidade, sem Gravação de Tela, AeroSpace fora, miniatura vazia | Tasks 7, 8, 10 |
| 8 riscos 1–3 | Task 1 (spikes), Task 7 (Secure Input) |
| 9 instalação + remoção do atalho | Task 10 |
| Coluna do Edge, abas, extensão, host, `BrowserSource` | **Plano 2** |
| Player do YouTube Music, `AlbumColor`, flip da capa | **Plano 3** |
| 6 "AeroSpace fora → lista simples do macOS" | **Adiado** — no Plano 1 o menu avisa e o painel abre vazio; reavaliar se acontecer na prática |
