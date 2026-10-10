import Testing
@testable import AlttabCore

private func w(_ id: Int) -> WindowItem {
    WindowItem(id: id, pid: 1, appName: "A", bundleID: nil, title: "t\(id)", workspace: "1")
}

@Suite struct MRUTrackerTests {
    @Test func touchMovesToFront() {
        var m = MRUTracker()
        m.touch(1); m.touch(2); m.touch(3); m.touch(1)
        #expect(m.order == [1, 3, 2])
    }

    @Test func touchSameIdTwiceKeepsSingleEntry() {
        var m = MRUTracker()
        m.touch(5); m.touch(5)
        #expect(m.order == [5])
    }

    @Test func pruneDropsClosedWindows() {
        var m = MRUTracker()
        m.touch(1); m.touch(2); m.touch(3)
        m.prune(keeping: [1, 3])
        #expect(m.order == [3, 1])
    }

    @Test func sortedPutsKnownFirstThenUnknownInInputOrder() {
        var m = MRUTracker()
        m.touch(2); m.touch(4)
        let ids = m.sorted([w(1), w(2), w(3), w(4)]).map(\.id)
        #expect(ids == [4, 2, 1, 3])
    }

    @Test func sortedIgnoresIdsNotInInput() {
        var m = MRUTracker()
        m.touch(99); m.touch(1)
        #expect(m.sorted([w(1), w(2)]).map(\.id) == [1, 2])
    }
}
