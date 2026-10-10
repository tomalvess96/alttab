import AlttabCore
import SwiftUI

extension AlbumColor.RGB {
    var color: Color { Color(red: r, green: g, blue: b) }
}

struct PlayerBar: View {
    let media: MediaState
    let receivedAt: Date
    let artwork: CGImage?
    let tint: Color
    let onControl: (MediaAction) -> Void
    let onCover: () -> Void
    /// Clique fora dos botões: vai para a aba do YouTube Music.
    let onOpen: () -> Void

    @State private var hover: CGPoint?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCover) { cover }
                .buttonStyle(.plain)
                .accessibilityLabel("Ampliar capa do álbum")
            VStack(alignment: .leading, spacing: 1) {
                Text(media.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .id(media.title)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                Text(media.artist.isEmpty ? "YouTube Music" : "\(media.artist) · YouTube Music")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.text.opacity(0.72))
                    .lineLimit(1)
            }
            .frame(width: 190, alignment: .leading)
            Visualizer(playing: media.playing, tint: tint)
                .frame(width: 46, height: 18)
            HStack(spacing: 2) {
                control("backward.end.fill", "Música anterior", .previous, size: 30)
                Button { onControl(.playPause) } label: {
                    Image(systemName: media.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(tint))
                        .shadow(color: tint.opacity(0.4), radius: 7)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(media.playing ? "Pausar" : "Tocar")
                control("forward.end.fill", "Próxima música", .next, size: 30)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 50)
        .background(tint.opacity(0.18), in: .rect(cornerRadius: 14))
        .overlay(glow)
        .overlay(alignment: .bottom) { progress }
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.33)))
        .clipShape(.rect(cornerRadius: 14))
        .shadow(color: tint.opacity(0.19), radius: 14, y: 8)
        .animation(.easeInOut(duration: 0.6), value: tint)
        .animation(.spring(response: 0.35), value: media.title)
        .contentShape(.rect(cornerRadius: 14))
        .onTapGesture(perform: onOpen)
        .help("Abrir no YouTube Music")
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hover = point
            case .ended: hover = nil
            }
        }
    }

    private var cover: some View {
        Group {
            if let artwork {
                Image(decorative: artwork, scale: 1).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [tint, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.45), radius: 6, y: 4)
        .id(media.title)
        .transition(.asymmetric(insertion: .modifier(active: FlipModifier(angle: 90, scale: 0.8), identity: FlipModifier(angle: 0, scale: 1)),
                                removal: .opacity))
    }

    private func control(_ symbol: String, _ label: String, _ action: MediaAction, size: CGFloat) -> some View {
        Button { onControl(action) } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }

    private var glow: some View {
        RadialGradient(colors: [tint.opacity(0.33), .clear],
                       center: .init(x: (hover?.x ?? 0) / 520, y: (hover?.y ?? 0) / 50),
                       startRadius: 0, endRadius: 220)
            .opacity(hover == nil ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: hover == nil)
            .allowsHitTesting(false)
    }

    private var progress: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !media.playing)) { context in
            let fraction = media.progress(at: context.date.timeIntervalSince(receivedAt))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.08))
                    Rectangle().fill(tint).frame(width: geo.size.width * fraction)
                    Circle().fill(.white).frame(width: 6, height: 6)
                        .shadow(color: tint, radius: 4)
                        .offset(x: geo.size.width * fraction - 3)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 12)
        }
    }
}

/// Barrinhas que só andam tocando; pausado ficam baixas e paradas.
struct Visualizer: View {
    let playing: Bool
    let tint: Color

    var body: some View {
        TimelineView(.animation(paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<9, id: \.self) { index in
                    let speed = 0.5 + Double((index * 37) % 5) / 10
                    let level = playing ? 0.25 + 0.75 * abs(sin(t * .pi / speed + Double(index) * 0.7)) : 0.2
                    Capsule().fill(tint).frame(height: 18 * level)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

struct FlipModifier: ViewModifier {
    let angle: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(scale)
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Capa grande no centro do painel, com controles de player. Clique fora dos controles fecha.
struct CoverOverlay: View {
    let media: MediaState
    let receivedAt: Date
    let artwork: CGImage?
    let tint: Color
    let onControl: (MediaAction) -> Void
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.55)).background(.ultraThinMaterial)
            VStack(spacing: 18) {
                Group {
                    if let artwork {
                        Image(decorative: artwork, scale: 1).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            LinearGradient(colors: [tint, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Image(systemName: "music.note").font(.system(size: 84, weight: .light)).foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 280, height: 280)
                .clipShape(.rect(cornerRadius: 22))
                .shadow(color: tint.opacity(0.4), radius: 40, y: 20)
                .transition(.modifier(active: FlipModifier(angle: 180, scale: 0.14), identity: FlipModifier(angle: 0, scale: 1)))
                VStack(spacing: 4) {
                    Text(media.title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    Text([media.artist, media.album].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.72)).lineLimit(1)
                }
                .frame(width: 360)
                progress
                controls
                Button(action: onOpen) {
                    Label("Abrir no YouTube Music", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text.opacity(0.8))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.white.opacity(0.08), in: .capsule)
                }
                .buttonStyle(PressStyle())
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .clipShape(.rect(cornerRadius: Theme.panelRadius))
        .contentShape(.rect)
        .onTapGesture(perform: onClose)
        .accessibilityLabel("Capa ampliada. Clique fora dos controles para fechar")
    }

    private var progress: some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !media.playing)) { context in
            let elapsed = context.date.timeIntervalSince(receivedAt)
            let fraction = media.progress(at: elapsed)
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))
                        Capsule().fill(tint).frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 4)
                HStack {
                    Text(MediaState.timeText(media.elapsed(at: elapsed)))
                    Spacer()
                    Text(media.duration > 0 ? MediaState.timeText(media.duration) : "ao vivo")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.text.opacity(0.65))
            }
            .frame(width: 320)
        }
    }

    private var controls: some View {
        HStack(spacing: 28) {
            controlButton("backward.end.fill", "Música anterior", .previous, size: 20)
            Button { onControl(.playPause) } label: {
                Image(systemName: media.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(tint))
                    .shadow(color: tint.opacity(0.5), radius: 14)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(media.playing ? "Pausar" : "Tocar")
            controlButton("forward.end.fill", "Próxima música", .next, size: 20)
        }
    }

    private func controlButton(_ symbol: String, _ label: String, _ action: MediaAction, size: CGFloat) -> some View {
        Button { onControl(action) } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 48, height: 48)
                .background(Circle().fill(.white.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}
