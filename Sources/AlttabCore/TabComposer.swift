public enum TabComposer {
    public static let edgeBundleID = "com.microsoft.edgemac"

    public static func itemID(forTab tabId: Int) -> Int { -(tabId + 1) }

    /// Liga cada janela do navegador (windowId da extensão) a uma janela do Edge no AeroSpace.
    /// O título da janela no AeroSpace começa com o título da aba ativa ("… — Microsoft Edge",
    /// às vezes com " - Áudio em reprodução" no meio). Com uma janela de cada lado, liga direto.
    public static func match(edgeWindows: [WindowItem], tabs: [BrowserTab]) -> [Int: Int] {
        let browserWindows = Dictionary(grouping: tabs, by: \.windowId)
        var result: [Int: Int] = [:]
        var free = edgeWindows
        for (browserWindow, windowTabs) in browserWindows {
            guard let active = windowTabs.first(where: \.active) ?? windowTabs.max(by: { $0.lastAccessed < $1.lastAccessed }),
                  !active.title.isEmpty,
                  let index = free.firstIndex(where: { $0.title.hasPrefix(active.title) }) else { continue }
            result[browserWindow] = free.remove(at: index).id
        }
        let unmatched = browserWindows.keys.filter { result[$0] == nil }
        if unmatched.count == 1, free.count == 1 { result[unmatched[0]] = free[0].id }
        return result
    }

    /// Troca cada janela do Edge reconhecida pelas abas dela, na mesma posição da ordem de uso,
    /// da aba usada mais recentemente para a mais antiga.
    public static func compose(windows: [WindowItem], tabs: [BrowserTab]) -> [WindowItem] {
        guard !tabs.isEmpty else { return windows }
        let edgeWindows = windows.filter { $0.bundleID == edgeBundleID }
        let mapping = match(edgeWindows: edgeWindows, tabs: tabs)
        let browserWindowFor = Dictionary(uniqueKeysWithValues: mapping.map { ($1, $0) })
        return windows.flatMap { window -> [WindowItem] in
            guard let browserWindow = browserWindowFor[window.id] else { return [window] }
            return tabs.filter { $0.windowId == browserWindow }
                .sorted { $0.lastAccessed > $1.lastAccessed }
                .map { tab in
                    WindowItem(id: itemID(forTab: tab.id), pid: window.pid, appName: window.appName,
                               bundleID: window.bundleID, title: tab.title, workspace: window.workspace,
                               tab: TabRef(tabId: tab.id, windowID: window.id, url: tab.url, host: tab.host,
                                           favIconURL: tab.favIconUrl, audible: tab.audible))
                }
        }
    }
}
