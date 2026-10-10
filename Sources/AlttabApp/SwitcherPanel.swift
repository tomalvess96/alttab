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

    /// Altura fixa por abertura: o conteúdo cresce (coluna em foco, grade do Edge) sem recalcular a janela.
    func present(width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let frame = NSRect(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.midY - height / 2,
                           width: width, height: height)
        setFrame(frame, display: true)
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
    }
}
