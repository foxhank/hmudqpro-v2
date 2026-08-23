import XCTest
@testable import hmudqpro

/// 时间线纯函数测试（跨天不依赖打开 App 的核心逻辑）。
final class WidgetTimelineTests: XCTestCase {
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func date(_ s: String) -> Date { Self.fmt.date(from: s)! }
    private func at(_ day: String, _ hm: String) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: date(day))
        let p = hm.split(separator: ":")
        c.hour = Int(p[0]); c.minute = Int(p[1])
        return Calendar.current.date(from: c)!
    }

    /// 学期：2026-08-31（周一）为第 1 周；周三两门课。
    private var courses: [Course] {
        [
            Course(kcmc: "系统解剖学", zc: "1", xq: "3", qsrq: "2026-09-02",
                   ps: "1", pe: "4", jxcdmc: "解剖楼301", jcdm: "01020304"),
            Course(kcmc: "生理学", zc: "1", xq: "3", qsrq: "2026-09-02",
                   ps: "5", pe: "6", jxcdmc: "主楼201", jcdm: "0506"),
        ]
    }

    private var calculator: SemesterCalculator {
        SemesterCalculator(courses: courses.map { .init(week: $0.week, startDate: date($0.qsrq)) })
    }

    func testFirstEntryIsNowAndAscending() {
        let now = date("2026-09-01")
        let entries = WidgetTimeline.entries(from: now, courses: courses, calculator: calculator)
        XCTAssertEqual(entries.first?.date, now)
        XCTAssertEqual(entries, entries.sorted { $0.date < $1.date })
        XCTAssertLessThanOrEqual(entries.count, WidgetTimeline.maxEntries)
        let days = Calendar.current.dateComponents([.day], from: now, to: entries.last!.date).day ?? 0
        XCTAssertGreaterThanOrEqual(days, 13, "时间线应覆盖至少 13 天")
    }

    func testDayPlanMatchesWeekAndWeekday() {
        let wed = WidgetTimeline.dayPlan(for: date("2026-09-02"), courses: courses, calculator: calculator)
        XCTAssertEqual(wed.courses.count, 2)
        XCTAssertEqual(wed.courses.first?.kcmc, "系统解剖学", "按大节升序")
        XCTAssertEqual(wed.weekNumber, 1)
        XCTAssertTrue(WidgetTimeline.dayPlan(for: date("2026-09-01"), courses: courses, calculator: calculator).courses.isEmpty,
                      "周二无课")
        XCTAssertTrue(WidgetTimeline.dayPlan(for: date("2026-09-09"), courses: courses, calculator: calculator).courses.isEmpty,
                      "zc=1 的课不出现在第 2 周")
        // 开学前（8-23 早于第 1 周周一 8-31）：不钳制成第 1 周，必须视为假期
        let vacation = WidgetTimeline.dayPlan(for: date("2026-08-23"), courses: courses, calculator: calculator)
        XCTAssertNil(vacation.weekNumber)
        XCTAssertTrue(vacation.courses.isEmpty, "假期不得显示第 1 周的课")
    }

    func testSwitchPointsAtCourseBoundariesAndMidnight() {
        let entries = WidgetTimeline.entries(from: date("2026-09-01"), courses: courses, calculator: calculator)
        let wedDates = entries.filter { Calendar.current.isDate($0.plan.date, inSameDayAs: date("2026-09-02")) }.map(\.date)
        XCTAssertTrue(wedDates.contains(at("2026-09-02", "8:00")))
        XCTAssertTrue(wedDates.contains(at("2026-09-02", "15:05")), "5-6 节 = 第 3 大节，15:05 结束")
        XCTAssertTrue(entries.contains { $0.date == at("2026-09-02", "0:00") }, "午夜跨天切换点")
    }

    func testPhaseProgression() {
        let wed = WidgetTimeline.dayPlan(for: date("2026-09-02"), courses: courses, calculator: calculator)
        XCTAssertEqual(WidgetTimeline.phase(of: courses[0], in: wed, at: at("2026-09-02", "10:00")), .active)
        XCTAssertEqual(WidgetTimeline.phase(of: courses[1], in: wed, at: at("2026-09-02", "10:00")), .upcoming)
        XCTAssertEqual(WidgetTimeline.phase(of: courses[0], in: wed, at: at("2026-09-02", "12:00")), .finished)
    }

    func testTomorrowPlan() {
        let entries = WidgetTimeline.entries(from: date("2026-09-01"), courses: courses, calculator: calculator)
        XCTAssertEqual(entries.first?.tomorrowPlan.courses.count, 2)
    }

    func testAcademicWeekdayMapping() {
        XCTAssertEqual(WidgetTimeline.academicWeekday(of: date("2026-09-02")), 3, "周三 = 3")
        XCTAssertEqual(WidgetTimeline.academicWeekday(of: date("2026-09-06")), 7, "周日 = 7")
    }
}
