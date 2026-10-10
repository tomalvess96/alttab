// Gera Resources/AppIcon.icns (ícone "Fenda": três traços, o do meio em âmbar e mais alto).
// Uso: swift scripts/make-icon.swift <pasta-de-saída-do-iconset>
import AppKit

let accent = NSColor(srgbRed: 1.0, green: 0.71, blue: 0.28, alpha: 1)      // #FFB547
let ground = NSColor(srgbRed: 0.078, green: 0.082, blue: 0.098, alpha: 1)  // #141519

/// Desenha no grid de 100 unidades do protótipo (corpo do ícone de 4 a 96).
func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // Grade de ícone do macOS: corpo ocupa ~80% do quadro (824 de 1024).
    let body = Double(pixels) * 824 / 1024
    let unit = body / 92
    let origin = (Double(pixels) - body) / 2 - 4 * unit
    func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> NSRect {
        // y do protótipo cresce para baixo; no AppKit, para cima.
        NSRect(x: origin + x * unit, y: Double(pixels) - (origin + (y + h) * unit), width: w * unit, height: h * unit)
    }
    ground.setFill()
    NSBezierPath(roundedRect: rect(4, 4, 92, 92), xRadius: 21 * unit, yRadius: 21 * unit).fill()
    NSColor(white: 1, alpha: 0.08).setStroke()
    let edge = NSBezierPath(roundedRect: rect(4.5, 4.5, 91, 91), xRadius: 20.5 * unit, yRadius: 20.5 * unit)
    edge.lineWidth = max(1, unit * 0.6)
    edge.stroke()
    // Pequeno (≤ 64 px): traços mais grossos para continuar legível.
    let small = pixels <= 64
    let side = NSColor(srgbRed: small ? 0.384 : 0.337, green: small ? 0.4 : 0.353, blue: small ? 0.435 : 0.388, alpha: 1)
    let bars: [(Double, Double, Double, Double, NSColor)] = small
        ? [(27, 30, 9, 40, side), (44, 22, 12, 56, accent), (64, 30, 9, 40, side)]
        : [(32, 30, 4.5, 40, side), (46, 24, 8, 52, accent), (63.5, 30, 4.5, 40, side)]
    for (x, y, w, h, color) in bars {
        color.setFill()
        NSBezierPath(roundedRect: rect(x, y, w, h), xRadius: w * unit / 2, yRadius: w * unit / 2).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    try render(pixels: points * scale).write(to: out.appendingPathComponent(name))
}
print("ok: \(out.path)")
