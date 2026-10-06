import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

enum ImportedFile {
    case image(UIImage)
    case pdf(ImportedPDF)
}

struct ImportedPDF: Identifiable {
    let id = UUID()
    let data: Data
    let pageCount: Int

    func render(pageIndex: Int, maxPixelSize: Int = 2400) throws -> UIImage {
        guard (0..<pageCount).contains(pageIndex), maxPixelSize > 0,
              let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              let page = document.page(at: pageIndex + 1) else {
            throw FileImportError.invalidPage
        }
        let bounds = page.getBoxRect(.cropBox)
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
            throw FileImportError.corruptPDF
        }
        let rotation = (page.rotationAngle % 360 + 360) % 360
        let rotated = rotation == 90 || rotation == 270
        let width = rotated ? bounds.height : bounds.width
        let height = rotated ? bounds.width : bounds.height
        let scale = CGFloat(maxPixelSize) / max(width, height)
        let size = CGSize(width: max(1, (width * scale).rounded()), height: max(1, (height * scale).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            cg.scaleBy(x: size.width / width, y: size.height / height)
            // Map the crop box explicitly; getDrawingTransform can leave media-box margins
            // on pages whose crop box and rotation have been edited by PDF tools.
            switch rotation {
            case 90:
                cg.translateBy(x: 0, y: bounds.width)
                cg.rotate(by: -.pi / 2)
            case 180:
                cg.translateBy(x: bounds.width, y: bounds.height)
                cg.rotate(by: .pi)
            case 270:
                cg.translateBy(x: bounds.height, y: 0)
                cg.rotate(by: .pi / 2)
            default: break
            }
            cg.translateBy(x: -bounds.minX, y: -bounds.minY)
            cg.clip(to: bounds)
            cg.drawPDFPage(page)
        }
    }
}

actor PDFPageRenderer {
    static let shared = PDFPageRenderer()

    func render(_ pdf: ImportedPDF, pageIndex: Int) throws -> UIImage {
        try Task.checkCancellation()
        let image = try pdf.render(pageIndex: pageIndex)
        try Task.checkCancellation()
        return image
    }
}

enum FileImport {
    static func load(_ url: URL, maximumBytes: Int = 100 * 1024 * 1024) throws -> ImportedFile {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        // Coordinate the read while access is active, including third-party file providers.
        var coordinationError: NSError?
        var readResult: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { readableURL in
            readResult = Result {
                let size = try readableURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= maximumBytes else { throw FileImportError.tooLarge }
                return try readData(from: readableURL, maximumBytes: maximumBytes)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let readResult else { throw CocoaError(.fileReadUnknown) }
        let data = try readResult.get()
        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .pdf) == true {
            guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider) else {
                throw FileImportError.corruptPDF
            }
            guard document.isUnlocked else { throw FileImportError.lockedPDF }
            guard document.numberOfPages > 0 else { throw FileImportError.corruptPDF }
            return .pdf(ImportedPDF(data: data, pageCount: document.numberOfPages))
        }
        guard type?.conforms(to: .image) == true else { throw FileImportError.unsupported }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: min(4096, max(width, height)),
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw FileImportError.corruptImage }
        return .image(UIImage(cgImage: image))
    }

    // The provider's size metadata may be unavailable or stale. Bound the actual read too.
    static func readData(from url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes >= 0, maximumBytes < Int.max else { throw FileImportError.tooLarge }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: min(1024 * 1024, maximumBytes - data.count + 1)), !chunk.isEmpty {
            guard chunk.count <= maximumBytes - data.count else { throw FileImportError.tooLarge }
            data.append(chunk)
        }
        return data
    }
}

enum FileImportError: LocalizedError {
    case unsupported, corruptImage, corruptPDF, lockedPDF, invalidPage, tooLarge

    var errorDescription: String? {
        switch self {
        case .unsupported: "请选择图片文件或 PDF。"
        case .corruptImage: "图片无法读取，请选择其他图片。"
        case .corruptPDF: "PDF 无法读取或没有可用页面，请选择其他文件。"
        case .lockedPDF: "此 PDF 需要密码，请先解锁后再导入。"
        case .invalidPage: "无法读取所选页面，请选择其他页面。"
        case .tooLarge: "文件超过 100 MB，请先压缩图片或拆分 PDF。"
        }
    }
}
