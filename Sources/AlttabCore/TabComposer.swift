public enum TabComposer {
    public static let edgeBundleID = "com.microsoft.edgemac"

    public static func itemID(forTab tabId: Int) -> Int { -(tabId + 1) }

    /// Título da janela do Edge no AeroSpace sem o sufixo do navegador e sem a marca de áudio.
    static func normalizedTitle(_ title: String) -> String {
        var result = title
        for suffix in [" — Microsoft Edge", " - Microsoft Edge"] where result.hasSuffix(suffix) {
            result = String(result.dropLast(suffix.count))
        }
        for marker in [" - Áudio em reprodução", " - Audio playing", " - Áudio silenciado", " - Audio muted"]
        where result.hasSuffix(marker) {
            result = String(result.dropLast(marker.count))
        }
        return result
    }

    /// Liga cada janela do navegador (windowId da extensão) a uma janela do Edge no AeroSpace pelo
    /// título da aba ativa: primeiro título exato, depois prefixo. Qualquer ambiguidade (títulos
    /// repetidos, mais de um candidato) deixa a janela sem ligar — melhor mostrar a janela do Edge
    /// do que pôr as abas no workspace errado. Com uma janela de cada lado, liga direto.
    public static func match(edgeWindows: [WindowItem], tabs: [BrowserTab]) -> [Int: Int] {
        let browserWindows = Dictionary(grouping: tabs, by: \.windowId)
        let order = browserWindows.keys.sorted()
        let activeTitle: [Int: String] = browserWindows.compactMapValues { windowTabs in
            (windowTabs.first(where: \.active) ?? windowTabs.max(by: { $0.lastAccessed < $1.lastAccessed }))?.title
        }
        let titleCount = Dictionary(activeTitle.values.map { ($0, 1) }, uniquingKeysWith: +)
        var free = edgeWindows.map { (window: $0, title: normalizedTitle($0.title)) }
        var result: [Int: Int] = [:]
        var ambiguous = false

        for exact in [true, false] {
            for browserWindow in order where result[browserWindow] == nil {
                guard let title = activeTitle[browserWindow], !title.isEmpty else { continue }
                guard titleCount[title] == 1 else { ambiguous = true; continue }
                let candidates = free.indices.filter { exact ? free[$0].title == title : free[$0].title.hasPrefix(title) }
                if candidates.count == 1 {
                    result[browserWindow] = free.remove(at: candidates[0]).window.id
                } else if candidates.count > 1 {
                    ambiguous = true
                }
            }
        }

        let unmatched = order.filter { result[$0] == nil }
        if !ambiguous, unmatched.count == 1, free.count == 1 { result[unmatched[0]] = free[0].window.id }
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
                                           favIconData: tab.favIconData, audible: tab.audible))
                }
        }
    }
}
