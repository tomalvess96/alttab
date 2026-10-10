import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = WindowStore()
    private let thumbs = WindowThumbs()
    let browser = BrowserStore()
    private lazy var bridge = BrowserBridge(store: browser)
    private lazy var controller = SwitcherController(store: store, thumbs: thumbs, browser: browser, bridge: bridge)
    private let hotkey = HotkeyMonitor()
    private var hotkeyActive = false
    private var statusItem: NSStatusItem!
    private var secureTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(warning: false)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        store.start()
        secureTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.setIcon(warning: SecureInput.holder() != nil) }
        }
        bridge.start()
        hotkey.onInput = { [weak self] input in self?.controller.handle(input) ?? false }
        hotkey.onOptionSync = { [weak self] held in self?.controller.syncOption(held: held) }
        hotkey.isSwitcherOpen = { [weak self] in self?.controller.isOpen ?? false }
        hotkeyActive = hotkey.start()
        if !hotkeyActive { openAccessibility() }
        // Ao acordar ou voltar à sessão o tap pode ficar "ligado" e surdo: recria sem esperar o vigia.
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(self, selector: #selector(recreateHotkey), name: name, object: nil)
        }
    }

    @objc private func recreateHotkey() {
        hotkeyActive = hotkey.restart()
    }

    private func setIcon(warning: Bool) {
        statusItem.button?.image = warning
            ? NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "AltTab: atalho bloqueado")
            : Self.menuBarGlyph
    }

    /// Ícone "Fenda" da barra de menu: três traços, o do meio mais alto. Imagem-modelo, então o
    /// macOS pinta de claro ou escuro conforme a barra.
    private static let menuBarGlyph: NSImage = {
        let image = NSImage(size: NSSize(width: 14, height: 16), flipped: true) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 1, y: 4, width: 1.6, height: 8), xRadius: 0.8, yRadius: 0.8).fill()
            NSBezierPath(roundedRect: NSRect(x: 5.6, y: 1, width: 2.8, height: 14), xRadius: 1.4, yRadius: 1.4).fill()
            NSBezierPath(roundedRect: NSRect(x: 11.4, y: 4, width: 1.6, height: 8), xRadius: 0.8, yRadius: 0.8).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "AltTab"
        return image
    }()

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let error = store.lastError {
            menu.addItem(disabled("AeroSpace não respondeu: \(error.prefix(80))"))
        } else {
            menu.addItem(disabled("\(store.windows.count) janelas · workspace \(store.currentWorkspace)"))
        }
        let withPhoto = browser.tabs.filter { browser.thumbnails[$0.id] != nil }.count
        menu.addItem(disabled(browser.connected ? "Edge: \(browser.tabs.count) abas · \(withPhoto) com foto" : "Edge: extensão desconectada"))
        if let holder = SecureInput.holder() {
            menu.addItem(disabled("Option+Tab bloqueado: Secure Input ativo em \(holder)"))
        }
        if !hotkeyActive {
            menu.addItem(disabled("Option+Tab desligado: conceda Acessibilidade e reabra o app"))
        }
        if !AXIsProcessTrusted() {
            menu.addItem(action("Conceder Acessibilidade…", #selector(openAccessibility)))
        }
        if !CGPreflightScreenCaptureAccess() {
            menu.addItem(action("Conceder Gravação de Tela…", #selector(openScreenCapture)))
        }
        menu.addItem(.separator())
        let login = action("Iniciar com o Mac", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(action("Sair", #selector(quit)))
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @objc private func openScreenCapture() {
        _ = CGRequestScreenCaptureAccess()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
