import Foundation

@main
enum WordGapLocatorCheck {
    static func main() {
        // Two words with uneven widths: the gap is around 55%, not 50%.
        var mixed = Array(repeating: 12, count: 100)
        for x in 52..<59 { mixed[x] = 0 }
        for x in [10, 20, 30, 70, 80] { mixed[x] = 0 }
        guard let mixedBoundary = WordGapLocator.boundaries(in: mixed, count: 1),
              abs(mixedBoundary[0] - 0.55) < 0.02 else {
            fatalError("Failed to locate the visual gap between English and Chinese")
        }

        // Three token boundaries must remain in reading order.
        var words = Array(repeating: 10, count: 120)
        for range in [22..<28, 60..<68, 94..<101] {
            for x in range { words[x] = 0 }
        }
        guard let boundaries = WordGapLocator.boundaries(in: words, count: 3),
              boundaries == boundaries.sorted(), boundaries.count == 3 else {
            fatalError("Failed to preserve word order")
        }
        print("Word gap checks passed")
    }
}
