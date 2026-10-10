import AlttabCore
import SwiftUI

struct HeaderView: View {
    let state: SwitcherState
    let controller: SwitcherController

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
            HStack(spacing: 1) {
                if !state.model.query.isEmpty {
                    Text(state.model.query).foregroundStyle(Theme.text).lineLimit(1)
                }
                if state.searchFocused { Caret() }
                if state.model.query.isEmpty {
                    Text(state.searchFocused ? "digite…" : "digite pra filtrar…").foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
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
            .strokeBorder(state.model.query.isEmpty && !state.searchFocused ? Color.white.opacity(0.1) : Theme.accent.opacity(0.55)))
        .animation(.easeOut(duration: 0.2), value: state.model.query.isEmpty)
        .animation(.easeOut(duration: 0.2), value: state.searchFocused)
        .contentShape(.rect(cornerRadius: 11))
        // Clicar na busca deixa o painel aberto ao soltar o Option, pronto para digitar.
        .onTapGesture { controller.focusSearch() }
        .accessibilityAddTraits(.isSearchField)
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

/// Cursor piscando no campo de busca quando ele está ativo.
struct Caret: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 1.5, height: 16)
                .opacity(Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0 ? 1 : 0)
        }
        .accessibilityHidden(true)
    }
}
