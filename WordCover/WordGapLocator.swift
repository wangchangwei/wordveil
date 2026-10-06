import Foundation

enum WordGapLocator {
    // The wider blank columns between printed words are selected in reading
    // order. Return nil when the image does not support a reliable split.
    static func boundaries(in ink: [Int]?, count: Int) -> [Double]? {
        guard count > 0, let ink, ink.count > 20 else { return nil }
        let lowInk = max(1, (ink.max() ?? 0) / 12)
        var runs: [(start: Int, end: Int)] = []
        var start: Int?
        for x in 0..<ink.count {
            if ink[x] <= lowInk {
                if start == nil { start = x }
            } else if let runStart = start {
                runs.append((runStart, x))
                start = nil
            }
        }
        if let start { runs.append((start, ink.count)) }
        let minWidth = max(2, ink.count / 150)
        let candidates = runs.filter {
            $0.start > 0 &&
            $0.end < ink.count &&
            $0.end - $0.start >= minWidth
        }
        guard candidates.count >= count else { return nil }
        let ranked = candidates.sorted { ($0.end - $0.start) > ($1.end - $1.start) }
        let selected = Array(ranked.prefix(count))
        if let widestRejected = ranked.dropFirst(count).first {
            let selectedMinimum = selected.map { $0.end - $0.start }.min() ?? 0
            let rejectedWidth = widestRejected.end - widestRejected.start
            let requiredSeparation = max(2, rejectedWidth / 2)
            guard selectedMinimum >= rejectedWidth + requiredSeparation else { return nil }
        }
        let widest = selected.sorted { $0.start < $1.start }
        return widest.map { Double($0.start + $0.end) / (2 * Double(ink.count)) }
    }
}
