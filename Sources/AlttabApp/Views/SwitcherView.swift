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
