import SwiftUI

/// 开屏检查（最多 3s）→ 按登录态分流到登录页或主界面。
struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var splash = SplashCoordinator.shared

    var body: some View {
        Group {
            if splash.phase != .finished {
                SplashView(coordinator: splash)
            } else if auth.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            splash.start(auth: auth)
            // SDK 在 UI 就绪后初始化（App.init 太早：穿山甲依赖 UIApplication，
            // 过早启动会导致进赞助页创建广告对象时 ObjC 层崩溃）
            SDKBootstrap.setupAll()
        }
    }
}

/// 主界面 Tab 骨架（P1 逐步填充）。
struct MainTabView: View {
    @ObservedObject private var splash = SplashCoordinator.shared
    @State private var showUpdateAlert = false

    var body: some View {
        TabView {
            ScheduleView()
                .tabItem { Label(String(localized: "tab.schedule"), systemImage: "calendar") }
            ToolsView()
                .tabItem { Label(String(localized: "tab.tools"), systemImage: "square.grid.2x2") }
            AssessmentView()
                .tabItem { Label(String(localized: "tab.assessment"), systemImage: "checkmark.seal") }
            ProfileView()
                .tabItem { Label(String(localized: "tab.me"), systemImage: "person") }
        }
        // 开屏查到的新版本在课表页（首屏）弹窗；强制更新只有「立即更新」不可跳过
        .alert(String(localized: "update.title"), isPresented: $showUpdateAlert) {
            if let info = splash.pendingUpdate {
                Button(String(localized: "update.now")) {
                    openDownload(info.downloadLink)
                    consumeUpdate()
                }
                if !info.forceUpdate {
                    Button(String(localized: "update.later"), role: .cancel) { consumeUpdate() }
                    Button(String(localized: "update.ignore")) {
                        UpdateService.ignoreVersion(code: info.versionCode)
                        consumeUpdate()
                    }
                }
            }
        } message: {
            if let info = splash.pendingUpdate {
                Text("v\(info.version)\n\n\(info.updateLog)")
            }
        }
        .onChange(of: splash.phase) { phase in
            if case .finished = phase, splash.pendingUpdate != nil { showUpdateAlert = true }
        }
        .onAppear {
            if case .finished = splash.phase, splash.pendingUpdate != nil { showUpdateAlert = true }
        }
    }

    private func consumeUpdate() {
        splash.pendingUpdate = nil
        showUpdateAlert = false
    }

    private func openDownload(_ link: String) {
        if let url = URL(string: link) { UIApplication.shared.open(url) }
    }
}
