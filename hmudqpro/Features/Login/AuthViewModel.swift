import Foundation
import SwiftUI
import WidgetKit

/// 登录态 ViewModel：登录/登出/启动恢复。
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var studentInfo: StudentInfo?

    private let authService: AuthService

    static let shared = AuthViewModel()

    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    /// app 启动时调用：恢复会话（Cookie → 自动重登）。
    func restoreOnLaunch() async {
        isLoading = true
        defer { isLoading = false }
        isLoggedIn = await SessionKeeper.shared.restoreSessionOnLaunch()
        if isLoggedIn {
            studentInfo = try? await authService.fetchStudentInfo()
        }
    }
    
    func login(studentID: String, password: String) async {
        guard !studentID.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "login.error.emptyFields")
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await authService.login(studentID: studentID, password: password)
            studentInfo = result.studentInfo
            isLoggedIn = result.success
            if result.success {
                AccountStore.record(studentID: studentID,
                                    name: result.studentInfo?.name ?? "",
                                    password: password)
            }
        } catch {
            errorMessage = String(localized: "login.error \(error.localizedDescription)")
        }
    }

    func logout() {
        authService.logout()
        isLoggedIn = false
        studentInfo = nil
    }

    /// 切换账号：清旧会话（Cookie/课表缓存/WebView 存储）→ 换凭据重新登录。
    /// 登录成功后课表页重建会自动拉新账号数据，小组件随课表刷新联动。
    func switchAccount(to studentID: String) async {
        guard let password = AccountStore.password(for: studentID) else { return }
        // 先回到登录态切换中的 UI（RootView 短暂显示登录页的加载态）
        isLoggedIn = false
        studentInfo = nil
        CookieSession.shared.clearAll()          // 旧账号 cookie
        ScheduleStore.shared?.clear()            // 旧账号课表缓存
        WebViewCoordinator.purgeCookieStore()    // 内嵌 WebView 的旧会话
        WidgetCenter.shared.reloadAllTimelines()  // 清掉旧账号的小组件数据
        await login(studentID: studentID, password: password)
    }
}
