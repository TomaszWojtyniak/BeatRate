import Foundation
@testable import BeatRateFixtures

/// Writes `json` to a fresh file in the temporary directory and returns its path.
func fixtureFile(_ json: String) -> String {
    let url = FileManager.default.temporaryDirectory.appending(path: "fixture.\(UUID()).json")
    try! Data(json.utf8).write(to: url)
    return url.path
}

/// Fixtures loaded from one or more JSON strings, in order.
func fixtures(_ files: String...) throws -> Fixtures {
    try Fixtures.load(files.map(fixtureFile))
}

enum Sample {
    static let discoveryAlbum = """
        {"id":"1440935467","title":"Discovery","artist":"Daft Punk","coverUrl":null,"releaseDate":null,"genre":"Electronic"}
        """

    static let signedIn = """
        {"device":{"firebaseUid":"u1","keychain":{"appleUserID":"apple-1"},"appleIDState":"authorized",
         "loggedInUserId":"u1","defaults":{"analyticsConsent":true,"mainMusicPlayer.u1":"appleMusic"}}}
        """
}
