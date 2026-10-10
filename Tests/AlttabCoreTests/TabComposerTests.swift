import Testing
@testable import AlttabCore

private func win(_ id: Int, _ ws: String, _ title: String, edge: Bool = false) -> WindowItem {
    WindowItem(id: id, pid: edge ? 99 : 1, appName: edge ? "Microsoft Edge" : "Warp",
               bundleID: edge ? TabComposer.edgeBundleID : "dev.warp.Warp-Stable", title: title, workspace: ws)
}

private func tab(_ id: Int, window: Int, _ title: String, active: Bool = false, at: Double, audible: Bool = false) -> BrowserTab {
    BrowserTab(id: id, windowId: window, title: title, url: "https://site\(id).com/x", favIconUrl: nil,
               active: active, audible: audible, lastAccessed: at)
}

@Suite struct TabComposerTests {
    @Test func itemIDIsNegativeAndUnique() {
        #expect(TabComposer.itemID(forTab: 0) == -1)
        #expect(TabComposer.itemID(forTab: 41) == -42)
    }

    @Test func singleEdgeWindowGetsAllTabs() {
        let windows = [win(613, "4", "ALT TAB"), win(297, "10", "Pontes — Microsoft Edge", edge: true)]
        let tabs = [tab(1, window: 5, "Pontes", active: true, at: 30), tab(2, window: 5, "YouTube", at: 20)]
        #expect(TabComposer.match(edgeWindows: [windows[1]], tabs: tabs) == [5: 297])
    }

    @Test func twoEdgeWindowsMatchByActiveTabTitle() {
        let edgeA = win(297, "10", "Pontes de acesso — Microsoft Edge", edge: true)
        let edgeB = win(300, "2", "(107) League - YouTube - Áudio em reprodução — Microsoft Edge", edge: true)
        let tabs = [tab(1, window: 5, "Pontes de acesso", active: true, at: 30),
                    tab(2, window: 8, "(107) League - YouTube", active: true, at: 40),
                    tab(3, window: 8, "Outra", at: 10)]
        #expect(TabComposer.match(edgeWindows: [edgeA, edgeB], tabs: tabs) == [5: 297, 8: 300])
    }

    @Test func composeReplacesEdgeWindowWithTabsInPlaceNewestFirst() {
        let windows = [win(613, "4", "ALT TAB"), win(297, "10", "Pontes — Microsoft Edge", edge: true), win(252, "2", "XML")]
        let tabs = [tab(1, window: 5, "Pontes", active: true, at: 30),
                    tab(2, window: 5, "YouTube", at: 50, audible: true),
                    tab(3, window: 5, "EvoDesk", at: 10)]
        let items = TabComposer.compose(windows: windows, tabs: tabs)
        #expect(items.map(\.id) == [613, -3, -2, -4, 252])
        #expect(items[1].workspace == "10")
        #expect(items[1].tab == TabRef(tabId: 2, windowID: 297, url: "https://site2.com/x", host: "site2.com",
                                       favIconURL: nil, audible: true))
        #expect(items[1].displayTitle == "YouTube")
    }

    @Test func unmatchedEdgeWindowStaysAsWindow() {
        let windows = [win(297, "10", "Algo — Microsoft Edge", edge: true), win(300, "2", "Outra — Microsoft Edge", edge: true)]
        let tabs = [tab(1, window: 5, "Nada a ver", active: true, at: 1)]
        #expect(TabComposer.compose(windows: windows, tabs: tabs).map(\.id) == [297, 300])
    }

    @Test func noTabsKeepsWindows() {
        let windows = [win(613, "4", "ALT TAB"), win(297, "10", "X — Microsoft Edge", edge: true)]
        #expect(TabComposer.compose(windows: windows, tabs: []) == windows)
    }

    @Test func quickSwitchFromEdgeSkipsSiblingTabs() {
        // Edge na frente: os dois primeiros itens são abas da mesma janela.
        let windows = [win(297, "10", "Pontes — Microsoft Edge", edge: true), win(613, "4", "ALT TAB")]
        let tabs = [tab(1, window: 5, "Pontes", active: true, at: 30), tab(2, window: 5, "YouTube", at: 20)]
        let model = SwitcherModel(windows: TabComposer.compose(windows: windows, tabs: tabs), currentWorkspace: "10")
        #expect(model.selectedID == 613)
    }

    @Test func searchFindsTabByHost() {
        let windows = [win(297, "10", "Pontes — Microsoft Edge", edge: true)]
        let tabs = [tab(1, window: 5, "Pontes", active: true, at: 30), tab(2, window: 5, "Vídeo", at: 20)]
        var model = SwitcherModel(windows: TabComposer.compose(windows: windows, tabs: tabs), currentWorkspace: "10")
        model.setQuery("site2")
        #expect(model.visible.map(\.id) == [-3])
    }
}
