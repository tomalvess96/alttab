public struct MRUTracker: Sendable {
    public private(set) var order: [Int] = []

    public init() {}

    public mutating func touch(_ id: Int) {
        order.removeAll { $0 == id }
        order.insert(id, at: 0)
    }

    public mutating func prune(keeping ids: Set<Int>) {
        order.removeAll { !ids.contains($0) }
    }

    public func sorted(_ items: [WindowItem]) -> [WindowItem] {
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        let known = items.filter { rank[$0.id] != nil }.sorted { rank[$0.id]! < rank[$1.id]! }
        let unknown = items.filter { rank[$0.id] == nil }
        return known + unknown
    }
}
