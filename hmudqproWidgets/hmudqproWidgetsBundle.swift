import WidgetKit
import SwiftUI

/// 小组件入口：今日课表 + 今明两天，数据全部来自 App Group 共享的 ScheduleStore。
@main
struct hmudqproWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayScheduleWidget()
        TodayTomorrowScheduleWidget()
    }
}

/// 共享数据加载 + 时间线组装（Provider 公共部分）。
enum WidgetDataSource {
    static func makeEntries(now: Date = Date()) -> [WidgetTimeline.Entry] {
        let courses = ScheduleStore.shared?.load() ?? []
        let calculator = SemesterCalculator(courses: courses.map {
            .init(week: $0.week, startDate: Self.date($0.qsrq))
        })
        return WidgetTimeline.entries(from: now, courses: courses, calculator: calculator)
    }

    static func date(_ yyyyMMdd: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: yyyyMMdd)
    }
}

extension WidgetTimeline.Entry: TimelineEntry {}

/// 「今日课表」：小/中尺寸，当天课程按节次推进高亮。
struct TodayScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayScheduleWidget", provider: ScheduleProvider()) { entry in
            TodayScheduleView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.today.name"))
        .description(String(localized: "widget.today.desc"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// 「今明两天」：中尺寸双栏。
struct TodayTomorrowScheduleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayTomorrowScheduleWidget", provider: ScheduleProvider()) { entry in
            TodayTomorrowView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.todayTomorrow.name"))
        .description(String(localized: "widget.todayTomorrow.desc"))
        .supportedFamilies([.systemMedium])
    }
}

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetTimeline.Entry {
        WidgetDataSource.makeEntries().first
            ?? .init(date: Date(), plan: .init(date: Date(), weekNumber: nil, courses: []), tomorrowPlan: .init(date: Date(), weekNumber: nil, courses: []))
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetTimeline.Entry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetTimeline.Entry>) -> Void) {
        let entries = WidgetDataSource.makeEntries()
        // 时间线耗尽后让系统自动来续（数据在本地，离线也能重算——这是跨天不依赖打开 App 的关键）
        let policy: TimelineReloadPolicy = entries.last.map { .after($0.date) } ?? .after(Date().addingTimeInterval(3600))
        completion(Timeline(entries: entries, policy: policy))
    }
}
