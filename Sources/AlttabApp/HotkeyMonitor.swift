import AlttabCore
import AppKit

@MainActor
final class HotkeyMonitor {
    /// Recebe a tecla traduzida e devolve se o evento deve ser engolido.
    var onInput: ((KeyInput) -> Bool)?
    /// Estado real do Option, lido de cada evento de tecla (cobre um "Option solto" perdido).
    var onOptionSync: ((Bool) -> Void)?
    /// Com o painel fechado, só o Tab interessa: o resto passa sem trabalho nenhum.
    var isSwitcherOpen: () -> Bool = { false }
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var optionWasHeld = false
    private var watchdog: Timer?

    private static let digitKeycodes: [Int64: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9, 29: 0]

    private static let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.flagsChanged.rawValue)

    func start() -> Bool {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: Self.mask, callback: hotkeyCallback, userInfo: refcon) else {
            return false
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        startWatchdog()
        return true
    }

    /// Joga fora o tap atual e cria outro. Usado quando o sistema diz que o tap está ligado
    /// mas as teclas não chegam (visto em 10/out: segundos por tecla, callback parado).
    @discardableResult
    func restart() -> Bool {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        guard start() else { return false }
        reenable()
        return true
    }

    /// A cada 5 s confere o tap na lista do sistema; morto, desligado ou lento demais → recria.
    /// Com o painel aberto não mexe: a primeira abertura monta a tela e já mediu ~600 ms num tap saudável.
    private func startWatchdog() {
        guard watchdog == nil else { return }
        watchdog = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.tap != nil, !self.isSwitcherOpen(), self.isUnhealthy() else { return }
                self.restart()
            }
        }
    }

    private func isUnhealthy() -> Bool {
        var count: UInt32 = 0
        guard CGGetEventTapList(0, nil, &count) == .success, count > 0 else { return false }
        var list = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
        guard CGGetEventTapList(count, &list, &count) == .success else { return false }
        let pid = getpid()
        let mine = list.prefix(Int(count)).first { $0.tappingProcess == pid && $0.eventsOfInterest == Self.mask }
        return TapHealth.needsRestart(found: mine != nil, enabled: mine?.enabled ?? false,
                                      avgLatencyMicros: mine?.avgUsecLatency ?? 0)
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        let held = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
        optionWasHeld = held
        onOptionSync?(held)
    }

    fileprivate func process(type: CGEventType, event: CGEvent) -> Bool {
        guard let input = translate(type: type, event: event) else { return false }
        return onInput?(input) ?? false
    }

    private func translate(type: CGEventType, event: CGEvent) -> KeyInput? {
        if type == .flagsChanged {
            let held = event.flags.contains(.maskAlternate)
            defer { optionWasHeld = held }
            if held && !optionWasHeld { return .optionDown }
            if !held && optionWasHeld { return .optionUp }
            return nil
        }
        guard type == .keyDown else { return nil }
        let held = event.flags.contains(.maskAlternate)
        if held != optionWasHeld {
            optionWasHeld = held
            onOptionSync?(held)
        }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        guard code == 48 || isSwitcherOpen() else { return nil }
        switch code {
        case 48: return .tab(shift: event.flags.contains(.maskShift))
        case 123: return .left
        case 124: return .right
        case 125: return .down
        case 126: return .up
        case 53: return .escape
        case 36, 76: return .enter
        case 51: return .backspace
        default: break
        }
        if let digit = Self.digitKeycodes[code] { return .digit(digit) }
        if let chars = NSEvent(cgEvent: event)?.charactersIgnoringModifiers, let first = chars.first,
           first.isLetter || first.isNumber || first.isPunctuation || first == " " {
            return .character(String(first))
        }
        return .other
    }
}

private func hotkeyCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                            refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
    // O tap roda no run loop principal; o evento não sai desta pilha.
    nonisolated(unsafe) let event = event
    let swallow = MainActor.assumeIsolated { () -> Bool in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            monitor.reenable()
            return false
        }
        return monitor.process(type: type, event: event)
    }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
