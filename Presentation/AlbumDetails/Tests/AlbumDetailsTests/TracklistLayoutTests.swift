import Models
import Testing
@testable import AlbumDetails

@MainActor
struct TracklistLayoutTests {

    @Test func `tracks are ordered by disc then number with unnumbered ones first`() {
        let layout = TracklistLayout(tracks: [Fixture.track(2, disc: 2), Fixture.track(1, disc: nil), Fixture.track(3), Fixture.track(nil)], isExpanded: false)

        #expect(layout.sortedTracks.map(\.id) == ["1-0", "0-1", "1-3", "2-2"])
    }

    @Test(arguments: [5, 6])
    func `only lists longer than five can collapse`(count: Int) {
        let layout = TracklistLayout(tracks: (1...count).map { Fixture.track($0) }, isExpanded: false)

        #expect(layout.canCollapse == (count > 5))
        #expect(layout.visibleTracks.count == 5)
    }

    @Test func `expanded list shows every track`() {
        let layout = TracklistLayout(tracks: (1...8).map { Fixture.track($0) }, isExpanded: true)

        #expect(layout.visibleTracks.count == 8)
    }

    @Test func `disc headers appear only for multi disc albums`() {
        let single = TracklistLayout(tracks: [Fixture.track(1), Fixture.track(2, disc: nil)], isExpanded: true)
        let double = TracklistLayout(tracks: [Fixture.track(1, disc: 2), Fixture.track(1)], isExpanded: true)

        #expect(!single.showsDiscHeaders)
        #expect(single.groupedVisible.map(\.disc) == [1])
        #expect(double.showsDiscHeaders)
        #expect(double.groupedVisible.map(\.disc) == [1, 2])
    }

    @Test(arguments: [(0.0, "0:00"), (59.4, "0:59"), (59.5, "1:00"), (314.0, "5:14"), (3_725.0, "62:05")])
    func `durations read as minutes and seconds`(seconds: Double, text: String) {
        #expect(TracklistLayout.duration(seconds) == text)
    }
}
