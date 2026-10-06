import AppKit
import Foundation

// Original, deterministic bilingual material used by OCR and UI regression tests.
let size = NSSize(width: 1200, height: 850)
let image = NSImage(size: size)
image.lockFocusFlipped(true)
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 64),
    .foregroundColor: NSColor.black
]
for (row, text) in ["apple   苹果", "banana   香蕉", "orange   橙子"].enumerated() {
    (text as NSString).draw(at: NSPoint(x: 80, y: 100 + row * 125), withAttributes: attributes)
}
("I have a beautiful dog." as NSString).draw(at: NSPoint(x: 80, y: 560), withAttributes: [
    .font: NSFont.systemFont(ofSize: 58), .foregroundColor: NSColor.black
])
("beautiful   漂亮的" as NSString).draw(at: NSPoint(x: 80, y: 700), withAttributes: attributes)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let url = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Tests/Fixtures/bilingual.png")
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: url)
print("Created bilingual fixture at \(url.path) (\(bitmap.pixelsWide)×\(bitmap.pixelsHigh))")
