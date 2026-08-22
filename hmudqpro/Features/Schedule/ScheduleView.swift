import SwiftUI

/// 课表页：周次选择器 + 6 大节 × 7 天网格（对齐安卓端块式课表）。
/// 一节课默认占一个大节（2 小节，如 1-2、3-4）；连堂课跨多个大节连成一整块卡片。
struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @AppStorage("schedule.colorStyle") private var colorStyleRaw = CourseColorStyle.default.rawValue

    private var colorStyle: CourseColorStyle {
        CourseColorStyle(rawValue: colorStyleRaw) ?? .default
    }

    /// 大节时间（1-2 节起算，共 6 大节）。
    private let slotTimes = [
        "8:00", "9:55", "13:30", "15:25", "18:00", "19:35",
    ]
    private let weekdays: [(index: Int, key: LocalizedStringKey)] = [
        (1, "weekday.mon"), (2, "weekday.tue"), (3, "weekday.wed"),
        (4, "weekday.thu"), (5, "weekday.fri"), (6, "weekday.sat"), (7, "weekday.sun"),
    ]

    private let slotHeight: CGFloat = 88

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.courses.isEmpty && viewModel.isLoading {
                    ProgressView("schedule.loading")
                } else if viewModel.courses.isEmpty {
                    emptyState
                } else {
                    scheduleGrid
                }
            }
            .navigationTitle("schedule.title")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { weekSelector }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task { await viewModel.loadIfNeeded() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("schedule.empty.title").font(.headline)
            Text("schedule.empty.message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("schedule.refresh") { Task { await viewModel.refresh() } }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 周次选择

    private var weekSelector: some View {
        Menu {
            ForEach(1...SemesterCalculator.totalWeeks, id: \.self) { week in
                Button {
                    viewModel.selectedWeek = week
                } label: {
                    if week == viewModel.currentWeek {
                        Text(String(localized: "schedule.week.current \(week)"))
                    } else {
                        Text(String(localized: "schedule.week \(week)"))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(String(localized: "schedule.week \(viewModel.selectedWeek)"))
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
        }
    }

    // MARK: - 网格

    private var scheduleGrid: some View {
        let entries = viewModel.gridEntries(week: viewModel.selectedWeek)

        return ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 4) {
                // 左侧时间列
                VStack(spacing: 4) {
                    Text("").frame(height: 28)
                    ForEach(0..<Course.bigSlotsPerDay, id: \.self) { slot in
                        VStack(spacing: 2) {
                            Text("\(slot * 2 + 1)")
                                .font(.caption2.monospacedDigit())
                            Text(slotTimes[slot])
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: slotHeight - 4)
                    }
                }
                // 7 天列
                ForEach(weekdays, id: \.index) { day in
                    DayColumn(weekday: day.index, label: Text(day.key),
                              entries: entries[day.index] ?? [:],
                              colorStyle: colorStyle,
                              slotHeight: slotHeight)
                }
            }
            .padding(.horizontal, 6)
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .adaptiveGlass()
                    .padding(.bottom, 8)
            }
        }
        .refreshable { await viewModel.refresh() }
    }
}

/// 单日列：6 个大节格，跨块课程卡片纵向连成一块。
private struct DayColumn: View {
    let weekday: Int
    let label: Text
    let entries: [Int: ScheduleViewModel.GridEntry]
    let colorStyle: CourseColorStyle
    let slotHeight: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            label
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .foregroundStyle(weekday == 6 || weekday == 7 ? Color.red.opacity(0.8) : .primary)

            ZStack(alignment: .top) {
                // 空格背景（节界标线）
                VStack(spacing: 4) {
                    ForEach(0..<Course.bigSlotsPerDay, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary.opacity(0.25))
                            .frame(height: slotHeight - 4)
                    }
                }
                // 课程块（起始大节定位，跨度展开）
                VStack(spacing: 4) {
                    ForEach(0..<Course.bigSlotsPerDay, id: \.self) { slot in
                        if let entry = entries[slot] {
                            CourseCard(entry: entry, colorStyle: colorStyle,
                                       height: CGFloat(entry.span) * (slotHeight - 4)
                                               + CGFloat(entry.span - 1) * 4)
                            Spacer(minLength: 0)
                                .frame(height: 0)
                        } else {
                            Color.clear.frame(height: slotHeight - 4)
                        }
                    }
                }
            }
        }
    }
}

/// 课程卡片：课名 + 教室 + 教师（对齐安卓 CourseCard）。
private struct CourseCard: View {
    let entry: ScheduleViewModel.GridEntry
    let colorStyle: CourseColorStyle
    let height: CGFloat

    @State private var showDetail = false

    var body: some View {
        let palette = CoursePalette.color(for: entry.course.kcmc, style: colorStyle)

        Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.course.kcmc)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)
                if !entry.course.jxcdmc.isEmpty {
                    Text(entry.course.jxcdmc.replacingOccurrences(of: "哈尔滨医科大学大庆校区", with: ""))
                        .font(.system(size: 9))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .opacity(0.85)
                }
                if !entry.course.teaxms.isEmpty {
                    Text(entry.course.teaxms)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .opacity(0.75)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(4)
            .foregroundStyle(palette.text)
            .background(palette.background, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(height: height)
        .sheet(isPresented: $showDetail) {
            CourseDetailSheet(course: entry.course, palette: palette)
                .presentationDetents([.medium])
        }
    }
}

/// 课程详情（点卡片弹出）。
private struct CourseDetailSheet: View {
    let course: Course
    let palette: CoursePalette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("course.name", course.kcmc)
                    row("course.teacher", course.teaxms)
                    row("course.location", course.jxcdmc)
                    row("course.week", String(localized: "course.week.value \(course.zc)"))
                    if !course.jxhjmc.isEmpty { row("course.type", course.jxhjmc) }
                }
            }
            .navigationTitle(course.kcmc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func row(_ key: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).textSelection(.enabled)
        }
    }
}
