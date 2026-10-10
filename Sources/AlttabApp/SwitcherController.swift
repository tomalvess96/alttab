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

    /// Fonte das abas do Edge (miniaturas e "visto há" chegam ao vivo enquanto o painel está aberto).
    var browser: BrowserStore?
    /// Capa do álbum ampliada no centro do painel.
    var coverOpen = false
    /// Busca ativada por clique: cursor piscando e painel fixo.
    var searchFocused = false
    /// Altura do painel nesta abertura (a grade do Edge se ajusta a ela, sem rolagem).
    var panelHeight: CGFloat = 720

    /// Espaço que sobra para a grade de abas: painel menos cabeçalho, destaque, player, rodapé e margens.
    var edgeGridHeight: Double { max(120, Double(panelHeight) - 440) }

    /// Altura para os cartões de uma coluna: painel menos margens, cabeçalho, rodapé,
    /// cabeçalho da coluna e a pílula do player quando ela aparece.
    var cardsHeight: Double {
        let player = browser?.currentMedia == nil ? 0.0 : 70.0
        return max(120, Double(panelHeight) - 48 - 40 - 60 - 20 - 31 - player)
    }

    /// `wide` é ignorado de propósito: altura igual em foco ou não, senão o cartão selecionado pelo
    /// mouse desce ao abrir a coluna e sai de baixo do ponteiro.
    func cardThumbHeight(count: Int, wide: Bool) -> CGFloat {
        CGFloat(ColumnLayout.cardThumbHeight(count: count, preferred: ColumnLayout.cardThumbPreferred, available: cardsHeight))
    }

    func thumbnail(for item: WindowItem) -> CGImage? {
        if let tab = item.tab { return browser?.thumbnails[tab.tabId] }
        return thumbnails[item.id]
    }

    func capturedAt(for item: WindowItem) -> Date? {
        item.tab.flatMap { browser?.capturedAt[$0.tabId] }
    }
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
    /// Clique em qualquer outro app fecha o painel (inclusive no modo fixo de busca).
    private var outsideClick: Any?

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
        state.browser = browser
    }

    /// Janelas do AeroSpace com as janelas do Edge trocadas pelas abas (se a extensão estiver ligada).
    private func currentItems() -> [WindowItem] {
        browser.connected ? TabComposer.compose(windows: store.mruOrdered, tabs: browser.tabs) : store.mruOrdered
    }

    func mediaControl(_ action: MediaAction) {
        guard let media = browser.currentMedia else { return }
        bridge.send(.mediaControl(tabId: media.tabId, action: action))
    }

    func focusSearch() {
        machine.stick()
        state.searchFocused = machine.isSticky
    }

    func select(_ id: Int) {
        state.model.select(id)
    }

    var isOpen: Bool { machine.isOpen }

    /// Chamado de dentro do tap de teclado: decide se engole e adia o trabalho de tela,
    /// para o callback nunca segurar a digitação do sistema.
    func handle(_ input: KeyInput) -> Bool {
        let (actions, swallow) = machine.handle(input)
        schedule(actions)
        return swallow
    }

    func syncOption(held: Bool) {
        schedule(machine.syncOption(held: held))
    }

    private func schedule(_ actions: [SwitcherAction]) {
        guard !actions.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in actions.forEach { self?.perform($0) } }
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
        state.model = SwitcherModel(windows: currentItems(), currentWorkspace: store.currentWorkspace)
        state.thumbnails = thumbs.cache
        state.closingID = nil
        state.coverOpen = false
        state.searchFocused = false
        state.openCount += 1
        let mouse = NSEvent.mouseLocation
        hoverGate.reset(x: mouse.x, y: mouse.y)

        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        panelWidth = min(1232, visible.width - 48)
        let panelHeight = min(visible.height - 80, 720)
        state.panelHeight = panelHeight
        if panel == nil {
            panel = SwitcherPanel(rootView: SwitcherView(state: state, controller: self, width: panelWidth, height: panelHeight))
        }
        panel?.present(width: panelWidth, height: panelHeight)

        thumbs.capture(ids: state.model.windows.filter { $0.tab == nil }.map(\.id)) { [weak self] id, image in
            self?.state.thumbnails[id] = image
        }
        Task {
            await store.refresh()
            guard machine.isOpen else { return }
            state.model.update(windows: currentItems())
        }
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

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

    private func hide() {
        machine.close()
        panel?.dismiss()
        if let outsideClick { NSEvent.removeMonitor(outsideClick) }
        outsideClick = nil
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
}
