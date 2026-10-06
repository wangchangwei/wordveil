import Foundation
import ImageIO
import SwiftData
import UIKit

struct NormalizedRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    init(_ rect: CGRect) {
        x = max(0, min(1, rect.minX))
        y = max(0, min(1, rect.minY))
        width = max(0, min(1 - x, rect.width))
        height = max(0, min(1 - y, rect.height))
    }

    mutating func move(dx: Double, dy: Double) {
        x = max(0, min(1 - width, x + dx))
        y = max(0, min(1 - height, y + dy))
    }

    mutating func resize(dw: Double, dh: Double) {
        width = min(1 - x, max(0.015, width + dw))
        height = min(1 - y, max(0.012, height + dh))
    }
}

enum BlockLanguage: String, Codable, CaseIterable {
    case english
    case chinese
    case japanese

    var nameKey: String {
        switch self {
        case .english: "英文"
        case .chinese: "中文"
        case .japanese: "日文"
        }
    }

    var shortKey: String {
        switch self {
        case .english: "英"
        case .chinese: "中"
        case .japanese: "日"
        }
    }

    var hideKey: String { "隐藏" + nameKey }
    var onlyKey: String { "只显示" + nameKey }
    var answerKey: String { nameKey + "答案" }
}

struct CardLanguagePair: Equatable {
    let native: BlockLanguage
    let target: BlockLanguage

    init(native: BlockLanguage = .chinese, target: BlockLanguage = .english) {
        self.native = native
        self.target = target == native ? (native == .english ? .chinese : .english) : target
    }

    var languages: [BlockLanguage] { [native, target] }
}

struct OCRBlock: Identifiable, Codable {
    var id = UUID()
    var text: String
    var language: BlockLanguage
    var bounds: NormalizedRect
    var hidden = false
    var estimated = false
    // Optional fields preserve decoding of cards saved before language settings existed.
    var languageNeedsReview: Bool?
    var languageIsManual: Bool?
}

@Model
final class StudyCard {
    @Attribute(.unique) var id: UUID
    var title: String
    var imageFilename: String
    var createdAt: Date
    var blocksData: Data
    var nativeLanguageRaw: String = "chinese"
    var targetLanguageRaw: String = "english"

    init(id: UUID = UUID(), title: String, imageFilename: String, blocks: [OCRBlock], languagePair: CardLanguagePair = .init()) throws {
        self.id = id
        self.title = title
        self.imageFilename = imageFilename
        self.createdAt = .now
        self.blocksData = try JSONEncoder().encode(blocks)
        self.nativeLanguageRaw = languagePair.native.rawValue
        self.targetLanguageRaw = languagePair.target.rawValue
    }

    var languagePair: CardLanguagePair {
        get {
            CardLanguagePair(native: BlockLanguage(rawValue: nativeLanguageRaw) ?? .chinese,
                             target: BlockLanguage(rawValue: targetLanguageRaw) ?? .english)
        }
        set {
            nativeLanguageRaw = newValue.native.rawValue
            targetLanguageRaw = newValue.target.rawValue
        }
    }

    func decodedBlocks() throws -> [OCRBlock] {
        try JSONDecoder().decode([OCRBlock].self, from: blocksData)
    }

    func setBlocks(_ blocks: [OCRBlock]) throws {
        blocksData = try JSONEncoder().encode(blocks)
    }
}

enum CardLibrary {
    @MainActor
    static func clearHistory(_ cards: [StudyCard], in context: ModelContext) throws {
        try deleteCards(cards, in: context)
    }

    @MainActor
    static func deleteCard(_ card: StudyCard, in context: ModelContext) throws {
        try deleteCards([card], in: context)
    }

    @MainActor
    private static func deleteCards(_ cards: [StudyCard], in context: ModelContext) throws {
        let filenames = cards.map(\.imageFilename)
        do {
            cards.forEach(context.delete)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        filenames.forEach(ImageStore.remove)
    }
}

enum ImageStore {
    static var directory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("CardImages", isDirectory: true)
    }

    static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        guard let cgImage = image.cgImage else { return image }
        let swapped: Bool
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored: swapped = true
        default: swapped = false
        }
        let size = CGSize(
            width: swapped ? cgImage.height : cgImage.width,
            height: swapped ? cgImage.width : cgImage.height
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }

    static func save(_ image: UIImage, id: UUID) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(id.uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        guard let data = normalized(image).jpegData(compressionQuality: 0.9) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: url, options: .atomic)
        return filename
    }

    static func load(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(filename).path)
    }

    static func thumbnail(_ filename: String, maxPixelSize: Int = 480) -> UIImage? {
        guard maxPixelSize > 0,
              let source = CGImageSourceCreateWithURL(
                directory.appendingPathComponent(filename) as CFURL,
                [kCGImageSourceShouldCache: false] as CFDictionary
              ),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    static func remove(_ filename: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }
}
