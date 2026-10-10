import Testing
@testable import AlttabCore

@Suite struct EdgeColumnLayoutTests {
    @Test func fourOrLessAreCards() {
        #expect(EdgeColumnLayout.mode(tabCount: 4, focused: true, searching: false) == .cards)
        #expect(EdgeColumnLayout.mode(tabCount: 0, focused: false, searching: false) == .cards)
    }

    @Test func unfocusedShowsThreePlusRest() {
        #expect(EdgeColumnLayout.mode(tabCount: 20, focused: false, searching: false) == .peek(visible: 3, hidden: 17))
    }

    @Test func unfocusedWhileSearchingShowsAllHits() {
        #expect(EdgeColumnLayout.mode(tabCount: 6, focused: false, searching: true) == .cards)
    }

    @Test(arguments: [(5, 3), (9, 3), (10, 5), (20, 5), (21, 6), (36, 6), (40, 7)])
    func focusedGridColumns(count: Int, columns: Int) {
        #expect(EdgeColumnLayout.mode(tabCount: count, focused: true, searching: false) == .heroGrid(columns: columns))
    }

    @Test func miniThumbHeightFollowsPrototype() {
        #expect(EdgeColumnLayout.miniThumbHeight(tabCount: 20, columns: 5) == 53)
        #expect(EdgeColumnLayout.miniThumbHeight(tabCount: 5, columns: 3) == 64)
        #expect(EdgeColumnLayout.miniThumbHeight(tabCount: 40, columns: 6) == 26)
    }

    @Test func focusWeightGrowsWithGrid() {
        #expect(EdgeColumnLayout.focusWeight(for: .cards) == 2.7)
        #expect(abs(EdgeColumnLayout.focusWeight(for: .heroGrid(columns: 5)) - 4.7) < 1e-9)
    }
}

@Suite struct EdgeColumnFitTests {
    @Test func manyTabsGrowColumnsToFitHeight() {
        #expect(EdgeColumnLayout.mode(tabCount: 100, focused: true, searching: false, gridHeight: 300) == .heroGrid(columns: 17))
        let thumb = EdgeColumnLayout.miniThumbHeight(tabCount: 100, columns: 17, available: 300)
        #expect(6 * (thumb + 22) <= 300)
    }

    @Test func usualCountsKeepPrototypeColumns() {
        #expect(EdgeColumnLayout.mode(tabCount: 20, focused: true, searching: false, gridHeight: 300) == .heroGrid(columns: 5))
        #expect(EdgeColumnLayout.mode(tabCount: 9, focused: true, searching: false, gridHeight: 300) == .heroGrid(columns: 3))
    }

    @Test func shortPanelStillFits() {
        guard case .heroGrid(let columns) = EdgeColumnLayout.mode(tabCount: 40, focused: true, searching: false, gridHeight: 120) else {
            Issue.record("esperava grade"); return
        }
        let rows = (40 + columns - 1) / columns
        #expect(Double(rows) * (EdgeColumnLayout.miniThumbHeight(tabCount: 40, columns: columns, available: 120) + 22) <= 120)
    }
}
