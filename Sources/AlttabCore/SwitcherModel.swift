import Foundation

public struct WorkspaceColumn: Equatable, Sendable, Identifiable {
    public let id: String
    public let items: [WindowItem]
}

public struct SwitcherModel: Equatable, Sendable {
    /// Janelas em ordem de uso recente (índice 0 = janela atual).
    public private(set) var windows: [WindowItem]
    public let currentWorkspace: String
    public private(set) var query = ""
    public private(set) var selectedID: Int?

    public init(windows: [WindowItem], currentWorkspace: String) {
        self.windows = windows
        self.currentWorkspace = currentWorkspace
        // Option+Tab rápido vai para a janela anterior — pula as outras abas da janela atual.
        let current = windows.first?.windowKey
        selectedID = windows.dropFirst().first { $0.windowKey != current }?.id ?? windows.first?.id
    }

    public var visible: [WindowItem] {
        query.isEmpty ? windows : windows.filter { Self.matches($0, query: query) }
    }

    public var columns: [WorkspaceColumn] {
        let groups = Dictionary(grouping: visible, by: \.workspace)
        return groups.keys.sorted(by: Self.workspaceOrder).map { WorkspaceColumn(id: $0, items: groups[$0]!) }
    }

    public var selected: WindowItem? { visible.first { $0.id == selectedID } }

    public var focusedColumnID: String? { selected?.workspace }

    public mutating func select(_ id: Int) {
        if visible.contains(where: { $0.id == id }) { selectedID = id }
    }

    public mutating func next() { step(1) }
    public mutating func previous() { step(-1) }

    private mutating func step(_ delta: Int) {
        let v = visible
        guard !v.isEmpty else { selectedID = nil; return }
        guard let i = v.firstIndex(where: { $0.id == selectedID }) else { selectedID = v[0].id; return }
        selectedID = v[(i + delta % v.count + v.count) % v.count].id
    }

    public mutating func moveColumn(_ delta: Int) {
        let cols = columns
        guard !cols.isEmpty else { return }
        let current = cols.firstIndex { $0.id == focusedColumnID } ?? 0
        let target = min(max(current + delta, 0), cols.count - 1)
        selectedID = cols[target].items.first?.id
    }

    public mutating func moveInColumn(_ delta: Int) {
        guard let col = columns.first(where: { $0.id == focusedColumnID }),
              let i = col.items.firstIndex(where: { $0.id == selectedID }) else { return }
        selectedID = col.items[min(max(i + delta, 0), col.items.count - 1)].id
    }

    public mutating func jump(toWorkspace workspace: String) {
        if let col = columns.first(where: { $0.id == workspace }) { selectedID = col.items.first?.id }
    }

    public mutating func setQuery(_ newQuery: String) {
        query = newQuery
        let v = visible
        if !newQuery.trimmingCharacters(in: .whitespaces).isEmpty || !v.contains(where: { $0.id == selectedID }) {
            selectedID = v.first?.id
        }
    }

    /// Troca a lista por uma mais nova mantendo busca e seleção; se a selecionada sumiu, vai para a vizinha.
    public mutating func update(windows newWindows: [WindowItem]) {
        let before = visible
        let index = before.firstIndex { $0.id == selectedID }
        windows = newWindows
        let after = visible
        guard !after.contains(where: { $0.id == selectedID }) else { return }
        if after.isEmpty {
            selectedID = nil
        } else if let index {
            selectedID = after[min(index, after.count - 1)].id
        } else {
            selectedID = after.first?.id
        }
    }

    public mutating func remove(_ id: Int) {
        let before = visible
        let index = before.firstIndex { $0.id == id }
        windows.removeAll { $0.id == id }
        guard selectedID == id else { return }
        let after = visible
        if after.isEmpty {
            selectedID = nil
        } else if let index {
            selectedID = after[min(index, after.count - 1)].id
        } else {
            selectedID = after.first?.id
        }
    }

    // MARK: - Regras puras

    public static func workspaceOrder(_ a: String, _ b: String) -> Bool {
        switch (Int(a), Int(b)) {
        case let (x?, y?): return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return a.localizedStandardCompare(b) == .orderedAscending
        }
    }

    private static let searchOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    public static func matches(_ item: WindowItem, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return [item.displayTitle, item.appName, item.tab?.host ?? ""]
            .contains { $0.range(of: q, options: searchOptions) != nil }
    }

    public static func highlight(in text: String, query: String) -> Range<String.Index>? {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return nil }
        return text.range(of: q, options: searchOptions)
    }
}
