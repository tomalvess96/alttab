import AlttabCore
import CoreGraphics
@preconcurrency import ScreenCaptureKit

@MainActor
final class WindowThumbs {
    private(set) var cache: [Int: CGImage] = [:]

    /// Captura as janelas pedidas e só substitui o cache quando a imagem nova não é vazia
    /// (janelas escondidas pelo AeroSpace podem voltar em branco — ver spike da Task 1).
    func capture(ids: [Int], update: @escaping @MainActor (Int, CGImage) -> Void) {
        Task {
            guard CGPreflightScreenCaptureAccess(),
                  let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            else { return }
            for id in ids {
                guard let window = content.windows.first(where: { Int($0.windowID) == id }),
                      let image = try? await Self.snapshot(window),
                      !ImageBlankness.isBlank(image) else { continue }
                cache[id] = image
                update(id, image)
            }
        }
    }

    nonisolated private static func snapshot(_ window: SCWindow) async throws -> CGImage {
        let config = SCStreamConfiguration()
        config.width = 480
        config.height = max(1, Int(480 * window.frame.height / max(window.frame.width, 1)))
        config.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: window)
        // O SDK do macOS 27 só importa a variante com completionHandler (ver spike da Task 1).
        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.featureUnsupported))
                }
            }
        }
    }
}
