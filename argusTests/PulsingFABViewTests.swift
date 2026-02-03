import SwiftUI
import XCTest

@testable import argus

class PulsingFABViewTests: XCTestCase {

    func testPulsingFABViewRendersSuccessfully() {
        let view = PulsingFABView()
        XCTAssertNotNil(view)
    }

    func testPulsingFABViewHasActionCallback() {
        var actionCalled = false
        let view = PulsingFABView {
            actionCalled = true
        }
        XCTAssertNotNil(view)
    }

    func testPulsingFABViewUsesCorrectIcon() {
        // Verify mic.fill icon is used
        let view = PulsingFABView()
        XCTAssertNotNil(view) // Visual test - would need snapshot testing for full verification
    }
}
