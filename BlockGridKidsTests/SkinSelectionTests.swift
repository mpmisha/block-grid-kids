import XCTest
@testable import BlockGridKids

final class SkinSelectionTests: XCTestCase {

    func testIndicesAreClampedIntoTheCatalogRange() {
        let selection = SkinSelection(
            blockPalette: 9,
            surfacePalette: -1,
            blockStyle: 4,
            surfaceStyle: -6
        )
        let range = 0..<SkinSelection.optionCount
        XCTAssertTrue(range.contains(selection.blockPalette))
        XCTAssertTrue(range.contains(selection.surfacePalette))
        XCTAssertTrue(range.contains(selection.blockStyle))
        XCTAssertTrue(range.contains(selection.surfaceStyle))
    }

    func testNextAlwaysChangesAtLeastTwoAxes() {
        var current = SkinSelection.initial
        for _ in 0..<500 {
            let next = current.next()
            XCTAssertGreaterThanOrEqual(
                next.differenceCount(from: current), 2,
                "A level change must be clearly visible"
            )
            current = next
        }
    }

    func testNextEventuallyVisitsEveryOptionOnEveryAxis() {
        var blockPalettes: Set<Int> = []
        var surfacePalettes: Set<Int> = []
        var blockStyles: Set<Int> = []
        var surfaceStyles: Set<Int> = []

        var current = SkinSelection.initial
        for _ in 0..<400 {
            current = current.next()
            blockPalettes.insert(current.blockPalette)
            surfacePalettes.insert(current.surfacePalette)
            blockStyles.insert(current.blockStyle)
            surfaceStyles.insert(current.surfaceStyle)
        }

        XCTAssertEqual(blockPalettes.count, SkinSelection.optionCount)
        XCTAssertEqual(surfacePalettes.count, SkinSelection.optionCount)
        XCTAssertEqual(blockStyles.count, SkinSelection.optionCount)
        XCTAssertEqual(surfaceStyles.count, SkinSelection.optionCount)
    }

    func testDecodingToleratesMissingAndOutOfRangeFields() throws {
        let json = Data(#"{"blockPalette": 7}"#.utf8)
        let selection = try JSONDecoder().decode(SkinSelection.self, from: json)
        XCTAssertEqual(selection.blockPalette, 3)
        XCTAssertEqual(selection.surfacePalette, 0)
        XCTAssertEqual(selection.blockStyle, 0)
        XCTAssertEqual(selection.surfaceStyle, 0)
    }

    func testRoundTripsThroughJSON() throws {
        let original = SkinSelection(
            blockPalette: 2,
            surfacePalette: 3,
            blockStyle: 1,
            surfaceStyle: 2
        )
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(SkinSelection.self, from: data), original)
    }

    func testCatalogResolvesEveryPermutation() {
        for blockPalette in 0..<SkinSelection.optionCount {
            for surfacePalette in 0..<SkinSelection.optionCount {
                for blockStyle in 0..<SkinSelection.optionCount {
                    for surfaceStyle in 0..<SkinSelection.optionCount {
                        SkinCatalog.apply(SkinSelection(
                            blockPalette: blockPalette,
                            surfacePalette: surfacePalette,
                            blockStyle: blockStyle,
                            surfaceStyle: surfaceStyle
                        ))
                        XCTAssertEqual(SkinCatalog.blockPalette.colors.count, 8)
                        XCTAssertEqual(SkinCatalog.blockStyle.rawValue, blockStyle)
                        XCTAssertEqual(SkinCatalog.surfaceStyle.rawValue, surfaceStyle)
                        XCTAssertFalse(SkinCatalog.surfacePalette.name.isEmpty)
                    }
                }
            }
        }
        SkinCatalog.reset()
    }

    func testApplyReportsWhetherTheLookChanged() {
        SkinCatalog.reset()
        XCTAssertFalse(SkinCatalog.apply(.initial), "Re-applying the same skin is a no-op")

        let revisionBefore = SkinCatalog.revision
        XCTAssertTrue(SkinCatalog.apply(SkinSelection(
            blockPalette: 1, surfacePalette: 2, blockStyle: 3, surfaceStyle: 1
        )))
        XCTAssertGreaterThan(SkinCatalog.revision, revisionBefore)
        SkinCatalog.reset()
    }
}
