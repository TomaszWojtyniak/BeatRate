import Models
import Testing
@testable import FirebaseService

@MainActor
struct AuthProfileTests {

    private func service(_ database: StubDatabaseFirebaseService) -> AuthFirebaseService {
        AuthFirebaseService(databaseService: database)
    }

    @Test func `first sign in creates a profile from apple's details`() async {
        let database = StubDatabaseFirebaseService()

        await service(database).createUserProfileIfNeeded(userId: "u", email: "a@b.c", firstName: "Ann", lastName: "Lee")

        let saved = database.savedProfiles
        #expect(saved.map(\.userId) == ["u"])
        #expect(saved.first?.profile.email == "a@b.c")
        #expect(saved.first?.profile.firstName == "Ann")
        #expect(saved.first?.profile.lastName == "Lee")
    }

    @Test func `new user without any details gets no profile`() async {
        let database = StubDatabaseFirebaseService()

        await service(database).createUserProfileIfNeeded(userId: "u", email: nil, firstName: nil, lastName: nil)

        #expect(database.savedProfiles.isEmpty)
    }

    @Test func `returning user with fresh name details is updated`() async {
        let database = StubDatabaseFirebaseService(existingProfile: FirebaseUserProfile(email: "a@b.c", firstName: nil, lastName: nil))

        await service(database).createUserProfileIfNeeded(userId: "u", email: "a@b.c", firstName: "Ann", lastName: nil)

        #expect(database.savedProfiles.first?.profile.firstName == "Ann")
    }

    // Apple omits the name after the first sign-in; saving then would erase it.
    @Test func `returning user without name details is left alone`() async {
        let database = StubDatabaseFirebaseService(existingProfile: FirebaseUserProfile(email: "a@b.c", firstName: "Ann", lastName: "Lee"))

        await service(database).createUserProfileIfNeeded(userId: "u", email: "a@b.c", firstName: nil, lastName: nil)

        #expect(database.savedProfiles.isEmpty)
    }
}
