import Testing
@testable import AlttabCore

@Suite struct HotkeyStateMachineTests {
    private func opened() -> HotkeyStateMachine {
        var m = HotkeyStateMachine()
        _ = m.handle(.optionDown)
        _ = m.handle(.tab(shift: false))
        return m
    }

    @Test func optionTabOpensAndSwallows() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.optionDown) == ([], false))
        #expect(m.handle(.tab(shift: false)) == ([.open], true))
        #expect(m.isOpen)
    }

    @Test func tabWithoutOptionPassesThrough() {
        var m = HotkeyStateMachine()
        #expect(m.handle(.tab(shift: false)) == ([], false))
        #expect(!m.isOpen)
    }

    @Test func quickTapCommitsOnOptionUp() {
        var m = opened()
        #expect(m.handle(.optionUp) == ([.commit], false))
        #expect(!m.isOpen)
    }

    @Test func optionUpWhenClosedDoesNothing() {
        var m = HotkeyStateMachine()
        _ = m.handle(.optionDown)
        #expect(m.handle(.optionUp) == ([], false))
    }

    @Test func shiftTabOpensOnLastItem() {
        var m = HotkeyStateMachine()
        _ = m.handle(.optionDown)
        #expect(m.handle(.tab(shift: true)) == ([.open, .previous, .previous], true))
    }

    @Test func tabWhileOpenCycles() {
        var m = opened()
        #expect(m.handle(.tab(shift: false)) == ([.next], true))
        #expect(m.handle(.tab(shift: true)) == ([.previous], true))
    }

    @Test func arrowsMap() {
        var m = opened()
        #expect(m.handle(.left) == ([.left], true))
        #expect(m.handle(.right) == ([.right], true))
        #expect(m.handle(.up) == ([.up], true))
        #expect(m.handle(.down) == ([.down], true))
    }

    @Test func escapeCancelsAndCloses() {
        var m = opened()
        #expect(m.handle(.escape) == ([.cancel], true))
        #expect(!m.isOpen)
        #expect(m.handle(.optionUp) == ([], false))
    }

    @Test func optionWClosesSelectedWhileNothingTyped() {
        var m = opened()
        #expect(m.handle(.character("w")) == ([.closeSelected], true))
        #expect(m.isOpen)
    }

    @Test func typingMakesStickyAndWBecomesLetter() {
        var m = opened()
        #expect(m.handle(.character("x")) == ([.type("x")], true))
        #expect(m.isSticky)
        #expect(m.handle(.character("w")) == ([.type("w")], true))
        #expect(m.handle(.optionUp) == ([], false))
        #expect(m.isOpen)
        #expect(m.handle(.enter) == ([.commit], true))
        #expect(!m.isOpen)
    }

    @Test func digitsJumpUntilSomethingIsTyped() {
        var m = opened()
        #expect(m.handle(.digit(3)) == ([.jump("3")], true))
        _ = m.handle(.character("a"))
        #expect(m.handle(.digit(3)) == ([.type("3")], true))
    }

    @Test func backspaceEmptiesQueryAndRestoresDigitJump() {
        var m = opened()
        _ = m.handle(.character("a"))
        #expect(m.handle(.backspace) == ([.backspace], true))
        #expect(m.handle(.digit(2)) == ([.jump("2")], true))
    }

    @Test func otherKeysSwallowedOnlyWhileOpen() {
        var closed = HotkeyStateMachine()
        #expect(closed.handle(.other) == ([], false))
        var m = opened()
        #expect(m.handle(.other) == ([], true))
    }

    @Test func closeResetsStateForNextOpen() {
        var m = opened()
        _ = m.handle(.character("a"))
        m.close()
        #expect(!m.isOpen && !m.isSticky)
        _ = m.handle(.optionDown)
        _ = m.handle(.tab(shift: false))
        #expect(m.handle(.character("w")) == ([.closeSelected], true))
    }
}

@Suite struct HotkeyStateMachineSyncTests {
    private func opened() -> HotkeyStateMachine {
        var m = HotkeyStateMachine()
        _ = m.handle(.optionDown)
        _ = m.handle(.tab(shift: false))
        return m
    }

    @Test func missedOptionReleaseCommitsOnSync() {
        var m = opened()
        #expect(m.syncOption(held: false) == [.commit])
        #expect(!m.isOpen)
        #expect(m.handle(.other) == ([], false))
    }

    @Test func syncWhileHeldDoesNothing() {
        var m = opened()
        #expect(m.syncOption(held: true) == [])
        #expect(m.isOpen)
    }

    @Test func syncInStickyModeKeepsPanelOpen() {
        var m = opened()
        _ = m.handle(.character("a"))
        #expect(m.syncOption(held: false) == [])
        #expect(m.isOpen)
    }
}
