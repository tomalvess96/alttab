import AlttabCore
import SwiftUI

struct WindowCardView: View {
    let item: WindowItem
    let isSelected: Bool
    let isWide: Bool
    let isClosing: Bool
    let thumbnail: CGImage?
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
        VStack(alignment: .leading, spacing: 8) {
            thumb
                .frame(height: isWide ? 112 : 58)
                .clipShape(.rect(cornerRadius: Theme.thumbRadius))
                .overlay(alignment: .topTrailing) {
                    if isSelected && !isClosing {
                        CloseButton(action: onClose)
                            .padding(6)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
            HStack(spacing: 6) {
                AppIcon(item: item).frame(width: 16, height: 16)
                HighlightedText(text: item.displayTitle, query: query)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius)
            .fill(isSelected ? Color.white.opacity(0.07) : Theme.cardFill))
        .overlay(glow)
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius)
            .strokeBorder(isSelected ? Theme.accent : Theme.cardStroke, lineWidth: 1))
        .shadow(color: isSelected ? Theme.accent.opacity(0.22) : .clear, radius: 8)
        .rotation3DEffect(.degrees(tilt.x), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(tilt.y), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .scaleEffect(hoverPoint == nil ? 1 : 1.03)
        .offset(y: hoverPoint == nil ? 0 : -3)
        .opacity(isClosing ? 0 : (appeared ? 1 : 0))
        .scaleEffect(isClosing ? 0.8 : (appeared ? 1 : 0.94))
        .blur(radius: isClosing ? 3 : 0)
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
                AppIcon(item: item).frame(width: 28, height: 28).opacity(0.85)
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
