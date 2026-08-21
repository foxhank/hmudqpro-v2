import SwiftUI

/// 课表页：周次选择器 + 周视图网格。
/// 用原生 ScrollView + LazyVGrid 布局，不自绘。
struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()

    private let weekdays: [(index: Int, key: LocalizedStringKey)] = [
        (1, "weekday.mon"), (2, "weekday.tue"), (3, "weekday.wed"),
        (4, "weekday.thu"), (5, "weekday.fri"), (6, "weekday.sat"), (7, "weekday.sun"),
    ]
    private let totalSlots = 12

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.courses.isEmpty && viewModel.isLoading {
                    ProgressView("schedule.loading")
                } else if viewModel.courses.isEmpty {
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
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 4) {
                // 左侧节次列
                VStack(spacing: 4) {
                    Text("").frame(height: 28)
                    ForEach(1...totalSlots, id: \.self) { slot in
                        Text("\(slot)")
                            .font(.caption2.monospacedDigit())
                            .frame(width: 22, height: cellHeight(slot) - 4)
                            .foregroundStyle(.secondary)
                    }
                }
                // 7 天列
                ForEach(weekdays, id: \.index) { day in
                    DayColumn(viewModel: viewModel, weekday: day.index, week: viewModel.selectedWeek,
                              label: Text(day.key), totalSlots: totalSlots)
                }
            }
            .padding(.horizontal, 8)
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: .capsule)
                    .padding(.bottom, 8)
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    private func cellHeight(_ slot: Int) -> CGFloat { 52 }
}

/// 单日列：竖排节次格。
private struct DayColumn: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let weekday: Int
    let week: Int
    let label: Text
    let totalSlots: Int

    var body: some View {
        VStack(spacing: 4) {
            label
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .foregroundStyle(weekday == 6 || weekday == 7 ? Color.red.opacity(0.8) : .primary)
            ForEach(1...totalSlots, id: \.self) { slot in
                CourseCell(courses: viewModel.courses(weekday: weekday, slot: slot, inWeek: week),
                           isStart: viewModel.courses(weekday: weekday, slot: slot, inWeek: week)
                               .contains { $0.startSlot == slot })
                    .frame(height: 48)
            }
        }
    }
}

/// 单个课格：只在该课起始节显示完整卡片，跨节的后续节显示延续色条。
private struct CourseCell: View {
    let courses: [Course]
    let isStart: Bool

    var body: some View {
        if courses.isEmpty {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.3))
        } else if isStart {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(courses) { course in
                    Text(course.kcmc)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                    if !course.jxcdmc.isEmpty {
                        Text(course.jxcdmc)
                            .font(.system(size: 9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(4)
            .background(Color(hexString: courses.first?.bgcolor ?? "").opacity(0.25), in: .rect(cornerRadius: 8))
            .overlay(alignment: .topLeading) { }
        } else {
            // 跨节延续：显示细色条
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hexString: courses.first?.bgcolor ?? "").opacity(0.15))
        }
    }
}

extension Color {
    /// 教务 bgcolor 字段（hex 如 "#FFCC99"，也可能为空）。
    init(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let rgb = UInt64(s, radix: 16) else {
            self = .blue.opacity(0.15) // 无色课程给个默认淡蓝
            return
        }
        self = Color(red: Double((rgb >> 16) & 0xFF) / 255,
                     green: Double((rgb >> 8) & 0xFF) / 255,
                     blue: Double(rgb & 0xFF) / 255)
    }
}
