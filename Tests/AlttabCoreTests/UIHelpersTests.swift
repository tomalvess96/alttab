import CoreGraphics
import Testing
@testable import AlttabCore

@Suite struct HoverGateTests {
    @Test func restingMouseAfterOpenDoesNotSelect() {
        var g = HoverGate()
        g.reset(x: 100, y: 100)
        let same = g.shouldSelect(x: 100, y: 100)
        let tiny = g.shouldSelect(x: 105, y: 103)
        #expect(!same)
        #expect(!tiny)
    }

    @Test func realMovementSelectsAndMovesAnchor() {
        var g = HoverGate()
        g.reset(x: 0, y: 0)
        let first = g.shouldSelect(x: 20, y: 0)
        let nudge = g.shouldSelect(x: 25, y: 0)
        let second = g.shouldSelect(x: 40, y: 0)
        #expect(first)
        #expect(!nudge)
        #expect(second)
    }

    @Test func withoutResetFirstMoveSelects() {
        var g = HoverGate()
        let first = g.shouldSelect(x: 1, y: 1)
        #expect(first)
    }
}

@Suite struct ColumnLayoutTests {
    @Test func emptyIsEmpty() {
        #expect(ColumnLayout.widths(count: 0, focusedIndex: nil, total: 1000, spacing: 10).isEmpty)
    }

    @Test func equalWithoutFocusAndFillsSpace() {
        let w = ColumnLayout.widths(count: 4, focusedIndex: nil, total: 1030, spacing: 10)
        #expect(w == [250, 250, 250, 250])
    }

    @Test func focusedGetsWeight() {
        let w = ColumnLayout.widths(count: 3, focusedIndex: 1, total: 1020, spacing: 10, focusWeight: 2)
        #expect(w == [250, 500, 250])
    }

    @Test func capsLimitWidthsDuringSearch() {
        let w = ColumnLayout.widths(count: 2, focusedIndex: 0, total: 1184, spacing: 10, caps: (340, 190))
        #expect(w == [340, 190])
    }
}

@Suite struct GreetingTests {
    @Test(arguments: [(4, "Boa noite"), (5, "Bom dia"), (11, "Bom dia"), (12, "Boa tarde"),
                      (17, "Boa tarde"), (18, "Boa noite"), (23, "Boa noite"), (0, "Boa noite")])
    func byHour(hour: Int, expected: String) {
        #expect(Greeting.text(hour: hour) == expected)
    }
}

@Suite struct ImageBlanknessTests {
    private func image(_ draw: (CGContext) -> Void) -> CGImage {
        let ctx = CGContext(data: nil, width: 64, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.clear(CGRect(x: 0, y: 0, width: 64, height: 40))
        draw(ctx)
        return ctx.makeImage()!
    }

    @Test func transparentIsBlank() {
        #expect(ImageBlankness.isBlank(image { _ in }))
    }

    @Test func solidBlackIsBlank() {
        #expect(ImageBlankness.isBlank(image { $0.setFillColor(gray: 0, alpha: 1); $0.fill(CGRect(x: 0, y: 0, width: 64, height: 40)) }))
    }

    @Test func darkWithLightTextIsNotBlank() {
        let img = image {
            $0.setFillColor(gray: 0.05, alpha: 1); $0.fill(CGRect(x: 0, y: 0, width: 64, height: 40))
            $0.setFillColor(gray: 0.9, alpha: 1); $0.fill(CGRect(x: 4, y: 30, width: 40, height: 4))
        }
        #expect(!ImageBlankness.isBlank(img))
    }
}

@Suite struct CardFitTests {
    @Test func fewCardsKeepPreferredSize() {
        #expect(ColumnLayout.cardThumbHeight(count: 2, preferred: 112, available: 470) == 112)
    }

    @Test func fourCardsShrinkToFit() {
        let thumb = ColumnLayout.cardThumbHeight(count: 4, preferred: 112, available: 470)
        #expect(thumb < 112)
        #expect(4 * (thumb + ColumnLayout.cardChrome) <= 470)
    }

    @Test func neverBelowMinimum() {
        #expect(ColumnLayout.cardThumbHeight(count: 30, preferred: 112, available: 470) == ColumnLayout.minCardThumb)
    }

    @Test func emptyColumnIsSafe() {
        #expect(ColumnLayout.cardThumbHeight(count: 0, preferred: 58, available: 470) == 58)
    }
}
