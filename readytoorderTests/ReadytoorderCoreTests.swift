import XCTest
@testable import readytoorder

final class ReadytoorderCoreTests: XCTestCase {
    func testOrderingDetailParamsClampsAndSplits() throws {
        var params = OrderingDetailParams()
        params.dinersText = "99"
        params.budgetText = "999999"
        params.spiceLevel = "hot"
        params.allergiesText = "花生, 海鲜; 芝麻"
        params.notes = "  少油少盐  "

        let payload = try XCTUnwrap(params.toBackendInput())
        XCTAssertEqual(payload.diners, 20)
        XCTAssertEqual(payload.budgetCNY, 50_000)
        XCTAssertEqual(payload.spiceLevel, "hot")
        XCTAssertEqual(payload.allergies, ["花生", "海鲜", "芝麻"])
        XCTAssertEqual(payload.notes, "少油少盐")
    }

    func testDishCategoryTagsDisplayValuesDeduplicates() {
        let tags = DishCategoryTags(
            cuisine: ["川菜", "川菜"],
            flavor: ["辣", "辣"],
            ingredient: ["鸡肉", "鸡肉"]
        )

        XCTAssertEqual(tags.displayValues, ["川菜", "辣", "鸡肉"])
    }
}
