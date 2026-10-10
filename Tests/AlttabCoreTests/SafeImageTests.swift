import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import AlttabCore

private func encoded(_ type: UTType, width: Int, height: Int) -> Data {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}

@Suite struct SafeImageTests {
    @Test func decodesJPEGAndPNG() {
        #expect(SafeImage.decode(encoded(.jpeg, width: 40, height: 20), maxPixelSize: 480) != nil)
        #expect(SafeImage.decode(encoded(.png, width: 40, height: 20), maxPixelSize: 480) != nil)
    }

    @Test func rejectsOtherFormatsAndGarbage() {
        #expect(SafeImage.decode(encoded(.tiff, width: 40, height: 20), maxPixelSize: 480) == nil)
        #expect(SafeImage.decode(Data("não é imagem".utf8), maxPixelSize: 480) == nil)
    }

    @Test func downscalesHugeImages() {
        let image = SafeImage.decode(encoded(.png, width: 2000, height: 1000), maxPixelSize: 480)
        #expect(image?.width == 480)
        #expect(image?.height == 240)
    }
}
