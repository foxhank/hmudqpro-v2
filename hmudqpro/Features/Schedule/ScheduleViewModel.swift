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

    /// 指定周的课程，按 (星期, 节次) 可直接查格。
    func courses(inWeek week: Int) -> [Course] {
        courses.filter { $0.week == week && $0.weekday != nil && $0.startSlot != nil }
    }

    /// 某天某节的课程（同一格可能多门，返回全部）。
    func courses(weekday: Int, slot: Int, inWeek week: Int) -> [Course] {
        courses(inWeek: week).filter {
            $0.weekday == weekday && ($0.startSlot ?? 0) <= slot && slot <= ($0.endSlot ?? 0)
        }
    }

    func weekDateRange(_ week: Int) -> (start: String, end: String)? {
        calculator?.weekDateRange(for: week)
    }

    private static func date(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: s)
    }
}
