//
//  Sequence+ConcurrentCompactMap.swift
//  CoreApp
//
//  Created by Tomasz Wojtyniak on 10/06/2026.
//

import Foundation

nonisolated extension Sequence where Element: Sendable {
    /// Transforms elements concurrently — at most `maxConcurrent` at a time —
    /// preserving input order and dropping `nil` results.
    ///
    /// The cap keeps bursts against rate-limited backends (MusicKit catalog,
    /// Firebase) bounded; values below 1 are clamped to sequential execution.
    public func concurrentCompactMap<T: Sendable>(
        maxConcurrent: Int,
        _ transform: @escaping @Sendable (Element) async -> T?
    ) async -> [T] {
        let items = Array(self)
        guard !items.isEmpty else { return [] }
        let limit = Swift.max(1, maxConcurrent)

        return await withTaskGroup(of: (Int, T?).self) { group in
            var results = [T?](repeating: nil, count: items.count)
            var nextIndex = 0

            while nextIndex < items.count && nextIndex < limit {
                let index = nextIndex
                group.addTask { (index, await transform(items[index])) }
                nextIndex += 1
            }

            for await (index, value) in group {
                results[index] = value
                if nextIndex < items.count {
                    let index = nextIndex
                    group.addTask { (index, await transform(items[index])) }
                    nextIndex += 1
                }
            }

            return results.compactMap { $0 }
        }
    }
}
