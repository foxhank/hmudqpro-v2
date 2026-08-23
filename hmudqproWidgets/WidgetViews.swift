import SwiftUI
import WidgetKit

// MARK: - 今日课表

struct TodayScheduleView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetTimeline.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header(plan: entry.plan, titleKey: "widget.today", compact: false)
            if entry.plan.courses.isEmpty {
                emptyView
            } else {
                ForEach(entry.plan.courses.prefix(rowLimit)) { course in
                    CourseRow(course: course, plan: entry.plan, at: entry.date)
                }
                // 小组件不支持滚动（WidgetKit 静态渲染），课多时截断 + 溢出提示
                if entry.plan.courses.count > rowLimit {
                    Text(String(format: NSLocalizedString("widget.moreCourses", comment: ""),
                                entry.plan.courses.count - rowLimit))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(2)
        .widgetBackground()
    }

    /// 留白给头部：小尺寸 4 条，中尺寸 5 条。
    private var rowLimit: Int { family == .systemSmall ? 4 : 5 }

    private var emptyView: some View {
        let key = entry.plan.weekNumber == nil ? "widget.vacation" : "widget.noCourse"
        return Label(NSLocalizedString(key, comment: ""),
                     systemImage: entry.plan.weekNumber == nil ? "sun.max.fill" : "cup.and.saucer.fill")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

// MARK: - 今明两天

struct TodayTomorrowView: View {
    let entry: WidgetTimeline.Entry

    var body: some View {
        HStack(spacing: 8) {
            dayColumn(plan: entry.plan, titleKey: "widget.today")
            Divider()
            dayColumn(plan: entry.tomorrowPlan, titleKey: "widget.tomorrow")
        }
        .widgetBackground()
    }

    @ViewBuilder
    private func dayColumn(plan: WidgetTimeline.DayPlan, titleKey: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header(plan: plan, titleKey: titleKey, compact: true)
            if plan.courses.isEmpty {
                Spacer()
                Text(NSLocalizedString(plan.weekNumber == nil ? "widget.vacation" : "widget.noCourse", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(plan.courses.prefix(5)) { course in
                    CompactCourseRow(course: course)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 组件

private func header(plan: WidgetTimeline.DayPlan, titleKey: String, compact: Bool) -> some View {
    HStack {
        Text(NSLocalizedString(titleKey, comment: ""))
            .font(compact ? .caption.bold() : .subheadline.bold())
            .foregroundStyle(.secondary)
        Spacer()
        if let week = plan.weekNumber {
            Text(String(format: String(localized: "widget.weekLabel"), week))
                .font(compact ? .caption2 : .caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tint)
        }
    }
}

private struct CourseRow: View {
    let course: Course
    let plan: WidgetTimeline.DayPlan
    let at: Date

    var body: some View {
        let palette = CoursePalette.color(for: course.kcmc, style: .default)
        let phase = WidgetTimeline.phase(of: course, in: plan, at: at)
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(palette.background)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(course.kcmc)
                    .font(.caption.bold())
                    .foregroundStyle(phase == .finished ? .secondary : .primary)
                    .lineLimit(1)
                Text("\(course.displayTimeText) \(course.jxcdmc)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if phase == .active {
                Text(String(localized: "widget.inClass"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
            }
        }
        .opacity(phase == .finished ? 0.45 : 1)
    }
}

private struct CompactCourseRow: View {
    let course: Course

    var body: some View {
        let palette = CoursePalette.color(for: course.kcmc, style: .default)
        HStack(spacing: 4) {
            Circle().fill(palette.background).frame(width: 5, height: 5)
            Text(course.kcmc)
                .font(.caption2)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(course.displayTimeText)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - iOS 17 containerBackground 兼容（iOS 16 无需）

extension View {
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}
