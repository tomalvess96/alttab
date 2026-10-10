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
