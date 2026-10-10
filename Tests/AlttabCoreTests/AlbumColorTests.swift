import CoreGraphics
import Testing
@testable import AlttabCore

private func image(_ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.clear(CGRect(x: 0, y: 0, width: 40, height: 40))
    draw(ctx)
    return ctx.makeImage()!
}

private func fill(_ ctx: CGContext, _ r: Double, _ g: Double, _ b: Double, _ rect: CGRect = CGRect(x: 0, y: 0, width: 40, height: 40)) {
    ctx.setFillColor(red: r, green: g, blue: b, alpha: 1)
    ctx.fill(rect)
}

@Suite struct AlbumColorTests {
    @Test func solidRedIsRed() {
        let c = AlbumColor.dominant(in: image { fill($0, 0.9, 0.1, 0.1) })
        #expect(c.r > 0.8 && c.g < 0.2 && c.b < 0.2)
    }

    @Test func grayCoverWithBluePatchPicksBlue() {
        let c = AlbumColor.dominant(in: image {
            fill($0, 0.5, 0.5, 0.5)
            fill($0, 0.1, 0.3, 0.9, CGRect(x: 0, y: 0, width: 20, height: 20))
        })
        #expect(c.b > c.r + 0.3)
    }

    @Test func whiteCoverIsDarkenedAndStaysGray() {
        let c = AlbumColor.clamped(AlbumColor.dominant(in: image { fill($0, 1, 1, 1) }))
        let hsb = AlbumColor.hsb(c)
        #expect(hsb.b <= 0.7001)
        #expect(hsb.s < 0.05)
    }

    @Test func darkNavyIsBrightenedAndSaturated() {
        let hsb = AlbumColor.hsb(AlbumColor.clamped(AlbumColor.RGB(r: 0.02, g: 0.04, b: 0.15)))
        #expect(hsb.b >= 0.3499)
        #expect(hsb.s >= 0.4499)
    }

    @Test func hsbRoundTrips() {
        let original = AlbumColor.RGB(r: 0.88, g: 0.34, b: 0.48)
        let hsb = AlbumColor.hsb(original)
        let back = AlbumColor.rgb(h: hsb.h, s: hsb.s, b: hsb.b)
        #expect(abs(back.r - original.r) < 1e-9 && abs(back.g - original.g) < 1e-9 && abs(back.b - original.b) < 1e-9)
    }
}
