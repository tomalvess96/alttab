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
}
