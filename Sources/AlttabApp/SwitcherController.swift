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
