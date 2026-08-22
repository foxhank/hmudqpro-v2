import Foundation
import SwiftUI

/// 课表页 ViewModel：加载缓存 → 拉取最新 → 计算当前周。
@MainActor
final class ScheduleViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var selectedWeek: Int = 1
    @Published var currentWeek: Int = 1
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: ScheduleService
    private var calculator: SemesterCalculator?

    init(service: ScheduleService = ScheduleService()) {
        self.service = service
    }

    /// 首次进入：显示缓存，同时后台刷新。
    func loadIfNeeded() async {
        guard courses.isEmpty else { return }
        let cached = ScheduleStore.shared?.load() ?? []
        apply(cached)
        await refresh()
    }

    /// 强制从教务拉取。
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await service.fetchCourses()
            apply(fetched)
            ScheduleStore.shared?.save(fetched)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ courses: [Course]) {
        self.courses = courses
        let calc = SemesterCalculator(courses: courses.map { .init(week: $0.week, startDate: Self.date($0.qsrq)) })
        calculator = calc
        if let w = calc.currentWeek() {
            currentWeek = w
            if selectedWeek == 1 { selectedWeek = w } // 首次定位到本周
        }
    }

    /// 指定周的课，按大节块过滤（有有效星期和节次码的）。
    func courses(inWeek week: Int) -> [Course] {
        courses.filter { $0.week == week && $0.weekday != nil && !$0.bigSlotIndices.isEmpty }
    }

    /// 网格条目：起始大节 + 跨度（1-2 节 = 1 个大节；1-4 节 = 跨 2 个大节连成一块）。
    struct GridEntry: Identifiable, Equatable {
        let course: Course
        let slot: Int      // 起始大节 0...5
        let span: Int      // 占几个大节

        var id: String { course.id }
        static func == (lhs: GridEntry, rhs: GridEntry) -> Bool { lhs.id == rhs.id }
    }

    /// (星期, 大节) → 该格起始的课程块。同格冲突时后到的覆盖（与安卓一致）。
    func gridEntries(week: Int) -> [Int: [Int: GridEntry]] {
        var grid: [Int: [Int: GridEntry]] = [:]
        for course in courses(inWeek: week) {
            guard let weekday = course.weekday, let first = course.firstBigSlot else { continue }
            let entry = GridEntry(course: course, slot: first, span: course.bigSlotSpan)
            grid[weekday, default: [:]][first] = entry
        }
        return grid
    }

    /// 某天某大节的课程（同格多门时返回全部，供详情展示）。
    func courses(weekday: Int, slot: Int, inWeek week: Int) -> [Course] {
        courses(inWeek: week).filter {
            $0.weekday == weekday && $0.bigSlotIndices.contains(slot)
        }
    }

    func weekDateRange(_ week: Int) -> (start: String, end: String)? {
        calculator?.weekDateRange(for: week)
    }

    /// 指定周 7 天（周一~周日）的日期，用于表头显示（如 8.30）。
    func weekDates(_ week: Int) -> [Date?] {
        guard let start = calculator?.semesterStartMonday else { return Array(repeating: nil, count: 7) }
        let calendar = Calendar(identifier: .gregorian)
        return (0..<7).map { offset in
            calendar.date(byAdding: .day, value: offset, to: start
                          .addingTimeInterval(TimeInterval((week - 1) * 7 * 86400)))
        }
    }

    func changeWeek(by delta: Int) {
        let new = min(max(1, selectedWeek + delta), SemesterCalculator.totalWeeks)
        selectedWeek = new
    }

    private static func date(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: s)
    }
}
