import SwiftUI

/// 「我的」页（对齐安卓 SettingsScreen）：
/// 顶部用户卡片（姓名/学号/学院，点击看完整信息）+ 三组两行列表（左图标+标题+副标题）。
/// 调试模式入口保留：连续点击卡片里的姓名 5 次。
struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var showInfoSheet = false
    @State private var showScheduleSettings = false
    @State private var scheduleRefreshTrigger = 0
    @State private var showDebug = false
    @State private var showPasswordPrompt = false
    @State private var debugPassword = ""
    @State private var toast: String?

    // 检查更新
    @State private var checkingUpdate = false
    @State private var updateInfo: UpdateInfo?
    @State private var updateError: String?
    @State private var upToDate = false

    private var shareURL: URL {
        URL(string: "https://apps.apple.com/app/id\(APIConfig.appStoreID)")!
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: 用户卡片
                Section {
                    Button { showInfoSheet = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(auth.studentInfo?.name ?? "…")
                                    .font(.title3.bold())
                                    .foregroundStyle(.primary)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onNameTap() }
                                Text(auth.studentInfo?.studentID ?? "…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let college = auth.studentInfo?.college, !college.isEmpty {
                                    Text(college)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }

                // MARK: 账号管理
                Section(String(localized: "settings.group.account")) {
                    SettingRow(icon: "person.2.fill", tint: .blue,
                               titleKey: "settings.switchAccount",
                               subtitleKey: nil, action: { auth.logout() })
                    SettingRow(icon: "arrow.clockwise.circle.fill", tint: .blue,
                               titleKey: "settings.refreshSession",
                               subtitleKey: "settings.refreshSession.sub") {
                        Task {
                            let ok = await SessionKeeper.shared.reloginIfPossible()
                            toast = ok ? String(localized: "settings.refreshSession.ok")
                                       : String(localized: "settings.refreshSession.fail")
                        }
                    }
                    SettingRow(icon: "rectangle.portrait.and.arrow.right.fill", tint: .red,
                               titleKey: "settings.logout",
                               subtitleKey: "settings.logout.sub", action: { auth.logout() })
                }

                // MARK: 应用功能
                Section(String(localized: "settings.group.features")) {
                    NavigationLink {
                        WidgetGuideView()
                    } label: {
                        SettingLabel(icon: "square.grid.2x2.fill", tint: .green,
                                     titleKey: "settings.addWidget",
                                     subtitleKey: "settings.addWidget.sub")
                    }
                    Button {
                        showScheduleSettings = true
                    } label: {
                        SettingLabel(icon: "textformat.size", tint: .blue,
                                     titleKey: "settings.scheduleDisplay",
                                     subtitleKey: "settings.scheduleDisplay.sub")
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await checkUpdate() }
                    } label: {
                        SettingLabel(icon: "arrow.down.circle.fill", tint: .blue,
                                     titleKey: "settings.checkUpdate",
                                     subtitleKey: String(format: NSLocalizedString("settings.checkUpdate.sub", comment: ""), UpdateService.currentVersion))
                    }
                    .buttonStyle(.plain)
                    Link(destination: APIConfig.feedbackURL) {
                        SettingLabel(icon: "bubble.left.and.exclamationmark.bubble.right.fill", tint: .purple,
                                     titleKey: "settings.feedback",
                                     subtitleKey: "settings.feedback.sub")
                    }
                    ShareLink(item: shareURL) {
                        SettingLabel(icon: "square.and.arrow.up.fill", tint: .blue,
                                     titleKey: "settings.share",
                                     subtitleKey: "settings.share.sub")
                    }
                }

                // MARK: 更多
                Section(String(localized: "settings.group.more")) {
                    NavigationLink {
                        WebViewScreen(titleKey: "settings.homepage", url: APIConfig.homepageURL)
                    } label: {
                        SettingLabel(icon: "house.fill", tint: .blue,
                                     titleKey: "settings.homepage",
                                     subtitleKey: "settings.homepage.sub")
                    }
                    Link(destination: APIConfig.giteeRepo) {
                        SettingLabel(icon: "chevron.left.forwardslash.chevron.right", tint: .green,
                                     titleKey: "settings.source",
                                     subtitleKey: "settings.source.sub")
                    }
                    NavigationLink { AboutView() } label: {
                        SettingLabel(icon: "info.circle.fill", tint: .gray,
                                     titleKey: "settings.about",
                                     subtitleKey: "settings.about.sub")
                    }
                }
            }
            .navigationTitle(String(localized: "tab.me"))
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.footnote)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                }
            }
            .task(id: toast) {
                guard toast != nil else { return }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                self.toast = nil
            }
            .sheet(isPresented: $showInfoSheet) { StudentInfoSheet(info: auth.studentInfo) }
            .sheet(isPresented: $showScheduleSettings) { ScheduleSettingsSheet(refreshTrigger: $scheduleRefreshTrigger) }
            .alert(String(localized: "update.found.title"), isPresented: Binding(
                get: { updateInfo != nil }, set: { if !$0 { updateInfo = nil } })) {
                Button(String(localized: "update.download")) {
                    if let link = updateInfo?.downloadLink,
                       let url = URL(string: link.isEmpty ? shareURL.absoluteString : link) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(String(localized: "common.done"), role: .cancel) {}
            } message: {
                if let info = updateInfo {
                    Text("v\(info.version)\n\(info.updateLog)")
                }
            }
            .alert(String(localized: "update.upToDate"), isPresented: $upToDate) {
                Button(String(localized: "common.done"), role: .cancel) {}
            }
            .alert(String(localized: "settings.checkUpdate"), isPresented: Binding(
                get: { updateError != nil }, set: { if !$0 { updateError = nil } })) {
                Button(String(localized: "common.done"), role: .cancel) {}
            } message: {
                Text(updateError ?? "")
            }
        }
        .alert(String(localized: "debug.password.title"), isPresented: $showPasswordPrompt) {
            SecureField(String(localized: "login.password"), text: $debugPassword)
            Button(String(localized: "common.done")) {
                if debugPassword == DebugGate.password {
                    debugPassword = ""
                    showDebug = true
                }
            }
            Button(String(localized: "common.cancel"), role: .cancel) { debugPassword = "" }
        } message: {
            Text("debug.password.message")
        }
        .fullScreenCover(isPresented: $showDebug) {
            DebugView()
        }
    }

    private func checkUpdate() async {
        checkingUpdate = true
        updateError = nil
        defer { checkingUpdate = false }
        do {
            if let info = try await UpdateService.check() {
                updateInfo = info
            } else {
                upToDate = true
            }
        } catch is CancellationError {
        } catch {
            updateError = error.localizedDescription
        }
    }

    /// 5 连击（1.5 秒内），超时重置。
    private func onNameTap() {
        debugTapCount += 1
        debugTapTask?.cancel()
        if debugTapCount >= 5 {
            debugTapCount = 0
            showPasswordPrompt = true
            return
        }
        debugTapTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { debugTapCount = 0 }
        }
    }

    @State private var debugTapCount = 0
    @State private var debugTapTask: Task<Void, Never>?
}

