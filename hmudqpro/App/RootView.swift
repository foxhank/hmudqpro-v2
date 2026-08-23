import SwiftUI

/// 根据登录态分流到登录页或主界面。
struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if auth.isLoggedIn {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

/// 主界面 Tab 骨架（P1 逐步填充）。
struct MainTabView: View {
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
    }
}
