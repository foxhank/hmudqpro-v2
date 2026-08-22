import XCTest
@testable import hmudqpro

final class ScheduleStoreTests: XCTestCase {
    // 用随机 suite 隔离，避免污染共享缓存
    private var store: ScheduleStore!

    override func setUp() {
        super.setUp()
        store = ScheduleStore(suiteName: "test.\(UUID().uuidString)")
    }

    func testSaveLoadRoundTrip() {
        let courses = [
            Course(kcmc: "生理学", zc: "1", xq: "1", ps: "1", pe: "2", teaxms: "张三", jxcdmc: "A101"),
            Course(kcmc: "生化", zc: "2", xq: "3", ps: "3", pe: "4"),
        ]
        store.save(courses)
        XCTAssertEqual(store.load(), courses)
        XCTAssertNotNil(store.fetchedAt)
    }

    func testIsSameAsCache() {
        let courses = [Course(kcmc: "系解", zc: "1", xq: "1")]
        store.save(courses)
        XCTAssertTrue(store.isSameAsCache(courses))
        XCTAssertFalse(store.isSameAsCache([Course(kcmc: "系解", zc: "2", xq: "1")]))
    }

    func testEmptyLoad() {
        XCTAssertTrue(store.load().isEmpty)
        XCTAssertNil(store.fetchedAt)
    }

    func testEncodingDeterminism() throws {
        let courses = [Course(kcmc: "药理", zc: "3", xq: "5", ps: "1", pe: "4")]
        let enc: () throws -> Data = {
            let e = JSONEncoder()
            e.outputFormatting = [.sortedKeys]
            return try e.encode(courses)
        }
        let d1 = try enc()
        let d2 = try enc()
        XCTAssertEqual(d1, d2, "sortedKeys 编码同一数据应字节一致")
    }
}