// MARK: - 两行设置行（左图标）

private struct SettingLabel: View {
    let icon: String
    let tint: Color
    let titleKey: String
    let subtitleKey: String?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString(titleKey, comment: ""))
                if let sub = subtitleKey {
                    Text(sub).font(.caption).foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
        }
    }
}

private struct SettingRow: View {
    let icon: String
    let tint: Color
    let titleKey: String
    let subtitleKey: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingLabel(icon: icon, tint: tint, titleKey: titleKey, subtitleKey: subtitleKey)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 学生信息弹层（点用户卡片）

private struct StudentInfoSheet: View {
    let info: StudentInfo?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let info {
                    LabeledContent(String(localized: "profile.name"), value: info.name)
                    LabeledContent(String(localized: "profile.studentID"), value: info.studentID)
                    if !info.gender.isEmpty { LabeledContent(String(localized: "profile.gender"), value: info.gender) }
                    if !info.birthday.isEmpty { LabeledContent(String(localized: "profile.birthday"), value: info.birthday) }
                    if !info.college.isEmpty { LabeledContent(String(localized: "profile.college"), value: info.college) }
                    if !info.major.isEmpty { LabeledContent(String(localized: "profile.major"), value: info.major) }
                    if !info.className.isEmpty { LabeledContent(String(localized: "profile.className"), value: info.className) }
                    if !info.grade.isEmpty { LabeledContent(String(localized: "profile.grade"), value: info.grade) }
                }
            }
            .navigationTitle(String(localized: "profile.info"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
    }
}

/// 调试模式入口常量。
enum DebugGate {
    static let password = "hmudqdebug"
}
