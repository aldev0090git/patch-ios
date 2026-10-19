import SwiftUI
import Testing
@testable import Patch

@Suite("Reduce Motion")
struct MotionTests {
    @Test("Normally the view gets the animation it asked for")
    func passesThroughWhenMotionIsFine() {
        #expect(Motion.animation(.snappy, reduceMotion: false) == .snappy)
        #expect(Motion.animation(.easeOut(duration: 0.4), reduceMotion: false)
            == .easeOut(duration: 0.4))
    }

    @Test("Reduced means a short flat fade, never a spring")
    func springsAreReplaced() {
        // A spring overshoots, which is movement with extra steps. Whatever
        // the view asked for, the reduced answer is the same flat curve.
        let reduced = Motion.animation(.snappy, reduceMotion: true)
        #expect(reduced == .easeInOut(duration: Motion.reducedDuration))
        #expect(reduced != .snappy)
        #expect(Motion.animation(.bouncy, reduceMotion: true) == reduced)
        #expect(Motion.animation(.smooth(duration: 0.7), reduceMotion: true) == reduced)
    }

    @Test("Reduced is not instant — something still has to say it changed")
    func feedbackSurvives() {
        // `nil` would be an instant jump, which leaves the user unsure the tap
        // registered. The setting asks for less movement, not less feedback.
        #expect(Motion.reducedDuration > 0)
    }
}
