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
        XCTAssertEqual(courses[0].slotCount, 2)
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
}
