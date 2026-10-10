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
                                                         searching: !state.model.query.isEmpty,
                                                         gridHeight: state.edgeGridHeight),
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
