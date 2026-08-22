import SwiftUI

/// 课表页：标题置顶，下行是周切换 + 设置入口；主体为 6 大节 × 7 天网格（对齐安卓端块式课表）。
/// 一节课默认占一个大节（2 小节，如 1-2、3-4）；连堂课跨多个大节连成一整块卡片。
struct ScheduleView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @AppStorage("schedule.colorStyle") private var colorStyleRaw = CourseColorStyle.default.rawValue
    @AppStorage("schedule.fontSize") private var fontSize = 11.0
    @AppStorage("schedule.backgroundVersion") private var backgroundVersion = 0

    @State private var showSettings = false
    @State private var refreshTrigger = 0
    /// 跟手滑动的水平偏移。
    @State private var dragOffset: CGFloat = 0

    private var colorStyle: CourseColorStyle {
        CourseColorStyle(rawValue: colorStyleRaw) ?? .default
    }

    /// 大节起止时间（共 6 大节）。
    private let slotStartTimes = ["8:00", "9:55", "13:30", "15:25", "18:00", "19:35"]
    private let slotEndTimes = ["9:35", "11:30", "15:05", "17:00", "19:30", "21:10"]
    private let weekdays: [(index: Int, key: LocalizedStringKey)] = [
        (1, "weekday.mon"), (2, "weekday.tue"), (3, "weekday.wed"),
        (4, "weekday.thu"), (5, "weekday.fri"), (6, "weekday.sat"), (7, "weekday.sun"),
    ]

    private let slotHeight: CGFloat = 88
    private let gridSpacing: CGFloat = 4
    /// 超过此滑动距离才切周。
    private let swipeThreshold: CGFloat = 70

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerRow
                Divider()
                Group {
                    if viewModel.courses.isEmpty && viewModel.isLoading {
                        ProgressView("schedule.loading").frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.courses.isEmpty {
                        emptyState
                    } else {
                        scheduleGrid
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // 大标题置顶，上滑后系统自动收起为居中小字（标准导航行为）
            .navigationTitle("schedule.title")
            .task { await viewModel.loadIfNeeded() }
            .onChange(of: refreshTrigger) { _ in
                Task { await viewModel.refresh() }
            }
            .sheet(isPresented: $showSettings) {
                ScheduleSettingsSheet(refreshTrigger: $refreshTrigger)
            }
        }
    }

    // MARK: - 标题下的操作行：← 第x周 → + 设置

    private var headerRow: some View {
        HStack {
            // 左侧占位与右侧齿轮对称，保证周次居中
            Image(systemName: "gearshape").opacity(0)
            Spacer()
            weekSwitcher
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// 居中的周次切换：← 第 x 周 →，点箭头切周。
    private var weekSwitcher: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.changeWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.selectedWeek <= 1)
            .foregroundStyle(viewModel.selectedWeek <= 1 ? .tertiary : .primary)

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
                Text(String(localized: "schedule.week \(viewModel.selectedWeek)"))
                    .font(.headline)
            }

            Button {
                viewModel.changeWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.selectedWeek >= SemesterCalculator.totalWeeks)
            .foregroundStyle(viewModel.selectedWeek >= SemesterCalculator.totalWeeks ? .tertiary : .primary)
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

    // MARK: - 网格

    private var scheduleGrid: some View {
        let entries = viewModel.gridEntries(week: viewModel.selectedWeek)
        let background = ScheduleBackground.load()
        let weekDates = viewModel.weekDates(viewModel.selectedWeek)
        let today = Date()

        return ScrollView(.vertical) {
            HStack(alignment: .top, spacing: gridSpacing) {
                // 左侧时间列：节次对 + 起止时间（7-8 / 15:25 / - / 17:00）
                VStack(spacing: gridSpacing) {
                    Text("").frame(height: 34)
                    ForEach(0..<Course.bigSlotsPerDay, id: \.self) { slot in
                        VStack(spacing: 1) {
                            Text("\(slot * 2 + 1)-\(slot * 2 + 2)")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                            Text(slotStartTimes[slot])
                                .font(.system(size: 9).monospacedDigit())
                            Text("-")
                                .font(.system(size: 9))
                            Text(slotEndTimes[slot])
                                .font(.system(size: 9).monospacedDigit())
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: slotHeight - gridSpacing)
                    }
                }
                // 7 天列（表头带日期，如 8.30 四）
                ForEach(weekdays, id: \.index) { day in
                    DayColumn(weekday: day.index, label: Text(day.key),
                              date: weekDates[day.index - 1],
                              isToday: weekDates[day.index - 1].map { Calendar.current.isDate($0, inSameDayAs: today) } ?? false,
                              entries: entries[day.index] ?? [:],
                              colorStyle: colorStyle,
                              fontSize: fontSize,
                              slotHeight: slotHeight,
                              gridSpacing: gridSpacing)
                }
            }
            .padding(.horizontal, 4)
            // 跟手：滑动时网格随手平移并渐隐，松手回弹/切周
            .offset(x: dragOffset)
            .opacity(1 - min(abs(dragOffset) / 600.0, 0.35))
            .animation(.interactiveSpring(), value: dragOffset)
        }
        .background {
            // 用户设置的背景图（30% 透明度衬底，对齐安卓）
            if let background {
                Image(uiImage: background)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.3)
                    .id(backgroundVersion) // 背景更换后强制刷新
            }
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
        // 左右滑动切周（与纵向滚动共存：位移明显偏向水平才接管）
        .simultaneousGesture(swipeGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // 垂直滚动优先；只有横向占主导时才跟手
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    if dragOffset != 0 { dragOffset = 0 }
                    return
                }
                let width = value.translation.width
                // 边界橡皮筋：第 1 周不能继续右滑、第 20 周不能继续左滑
                if (viewModel.selectedWeek <= 1 && width > 0)
                    || (viewModel.selectedWeek >= SemesterCalculator.totalWeeks && width < 0) {
                    dragOffset = width / 6
                } else {
                    dragOffset = width
                }
            }
            .onEnded { value in
                let width = value.translation.width
                // 甩动速度足够时降低阈值，更跟手
                let velocityBonus: CGFloat = abs(value.velocity.width) > 600 ? 25 : 0
                let delta: Int
                if width < -(swipeThreshold - velocityBonus) { delta = 1 }
                else if width > (swipeThreshold - velocityBonus) { delta = -1 }
                else { delta = 0 }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    viewModel.changeWeek(by: delta)
                    dragOffset = 0
                }
            }
    }
}

