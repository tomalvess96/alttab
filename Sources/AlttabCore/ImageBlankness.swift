import CoreGraphics

/// Uma captura "vazia" (transparente ou de uma cor só) não deve substituir uma miniatura boa do cache.
public enum ImageBlankness {
    public static func isBlank(_ image: CGImage, threshold: Double = 0.02) -> Bool {
        let w = 16, h = 16
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return true }
        var minLuma = 255, maxLuma = 0, maxAlpha = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let luma = (Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])) / 3
            minLuma = min(minLuma, luma)
            maxLuma = max(maxLuma, luma)
            maxAlpha = max(maxAlpha, Int(pixels[i + 3]))
        }
        return maxAlpha < 8 || Double(maxLuma - minLuma) / 255 < threshold
    }
}
