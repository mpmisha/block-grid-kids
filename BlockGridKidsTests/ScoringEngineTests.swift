import XCTest
@testable import BlockGridKids

final class ScoringEngineTests: XCTestCase {

    func testPlacementPointsMatchCellCount() {
        XCTAssertEqual(ScoringEngine.placementPoints(cellCount: 1), 1)
        XCTAssertEqual(ScoringEngine.placementPoints(cellCount: 9), 9)
    }

    func testLineClearPointsGrowQuadratically() {
        XCTAssertEqual(ScoringEngine.lineClearPoints(lineCount: 0), 0)
        XCTAssertEqual(ScoringEngine.lineClearPoints(lineCount: 1), 10)
        XCTAssertEqual(ScoringEngine.lineClearPoints(lineCount: 2), 40)
        XCTAssertEqual(ScoringEngine.lineClearPoints(lineCount: 3), 90)
    }

    func testStreakOnlyPaysAfterTheFirstClear() {
        XCTAssertEqual(ScoringEngine.streakPoints(streak: 1, didClear: true), 0)
        XCTAssertEqual(ScoringEngine.streakPoints(streak: 2, didClear: true), 5)
        XCTAssertEqual(ScoringEngine.streakPoints(streak: 4, didClear: true), 15)
    }

    func testNoStreakPointsWithoutAClear() {
        XCTAssertEqual(ScoringEngine.streakPoints(streak: 6, didClear: false), 0)
    }

    func testBreakdownTotals() {
        let breakdown = ScoringEngine.breakdown(cellCount: 4, lineCount: 2, streak: 3)
        XCTAssertEqual(breakdown.placementPoints, 4)
        XCTAssertEqual(breakdown.lineClearPoints, 40)
        XCTAssertEqual(breakdown.streakPoints, 10)
        XCTAssertEqual(breakdown.total, 54)
    }
}
