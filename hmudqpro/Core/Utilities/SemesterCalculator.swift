import Foundation

/// 学期周次计算器（从 v1 WeekDateMapper 移植重构）。
///
/// 核心思路不变：用"第一堂课"（日期最早且有周次信息的课）反推第 1 周的周一，
/// 之后一切周次/学期边界都由此推导，不硬编码任何学期日期。
///
/// 与 v1 的区别：纯值类型、无副作用、不打印日志、输入用独立的
/// `CourseDateInfo` 而非完整 CourseInfo，方便单测与复用。
struct SemesterCalculator: Equatable {
    /// 参与推算的最小课程信息：周次（zc）+ 上课日期（qsrq，yyyy-MM-dd）。
    struct CourseDateInfo: Equatable {
        var week: Int?
        var startDate: Date?

        init(week: Int?, startDate: Date?) {
            self.week = week
            self.startDate = startDate
        }
    }

    /// 学期总周数：18 周上课 + 2 周考试。
    static let totalWeeks = 20

    /// 第 1 周的周一。nil 表示尚未建立映射（无有效课程数据）。
    let semesterStartMonday: Date?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - 构建

    /// 用课程列表推算学期起点（最早有日期的课程 → 所在周周一 → 回退 (week-1) 周）。
    init(courses: [CourseDateInfo]) {
        let dated = courses.compactMap { info -> (week: Int, date: Date)? in
            guard let week = info.week, let date = info.startDate else { return nil }
            return (week, date)
        }
        guard let first = dated.min(by: { $0.date < $1.date }) else {
            self.semesterStartMonday = nil
            return
        }

        let calendar = Calendar(identifier: .gregorian)
        // 该课所在周的周一（weekday: 1=周日…7=周六）
        let weekday = calendar.component(.weekday, from: first.date)
        let daysToMonday = weekday == 1 ? -6 : 2 - weekday
        guard let thisWeeksMonday = calendar.date(byAdding: .day, value: daysToMonday, to: first.date),
              let weekOne = calendar.date(byAdding: .weekOfYear, value: -(first.week - 1), to: thisWeeksMonday)
        else {
            self.semesterStartMonday = nil
            return
        }
        self.semesterStartMonday = calendar.startOfDay(for: weekOne)
    }

    var isInitialized: Bool { semesterStartMonday != nil }

    // MARK: - 周次查询

    /// 指定日期是第几周（从 1 开始；未初始化返回 nil）。
    func weekNumber(for date: Date) -> Int? {
        guard let start = semesterStartMonday else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let days = calendar.dateComponents([.day], from: start, to: date).day ?? 0
        return days / 7 + 1
    }

    /// 今天是第几周，钳到 1...totalWeeks（v1 getCurrentWeek 语义）。
    func currentWeek(today: Date = Date()) -> Int? {
        guard let raw = weekNumber(for: today) else { return nil }
        return min(max(1, raw), Self.totalWeeks)
    }

    // MARK: - 学期位置

    enum SemesterPosition: Equatable {
        case inSemester(currentWeek: Int)
        case beforeSemester
        case afterSemester
    }

    /// 今天相对学期的位置（学期边界：第 1 周周一 ～ 第 20 周周日）。
    func position(today: Date = Date()) -> SemesterPosition {
        guard let start = semesterStartMonday else { return .beforeSemester }
        let calendar = Calendar(identifier: .gregorian)
        guard let end = calendar.date(byAdding: .day, value: Self.totalWeeks * 7 - 1, to: start) else {
            return .beforeSemester
        }
        if today < start { return .beforeSemester }
        if today > end { return .afterSemester }
        return .inSemester(currentWeek: min(max(1, weekNumber(for: today) ?? 1), Self.totalWeeks))
    }

    /// 学期最后一天（第 20 周周日）。
    func semesterEndDate() -> Date? {
        semesterStartMonday.map { start in
            Calendar(identifier: .gregorian).date(byAdding: .day, value: Self.totalWeeks * 7 - 1, to: start)!
        }
    }

    /// 距开学还有几天（开学后为 0）。
    func daysBeforeSemesterStart(today: Date = Date()) -> Int {
        guard let start = semesterStartMonday else { return 0 }
        let calendar = Calendar(identifier: .gregorian)
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: today),
                                           to: calendar.startOfDay(for: start)).day ?? 0
        return max(0, diff)
    }

    /// 指定周的周一～周日（yyyy-MM-dd）。
    func weekDateRange(for week: Int) -> (start: String, end: String)? {
        guard let start = semesterStartMonday, week >= 1 else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        guard let weekStart = calendar.date(byAdding: .weekOfYear, value: week - 1, to: start),
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return nil }
        return (Self.dayFormatter.string(from: weekStart), Self.dayFormatter.string(from: weekEnd))
    }
}
