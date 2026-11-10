import Testing
@testable import TabBar

@MainActor
struct TabBarScreenTests {

    @Test(arguments: TabBarScreen.allCases)
    func `every tab is open with music access`(tab: TabBarScreen) {
        #expect(tab.isAvailable(hasMusicAccess: true))
    }

    // App Review 5.1.1(v): logout and account deletion must stay reachable.
    @Test(arguments: [(TabBarScreen.home, false), (.search, false), (.account, true)])
    func `only account stays open without music access`(tab: TabBarScreen, isOpen: Bool) {
        #expect(tab.isAvailable(hasMusicAccess: false) == isOpen)
    }

    @Test func `each tab identifies as itself`() {
        #expect(TabBarScreen.allCases.map(\.id) == TabBarScreen.allCases)
    }
}
