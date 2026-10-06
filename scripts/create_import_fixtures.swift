import AppKit
import PDFKit
import ImageIO

// Two real PDF pages: page 1 is a different lesson; page 2 is the bilingual OCR fixture.
let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Tests/Fixtures")
let image = NSImage(contentsOf: root.appendingPathComponent("bilingual.png"))!
let cover = NSImage(size: NSSize(width: 1200, height: 850))
cover.lockFocusFlipped(true)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 1200, height: 850).fill()
("Lesson 1\nhello  你好" as NSString).draw(at: NSPoint(x: 100, y: 200), withAttributes: [
    .font: NSFont.systemFont(ofSize: 72), .foregroundColor: NSColor.black
])
cover.unlockFocus()
let document = PDFDocument()
document.insert(PDFPage(image: cover)!, at: 0)
document.insert(PDFPage(image: image)!, at: 1)
let output = root.appendingPathComponent("import-lesson.pdf")
guard document.write(to: output) else { fatalError("Could not write PDF fixture") }
print("Created \(output.path)")
let heicURL = root.appendingPathComponent("bilingual.heic")
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!.cgImage!
let destination = CGImageDestinationCreateWithURL(heicURL as CFURL, "public.heic" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, bitmap, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write HEIC fixture") }
print("Created \(heicURL.path)")
