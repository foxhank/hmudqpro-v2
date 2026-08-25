import SwiftUI
import PhotosUI

/// 课表设置面板（参照安卓 ScheduleSettingsDialog）：
/// 字体大小、背景图片、刷新课表、配色主题。
struct ScheduleSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("schedule.fontSize") private var fontSize = 12.0
    @AppStorage("schedule.colorStyle") private var colorStyleRaw = CourseColorStyle.default.rawValue
    @AppStorage("schedule.weekStartsSunday") private var weekStartsSunday = false
    @AppStorage("schedule.backgroundImmersive") private var backgroundImmersive = true
    @Binding var refreshTrigger: Int

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var hasBackground = ScheduleBackground.load() != nil
    @State private var isRefreshing = false
    /// 与 ScheduleView 共享：背景增删后 +1，触发主视图重新加载背景图
    @AppStorage("schedule.backgroundVersion") private var backgroundVersion = 0

    private let fontSizeRange: ClosedRange<Double> = 9...16
    private let defaultFontSize = 12.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // MARK: 字体大小
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("settings.fontSize")
                            Spacer()
                            Text("\(Int(fontSize))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            if fontSize != defaultFontSize {
                                Button("settings.fontSize.reset") {
                                    withAnimation { fontSize = defaultFontSize }
                                }
                                .font(.caption)
                            }
                        }
                        Slider(value: $fontSize, in: fontSizeRange, step: 1)
                    }

                    // MARK: 每周开始
                    Picker("settings.weekStart", selection: $weekStartsSunday) {
                        Text("settings.weekStart.monday").tag(false)
                        Text("settings.weekStart.sunday").tag(true)
                    }

                    // MARK: 配色主题
                    Picker("settings.colorStyle", selection: $colorStyleRaw) {
                        Text("settings.colorStyle.default").tag(CourseColorStyle.default.rawValue)
                        Text("settings.colorStyle.bright").tag(CourseColorStyle.bright.rawValue)
                    }

                    // MARK: 背景覆盖范围（只在设置了背景图时才有意义）
                    if hasBackground {
                        Picker("settings.background.scope", selection: $backgroundImmersive) {
                            Text("settings.background.scope.grid").tag(false)
                            Text("settings.background.scope.immersive").tag(true)
                        }
                    }

                    // MARK: 背景图片
                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        Label("settings.background.pick", systemImage: "photo")
                    }
                    if hasBackground {
                        Button(role: .destructive) {
                            ScheduleBackground.clear()
                            hasBackground = false
                            backgroundVersion += 1
                        } label: {
                            Label("settings.background.clear", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("settings.display")
                }

                Section {
                    Button {
                        refreshTrigger += 1
                        isRefreshing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isRefreshing = false }
                        dismiss()
                    } label: {
                        HStack {
                            Label("settings.refresh", systemImage: "arrow.clockwise")
                            Spacer()
                            if isRefreshing { ProgressView() }
                        }
                    }
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .onChange(of: photoPickerItem) { item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        ScheduleBackground.save(data)
                        hasBackground = true
                        backgroundVersion += 1
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
