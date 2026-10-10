public enum EdgeColumnLayout: Equatable, Sendable {
    /// Cartões normais (poucas abas, ou resultados de busca numa coluna fora de foco).
    case cards
    /// Fora de foco: as mais recentes + um cartão empilhado "+N".
    case peek(visible: Int, hidden: Int)
    /// Em foco: destaque grande da aba selecionada + grade fixa de miniaturas.
    case heroGrid(columns: Int)

    public static let peekCount = 3

    public static func mode(tabCount: Int, focused: Bool, searching: Bool) -> EdgeColumnLayout {
        guard tabCount > 4 else { return .cards }
        if focused { return .heroGrid(columns: tabCount <= 9 ? 3 : tabCount <= 20 ? 5 : 6) }
        if searching { return .cards }
        return .peek(visible: peekCount, hidden: tabCount - peekCount)
    }

    public static func miniThumbHeight(tabCount: Int, columns: Int, available: Double = 300) -> Double {
        let rows = max(1, (tabCount + max(columns, 1) - 1) / max(columns, 1))
        return min(64, max(26, (available / Double(rows)).rounded(.down) - 22))
    }

    /// Peso da coluna em foco no `ColumnLayout`: a grade precisa de mais largura.
    public static func focusWeight(for mode: EdgeColumnLayout) -> Double {
        if case .heroGrid(let columns) = mode { return 2.2 + Double(columns) * 0.5 }
        return 2.7
    }
}
