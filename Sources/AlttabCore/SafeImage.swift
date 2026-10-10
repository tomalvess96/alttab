import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Imagens vindas da extensão (miniatura, ícone) ou da internet (capa): só JPEG/PNG,
/// decodificadas já reduzidas — um arquivo que declara 60.000 px não vira gigabytes na memória.
public enum SafeImage {
    public static func decode(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              type == UTType.jpeg.identifier || type == UTType.png.identifier else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
