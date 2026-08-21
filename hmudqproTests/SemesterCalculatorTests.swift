import XCTest
@testable import hmudqpro

/// SemesterCalculator 单测。日期全部显式构造，不依赖"今天"。
final class SemesterCalculatorTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)
    private var formatter: DateFormatter {
        SemesterCalculatorTests.df
    }
    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func date(_ s: String) -> Date { formatter.date(from: s)! }

    /// 2026-09-07 是周一。第 3 周的课 → 学期第 1 周周一 = 2026-08-24。
    private var calculator: SemesterCalculator {
        SemesterCalculator(courses: [
            .init(week: 3, startDate: date("2026-09-07")),
            .init(week: 5, startDate: date("2026-09-21")),
        ])
    }

    // MARK: - 构建

    func testInfersSemesterStart() {
        XCTAssertEqual(calculator.semesterStartMonday, date("2026-08-24"))
        XCTAssertTrue(calculator.isInitialized)
    }

    func testEmptyCoursesNotInitialized() {
        let c = SemesterCalculator(courses: [])
        XCTAssertFalse(c.isInitialized)
        XCTAssertNil(c.weekNumber(for: Date()))
        XCTAssertEqual(c.position(), .beforeSemester)
    }

    func testIgnoresInvalidEntries() {
        let c = SemesterCalculator(courses: [
            .init(week: nil, startDate: date("2026-09-01")),
            .init(week: 1, startDate: nil),
            .init(week: 1, startDate: date("2026-09-07")), // 周一第1周
        ])
        XCTAssertEqual(c.semesterStartMonday, date("2026-09-07"))
    }

    /// 周日的课：weekday=1，应回退 6 天到周一。
    func testSundayCourse() {
        let c = SemesterCalculator(courses: [.init(week: 1, startDate: date("2026-09-13"))]) // 周日
        XCTAssertEqual(c.semesterStartMonday, date("2026-09-07"))
    }

    // MARK: - 周次

    func testWeekNumber() {
        XCTAssertEqual(calculator.weekNumber(for: date("2026-08-24")), 1)  // 第1周周一
        XCTAssertEqual(calculator.weekNumber(for: date("2026-08-30")), 1)  // 第1周周日
        XCTAssertEqual(calculator.weekNumber(for: date("2026-08-31")), 2)  // 第2周周一
        XCTAssertEqual(calculator.weekNumber(for: date("2026-09-07")), 3)
    }

    func testCurrentWeekClamped() {
        XCTAssertEqual(calculator.currentWeek(today: date("2026-09-01")), 2)
        XCTAssertEqual(calculator.currentWeek(today: date("2027-01-01")), 19)   // 第19周
        XCTAssertEqual(calculator.currentWeek(today: date("2027-01-11")), 20)   // 第20周周一（最后一天附近）
        XCTAssertEqual(calculator.currentWeek(today: date("2027-06-01")), 20)   // 学期后钳到20
        XCTAssertEqual(calculator.currentWeek(today: date("2026-01-01")), 1)    // 学期前钳到1
    }

    // MARK: - 学期位置

    func testPositionBefore() {
        XCTAssertEqual(calculator.position(today: date("2026-08-23")), .beforeSemester)
    }

    func testPositionDuring() {
        XCTAssertEqual(calculator.position(today: date("2026-09-09")), .inSemester(currentWeek: 3))
        XCTAssertEqual(calculator.position(today: date("2026-08-24")), .inSemester(currentWeek: 1))
    }

    func testPositionAfter() {
        // 第20周周日 = 2026-08-24 + 139 天 = 2027-01-10
        XCTAssertEqual(calculator.semesterEndDate(), date("2027-01-10"))
        XCTAssertEqual(calculator.position(today: date("2027-01-11")), .afterSemester)
    }

    // MARK: - 倒计时与周范围

    func testDaysBeforeStart() {
        XCTAssertEqual(calculator.daysBeforeSemesterStart(today: date("2026-08-20")), 4)
        XCTAssertEqual(calculator.daysBeforeSemesterStart(today: date("2026-08-24")), 0)
        XCTAssertEqual(calculator.daysBeforeSemesterStart(today: date("2026-09-01")), 0) // 开学后为0
    }

    func testWeekDateRange() {
        let range = calculator.weekDateRange(for: 1)
        XCTAssertEqual(range?.start, "2026-08-24")
        XCTAssertEqual(range?.end, "2026-08-30")
        let week3 = calculator.weekDateRange(for: 3)
        XCTAssertEqual(week3?.start, "2026-09-07")
        XCTAssertEqual(week3?.end, "2026-09-13")
        XCTAssertNil(calculator.weekDateRange(for: 0))
    }
}
