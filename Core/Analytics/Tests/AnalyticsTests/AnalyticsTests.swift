import Testing
@testable import Analytics

@Test func screenViewNamesTheScreenInBothNameAndClass() {
    let params = AnalyticsEvent.screenView(.albumDetails, ["album_id": "42"]).parameters

    #expect(params["screen_name"] as? String == "album_details")
    #expect(params["screen_class"] as? String == "album_details")
    #expect(params["album_id"] as? String == "42")
}
