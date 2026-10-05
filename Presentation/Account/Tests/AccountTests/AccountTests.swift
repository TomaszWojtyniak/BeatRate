import Testing
@testable import Account

/// The Account average only appears from `minRatingsForAverage` (5) ratings, and
/// 0 ("not rated") never counts toward it.
@MainActor
@Test func averageNeedsFiveRatings() {
    #expect(AccountDataModel.average(of: [8, 9, 10, 7]) == nil)
    #expect(AccountDataModel.average(of: [8, 9, 10, 7, 6]) == 8)
    #expect(AccountDataModel.average(of: [8, 9, 10, 7, 0]) == nil)
}
