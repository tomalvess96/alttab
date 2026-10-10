/// Só deixa o mouse trocar a seleção depois de um movimento real.
/// Evita que o cartão embaixo de um mouse parado roube a seleção quando o painel abre
/// ou quando o layout muda embaixo do ponteiro.
public struct HoverGate: Sendable {
    private var anchor: (x: Double, y: Double)?
    public let minDistance: Double

    public init(minDistance: Double = 14) {
        self.minDistance = minDistance
    }

    public mutating func reset(x: Double, y: Double) {
        anchor = (x, y)
    }

    public mutating func shouldSelect(x: Double, y: Double) -> Bool {
        if let a = anchor, ((x - a.x) * (x - a.x) + (y - a.y) * (y - a.y)).squareRoot() < minDistance {
            return false
        }
        anchor = (x, y)
        return true
    }
}
