import CoreGraphics
import CoreImage
import UIKit

/// One recognized text line in reading order.
///
/// `rect` uses normalized `[0, 1]` image coordinates with the origin at the
/// displayed image's top-left corner. This makes the value independent of the
/// view's size and suitable for persistence.
public struct OCRLine: Equatable, Sendable {
    public let text: String
    public let rect: CGRect

    public init(text: String, rect: CGRect) {
        self.text = text
        self.rect = rect
    }
}

public enum OCRServiceError: LocalizedError {
    case invalidImage

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The selected image could not be converted for OCR."
        }
    }
}

/// Offline PaddleOCR entry point used by the app.
///
/// Models are loaded lazily from `Models/det` and `Models/rec` in the app
/// bundle and are reused for subsequent calls. This API never accesses the
/// network.
public enum OCRService {
    private static let backend = OCRBackend()

    /// Recognizes text lines in a `UIImage` with PP-OCRv6_small.
    ///
    /// The returned rectangles match the orientation in which UIKit displays
    /// the image, including mirrored camera images.
    @MainActor
    public static func recognize(_ image: UIImage) async throws -> [OCRLine] {
        guard let source = image.cgImage else {
            throw OCRServiceError.invalidImage
        }
        return try await backend.recognize(source, orientation: image.imageOrientation.exifOrientation)
    }
}

private actor OCRBackend {
    private let sessionManager = ORTSessionManager()
    private var engine: OCREngine?
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private let maximumOCRSide: CGFloat = 1600

    private func makeDisplayOrientedCGImage(from source: CGImage, orientation: Int32) -> CGImage? {
        let oriented = CIImage(cgImage: source)
            .oriented(forExifOrientation: orientation)
        let extent = oriented.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        let translated = oriented.transformed(
            by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY)
        )
        let scale = min(1, maximumOCRSide / max(extent.width, extent.height))
        let processed = translated.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )
        return imageContext.createCGImage(
            processed,
            from: CGRect(
                origin: .zero,
                size: CGSize(
                    width: floor(extent.width * scale),
                    height: floor(extent.height * scale)
                )
            )
        )
    }
    func recognize(_ source: CGImage, orientation: Int32) async throws -> [OCRLine] {
        try Task.checkCancellation()
        guard let image = makeDisplayOrientedCGImage(from: source, orientation: orientation) else {
            throw OCRServiceError.invalidImage
        }
        let engine = try await loadedEngine()
        try Task.checkCancellation()
        let output = try await engine.run(image)
        try Task.checkCancellation()
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        guard width > 0, height > 0 else {
            throw OCRServiceError.invalidImage
        }

        return output.results.compactMap { result in
            let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let rect = normalizedRect(for: result.polygon, width: width, height: height) else {
                return nil
            }
            return OCRLine(text: text, rect: rect)
        }
    }

    private func loadedEngine() async throws -> OCREngine {
        if let engine { return engine }

        try await sessionManager.loadModels(executionProvider: .cpu)
        let loaded = try OCREngine(sessionManager: sessionManager)
        engine = loaded
        return loaded
    }

    private func normalizedRect(
        for polygon: [[Int32]],
        width: CGFloat,
        height: CGFloat
    ) -> CGRect? {
        let points = polygon.compactMap { pair -> CGPoint? in
            guard pair.count >= 2 else { return nil }
            return CGPoint(x: CGFloat(pair[0]), y: CGFloat(pair[1]))
        }
        guard !points.isEmpty else { return nil }

        let minX = points.map(\.x).min() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let maxY = points.map(\.y).max() ?? 0

        let x0 = min(max(minX / width, 0), 1)
        let y0 = min(max(minY / height, 0), 1)
        let x1 = min(max(maxX / width, 0), 1)
        let y1 = min(max(maxY / height, 0), 1)
        guard x1 > x0, y1 > y0 else { return nil }

        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}

private extension UIImage.Orientation {
    var exifOrientation: Int32 {
        switch self {
        case .up: return 1
        case .upMirrored: return 2
        case .down: return 3
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .right: return 6
        case .rightMirrored: return 7
        case .left: return 8
        @unknown default: return 1
        }
    }
}
