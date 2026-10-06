import AppKit
import CoreText

// Shared vector geometry exports both editable SVG and native PNG artwork.
struct Ink {
    let hex: String
    var alpha: CGFloat = 1
    var cg: CGColor {
        let n = UInt32(hex, radix: 16)!
        return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [
            CGFloat((n >> 16) & 255) / 255,
            CGFloat((n >> 8) & 255) / 255,
            CGFloat(n & 255) / 255, alpha
        ])!
    }
}

struct Shape {
    let path: CGPath
    let colors: [Ink]
    var edge: Ink? = nil
    var edgeWidth: CGFloat = 1
    var shadow: CGFloat = 0
    var blur: CGFloat = 12
    var offset: CGFloat = 8

    func transformed(_ t: CGAffineTransform) -> Shape {
        var transform = t
        return Shape(path: path.copy(using: &transform)!, colors: colors, edge: edge,
                     edgeWidth: edgeWidth * t.a, shadow: shadow, blur: blur * t.a, offset: offset * t.a)
    }
}

func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func lettering(_ text: String, font name: String, size: CGFloat, x: CGFloat, y: CGFloat) -> CGPath {
    let font = CTFontCreateWithName(name as CFString, size, nil)
    let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    let outline = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
        for i in 0..<count {
            if let glyph = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                outline.addPath(glyph, transform: CGAffineTransform(translationX: positions[i].x, y: positions[i].y))
            }
        }
    }
    let bounds = outline.boundingBoxOfPath
    var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: x - bounds.minX, ty: y + bounds.maxY)
    return outline.copy(using: &transform)!
}

func mark() -> [Shape] {
    let letter = lettering("W", font: "AvenirNext-DemiBold", size: 378, x: 0, y: 0)
    let bounds = letter.boundingBoxOfPath
    var center = CGAffineTransform(translationX: 512 - bounds.width / 2, y: 322)

    let ribbon = CGMutablePath()
    ribbon.move(to: CGPoint(x: 224, y: 456))
    ribbon.addLine(to: CGPoint(x: 704, y: 456))
    ribbon.addCurve(to: CGPoint(x: 802, y: 536), control1: CGPoint(x: 725, y: 496), control2: CGPoint(x: 759, y: 526))
    ribbon.addLine(to: CGPoint(x: 802, y: 588))
    ribbon.addQuadCurve(to: CGPoint(x: 778, y: 612), control: CGPoint(x: 802, y: 612))
    ribbon.addLine(to: CGPoint(x: 224, y: 612))
    ribbon.addQuadCurve(to: CGPoint(x: 200, y: 588), control: CGPoint(x: 200, y: 612))
    ribbon.addLine(to: CGPoint(x: 200, y: 480))
    ribbon.addQuadCurve(to: CGPoint(x: 224, y: 456), control: CGPoint(x: 200, y: 456))
    ribbon.closeSubpath()

    let curl = CGMutablePath()
    curl.move(to: CGPoint(x: 704, y: 456))
    curl.addCurve(to: CGPoint(x: 796, y: 438), control1: CGPoint(x: 738, y: 456), control2: CGPoint(x: 772, y: 451))
    curl.addCurve(to: CGPoint(x: 802, y: 536), control1: CGPoint(x: 807, y: 463), control2: CGPoint(x: 811, y: 500))
    curl.addCurve(to: CGPoint(x: 704, y: 456), control1: CGPoint(x: 761, y: 530), control2: CGPoint(x: 726, y: 497))
    curl.closeSubpath()

    return [
        Shape(path: rounded(244, 178, 536, 668, 68), colors: [Ink(hex: "FFFEF9"), Ink(hex: "E9EFF3")],
              edge: Ink(hex: "FFFFFF", alpha: 0.75), edgeWidth: 2, shadow: 0.17, blur: 28, offset: 20),
        Shape(path: letter.copy(using: &center)!, colors: [Ink(hex: "354B61")]),
        Shape(path: ribbon, colors: [Ink(hex: "ACBDD0"), Ink(hex: "7189A4")],
              edge: Ink(hex: "DDE7EF", alpha: 0.60), edgeWidth: 1.5, shadow: 0.19, blur: 13, offset: 9),
        Shape(path: curl, colors: [Ink(hex: "FEFCF4"), Ink(hex: "CEDAE5")],
              edge: Ink(hex: "FFFFFF", alpha: 0.60), edgeWidth: 1, shadow: 0.10, blur: 5, offset: 3)
    ]
}

