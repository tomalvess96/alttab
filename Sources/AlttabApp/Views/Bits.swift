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
