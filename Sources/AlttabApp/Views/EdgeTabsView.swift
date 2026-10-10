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
                                    height: EdgeColumnLayout.miniThumbHeight(tabCount: tabs.count, columns: columns,
                                                                            available: state.edgeGridHeight),
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
            thumbHeight: state.cardThumbHeight(count: min(tabs.count, 4), wide: isFocused),
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
                        // Sempre reserva as duas linhas: título curto ou longo, a grade embaixo não sobe nem desce.
                        .lineLimit(2, reservesSpace: true)
                    Text(item.tab?.host ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
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
