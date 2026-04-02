import XCTest
@testable import argus

final class RiskEscapePolicyTests: XCTestCase {

    func testDeepRiskOffPolicy() {
        let policy = RiskEscapePolicy.from(aetherScore: 23)

        XCTAssertEqual(policy.mode, .deepRiskOff)
        XCTAssertTrue(policy.blockRiskyBuys)
        XCTAssertTrue(policy.forceSafeOnlyBuys)
        XCTAssertEqual(policy.minimumTrimPercent, RiskBudgetConfig.deepRiskOffTrimPercent)
    }

    func testRiskOffPolicy() {
        let policy = RiskEscapePolicy.from(aetherScore: 35)

        XCTAssertEqual(policy.mode, .riskOff)
        XCTAssertTrue(policy.blockRiskyBuys)
        XCTAssertTrue(policy.forceSafeOnlyBuys)
        XCTAssertEqual(policy.minimumTrimPercent, RiskBudgetConfig.riskOffTrimPercent)
    }

    func testNormalPolicy() {
        let policy = RiskEscapePolicy.from(aetherScore: 55)

        XCTAssertEqual(policy.mode, .normal)
        XCTAssertFalse(policy.blockRiskyBuys)
        XCTAssertFalse(policy.forceSafeOnlyBuys)
        XCTAssertEqual(policy.minimumTrimPercent, 0)
    }

    func testDynamicMaxRiskRByAetherScore() {
        XCTAssertEqual(RiskBudgetConfig.dynamicMaxRiskR(aetherScore: 23), 0.8, accuracy: 0.0001)
        XCTAssertEqual(RiskBudgetConfig.dynamicMaxRiskR(aetherScore: 35), 1.5, accuracy: 0.0001)
        XCTAssertEqual(RiskBudgetConfig.dynamicMaxRiskR(aetherScore: 55), 20.0, accuracy: 0.0001)
    }
}
