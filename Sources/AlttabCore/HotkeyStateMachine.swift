public enum KeyInput: Equatable, Sendable {
    case optionDown, optionUp
    case tab(shift: Bool)
    case left, right, up, down
    case escape, enter, backspace
    case digit(Int)
    case character(String)
    case other
}

public enum SwitcherAction: Equatable, Sendable {
    case open, next, previous, left, right, up, down
    case commit, cancel, closeSelected
    /// "/" ou espaço com a busca vazia: ativa a busca (painel fixo) sem digitar nada.
    case focusSearch
    case jump(String)
    case type(String)
    case backspace
}

public struct HotkeyStateMachine: Sendable {
    public private(set) var isOpen = false
    public private(set) var isSticky = false
    private var optionHeld = false
    private var queryLength = 0

    public init() {}

    /// Clique na busca: o painel fica aberto ao soltar o Option, e as letras vão para a busca.
    public mutating func stick() {
        guard isOpen else { return }
        isSticky = true
    }

    public mutating func close() {
        isOpen = false
        isSticky = false
        queryLength = 0
    }

    /// Confere o Option com o estado real do teclado (cada evento traz os modificadores).
    /// Se o "Option solto" se perdeu, age como se ele tivesse chegado agora.
    public mutating func syncOption(held: Bool) -> [SwitcherAction] {
        guard optionHeld != held else { return [] }
        return handle(held ? .optionDown : .optionUp).actions
    }

    public mutating func handle(_ input: KeyInput) -> (actions: [SwitcherAction], swallow: Bool) {
        switch input {
        case .optionDown:
            optionHeld = true
            return ([], false)
        case .optionUp:
            optionHeld = false
            guard isOpen, !isSticky else { return ([], false) }
            close()
            return ([.commit], false)
        default:
            break
        }

        guard isOpen else {
            guard case .tab(let shift) = input, optionHeld else { return ([], false) }
            isOpen = true
            return (shift ? [.open, .previous, .previous] : [.open], true)
        }

        switch input {
        case .tab(let shift): return ([shift ? .previous : .next], true)
        case .left: return ([.left], true)
        case .right: return ([.right], true)
        case .up: return ([.up], true)
        case .down: return ([.down], true)
        case .escape:
            close()
            return ([.cancel], true)
        case .enter:
            close()
            return ([.commit], true)
        case .backspace:
            queryLength = max(0, queryLength - 1)
            return ([.backspace], true)
        case .digit(let n):
            guard queryLength > 0 else { return ([.jump(String(n))], true) }
            queryLength += 1
            return ([.type(String(n))], true)
        case .character(let c) where (c == "/" || c == " ") && queryLength == 0:
            isSticky = true
            return ([.focusSearch], true)
        case .character(let c):
            if c.lowercased() == "w", optionHeld, queryLength == 0, !isSticky { return ([.closeSelected], true) }
            queryLength += 1
            isSticky = true
            return ([.type(c)], true)
        case .other:
            return ([], true)
        case .optionDown, .optionUp:
            return ([], false)
        }
    }
}
