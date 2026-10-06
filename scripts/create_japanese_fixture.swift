import AppKit
let size = NSSize(width: 1400, height: 1000)
let image = NSImage(size: size)
image.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 64), .foregroundColor: NSColor.black]
for (i, row) in ["りんご       苹果", "バナナ       香蕉", "美しい       漂亮的", "猫          猫咪"].enumerated() {
    (row as NSString).draw(at: NSPoint(x: 120, y: 800 - i * 180), withAttributes: attrs)
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
