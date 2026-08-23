import Foundation

/// 小组件时间线（纯函数，主 App 与 Widget 共编，单测友好）。
///
/// 核心策略：一次性预生成未来 `horizonDays` 天的 entries，每个 entry 自带当天
/// 课程快照，跨天/跨节次切换由 WidgetKit 按时间免费完成——不依赖系统刷新预算，
/// 用户连续多天不打开 App 也能在午夜准点切到第二天的课。
enum WidgetTimeline {
    /// 预生成天数：14 天 × 每天最多十几个切换点，总量控制在 ~100 条安全线内。
    static let horizonDays = 14
    /// 社区实测时间线超过 ~100 条会静默失败。
    static let maxEntries = 100

    /// 一天的展示快照。
    struct DayPlan: Equatable {
        let date: Date            // 当天 00:00
        let weekNumber: Int?      // 学期第几周（nil = 学期外/未知）
        let courses: [Course]     // 当天课程，按大节升序
    }

    /// 一个切换点。date 之后小组件就显示这份快照（含明天，供双栏组件使用）。
    struct Entry: Equatable {
        let date: Date
        let plan: DayPlan
        let tomorrowPlan: DayPlan
    }

    private static let calendar = Calendar(identifier: .gregorian)

    // MARK: - 当天课程

    /// 教务 xq（1=周一…7=周日）← Calendar.weekday（1=周日…7=周六）。
    static func academicWeekday(of date: Date) -> Int {
        ((calendar.component(.weekday, from: date) + 5) % 7) + 1
    }

    /// 某天的课程：周次 + 星期双匹配（教务一行 = 某周某天一节课）。
    static func dayPlan(for date: Date, courses: [Course], calculator: SemesterCalculator) -> DayPlan {
        let week = calculator.weekNumber(for: date)
        let weekday = academicWeekday(of: date)
        let dayCourses = courses
            .filter { $0.week == week && $0.weekday == weekday }
            .sorted { ($0.firstBigSlot ?? .max) < ($1.firstBigSlot ?? .max) }
        return DayPlan(date: calendar.startOfDay(for: date),
                       weekNumber: week.map { min(max($0, 1), SemesterCalculator.totalWeeks) },
                       courses: dayCourses)
    }

    // MARK: - 时间线生成

    /// 生成未来 `horizonDays` 天的切换点：
    /// 每天以午夜（今天以 now）为起点，之后在每节课的起止时刻各切一次，
    /// 供视图做「进行中/已结束」的高亮推进。严格升序，总量封顶 `maxEntries`。
    static func entries(from now: Date = Date(), courses: [Course],
                        calculator: SemesterCalculator) -> [Entry] {
        var result: [Entry] = []
        let today = calendar.startOfDay(for: now)

        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: offset + 1, to: today) else { break }
            let plan = dayPlan(for: day, courses: courses, calculator: calculator)
            let tomorrowPlan = dayPlan(for: nextDay, courses: courses, calculator: calculator)

            var switchPoints: Set<Date> = [offset == 0 ? now : day]
            for course in plan.courses {
                if let first = course.firstBigSlot, let last = course.bigSlotIndices.last,
                   first < Course.slotTimeRanges.count, last < Course.slotTimeRanges.count {
                    if let start = slotDate(day, Course.slotTimeRanges[first].0),
                       let end = slotDate(day, Course.slotTimeRanges[last].1) {
                        switchPoints.insert(start)
                        switchPoints.insert(end)
                    }
                }
            }
            // 首条必须是 now（否则小组件到下一个切换点前无内容可显示）
            if offset == 0 {
                result.append(Entry(date: now, plan: plan, tomorrowPlan: tomorrowPlan))
                switchPoints.remove(now)
            }
            result += switchPoints
                .filter { $0 > now }   // 今天的已过切换点丢弃
                .sorted()
                .map { Entry(date: $0, plan: plan, tomorrowPlan: tomorrowPlan) }

            if result.count >= maxEntries { break }
        }
        return Array(result.prefix(maxEntries))
    }

    /// "8:00" + 当天 → 具体时刻。
    private static func slotDate(_ day: Date, _ time: String) -> Date? {
        let parts = time.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = h
        comps.minute = m
        return calendar.date(from: comps)
    }

    // MARK: - 视图辅助（高亮判定也做成纯函数，视图不做日期运算）

    /// entry 时刻该课的状态。
    enum CoursePhase { case upcoming, active, finished }

    static func phase(of course: Course, in plan: DayPlan, at moment: Date) -> CoursePhase {
        guard let first = course.firstBigSlot, let last = course.bigSlotIndices.last,
              first < Course.slotTimeRanges.count, last < Course.slotTimeRanges.count,
              let start = slotDate(plan.date, Course.slotTimeRanges[first].0),
              let end = slotDate(plan.date, Course.slotTimeRanges[last].1) else { return .upcoming }
        if moment < start { return .upcoming }
        if moment >= end { return .finished }
        return .active
    }
}
