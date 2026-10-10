import AlttabCore
import SwiftUI

struct WindowCardView: View {
    let item: WindowItem
    let isSelected: Bool
    let isWide: Bool
    /// Miniatura já encolhida para a coluna caber no painel (nil = tamanho padrão).
    var thumbHeight: CGFloat? = nil
    let isClosing: Bool
    let thumbnail: CGImage?
    var capturedAt: Date? = nil
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
        face
            // Inclinação, zoom e entrada são só desenho: o desenho não recebe o mouse.
            // Com perspectiva, a área do cartão inclinado é projetada e passava a "pegar"
            // o mouse até ~200 pt fora do cartão, roubando a seleção dos vizinhos.
            .rotation3DEffect(.degrees(tilt.x), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(tilt.y), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(hoverPoint == nil ? 1 : 1.03)
            .offset(y: hoverPoint == nil ? 0 : -3)
            .opacity(isClosing ? 0 : (appeared ? 1 : 0))
            .scaleEffect(isClosing ? 0.8 : (appeared ? 1 : 0.94))
            .blur(radius: isClosing ? 3 : 0)
            .allowsHitTesting(false)
            .overlay(alignment: .topTrailing) {
                if isSelected && !isClosing {
                    CloseButton(action: onClose)
                        .padding(13)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            // O mouse é medido neste retângulo fixo, do tamanho exato do cartão.
            .contentShape(.rect(cornerRadius: Theme.cardRadius))
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

    private var face: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumb
                .frame(height: thumbHeight ?? CGFloat(ColumnLayout.cardThumbPreferred))
                .clipShape(.rect(cornerRadius: Theme.thumbRadius))
                .overlay(alignment: .bottomTrailing) {
                    if let ago = Ago.text(capturedAt) { AgoBadge(text: ago).padding(5) }
                }
            HStack(spacing: 6) {
                ItemIcon(item: item, size: 16)
                HighlightedText(text: item.displayTitle, query: query)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                if item.tab?.audible == true {
                    Spacer(minLength: 0)
                    AudioBars()
                }
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius)
            .fill(isSelected ? Color.white.opacity(0.07) : Theme.cardFill))
        .overlay(glow)
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius)
            .strokeBorder(isSelected ? Theme.accent : Theme.cardStroke, lineWidth: 1))
        .shadow(color: isSelected ? Theme.accent.opacity(0.22) : .clear, radius: 8)
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
                ItemIcon(item: item, size: 28).opacity(0.85)
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
