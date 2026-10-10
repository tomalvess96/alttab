public enum ColumnLayout {
    public static func widths(count: Int, focusedIndex: Int?, total: Double, spacing: Double,
                              focusWeight: Double = 2.7,
                              caps: (focused: Double, other: Double)? = nil) -> [Double] {
        guard count > 0 else { return [] }
        let usable = max(0, total - spacing * Double(count - 1))
        let weights = (0..<count).map { $0 == focusedIndex ? focusWeight : 1 }
        let sum = weights.reduce(0, +)
        return weights.enumerated().map { index, weight in
            let width = usable * weight / sum
            guard let caps else { return width }
            return min(width, index == focusedIndex ? caps.focused : caps.other)
        }
    }

    /// Altura do cartão além da miniatura: margens, rótulo, borda e espaço até o próximo.
    public static let cardChrome = 49.0
    public static let minCardThumb = 24.0

    /// Miniatura do cartão: o tamanho preferido, encolhendo para todos os cartões da coluna caberem na altura.
    public static func cardThumbHeight(count: Int, preferred: Double, available: Double) -> Double {
        guard count > 0 else { return preferred }
        let fit = (available / Double(count)).rounded(.down) - cardChrome
        return min(preferred, max(minCardThumb, fit))
    }
}
