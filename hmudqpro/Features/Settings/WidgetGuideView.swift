import SwiftUI

/// 小组件添加引导：App 内实时预览（复用真实课表数据）+ 添加步骤。
/// iOS 不支持像鸿蒙那样半屏预览一键添加，只能引导用户长按桌面手动添加。
struct WidgetGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 预览：用真实缓存课表渲染两款小组件的样子
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "widget.guide.preview"))
                        .font(.subheadline.bold()).foregroundStyle(.secondary)
                    WidgetPreviewSmall()
                        .frame(width: 158, height: 158)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    WidgetPreviewMedium()
                        .frame(height: 148)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "widget.guide.steps"))
                        .font(.subheadline.bold()).foregroundStyle(.secondary)
                    GuideStep(number: 1, text: String(localized: "widget.guide.step1"))
                    GuideStep(number: 2, text: String(localized: "widget.guide.step2"))
                    GuideStep(number: 3, text: String(localized: "widget.guide.step3"))
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "settings.addWidget"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GuideStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.tint))
            Text(text).font(.subheadline)
        }
    }
}

// MARK: - 预览（复用 Shared 层真实数据与配色，所见即所得）

private struct WidgetPreviewSmall: View {
    var body: some View {
        let plan = previewPlan(dayOffset: 0)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(localized: "widget.today")).font(.subheadline.bold()).foregroundStyle(.secondary)
                Spacer()
                if let week = plan.weekNumber {
                    Text(String(format: String(localized: "widget.weekLabel"), week))
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.tint)
                }
            }
            if plan.courses.isEmpty {
                Label(String(localized: "widget.noCourse"), systemImage: "cup.and.saucer.fill")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(plan.courses.prefix(4)) { course in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(CoursePalette.color(for: course.kcmc, style: .default).background)
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(course.kcmc).font(.caption.bold()).lineLimit(1)
                            Text("\(course.displayTimeText) \(course.jxcdmc)").font(.caption2)
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
    }
}

private struct WidgetPreviewMedium: View {
    var body: some View {
        let today = previewPlan(dayOffset: 0)
        let tomorrow = previewPlan(dayOffset: 1)
        HStack(spacing: 10) {
            previewColumn(plan: today, titleKey: "widget.today")
            Divider()
            previewColumn(plan: tomorrow, titleKey: "widget.tomorrow")
        }
        .padding(12)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func previewColumn(plan: WidgetTimeline.DayPlan, titleKey: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(.caption.bold()).foregroundStyle(.secondary)
            if plan.weekNumber != nil {
                Text(String(format: String(localized: "widget.weekLabel"), plan.weekNumber!))
                    .font(.caption2).fontWeight(.semibold).foregroundStyle(.tint)
            }
            if plan.courses.isEmpty {
                Spacer()
                Text(plan.weekNumber == nil
                     ? String(localized: "widget.vacation")
                     : String(localized: "widget.noCourse"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(plan.courses.prefix(5)) { course in
                    HStack(spacing: 4) {
                        Circle().fill(CoursePalette.color(for: course.kcmc, style: .default).background)
                            .frame(width: 5, height: 5)
                        Text(course.kcmc).font(.caption2).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(course.displayTimeText).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 读 App Group 缓存的真实课表算预览数据。
private func previewPlan(dayOffset: Int) -> WidgetTimeline.DayPlan {
    let courses = ScheduleStore.shared?.load() ?? []
    let calculator = SemesterCalculator(courses: courses.map {
        .init(week: $0.week, startDate: WidgetGuideView.date($0.qsrq))
    })
    let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    return WidgetTimeline.dayPlan(for: day, courses: courses, calculator: calculator)
}

extension WidgetGuideView {
    static func date(_ yyyyMMdd: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: yyyyMMdd)
    }
}

#Preview {
    NavigationStack { WidgetGuideView() }
}
