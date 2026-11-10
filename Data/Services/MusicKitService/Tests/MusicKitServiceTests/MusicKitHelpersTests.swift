import Foundation
import Testing
@testable import MusicKitService

/// A page of numbers; `next` builds the following page, nil when it fails to load.
struct StubPage: PagedBatch, Sendable {
    let items: [Int]
    let remaining: [[Int]]
    var failsNext = false

    var hasNextBatch: Bool { !remaining.isEmpty }

    func makeIterator() -> IndexingIterator<[Int]> { items.makeIterator() }

    func nextPage() async throws -> StubPage? {
        if failsNext { throw StubError() }
        guard let next = remaining.first else { return nil }
        return StubPage(items: next, remaining: Array(remaining.dropFirst()))
    }
}

struct MusicKitHelpersTests {

    // MARK: - Subscription timeout

    @Test func `value is returned as soon as it arrives`() async {
        let value = await MusicKitService.value(within: .seconds(5)) { 7 }

        #expect(value == 7)
    }

    // Accounts without Apple Music never yield a subscription; the launch must not hang.
    @Test func `silent operation gives up after the timeout`() async {
        let value: Int? = await MusicKitService.value(within: .milliseconds(10)) {
            for await value in AsyncStream<Int>(unfolding: { try? await Task.sleep(for: .seconds(60)); return nil }) {
                return value
            }
            return nil
        }

        #expect(value == nil)
    }

    @Test func `operation that finds nothing gives nothing`() async {
        let value: Int? = await MusicKitService.value(within: .seconds(5)) { nil }

        #expect(value == nil)
    }

    // MARK: - Batching

    @Test func `pages are collected in order`() async throws {
        let first = StubPage(items: [1, 2], remaining: [[3], [4, 5]])

        #expect(try await MusicKitService.allBatches(of: first, maxBatches: 4) == [1, 2, 3, 4, 5])
    }

    // Huge discographies must not fan out into unbounded requests.
    @Test func `collection stops at the batch cap`() async throws {
        let first = StubPage(items: [1], remaining: [[2], [3], [4], [5]])

        #expect(try await MusicKitService.allBatches(of: first, maxBatches: 2) == [1, 2])
    }

    @Test func `missing collection is empty`() async throws {
        #expect(try await MusicKitService.allBatches(of: StubPage?.none, maxBatches: 4).isEmpty)
    }

    @Test func `page that claims more but returns none ends collection`() async throws {
        struct Truncated: PagedBatch, Sendable {
            var hasNextBatch: Bool { true }
            func makeIterator() -> IndexingIterator<[Int]> { [1].makeIterator() }
            func nextPage() async throws -> Truncated? { nil }
        }

        #expect(try await MusicKitService.allBatches(of: Truncated(), maxBatches: 4) == [1])
    }

    @Test func `failed page load is passed on`() async {
        let first = StubPage(items: [1], remaining: [[2]], failsNext: true)

        await #expect(throws: StubError.self) { try await MusicKitService.allBatches(of: first, maxBatches: 4) }
    }
}
