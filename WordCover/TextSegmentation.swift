import CoreGraphics
import Foundation
import UIKit

enum TextSegmentation {
    private static let pattern = try! NSRegularExpression(
        pattern: "[A-Za-z]+(?:['’\\-][A-Za-z]+)*|[\\p{Han}\\p{Hiragana}\\p{Katakana}ー々〆ヶ\\u3099\\u309A\\uFF9E\\uFF9F]+"
    )

    static func blocks(from lines: [OCRLine], image: UIImage, languagePair: CardLanguagePair = .init()) -> [OCRBlock] {
        lines.flatMap { line in
            let text = line.text
            let nsText = text as NSString
            let matches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            guard !matches.isEmpty else { return [OCRBlock]() }

            let lineRect = line.rect.standardized
            let boundaryInk = columnInk(in: lineRect, image: image)
            let gaps = WordGapLocator.boundaries(in: boundaryInk, count: matches.count - 1)
            let total = max(1, nsText.length)
            var result: [OCRBlock] = []
            var previousEnd = 0.0

            for (index, match) in matches.enumerated() {
                let token = nsText.substring(with: match.range)
                let next = index + 1 < matches.count ? matches[index + 1] : nil
                let leftExpected = Double(match.range.location) / Double(total)
                let rightExpected = Double(match.range.location + match.range.length) / Double(total)
                let left = index == 0 ? max(0, leftExpected) : previousEnd
                let right: Double
                if let gaps {
                    right = index < gaps.count ? gaps[index] : 0.995
                } else if let next {
                    let midpoint = Double(match.range.location + match.range.length + next.range.location) / (2 * Double(total))
                    right = midpoint
                } else {
                    right = min(1, max(rightExpected, 0.995))
                }
                previousEnd = right

                let x = lineRect.minX + CGFloat(left) * lineRect.width
                let width = max(0, CGFloat(right - left) * lineRect.width)
                let rect = CGRect(x: x, y: lineRect.minY, width: width, height: lineRect.height)
                result.append(OCRBlock(
                    text: token,
                    language: classify(text: token, languagePair: languagePair),
                    bounds: NormalizedRect(rect),
                    estimated: matches.count > 1 && gaps == nil,
                    languageNeedsReview: needsLanguageReview(text: token, languagePair: languagePair)
                ))
            }
            return result
        }
    }

    static func classify(text: String, languagePair: CardLanguagePair) -> BlockLanguage {
        if containsKana(text) { return .japanese }
        if text.unicodeScalars.contains(where: { $0.properties.isIdeographic }) {
            return languagePair.languages.contains(.japanese) && !languagePair.languages.contains(.chinese)
                ? .japanese : .chinese
        }
        return .english
    }

    static func needsLanguageReview(text: String, languagePair: CardLanguagePair) -> Bool {
        languagePair.languages.contains(.chinese) && languagePair.languages.contains(.japanese)
            && !containsKana(text) && text.unicodeScalars.contains(where: { $0.properties.isIdeographic })
    }

    private static func containsKana(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            (0x3041...0x309F).contains($0.value) || (0x30A0...0x30FF).contains($0.value)
                || (0xFF66...0xFF9F).contains($0.value) || (0x31F0...0x31FF).contains($0.value)
        }
    }

    private static func columnInk(in normalized: CGRect, image: UIImage) -> [Int]? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let crop = CGRect(
            x: normalized.minX * CGFloat(width),
            y: normalized.minY * CGFloat(height),
            width: normalized.width * CGFloat(width),
            height: normalized.height * CGFloat(height)
        ).integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard crop.width > 8, crop.height > 2,
              let region = cgImage.cropping(to: crop) else { return nil }
        let sampleWidth = min(600, max(16, Int(crop.width)))
        let sampleHeight = min(80, max(8, Int(crop.height)))
        var pixels = [UInt8](repeating: 255, count: sampleWidth * sampleHeight)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: sampleWidth,
                height: sampleHeight,
                bitsPerComponent: 8,
                bytesPerRow: sampleWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(region, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))
            return true
        }
        guard rendered else { return nil }
        return (0..<sampleWidth).map { x in
            (0..<sampleHeight).reduce(0) { count, y in
                count + (pixels[y * sampleWidth + x] < 170 ? 1 : 0)
            }
        }
    }
}
