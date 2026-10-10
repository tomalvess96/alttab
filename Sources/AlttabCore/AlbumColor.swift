import CoreGraphics

/// Cor da pílula do player tirada da capa do álbum.
public enum AlbumColor {
    public struct RGB: Equatable, Sendable {
        public let r: Double
        public let g: Double
        public let b: Double

        public init(r: Double, g: Double, b: Double) {
            self.r = r
            self.g = g
            self.b = b
        }
    }

    /// Cor dominante: agrupa pixels coloridos por matiz (12 faixas, peso = saturação × brilho)
    /// e devolve a média da faixa mais pesada. Capa sem cor devolve a média geral.
    public static func dominant(in image: CGImage) -> RGB {
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return RGB(r: 0.5, g: 0.5, b: 0.5) }

        var weight = [Double](repeating: 0, count: 12)
        var sums = [(Double, Double, Double)](repeating: (0, 0, 0), count: 12)
        var all = (0.0, 0.0, 0.0)
        var count = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) where pixels[i + 3] > 0 {
            let color = RGB(r: Double(pixels[i]) / 255, g: Double(pixels[i + 1]) / 255, b: Double(pixels[i + 2]) / 255)
            all = (all.0 + color.r, all.1 + color.g, all.2 + color.b)
            count += 1
            let (h, s, v) = hsb(color)
            guard s > 0.25, v > 0.2 else { continue }
            let bucket = min(11, Int(h * 12))
            let w = s * v
            weight[bucket] += w
            sums[bucket] = (sums[bucket].0 + color.r * w, sums[bucket].1 + color.g * w, sums[bucket].2 + color.b * w)
        }
        if let best = weight.indices.max(by: { weight[$0] < weight[$1] }), weight[best] > 1 {
            let w = weight[best]
            return RGB(r: sums[best].0 / w, g: sums[best].1 / w, b: sums[best].2 / w)
        }
        guard count > 0 else { return RGB(r: 0.5, g: 0.5, b: 0.5) }
        return RGB(r: all.0 / count, g: all.1 / count, b: all.2 / count)
    }

    /// Mantém o texto branco legível: brilho entre 0,35 e 0,70; capa colorida ganha saturação mínima 0,45.
    public static func clamped(_ color: RGB) -> RGB {
        let (h, s, b) = hsb(color)
        let saturation = s > 0.15 ? max(s, 0.45) : s
        return rgb(h: h, s: saturation, b: min(0.7, max(0.35, b)))
    }

    public static func hsb(_ c: RGB) -> (h: Double, s: Double, b: Double) {
        let maxV = max(c.r, c.g, c.b), minV = min(c.r, c.g, c.b)
        let delta = maxV - minV
        var hue = 0.0
        if delta > 0 {
            if maxV == c.r {
                hue = ((c.g - c.b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxV == c.g {
                hue = (c.b - c.r) / delta + 2
            } else {
                hue = (c.r - c.g) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, maxV == 0 ? 0 : delta / maxV, maxV)
    }

    public static func rgb(h: Double, s: Double, b: Double) -> RGB {
        let c = b * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = b - c
        let (r, g, bl): (Double, Double, Double)
        switch Int(h * 6) % 6 {
        case 0: (r, g, bl) = (c, x, 0)
        case 1: (r, g, bl) = (x, c, 0)
        case 2: (r, g, bl) = (0, c, x)
        case 3: (r, g, bl) = (0, x, c)
        case 4: (r, g, bl) = (x, 0, c)
        default: (r, g, bl) = (c, 0, x)
        }
        return RGB(r: r + m, g: g + m, b: bl + m)
    }
}
