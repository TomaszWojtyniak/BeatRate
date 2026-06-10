import Foundation
import Testing
@testable import CoreApp

struct ConcurrentCompactMapTests {

    @Test func preservesInputOrder() async {
        let input = Array(0..<50)
        let result = await input.concurrentCompactMap(maxConcurrent: 4) { value -> Int? in
            try? await Task.sleep(for: .milliseconds(Int.random(in: 1...10)))
            return value * 2
        }
        #expect(result == input.map { $0 * 2 })
    }

    @Test func dropsNilResults() async {
        let result = await Array(0..<10).concurrentCompactMap(maxConcurrent: 3) { value -> Int? in
            value.isMultiple(of: 2) ? value : nil
        }
        #expect(result == [0, 2, 4, 6, 8])
    }

    @Test func neverExceedsMaxConcurrent() async {
        let counter = ConcurrencyCounter()
        _ = await Array(0..<20).concurrentCompactMap(maxConcurrent: 4) { value -> Int? in
            await counter.enter()
            try? await Task.sleep(for: .milliseconds(5))
            await counter.exit()
            return value
        }
        #expect(await counter.maxObserved <= 4)
    }

    @Test func handlesEmptyInput() async {
        let result = await [Int]().concurrentCompactMap(maxConcurrent: 4) { value -> Int? in value }
        #expect(result.isEmpty)
    }

    @Test func clampsNonPositiveMaxConcurrentToSequential() async {
        let result = await [1, 2, 3].concurrentCompactMap(maxConcurrent: 0) { value -> Int? in value }
        #expect(result == [1, 2, 3])
    }
}

private actor ConcurrencyCounter {
    private var current = 0
    private(set) var maxObserved = 0

    func enter() {
        current += 1
        maxObserved = max(maxObserved, current)
    }

    func exit() {
        current -= 1
    }
}
