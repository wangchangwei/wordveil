import SwiftData
import ImageIO
import PDFKit
import UIKit
import XCTest
@testable import WordCover

final class WordCoverTests: XCTestCase {
    func testAppLanguageProvidesStableIdentifiersAndLocales() {
        XCTAssertEqual(AppLanguage.chinese.rawValue, "zh-Hans")
        XCTAssertEqual(AppLanguage.english.rawValue, "en")
        XCTAssertEqual(AppLanguage.allCases, [.chinese, .english])
        XCTAssertEqual(AppLanguage.chinese.locale.identifier, "zh-Hans")
        XCTAssertEqual(AppLanguage.english.locale.identifier, "en")
    }

    func testEnglishAppLanguageTranslatesCoreActionsAndFallsBackToSource() {
        XCTAssertEqual(AppLanguage.english.text("挡住单词"), "Wordveil")
        XCTAssertEqual(AppLanguage.english.text("新建学习卡片"), "New Study Card")
        XCTAssertEqual(AppLanguage.english.text("遮挡英文"), "Mask English")
        XCTAssertEqual(AppLanguage.english.text("遮挡中文"), "Mask Chinese")
        XCTAssertEqual(AppLanguage.english.text("全部显示"), "Show All")
        XCTAssertEqual(AppLanguage.english.text("重新练习"), "Practice Again")
        XCTAssertEqual(AppLanguage.english.text("清空"), "Clear All")
        XCTAssertEqual(AppLanguage.english.text("清空历史卡片？"), "Clear Previous Cards?")
        XCTAssertEqual(AppLanguage.english.text("unmapped-value"), "unmapped-value")
    }

    func testChineseAppLanguageUsesSourceKeys() {
        XCTAssertEqual(AppLanguage.chinese.text("我的卡片"), "我的卡片")
        XCTAssertEqual(AppLanguage.chinese.text("图片与 PDF"), "图片与 PDF")
    }

    func testAppLanguageFormatsCountsAndRecognitionStatus() {
        XCTAssertEqual(AppLanguage.english.format("共 %d 张卡片", 3), "3 cards")
        XCTAssertEqual(AppLanguage.english.format("已揭晓 %d / %d", 2, 5), "Revealed 2 / 5")
        XCTAssertEqual(
            AppLanguage.english.format("离线识别 %.1f 秒 · %d 处文字", 2.35, 8),
            "Offline recognition 2.4 sec · 8 text regions"
        )
        XCTAssertEqual(AppLanguage.chinese.format("第 %d 页 / 共 %d 页", 2, 7), "第 2 页 / 共 7 页")
    }

