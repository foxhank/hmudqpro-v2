import XCTest
@testable import hmudqpro

final class ScheduleParserTests: XCTestCase {
    func testParseJSON() throws {
        let json = """
        [{"kcmc":"系统解剖学","zc":"1","xq":"1","qsrq":"2026-09-07","ps":"1","pe":"2","teaxms":"张三","jxcdmc":"A101","jxbmc":"系解1班"},
         {"kcmc":"生理学","zc":"1","xq":"3","ps":"3","pe":"4","teaxms":"李四"}]
        """
        let courses = try ScheduleParser.parse(json)
        XCTAssertEqual(courses.count, 2)
        XCTAssertEqual(courses[0].kcmc, "系统解剖学")
        XCTAssertEqual(courses[0].week, 1)
        XCTAssertEqual(courses[0].weekday, 1)
        XCTAssertEqual(courses[0].bigSlotIndices, [0]) // ps=1 pe=2 → 大节0
        XCTAssertEqual(courses[1].teaxms, "李四")
    }

    func testParseHTMLThrows() {
        XCTAssertThrowsError(try ScheduleParser.parse("<html><body>请登录</body></html>")) { error in
            XCTAssertEqual(error as? ScheduleParser.ParseError, .htmlResponse)
        }
    }

    func testParseEmptyThrows() {
        XCTAssertThrowsError(try ScheduleParser.parse("[]"))
        XCTAssertThrowsError(try ScheduleParser.parse(""))
    }

    func testMissingFieldsDefaultEmpty() throws {
        let json = "[{\"kcmc\":\"药理学\",\"zc\":\"2\",\"xq\":\"5\"}]"
        let courses = try ScheduleParser.parse(json)
        XCTAssertEqual(courses[0].teaxms, "")
        XCTAssertEqual(courses[0].jxcdmc, "")
    }

    func testSemesterRange() {
        var comps = DateComponents(); comps.year = 2026; comps.month = 9; comps.day = 1
        let autumn = ScheduleParser.currentSemesterRange(today: Calendar.current.date(from: comps)!)
        XCTAssertEqual(autumn.start, "2026-08-15")
        XCTAssertEqual(autumn.end, "2027-01-20")

        comps.year = 2027; comps.month = 1
        let january = ScheduleParser.currentSemesterRange(today: Calendar.current.date(from: comps)!)
        XCTAssertEqual(january.start, "2026-08-15")

        comps.year = 2027; comps.month = 4
        let spring = ScheduleParser.currentSemesterRange(today: Calendar.current.date(from: comps)!)
        XCTAssertEqual(spring.start, "2027-02-20")
        XCTAssertEqual(spring.end, "2027-06-30")
    }

    func testCourseCodingRoundTrip() throws {
        let course = Course(kcmc: "生物化学", zc: "3", xq: "2", ps: "5", pe: "8", teaxms: "王五")
        let data = try JSONEncoder().encode([course])
        let decoded = try JSONDecoder().decode([Course].self, from: data)
        XCTAssertEqual(decoded, [course])
    }

    // MARK: - 大节块识别（对齐安卓 getAllTimeSlotIndices）

    func testBigSlotsFromJcdm() {
        // 单大节：1-2 节
        XCTAssertEqual(Course(kcmc: "x", zc: "1", xq: "1", jcdm: "0102").bigSlotIndices, [0])
        // 3-4 节
        XCTAssertEqual(Course(kcmc: "x", zc: "1", xq: "1", jcdm: "0304").bigSlotIndices, [1])
        // 连堂 1-4 节：跨 2 个大节
        let c = Course(kcmc: "x", zc: "1", xq: "1", jcdm: "01020304")
        XCTAssertEqual(c.bigSlotIndices, [0, 1])
        XCTAssertEqual(c.bigSlotSpan, 2)
        // 非连续（1-2 + 5-6）
        let d = Course(kcmc: "x", zc: "1", xq: "1", jcdm: "01020506")
        XCTAssertEqual(d.bigSlotIndices, [0, 2])
        // 11-12 节 → 最后一个
        XCTAssertEqual(Course(kcmc: "x", zc: "1", xq: "1", jcdm: "1112").bigSlotIndices, [5])
        // 越界忽略（ps/pe 置空避免触发兜底）
        XCTAssertEqual(Course(kcmc: "x", zc: "1", xq: "1", ps: "", pe: "", jcdm: "1314").bigSlotIndices, [])
    }

    func testBigSlotsFallbackToPsPe() {
        // 无 jcdm：ps=1 pe=4 → 大节 0,1
        let c = Course(kcmc: "x", zc: "1", xq: "1", ps: "1", pe: "4")
        XCTAssertEqual(c.bigSlotIndices, [0, 1])
        // ps=3 pe=4 → 大节 1
        XCTAssertEqual(Course(kcmc: "x", zc: "1", xq: "1", ps: "3", pe: "4").bigSlotIndices, [1])
    }

    // MARK: - 配色（稳定 hash）

    func testPaletteStableAcrossCalls() {
        // 同名课同色；不同主题不同结果
        let a1 = CoursePalette.color(for: "系统解剖学", style: .default)
        let a2 = CoursePalette.color(for: "系统解剖学", style: .default)
        let b1 = CoursePalette.color(for: "生理学", style: .default)
        let bright = CoursePalette.color(for: "系统解剖学", style: .bright)
        XCTAssertEqual(a1.background.description, a2.background.description, "同名课两次取色应一致")
        XCTAssertNotEqual(a1.background.description, b1.background.description, "不同课颜色应大概率不同")
        XCTAssertNotEqual(a1.background.description, bright.background.description, "两套主题颜色应不同")
    }
}