func n(_ value: CGFloat) -> String { String(format: "%.3f", Double(value)) }

func svgPath(_ path: CGPath) -> String {
    var parts: [String] = []
    path.applyWithBlock { element in
        let e = element.pointee
        func p(_ i: Int) -> String { "\(n(e.points[i].x)) \(n(e.points[i].y))" }
        switch e.type {
        case .moveToPoint: parts.append("M\(p(0))")
        case .addLineToPoint: parts.append("L\(p(0))")
        case .addQuadCurveToPoint: parts.append("Q\(p(0)) \(p(1))")
        case .addCurveToPoint: parts.append("C\(p(0)) \(p(1)) \(p(2))")
        case .closeSubpath: parts.append("Z")
        @unknown default: break
        }
    }
    return parts.joined(separator: " ")
}

func export(_ name: String, width: Int, height: Int, shapes: [Shape], directory: URL, opaque: Bool = false) throws {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: space, bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue)!
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: 1, y: -1)
    var definitions = ""
    var elements = ""
    for (index, shape) in shapes.enumerated() {
        let bounds = shape.path.boundingBoxOfPath
        if shape.shadow > 0 {
            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: -shape.offset), blur: shape.blur, color: Ink(hex: "243447", alpha: shape.shadow).cg)
            context.addPath(shape.path)
            context.setFillColor(shape.colors[0].cg)
            context.fillPath()
            context.restoreGState()
            definitions += "<filter id=\"s\(index)\" x=\"-40%\" y=\"-40%\" width=\"180%\" height=\"190%\"><feDropShadow dx=\"0\" dy=\"\(n(shape.offset))\" stdDeviation=\"\(n(shape.blur / 2))\" flood-color=\"#243447\" flood-opacity=\"\(n(shape.shadow))\"/></filter>"
        }
        context.saveGState()
        context.addPath(shape.path)
        context.clip()
        if shape.colors.count > 1 {
            let gradient = CGGradient(colorsSpace: space, colors: shape.colors.map(\.cg) as CFArray, locations: nil)!
            context.drawLinearGradient(gradient, start: CGPoint(x: bounds.minX, y: bounds.minY),
                                       end: CGPoint(x: bounds.maxX, y: bounds.maxY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else {
            context.setFillColor(shape.colors[0].cg)
            context.fill(bounds)
        }
        context.restoreGState()
        if let edge = shape.edge {
            context.addPath(shape.path)
            context.setStrokeColor(edge.cg)
            context.setLineWidth(shape.edgeWidth)
            context.strokePath()
        }
        var fill = "#\(shape.colors[0].hex)"
        if shape.colors.count > 1 {
            definitions += "<linearGradient id=\"g\(index)\" gradientUnits=\"userSpaceOnUse\" x1=\"\(n(bounds.minX))\" y1=\"\(n(bounds.minY))\" x2=\"\(n(bounds.maxX))\" y2=\"\(n(bounds.maxY))\">"
            for (i, color) in shape.colors.enumerated() {
                definitions += "<stop offset=\"\(n(CGFloat(i) / CGFloat(shape.colors.count - 1)))\" stop-color=\"#\(color.hex)\" stop-opacity=\"\(n(color.alpha))\"/>"
            }
            definitions += "</linearGradient>"
            fill = "url(#g\(index))"
        }
        let stroke = shape.edge.map { " stroke=\"#\($0.hex)\" stroke-opacity=\"\(n($0.alpha))\" stroke-width=\"\(n(shape.edgeWidth))\"" } ?? ""
        let shadow = shape.shadow > 0 ? " filter=\"url(#s\(index))\"" : ""
        elements += "<path d=\"\(svgPath(shape.path))\" fill=\"\(fill)\"\(stroke)\(shadow)/>\n"
    }
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + ".png"))
    let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" height=\"\(height)\" viewBox=\"0 0 \(width) \(height)\"><defs>\(definitions)</defs>\n\(elements)</svg>"
    try svg.write(to: directory.appendingPathComponent(name + ".svg"), atomically: true, encoding: .utf8)
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let background = Shape(path: rounded(0, 0, 1024, 1024, 0), colors: [Ink(hex: "95AABE"), Ink(hex: "5D748E")])
let symbol = mark()
try export("app-icon-1024", width: 1024, height: 1024, shapes: [background] + symbol, directory: output, opaque: true)
let crop = CGAffineTransform(translationX: -160, y: -140)
try export("logo-mark", width: 704, height: 768, shapes: symbol.map { $0.transformed(crop) }, directory: output)

