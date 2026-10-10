import Testing
@testable import AlttabCore

private func w(_ id: Int, _ ws: String, _ title: String = "", app: String = "Warp") -> WindowItem {
    WindowItem(id: id, pid: 1, appName: app, bundleID: nil, title: title.isEmpty ? "janela \(id)" : title, workspace: ws)
}

@Suite struct SwitcherModelTests {
    // MRU: 1 é a janela atual, 2 a anterior…
    let mru = [w(1, "4", "Alt+Tab com abas"), w(2, "4", "EVODESK"), w(3, "3", "DESKSOFT"),
               w(4, "10", "YouTube - Áudio em reprodução", app: "Microsoft Edge"), w(5, "3", "SAMAE")]

    @Test func initialSelectionIsPreviousWindow() {
        #expect(SwitcherModel(windows: mru, currentWorkspace: "4").selectedID == 2)
    }

    @Test func singleWindowSelectsItself() {
        #expect(SwitcherModel(windows: [w(9, "1")], currentWorkspace: "1").selectedID == 9)
    }

    @Test func noWindowsIsSafe() {
        var m = SwitcherModel(windows: [], currentWorkspace: "1")
        #expect(m.selectedID == nil)
        m.next(); m.previous(); m.moveColumn(1); m.moveInColumn(1); m.jump(toWorkspace: "2")
        #expect(m.selectedID == nil)
        #expect(m.columns.isEmpty)
    }

    @Test func nextAndPreviousWrapInMRUOrder() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.next(); #expect(m.selectedID == 3)
        m.next(); m.next(); m.next(); #expect(m.selectedID == 1)
        m.previous(); #expect(m.selectedID == 5)
    }

    @Test func workspaceOrderIsNumericThenNames() {
        let names = ["web", "10", "2", "9", ""]
        #expect(names.sorted(by: SwitcherModel.workspaceOrder) == ["2", "9", "10", "", "web"])
    }

    @Test func columnsGroupByWorkspaceKeepingMRUInside() {
        let cols = SwitcherModel(windows: mru, currentWorkspace: "4").columns
        #expect(cols.map(\.id) == ["3", "4", "10"])
        #expect(cols[0].items.map(\.id) == [3, 5])
        #expect(cols[1].items.map(\.id) == [1, 2])
    }

    @Test func focusedColumnFollowsSelection() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        #expect(m.focusedColumnID == "4")
        m.select(4)
        #expect(m.focusedColumnID == "10")
    }

    @Test func moveColumnSelectsFirstOfNeighborAndClamps() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.moveColumn(1); #expect(m.selectedID == 4)
        m.moveColumn(1); #expect(m.selectedID == 4)
        m.moveColumn(-2); #expect(m.selectedID == 3)
        m.moveColumn(-1); #expect(m.selectedID == 3)
    }

    @Test func moveInColumnClamps() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.select(3)
        m.moveInColumn(1); #expect(m.selectedID == 5)
        m.moveInColumn(1); #expect(m.selectedID == 5)
        m.moveInColumn(-5); #expect(m.selectedID == 3)
    }

    @Test func jumpToWorkspace() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.jump(toWorkspace: "3"); #expect(m.selectedID == 3)
        m.jump(toWorkspace: "7"); #expect(m.selectedID == 3)
    }

    @Test func queryIsAccentAndCaseInsensitive() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("audio")
        #expect(m.visible.map(\.id) == [4])
        #expect(m.selectedID == 4)
    }

    @Test func queryMatchesAppName() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("edge")
        #expect(m.visible.map(\.id) == [4])
    }

    @Test func querySnapsSelectionToFirstHitAndHidesEmptyColumns() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("desk")
        #expect(m.visible.map(\.id) == [2, 3])
        #expect(m.selectedID == 2)
        #expect(m.columns.map(\.id) == ["3", "4"])
    }

    @Test func queryWithoutHitsClearsSelection() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("zzz")
        #expect(m.selectedID == nil)
        m.next()
        #expect(m.selectedID == nil)
    }

    @Test func selectIgnoresHiddenWindow() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.setQuery("samae")
        m.select(1)
        #expect(m.selectedID == 5)
    }

    @Test func highlightFindsRangeIgnoringAccents() {
        let t = "YouTube - Áudio em reprodução"
        let r = SwitcherModel.highlight(in: t, query: "audio")
        #expect(r.map { String(t[$0]) } == "Áudio")
        #expect(SwitcherModel.highlight(in: t, query: "") == nil)
    }

    @Test func removeSelectedMovesToNextVisible() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.remove(2)
        #expect(m.selectedID == 3)
        #expect(!m.windows.contains { $0.id == 2 })
    }

    @Test func removeLastSelectedMovesToPrevious() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.select(5)
        m.remove(5)
        #expect(m.selectedID == 4)
    }

    @Test func removeOtherKeepsSelection() {
        var m = SwitcherModel(windows: mru, currentWorkspace: "4")
        m.remove(4)
        #expect(m.selectedID == 2)
    }

    @Test func removeEverythingClearsSelection() {
        var m = SwitcherModel(windows: [w(1, "1"), w(2, "1")], currentWorkspace: "1")
        m.remove(2); m.remove(1)
        #expect(m.selectedID == nil)
        #expect(m.columns.isEmpty)
    }
}