    func testFileImportHEICDecodesActualHEICFile() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "bilingual", withExtension: "heic", subdirectory: "Fixtures"))
        guard case let .image(image) = try FileImport.load(url) else { return XCTFail("Expected HEIC image") }
        XCTAssertEqual(image.cgImage?.width, 2400)
        XCTAssertEqual(image.cgImage?.height, 1700)
        XCTAssertEqual(image.imageOrientation, .up)
    }

    func testFileReadEnforcesLimitWithoutFileSizeMetadata() throws {
        let directory = try temporaryImportDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("provider-content")
        let data = Data(repeating: 1, count: 100)
        try data.write(to: url)
        XCTAssertThrowsError(try FileImport.readData(from: url, maximumBytes: 99))
        XCTAssertEqual(try FileImport.readData(from: url, maximumBytes: 100), data)
    }

    @MainActor
    func testLargeFileImageIsDownsampledBeforeEditing() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 5000, height: 100), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 5000, height: 100))
        }
        let directory = try temporaryImportDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("large.jpg")
        try XCTUnwrap(image.jpegData(compressionQuality: 0.8)).write(to: url)
        guard case let .image(imported) = try FileImport.load(url) else { return XCTFail("Expected image") }
        XCTAssertEqual(imported.cgImage?.width, 4096)
        XCTAssertEqual(Double(imported.cgImage!.width) / Double(imported.cgImage!.height), 50, accuracy: 0.7)
    }

    func testCancelledPDFRenderDoesNotProducePreview() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "import-lesson", withExtension: "pdf", subdirectory: "Fixtures"))
        guard case let .pdf(pdf) = try FileImport.load(url) else { return XCTFail("Expected PDF") }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await PDFPageRenderer.shared.render(pdf, pageIndex: 0)
        }
        do {
            _ = try await task.value
            XCTFail("Cancelled renderer must discard its work")
        } catch is CancellationError { }
    }

    @MainActor
    func testFileImportPNGRecognizesRealChineseAndEnglish() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "bilingual", withExtension: "png", subdirectory: "Fixtures"))
        guard case let .image(image) = try FileImport.load(url) else {
            return XCTFail("PNG should import as an image")
        }
        let lines = try await OCRService.recognize(image)
        let text = lines.map(\.text).joined(separator: " ")
        XCTAssertTrue(text.contains("apple"))
        XCTAssertTrue(text.contains("苹果"))
    }

    @MainActor
    func testFileImportJPEGAppliesEXIFOrientation() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 60), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        }
        let directory = try temporaryImportDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("rotated.jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        guard case let .image(imported) = try FileImport.load(url) else { return XCTFail("Expected image") }
        XCTAssertEqual(imported.imageOrientation, .up)
        XCTAssertEqual(imported.cgImage?.width, 60)
        XCTAssertEqual(imported.cgImage?.height, 120)
    }

    @MainActor
    func testFileImportPDFUsesSelectedPageAndRemainsRecognizable() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "bilingual", withExtension: "png", subdirectory: "Fixtures"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: fixture.path))
        let size = CGSize(width: 1200, height: 850)
        let data = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size)).pdfData { context in
            context.beginPage()
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            context.beginPage()
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        let directory = try temporaryImportDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("lesson.pdf")
        try data.write(to: url)
        guard case let .pdf(pdf) = try FileImport.load(url) else { return XCTFail("Expected PDF") }
        XCTAssertEqual(pdf.pageCount, 2)
        XCTAssertThrowsError(try pdf.render(pageIndex: -1))
        XCTAssertThrowsError(try pdf.render(pageIndex: 2))
        let rendered = try pdf.render(pageIndex: 1)
        XCTAssertEqual(rendered.cgImage?.width, 2400)
        XCTAssertEqual(rendered.cgImage?.height, 1700)
        let text = try await OCRService.recognize(rendered).map(\.text).joined(separator: " ")
        XCTAssertTrue(text.contains("apple"), text)
        XCTAssertTrue(text.contains("苹果"), text)
        let filename = try ImageStore.save(rendered, id: UUID())
        defer { ImageStore.remove(filename) }
        XCTAssertNotNil(ImageStore.load(filename), "The PDF page must persist independently of its source file")
    }

    @MainActor
    func testPDFRenderingRespectsRotationAndCropBox() throws {
        let data = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 500)).pdfData { context in
            context.beginPage()
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 500))
            UIColor.white.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 200, height: 400))
            UIColor.red.setFill()
            context.fill(CGRect(x: 50, y: 50, width: 100, height: 200))
        }
        let document = try XCTUnwrap(PDFDocument(data: data))
        let page = try XCTUnwrap(document.page(at: 0))
        page.setBounds(CGRect(x: 50, y: 50, width: 200, height: 400), for: .cropBox)
        // Rotation must map the crop's red upper-left quadrant to the correct display corner.
        for (rotation, width, height, redX, redY, whiteX, whiteY) in [
            (0, 400, 800, 100, 100, 300, 700),
            (90, 800, 400, 700, 100, 100, 300),
            (180, 400, 800, 300, 700, 100, 100),
            (270, 800, 400, 100, 300, 700, 100)
        ] {
            page.rotation = rotation
            let pdf = ImportedPDF(data: try XCTUnwrap(document.dataRepresentation()), pageCount: 1)
            let rendered = try pdf.render(pageIndex: 0, maxPixelSize: 800)
            XCTAssertEqual(rendered.cgImage?.width, width)
            XCTAssertEqual(rendered.cgImage?.height, height)
            XCTAssertGreaterThan(pixel(rendered, x: redX, y: redY).0, 220, "Rotation \(rotation)")
            XCTAssertLessThan(pixel(rendered, x: redX, y: redY).1, 40, "Rotation \(rotation)")
            XCTAssertGreaterThan(pixel(rendered, x: whiteX, y: whiteY).1, 220, "Rotation \(rotation)")
        }
    }

    func testFileImportRejectsCorruptUnsupportedAndOversizedFiles() throws {
        let directory = try temporaryImportDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["broken.png", "broken.pdf", "notes.txt"] {
            let url = directory.appendingPathComponent(name)
            try Data("not an image or PDF".utf8).write(to: url)
            XCTAssertThrowsError(try FileImport.load(url), name)
        }
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "bilingual", withExtension: "png", subdirectory: "Fixtures"))
        XCTAssertThrowsError(try FileImport.load(fixture, maximumBytes: 10))
    }

    private func temporaryImportDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func pixel(_ image: UIImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8) {
        let cg = image.cgImage!
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        bytes.withUnsafeMutableBytes { storage in
            let context = CGContext(data: storage.baseAddress, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        let offset = (y * cg.width + x) * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2])
    }

    func testAmbiguousCharacterGapsAreNotReportedAsWordPositions() {
        var ink = Array(repeating: 12, count: 100)
        for range in [18..<23, 38..<43, 58..<63, 78..<83] {
            for x in range { ink[x] = 0 }
        }
        XCTAssertNil(WordGapLocator.boundaries(in: ink, count: 1))
    }

    @MainActor
    func testMissingWordGapsMarkAllAffectedFramesAsEstimated() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 100)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 500, height: 100))
        }
        let blocks = TextSegmentation.blocks(from: [OCRLine(text: "apple 苹果", rect: CGRect(x: 0, y: 0, width: 1, height: 1))], image: image)
        XCTAssertEqual(blocks.map(\.text), ["apple", "苹果"])
        XCTAssertTrue(blocks.allSatisfy(\.estimated), "Both frames depend on an estimated boundary")
    }

    @MainActor
    func testHanExtensionIsClassifiedAsChinese() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in }
        let blocks = TextSegmentation.blocks(from: [OCRLine(text: "㐀", rect: CGRect(x: 0, y: 0, width: 1, height: 1))], image: image)
        XCTAssertEqual(blocks.first?.language, .chinese)
    }

    func testDefaultAndReversedLanguagePairsClassifyBothLanguages() {
        let defaultPair = CardLanguagePair()
        XCTAssertEqual(defaultPair.native, .chinese)
        XCTAssertEqual(defaultPair.target, .english)
        XCTAssertEqual(TextSegmentation.classify(text: "apple", languagePair: defaultPair), .english)
        XCTAssertEqual(TextSegmentation.classify(text: "苹果", languagePair: defaultPair), .chinese)

        let reversedPair = CardLanguagePair(native: .english, target: .chinese)
        XCTAssertEqual(TextSegmentation.classify(text: "apple", languagePair: reversedPair), .english)
        XCTAssertEqual(TextSegmentation.classify(text: "苹果", languagePair: reversedPair), .chinese)

        let normalizedPair = CardLanguagePair(native: .japanese, target: .japanese)
        XCTAssertNotEqual(normalizedPair.native, normalizedPair.target)
    }

    func testKanaIsJapaneseEvenWhenTheCardUsesChineseAndEnglish() {
        XCTAssertEqual(
            TextSegmentation.classify(text: "りんご", languagePair: CardLanguagePair()),
            .japanese
        )
    }

    @MainActor
    func testJapaneseMixedScriptStaysTogetherAndSeparatesFromChinese() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 120)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 800, height: 120))
        }
        let blocks = TextSegmentation.blocks(
            from: [OCRLine(text: "日本語を学ぶ、中文", rect: CGRect(x: 0, y: 0, width: 1, height: 1))],
            image: image,
            languagePair: CardLanguagePair(native: .chinese, target: .japanese)
        )

        XCTAssertEqual(blocks.map(\.text), ["日本語を学ぶ", "中文"])
        XCTAssertEqual(blocks.map(\.language), [.japanese, .chinese])
        XCTAssertEqual(blocks.map(\.languageNeedsReview), [false, true])
    }

    @MainActor
    func testPureHanUsesJapaneseWhenChineseIsNotInPair() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 100)).image { _ in }
        let blocks = TextSegmentation.blocks(
            from: [OCRLine(text: "日本語", rect: CGRect(x: 0, y: 0, width: 1, height: 1))],
            image: image,
            languagePair: CardLanguagePair(native: .english, target: .japanese)
        )

        let block = try XCTUnwrap(blocks.first)
        XCTAssertEqual(block.language, .japanese)
        XCTAssertEqual(block.languageNeedsReview, false)
    }

    func testLegacyBlockJSONDefaultsNewLanguageMetadataToNil() throws {
        struct LegacyBlock: Encodable {
            let id: UUID
            let text: String
            let language: BlockLanguage
            let bounds: NormalizedRect
            let hidden: Bool
            let estimated: Bool
        }

        let legacy = LegacyBlock(
            id: UUID(),
            text: "猫",
            language: .chinese,
            bounds: NormalizedRect(CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1)),
            hidden: true,
            estimated: false
        )
        let decoded = try XCTUnwrap(
            JSONDecoder().decode([OCRBlock].self, from: JSONEncoder().encode([legacy])).first
        )

        XCTAssertNil(decoded.languageNeedsReview)
        XCTAssertNil(decoded.languageIsManual)
    }

    func testManualLanguageCorrectionSurvivesBlockEncoding() throws {
        var block = OCRBlock(
            text: "猫",
            language: .chinese,
            bounds: NormalizedRect(CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1)),
            languageNeedsReview: true
        )
        block.language = .japanese
        block.languageNeedsReview = false
        block.languageIsManual = true

        let decoded = try JSONDecoder().decode(
            OCRBlock.self,
            from: JSONEncoder().encode(block)
        )

        XCTAssertEqual(decoded.language, .japanese)
        XCTAssertEqual(decoded.languageNeedsReview, false)
        XCTAssertEqual(decoded.languageIsManual, true)
    }

    func testFrameAdjustmentStaysWithinImageAtEdges() {
        var rect = NormalizedRect(CGRect(x: 0.998, y: 0.999, width: 0.002, height: 0.001))
        rect.resize(dw: -1, dh: -1)
        XCTAssertLessThanOrEqual(rect.x + rect.width, 1)
        XCTAssertLessThanOrEqual(rect.y + rect.height, 1)
        rect.move(dx: -2, dy: -2)
        rect.resize(dw: 2, dh: 2)
        XCTAssertEqual(rect.cgRect, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    @MainActor
    func testEnglishWordFramesFollowActualPrintedSpacing() {
        let text = "I have a beautiful dog."
        let font = UIFont.systemFont(ofSize: 48)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let size = CGSize(width: textSize.width + 100, height: 150)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (text as NSString).draw(at: CGPoint(x: 50, y: 45), withAttributes: attributes)
        }
        let lineRect = CGRect(x: 50 / size.width, y: 45 / size.height, width: textSize.width / size.width, height: textSize.height / size.height)
        let blocks = TextSegmentation.blocks(from: [OCRLine(text: text, rect: lineRect)], image: image)
        XCTAssertEqual(blocks.map(\.text), ["I", "have", "a", "beautiful", "dog"])
        let nsText = text as NSString
        var searchLocation = 0
        for block in blocks {
            let searchRange = NSRange(location: searchLocation, length: nsText.length - searchLocation)
            let range = nsText.range(of: block.text, options: [], range: searchRange)
            guard range.location != NSNotFound else {
                XCTFail("Missing sequential range for \(block.text)")
                return
            }
            searchLocation = range.location + range.length
            let left = 50 + (nsText.substring(to: range.location) as NSString).size(withAttributes: attributes).width
            let width = (block.text as NSString).size(withAttributes: attributes).width
            let frame = block.bounds.cgRect
            XCTAssertGreaterThanOrEqual(frame.midX * size.width, left - 5, block.text)
            XCTAssertLessThanOrEqual(frame.midX * size.width, left + width + 5, block.text)
        }
    }

    @MainActor
    func testReliableFramesDoNotOverlapInsideNarrowOCRLine() throws {
        let imageSize = CGSize(width: 4_000, height: 100)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: imageSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
            UIColor.black.setFill()
            context.fill(CGRect(x: 400, y: 20, width: 14, height: 50))
            context.fill(CGRect(x: 425, y: 20, width: 15, height: 50))
        }
        let lineRect = CGRect(x: 0.1, y: 0.2, width: 0.01, height: 0.5)

        let blocks = TextSegmentation.blocks(
            from: [OCRLine(text: "a b", rect: lineRect)],
            image: image
        )

        XCTAssertEqual(blocks.map(\.text), ["a", "b"])
        XCTAssertTrue(blocks.allSatisfy { !$0.estimated })
        let first = try XCTUnwrap(blocks.first?.bounds.cgRect)
        let second = try XCTUnwrap(blocks.last?.bounds.cgRect)
        XCTAssertLessThanOrEqual(first.maxX, second.minX + 1e-12)
    }

    func testExpandedHitAreasKeepAdjacentThinRowsIndependent() {
        let fittedSize = CGSize(width: 300, height: 200)
        let upper = OCRBlock(
            text: "upper",
            language: .english,
            bounds: NormalizedRect(CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0.005))
        )
        let lower = OCRBlock(
            text: "lower",
            language: .english,
            bounds: NormalizedRect(CGRect(x: 0.2, y: 0.215, width: 0.2, height: 0.005))
        )
        let blocks = [upper, lower]

        let upperHit = MaskHitArea.rect(for: upper.id, blocks: blocks, fittedSize: fittedSize)
        let lowerHit = MaskHitArea.rect(for: lower.id, blocks: blocks, fittedSize: fittedSize)
        let upperVisualCenter = CGPoint(x: 0.3 * fittedSize.width, y: 0.2025 * fittedSize.height)
        let lowerVisualCenter = CGPoint(x: 0.3 * fittedSize.width, y: 0.2175 * fittedSize.height)

        XCTAssertFalse(upperHit.intersects(lowerHit))
        XCTAssertTrue(upperHit.contains(upperVisualCenter))
        XCTAssertFalse(lowerHit.contains(upperVisualCenter))
        XCTAssertTrue(lowerHit.contains(lowerVisualCenter))
        XCTAssertFalse(upperHit.contains(lowerVisualCenter))
    }

    func testExpandedHitAreasContainVisibleFramesWithoutOverlappingNarrowNeighbor() {
        let fittedSize = CGSize(width: 300, height: 200)
        let wide = OCRBlock(
            text: "beautiful",
            language: .english,
            bounds: NormalizedRect(CGRect(x: 0.1, y: 0.4, width: 0.5, height: 0.04))
        )
        let narrow = OCRBlock(
            text: "I",
            language: .english,
            bounds: NormalizedRect(CGRect(x: 0.605, y: 0.4, width: 0.01, height: 0.04))
        )
        let blocks = [wide, narrow]
        let wideVisual = CGRect(x: 30, y: 80, width: 150, height: 8)
        let narrowVisual = CGRect(x: 181.5, y: 80, width: 3, height: 8)

        let wideHit = MaskHitArea.rect(for: wide.id, blocks: blocks, fittedSize: fittedSize)
        let narrowHit = MaskHitArea.rect(for: narrow.id, blocks: blocks, fittedSize: fittedSize)

        XCTAssertFalse(wideHit.intersects(narrowHit))
        XCTAssertTrue(wideHit.contains(wideVisual))
        XCTAssertTrue(narrowHit.contains(narrowVisual))
    }

    @MainActor
    func testExistingCardStoreMigratesToDefaultChineseEnglishPair() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("cards.store")
        let id = UUID()
        let originalBlock = OCRBlock(
            text: "apple",
            language: .english,
            bounds: NormalizedRect(CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1)),
            hidden: true
        )
        let blocksData = try JSONEncoder().encode([originalBlock])
        let legacySchema = Schema(versionedSchema: LegacyCardSchema.self)
        let legacyConfiguration = ModelConfiguration(schema: legacySchema, url: storeURL)
        do {
            let container = try ModelContainer(for: legacySchema, configurations: legacyConfiguration)
            container.mainContext.insert(LegacyCardSchema.StudyCard(
                id: id,
                title: "Legacy",
                imageFilename: "legacy.jpg",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                blocksData: blocksData
            ))
            try container.mainContext.save()
        }

        let currentSchema = Schema([StudyCard.self])
        let currentConfiguration = ModelConfiguration(schema: currentSchema, url: storeURL)
        let migratedContainer = try ModelContainer(for: currentSchema, configurations: currentConfiguration)
        let migrated = try XCTUnwrap(
            migratedContainer.mainContext.fetch(FetchDescriptor<StudyCard>()).first
        )

        XCTAssertEqual(migrated.id, id)
        XCTAssertEqual(migrated.title, "Legacy")
        XCTAssertEqual(migrated.languagePair, CardLanguagePair())
        XCTAssertEqual(try migrated.decodedBlocks().first?.text, "apple")
        XCTAssertEqual(try migrated.decodedBlocks().first?.hidden, true)
    }

    @MainActor
    func testSavedCardRetainsMaskStateAdjustedCoordinatesAndLanguagePair() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration(url: directory.appendingPathComponent("cards.store"))
        let id = UUID()
        let block = OCRBlock(text: "beautiful", language: .english, bounds: NormalizedRect(CGRect(x: 0.25, y: 0.3, width: 0.2, height: 0.08)), hidden: true, estimated: true)
        do {
            let container = try ModelContainer(for: StudyCard.self, configurations: config)
            let card = try StudyCard(
                id: id,
                title: "日语 Unit 1",
                imageFilename: "image.jpg",
                blocks: [block],
                languagePair: CardLanguagePair(native: .chinese, target: .japanese)
            )
            container.mainContext.insert(card)
            try container.mainContext.save()
        }
        let reopened = try ModelContainer(for: StudyCard.self, configurations: config)
        let saved = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<StudyCard>()).first)
        let savedBlocks = try saved.decodedBlocks()
        XCTAssertEqual(saved.id, id)
        XCTAssertEqual(saved.title, "日语 Unit 1")
        XCTAssertEqual(saved.languagePair.native, .chinese)
        XCTAssertEqual(saved.languagePair.target, .japanese)
        XCTAssertEqual(savedBlocks.first?.bounds, block.bounds)
        XCTAssertEqual(savedBlocks.first?.hidden, true)
        XCTAssertEqual(savedBlocks.first?.estimated, true)
    }

    @MainActor
    func testClearHistoryRemovesPersistedCardsAndTheirImages() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let config = ModelConfiguration(url: directory.appendingPathComponent("cards.store"))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let filenames = try (0..<2).map { _ in try ImageStore.save(image, id: UUID()) }
        defer { filenames.forEach(ImageStore.remove) }
        let container = try ModelContainer(for: StudyCard.self, configurations: config)
        for (index, filename) in filenames.enumerated() {
            container.mainContext.insert(try StudyCard(title: "Card \(index)", imageFilename: filename, blocks: []))
        }
        try container.mainContext.save()

        try CardLibrary.clearHistory(container.mainContext.fetch(FetchDescriptor<StudyCard>()), in: container.mainContext)

        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<StudyCard>()).isEmpty)
        XCTAssertTrue(filenames.allSatisfy { ImageStore.load($0) == nil })
        let reopened = try ModelContainer(for: StudyCard.self, configurations: config)
        XCTAssertTrue(try reopened.mainContext.fetch(FetchDescriptor<StudyCard>()).isEmpty)
    }

    @MainActor
    func testCorruptSavedBlocksAreReported() throws {
        let card = try StudyCard(title: "Corrupt", imageFilename: "image.jpg", blocks: [])
        card.blocksData = Data("not JSON".utf8)

        XCTAssertThrowsError(try card.decodedBlocks())
    }

    @MainActor
    func testThumbnailDownsamplesWithoutReplacingOriginal() throws {
        let size = CGSize(width: 1_200, height: 600)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let filename = try ImageStore.save(image, id: UUID())
        defer { ImageStore.remove(filename) }

        let thumbnail = try XCTUnwrap(ImageStore.thumbnail(filename, maxPixelSize: 300))
        let original = try XCTUnwrap(ImageStore.load(filename))
        let thumbnailPixels = try XCTUnwrap(thumbnail.cgImage)
        let originalPixels = try XCTUnwrap(original.cgImage)

        XCTAssertEqual(originalPixels.width, 1_200)
        XCTAssertEqual(originalPixels.height, 600)
        XCTAssertLessThanOrEqual(max(thumbnailPixels.width, thumbnailPixels.height), 300)
        XCTAssertEqual(
            Double(thumbnailPixels.width) / Double(thumbnailPixels.height),
            2,
            accuracy: 0.02
        )
    }

    @MainActor
    func testBundledPaddleOCRRecognizesEnglishAndChinese() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "bilingual", withExtension: "png", subdirectory: "Fixtures"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        let start = CFAbsoluteTimeGetCurrent()
        let lines = try await OCRService.recognize(image)
        let duration = CFAbsoluteTimeGetCurrent() - start
        let text = lines.map(\.text).joined(separator: " ")
        print("Bundled PaddleOCR simulator elapsed: \(duration)s; text: \(text)")
        for expected in ["apple", "banana", "orange", "beautiful", "苹果", "香蕉", "橙子", "漂亮的"] {
            XCTAssertTrue(text.contains(expected), "Missing \(expected) in \(text)")
        }
        XCTAssertTrue(lines.allSatisfy { $0.rect.minX >= 0 && $0.rect.minY >= 0 && $0.rect.maxX <= 1 && $0.rect.maxY <= 1 })
        let blocks = TextSegmentation.blocks(from: lines, image: image)
        XCTAssertEqual(Set(blocks.filter { $0.language == .chinese }.map(\.text)), Set(["苹果", "香蕉", "橙子", "漂亮的"]))
        let apple = try XCTUnwrap(blocks.first { $0.text == "apple" })
        XCTAssertLessThan(apple.bounds.y, 0.3, "OCR coordinates must use the displayed image's top-left origin")
        XCTAssertGreaterThan(blocks.first { $0.text == "beautiful" }?.bounds.y ?? 0, 0.5)
    }

    @MainActor
    func testBundledPaddleOCRRecognizesJapaneseKanaAndSegmentsIt() async throws {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(
                forResource: "chinese-japanese",
                withExtension: "png",
                subdirectory: "Fixtures"
            )
        )
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path))
        let lines = try await OCRService.recognize(image)
        let recognized = lines.map(\.text).joined(separator: " ")

        XCTAssertTrue(recognized.contains("りんご"), recognized)
        XCTAssertTrue(recognized.contains("バナナ"), recognized)
        XCTAssertTrue(recognized.contains("美しい"), recognized)

        let blocks = TextSegmentation.blocks(
            from: lines,
            image: image,
            languagePair: CardLanguagePair(native: .chinese, target: .japanese)
        )
        XCTAssertTrue(blocks.contains { $0.text.contains("りんご") && $0.language == .japanese })
        XCTAssertTrue(blocks.contains { $0.text.contains("バナナ") && $0.language == .japanese })
        XCTAssertTrue(blocks.contains { $0.text.contains("美しい") && $0.language == .japanese })
    }
}

private enum LegacyCardSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [StudyCard.self] }

    @Model
    final class StudyCard {
        @Attribute(.unique) var id: UUID
        var title: String
        var imageFilename: String
        var createdAt: Date
        var blocksData: Data

        init(id: UUID, title: String, imageFilename: String, createdAt: Date, blocksData: Data) {
            self.id = id
            self.title = title
            self.imageFilename = imageFilename
            self.createdAt = createdAt
            self.blocksData = blocksData
        }
    }
}
