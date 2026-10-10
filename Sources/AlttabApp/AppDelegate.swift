import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = WindowStore()
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
    }

    private func setIcon(warning: Bool) {
        let name = warning ? "exclamationmark.triangle" : "rectangle.on.rectangle"
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Alttab")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let error = store.lastError {
            menu.addItem(disabled("AeroSpace não respondeu: \(error.prefix(80))"))
        } else {
            menu.addItem(disabled("\(store.windows.count) janelas · workspace \(store.currentWorkspace)"))
        }
        if let holder = SecureInput.holder() {
            menu.addItem(disabled("Option+Tab bloqueado: Secure Input ativo em \(holder)"))
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
