import Testing
@testable import BeijingTimeCore

struct FixedFaceTests {
    @Test func ordinaryBackgroundIsDarkAndTranslucent() {
        let color = FixedFace.background(reduceTransparency: false)
        #expect(color.white < 0.2)
        #expect(color.alpha > 0)
        #expect(color.alpha < 1)
    }

    @Test func reducedTransparencyUsesTheSameDarknessOpaque() {
        let ordinary = FixedFace.background(reduceTransparency: false)
        let reduced = FixedFace.background(reduceTransparency: true)
        #expect(reduced.white == ordinary.white)
        #expect(reduced.alpha == 1)
    }

    @Test func textStaysLight() {
        #expect(FixedFace.text.white > 0.9)
        #expect(FixedFace.text.alpha == 1)
    }
}
