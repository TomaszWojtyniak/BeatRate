import Testing
@testable import CoreUI

@MainActor
struct AppShadowTests {

    // The modifier only draws one or two layers; a third would silently vanish.
    @Test(arguments: AppShadow.allCases)
    func `every tier has one or two layers`(style: AppShadow) {
        #expect((1...2).contains(style.layers.count))
    }

    @Test func `neutral elevation gets deeper from low to high`() {
        let radii = [AppShadow.low, .medium, .high].map { $0.layers[0].radius }

        #expect(radii == radii.sorted())
        #expect(Set(radii).count == radii.count)
    }

    @Test func `every shadow falls straight down`() {
        let layers = AppShadow.allCases.flatMap(\.layers)

        #expect(layers.allSatisfy { $0.x == 0 && $0.y > 0 })
    }
}
