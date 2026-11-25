import FirebaseService
import FirebaseServiceFakes
import Foundation
import Testing

struct FakeRealtimeDatabaseTests {
    @Test func `a multi-path update with one failing path changes nothing`() async {
        let database = FakeRealtimeDatabase(DatabaseValue(["a": 1]), failingWrites: ["c"])

        await #expect(throws: FakeDatabaseError(path: "c")) {
            try await database.update("", with: ["a": DatabaseValue(2), "b": DatabaseValue(3), "c": DatabaseValue(4)])
        }

        #expect(await database.value("a").raw as? Int == 1)
        #expect(await database.value("b").raw == nil)
    }

    @Test func `a delayed multi-path update waits once and lands all at once`() async throws {
        let database = FakeRealtimeDatabase(delay: .milliseconds(100))
        let clock = ContinuousClock()

        let start = clock.now
        let update = Task {
            try await database.update("", with: ["x": DatabaseValue(1), "y": DatabaseValue(2), "z": DatabaseValue(3)])
        }
        try await Task.sleep(for: .milliseconds(50))
        #expect(await database.value("x").raw == nil)
        try await update.value

        #expect(clock.now - start < .milliseconds(250))
        #expect(await database.value("x").raw as? Int == 1)
        #expect(await database.value("z").raw as? Int == 3)
    }

    @Test func `null leaves in the initial tree are absent, as in Firebase`() async throws {
        let database = FakeRealtimeDatabase(DatabaseValue(["albums": ["1": NSNull(), "2": ["title": "B"]], "empty": [String: Any]()]))

        #expect(try await database.read("albums/1").raw == nil)
        #expect(try await database.read("empty").raw == nil)
        #expect(try await database.read("albums/2/title").raw as? String == "B")
    }
}
