import Testing
@testable import AlbumDetails

@MainActor
struct StarRatingScaleTests {

    @Test(arguments: [
        (0, 7.5, StarRatingScale.Fill.full),
        (6, 7.5, .full),
        (7, 7.5, .half),
        (8, 7.5, .empty),
        (0, 0.0, .empty),
    ])
    func `each star fills from the rating`(star: Int, rating: Double, fill: StarRatingScale.Fill) {
        #expect(StarRatingScale.fill(ofStar: star, rating: rating) == fill)
    }

    @Test(arguments: [(-1.0, 0.0), (5.5, 5.5), (11.0, 10.0)])
    func `ratings stay between zero and ten`(rating: Double, clamped: Double) {
        #expect(StarRatingScale.clamped(rating) == clamped)
    }

    // Row 100 wide, so each star is 10 wide.
    @Test(arguments: [
        (-5.0, 0.0),
        (2.0, 0.0),
        (5.0, 0.5),
        (8.0, 1.0),
        (35.0, 3.5),
        (100.0, 10.0),
        (140.0, 10.0),
    ])
    func `dragging rounds to the nearest half star`(x: Double, rating: Double) {
        #expect(StarRatingScale.dragRating(atX: x, width: 100) == rating)
    }

    @Test(arguments: [(0.0, 0), (34.0, 3), (99.0, 9), (100.0, 9)])
    func `tap lands on the star under the finger`(x: Double, star: Int) {
        #expect(StarRatingScale.tappedStar(atX: x, width: 100) == star)
    }

    @Test func `tap fills a star and a quick second tap halves it`() {
        #expect(StarRatingScale.tapRating(star: 3, isQuickRepeat: false) == 4)
        #expect(StarRatingScale.tapRating(star: 3, isQuickRepeat: true) == 3.5)
    }
}
