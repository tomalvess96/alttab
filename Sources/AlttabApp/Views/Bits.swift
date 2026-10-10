import AlttabCore
import AppKit
import Collaboration
import SwiftUI

struct AppIcon: View {
    let item: WindowItem
    var body: some View {
        Image(nsImage: Self.icon(for: item))
            .resizable()
            .interpolation(.high)
    }

    static func icon(for item: WindowItem) -> NSImage {
        if let app = NSRunningApplication(processIdentifier: item.pid), let icon = app.icon { return icon }
        if let id = item.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil) ?? NSImage()
    }
}

struct HighlightedText: View {
    let text: String
    let query: String
    var body: some View {
        Text(attributed)
    }

    private var attributed: AttributedString {
        var result = AttributedString(text)
        if let range = SwitcherModel.highlight(in: text, query: query),
           let lower = AttributedString.Index(range.lowerBound, within: result),
           let upper = AttributedString.Index(range.upperBound, within: result) {
            result[lower..<upper].backgroundColor = Theme.accent.opacity(0.25)
        }
        return result
    }
}

struct CloseButton: View {
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 24, height: 24)
                .background(Circle().fill(hovering ? Color.red : Color(white: 0.17).opacity(0.92)))
                .overlay(Circle().strokeBorder(.white.opacity(0.18)))
                .scaleEffect(hovering ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .accessibilityLabel("Fechar janela")
    }
}

struct Kbd: View {
    let keys: String
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Text(keys)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.white.opacity(0.08), in: .rect(cornerRadius: 5))
            Text(label).foregroundStyle(Theme.muted)
        }
        .font(.system(size: 12))
    }
}

enum UserProfile {
    static var name: String { UserDefaults.standard.string(forKey: "greetingName") ?? "Tom" }

    static let photo: NSImage? = {
        let identity = CBIdentity(name: NSUserName(), authority: CBIdentityAuthority.local()) as? CBUserIdentity
        return identity?.image
    }()
}

struct TabIcon: View {
    let tab: TabRef
    let size: CGFloat

    /// O ícone vem em bytes da extensão (cache de favicons do Edge): nenhum download a pedido da página.
    private var image: CGImage? {
        tab.favIconData.flatMap { Data(base64Encoded: $0) }.flatMap { SafeImage.decode($0, maxPixelSize: 64) }
    }

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().interpolation(.high)
            } else {
                Text(String(tab.host.prefix(1)).uppercased())
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(white: 0.32))
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.25))
    }
}

/// Ícone do app para janela; favicon para aba.
struct ItemIcon: View {
    let item: WindowItem
    let size: CGFloat

    var body: some View {
        if let tab = item.tab {
            TabIcon(tab: tab, size: size)
        } else {
            AppIcon(item: item).frame(width: size, height: size)
        }
    }
}

struct AudioBars: View {
    @State private var phase = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 2, height: phase ? [10, 4, 8][index] : [4, 10, 5][index])
                    .animation(.easeInOut(duration: 0.4 + Double(index) * 0.1).repeatForever(autoreverses: true), value: phase)
            }
        }
        .frame(height: 10, alignment: .bottom)
        .onAppear { phase = true }
        .accessibilityLabel("Tocando áudio")
    }
}

struct AgoBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, design: .monospaced))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(.black.opacity(0.55), in: .rect(cornerRadius: 4))
    }
}

enum Ago {
    static func text(_ date: Date?) -> String? {
        guard let date else { return nil }
        if Date.now.timeIntervalSince(date) < 60 { return "agora" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
