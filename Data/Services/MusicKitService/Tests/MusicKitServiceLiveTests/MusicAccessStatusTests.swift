#if os(iOS)
import MusicKit
import MusicKitService
import Testing
@testable import MusicKitServiceLive

struct MusicAccessStatusTests {

    @Test(arguments: [
        (MusicAuthorization.Status.notDetermined, MusicAccessStatus.notDetermined),
        (.denied, .denied), (.restricted, .restricted), (.authorized, .authorized),
    ])
    func `every MusicKit authorization status keeps its meaning`(status: MusicAuthorization.Status, expected: MusicAccessStatus) {
        #expect(MusicAccessStatus(status) == expected)
    }
}
#endif
