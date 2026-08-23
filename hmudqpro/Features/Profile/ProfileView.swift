import SwiftUI

/// 「我的」页框架。正式功能后续迭代；当前提供调试模式入口：
/// 连续点击页面标题 5 次 → 输入密码 → 进入 DebugView。
struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var titleTapCount = 0
    @State private var titleTapTask: Task<Void, Never>?
    @State private var showPasswordPrompt = false
    @State private var showDebug = false
    @State private var debugPassword = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 可点击的标题（导航栏标题点不到，页面内放大字标题）
                Text("tab.me")
                    .font(.largeTitle.bold())
                    .contentShape(Rectangle())
                    .onTapGesture { onTitleTap() }

                if let info = auth.studentInfo {
                    VStack(spacing: 4) {
                        Text(info.name).font(.title2)
                        Text("\(info.college) · \(info.className)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("profile.placeholder")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape")
                    }
                }
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

    /// 5 连击（1.5 秒内），超时重置。
    private func onTitleTap() {
        titleTapCount += 1
        titleTapTask?.cancel()
        if titleTapCount >= 5 {
            titleTapCount = 0
            showPasswordPrompt = true
            return
        }
        titleTapTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { titleTapCount = 0 }
        }
    }
}

/// 调试模式入口常量。
enum DebugGate {
    static let password = "hmudqdebug"
}