/// 单日列：表头（日期+星期）+ 6 个大节格，课程块与背景格严格对齐。
private struct DayColumn: View {
    let weekday: Int
    let label: Text
    let date: Date?
    let isToday: Bool
    let entries: [Int: ScheduleViewModel.GridEntry]
    let colorStyle: CourseColorStyle
    let fontSize: Double
    let slotHeight: CGFloat
    let gridSpacing: CGFloat

    private var dateText: String? {
        guard let date else { return nil }
        let comps = Calendar.current.dateComponents([.month, .day], from: date)
        return "\(comps.month ?? 0).\(comps.day ?? 0)"
    }

    var body: some View {
        VStack(spacing: gridSpacing) {
            VStack(spacing: 1) {
                Text(dateText ?? "")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                label
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(isToday ? Color.accentColor.opacity(0.15) : Color.clear, in: .rect(cornerRadius: 6))

            ZStack(alignment: .top) {
                // 空格背景（节界标线）
                VStack(spacing: gridSpacing) {
                    ForEach(0..<Course.bigSlotsPerDay, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary.opacity(0.25))
                            .frame(height: slotHeight - gridSpacing)
                    }
                }
                // 课程块：与背景格逐格对齐；跨块高度 = span 格 + 中间间隔
                VStack(spacing: gridSpacing) {
                    ForEach(0..<Course.bigSlotsPerDay, id: \.self) { slot in
                        if let entry = entries[slot] {
                            CourseCard(entry: entry, colorStyle: colorStyle, fontSize: fontSize,
                                       height: CGFloat(entry.span) * (slotHeight - gridSpacing)
                                               + CGFloat(entry.span - 1) * gridSpacing)
                        } else {
                            // 与背景格等高的占位，保证后续课程对齐
                            Color.clear.frame(height: slotHeight - gridSpacing)
                        }
                    }
                }
            }
        }
    }

    private var textColor: Color {
        if isToday { return .accentColor }
        if weekday == 6 || weekday == 7 { return .red.opacity(0.8) }
        return .primary
    }
}

/// 课程卡片：课名 + 教室 + 教师（对齐安卓 CourseCard）。
private struct CourseCard: View {
    let entry: ScheduleViewModel.GridEntry
    let colorStyle: CourseColorStyle
    let fontSize: Double
    let height: CGFloat

    @State private var showDetail = false

    var body: some View {
        let palette = CoursePalette.color(for: entry.course.kcmc, style: colorStyle)

        Button {
            showDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.course.kcmc)
                    .font(.system(size: fontSize, weight: .semibold))
                    .lineLimit(4)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)
                if !entry.course.jxcdmc.isEmpty {
                    Text(entry.course.jxcdmc.replacingOccurrences(of: "哈尔滨医科大学大庆校区", with: ""))
                        .font(.system(size: max(8, fontSize - 2)))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .opacity(0.85)
                }
                if !entry.course.teaxms.isEmpty {
                    Text(entry.course.teaxms)
                        .font(.system(size: max(8, fontSize - 2)))
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
