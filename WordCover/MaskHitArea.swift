import CoreGraphics
import Foundation

enum MaskHitArea {
    static func rect(for id: UUID, blocks: [OCRBlock], fittedSize: CGSize) -> CGRect {
        guard let block = blocks.first(where: { $0.id == id }) else { return .zero }
        func displayed(_ block: OCRBlock) -> CGRect {
            let bounds = block.bounds.cgRect
            return CGRect(x: bounds.minX * fittedSize.width, y: bounds.minY * fittedSize.height,
                          width: bounds.width * fittedSize.width, height: bounds.height * fittedSize.height)
        }
        func expanded(_ rect: CGRect) -> CGRect {
            rect.insetBy(dx: -max(0, (16 - rect.width) / 2), dy: -max(0, (16 - rect.height) / 2))
        }
        let visible = displayed(block)
        let candidate = expanded(visible)
        var left = visible.minX - candidate.minX
        var right = candidate.maxX - visible.maxX
        var top = visible.minY - candidate.minY
        var bottom = candidate.maxY - visible.maxY
        for neighbor in blocks where neighbor.id != id {
            let other = displayed(neighbor)
            let otherCandidate = expanded(other)
            // Share blank space between neighboring masks. Expanded invisible
            // targets must not steal a tap from a nearby visible answer.
            if candidate.minY < otherCandidate.maxY && candidate.maxY > otherCandidate.minY {
                if other.maxX <= visible.minX { left = min(left, (visible.minX - other.maxX) / 2) }
                if other.minX >= visible.maxX { right = min(right, (other.minX - visible.maxX) / 2) }
            }
            if candidate.minX < otherCandidate.maxX && candidate.maxX > otherCandidate.minX {
                if other.maxY <= visible.minY { top = min(top, (visible.minY - other.maxY) / 2) }
                if other.minY >= visible.maxY { bottom = min(bottom, (other.minY - visible.maxY) / 2) }
            }
        }
        return CGRect(x: visible.minX - left, y: visible.minY - top,
                      width: visible.width + left + right, height: visible.height + top + bottom)
            .intersection(CGRect(origin: .zero, size: fittedSize))
    }
}