let mini = CGAffineTransform(a: 0.30, b: 0, c: 0, d: 0.30, tx: -40, ty: -32)
let wordmark = Shape(path: lettering("Wordveil", font: "AvenirNext-DemiBold", size: 112, x: 242, y: 78), colors: [Ink(hex: "354B61")])
let tagline = Shape(path: lettering("Hide. Recall. Reveal.", font: "AvenirNext-Regular", size: 28, x: 246, y: 184), colors: [Ink(hex: "71849A")])
try export("logo-horizontal", width: 780, height: 250,
           shapes: symbol.map { $0.transformed(mini) } + [wordmark, tagline], directory: output)

let boardBackground = Shape(path: rounded(0, 0, 1600, 980, 0), colors: [Ink(hex: "F4F5F3")])
let iconTransform = CGAffineTransform(a: 0.54, b: 0, c: 0, d: 0.54, tx: 108, ty: 176)
let previewBackground = Shape(path: rounded(0, 0, 1024, 1024, 210), colors: background.colors, shadow: 0.14, blur: 28, offset: 18)
let previewIcon = ([previewBackground] + symbol).map { $0.transformed(iconTransform) }
let boardTexts = [
    Shape(path: lettering("Wordveil", font: "AvenirNext-DemiBold", size: 110, x: 764, y: 292), colors: [Ink(hex: "354B61")]),
    Shape(path: lettering("Hide. Recall. Reveal.", font: "AvenirNext-Regular", size: 32, x: 770, y: 420), colors: [Ink(hex: "71849A")]),
    Shape(path: lettering("遮住答案，记住单词。", font: "PingFangSC-Regular", size: 28, x: 770, y: 513), colors: [Ink(hex: "71849A")]),
    Shape(path: lettering("WORD + VEIL", font: "AvenirNext-Medium", size: 18, x: 112, y: 844), colors: [Ink(hex: "71849A")]),
    Shape(path: lettering("A quiet moment. A stronger memory.", font: "AvenirNext-Regular", size: 21, x: 768, y: 839), colors: [Ink(hex: "71849A")])
]
try export("brand-preview", width: 1600, height: 980, shapes: [boardBackground] + previewIcon + boardTexts, directory: output, opaque: true)

var sizeCheck = [Shape(path: rounded(0, 0, 560, 180, 0), colors: [Ink(hex: "F4F5F3")])]
for (x, side) in [(32.0, 120.0), (220.0, 60.0), (360.0, 40.0), (474.0, 29.0)] {
    let transform = CGAffineTransform(a: side / 1024, b: 0, c: 0, d: side / 1024, tx: x, ty: 24)
    sizeCheck += ([previewBackground] + symbol).map { $0.transformed(transform) }
    sizeCheck.append(Shape(path: lettering("\(Int(side)) px", font: "AvenirNext-Regular", size: 14, x: x, y: 154), colors: [Ink(hex: "71849A")]))
}
try export("icon-size-check", width: 560, height: 180, shapes: sizeCheck, directory: output, opaque: true)
print("Exported app icon, transparent logo mark, horizontal logo, and brand preview as PNG + SVG.")
