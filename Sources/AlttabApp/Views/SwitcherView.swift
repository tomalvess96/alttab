import AlttabCore
import SwiftUI

struct SwitcherView: View {
    let state: SwitcherState
    let controller: SwitcherController
    let width: CGFloat
    let height: CGFloat

    private let padding: CGFloat = 24
    private let spacing: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeaderView(state: state)
            columns
            Spacer(minLength: 0)
            player
            footer
        }
        .padding(padding)
        .frame(width: width, height: height, alignment: .top)
        .glassEffect(.regular.tint(.black.opacity(0.35)), in: .rect(cornerRadius: Theme.panelRadius))
        .overlay {
            if state.coverOpen, let browser = state.browser, let media = browser.currentMedia {
                CoverOverlay(media: media, artwork: media.artworkUrl.flatMap { browser.artwork[$0] },
                             tint: tint(browser, media),
                             onClose: { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { state.coverOpen = false } })
            }
        }
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
            let focusedTabs = focusedIndex.map { cols[$0].items.filter { $0.tab != nil }.count } ?? 0
            let focusMode = EdgeColumnLayout.mode(tabCount: focusedTabs, focused: true, searching: false)
            let widths = ColumnLayout.widths(count: cols.count, focusedIndex: focusedIndex,
                                             total: Double(width - padding * 2), spacing: Double(spacing),
                                             focusWeight: EdgeColumnLayout.focusWeight(for: focusMode),
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
