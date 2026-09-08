import Foundation
import SwiftUI
import WidgetKit

/// 登录态 ViewModel：登录/登出/启动恢复。
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// 当前 errorMessage 是否属于教务/网络侧故障（HTTP 错误、超时、无法获取页面）。
    /// 只有这类故障才显示「看缓存课表」兜底入口；账密错误是明确错误，不算。
    @Published private(set) var isServerSideError = false
    @Published var studentInfo: StudentInfo?
    /// 启动会话恢复是否已结束（开屏页用它判断能否结束等待）。
    @Published var restoreFinished = false

    /// 持久化学生信息（开屏生日彩蛋在登录前就要读到生日）。
    static let studentInfoKey = "profile.studentInfo"

    private let authService: AuthService

    static let shared = AuthViewModel()

    init(authService: AuthService = AuthService()) {
        self.authService = authService
        // 启动即用上次持久化的学生信息（我的页不再每次联网拉取）；
        // 登录/切换账号时才会重新获取并覆盖。缓存的姓名若被教务脱敏成 *** 则丢弃。
        if let saved = Self.savedStudentInfo, ProfileView.isValid(saved.name) {
            studentInfo = saved
        } else if let saved = Self.savedStudentInfo {
            studentInfo = StudentInfo(name: "", studentID: saved.studentID,
                                      college: saved.college, major: saved.major,
                                      className: saved.className, grade: saved.grade,
                                      birthday: saved.birthday, gender: saved.gender)
        }
    }

    /// app 启动时调用：恢复会话（Cookie → 自动重登）。学生信息用持久化缓存，不重新抓取。
    func restoreOnLaunch() async {
        isLoading = true
        defer {
            isLoading = false
            restoreFinished = true
        }
        isLoggedIn = await SessionKeeper.shared.restoreSessionOnLaunch()
        // 一次性迁移/兜底：没存过、或缓存姓名被脱敏成 *** 时补抓一次
        if isLoggedIn, studentInfo == nil || !ProfileView.isValid(studentInfo?.name ?? "") {
            if let fresh = try? await authService.fetchStudentInfo(),
               ProfileView.isValid(fresh.name) {
                studentInfo = fresh
                persistStudentInfo()
            }
        }
    }
    
    func login(studentID: String, password: String) async {
        guard !studentID.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "login.error.emptyFields")
            isServerSideError = false
            return
        }
        isLoading = true
        errorMessage = nil
        isServerSideError = false
        defer { isLoading = false }
        do {
            let result = try await authService.login(studentID: studentID, password: password)
            studentInfo = result.studentInfo
            isLoggedIn = result.success
            if result.success {
                AccountStore.record(studentID: studentID,
                                    name: result.studentInfo?.name ?? "",
                                    password: password)
                persistStudentInfo()
            }
        } catch {
            let detail = error.localizedDescription
            // 账密错误只报本身；其他错误（超时/500/网络）附「教务可能挂了」提示
            let isCredential = (error as? AuthService.AuthError)?.isCredentialError ?? false
            if isCredential {
                errorMessage = detail
                isServerSideError = false
            } else {
                errorMessage = detail + "\n" + String(localized: "login.error.jwcDownHint")
                isServerSideError = true
            }
        }
    }

    private func persistStudentInfo() {
        guard let info = studentInfo, let data = try? JSONEncoder().encode(info) else { return }
        UserDefaults.standard.set(data, forKey: Self.studentInfoKey)
    }

    /// 上次成功登录的学生信息（开屏页读取）。
    static var savedStudentInfo: StudentInfo? {
        guard let data = UserDefaults.standard.data(forKey: studentInfoKey) else { return nil }
        return try? JSONDecoder().decode(StudentInfo.self, from: data)
    }

    /// 登录页是否显示"跳过登录看缓存课表"入口：之前登录过（有持久化 Cookie 或课表缓存）就有。
    var hasCachedSession: Bool {
        if KeychainStore.data(forKey: KeychainStore.Keys.cookies) != nil { return true }
        return !(ScheduleStore.shared?.load().isEmpty ?? true)
    }

    /// 不走网络登录，直接带缓存进主界面（恢复 Cookie → 置登录态）。
    /// 适合教务故障 / 莫名卡退被踢回登录页的用户：课表先看本地缓存，
    /// 若 Cookie 仍有效则各请求照常工作，失效则由 SessionKeeper 择机自动重登。
    ///
    /// 多账号：Cookie 与课表缓存都是单槽，天然属于「上次使用的账号」。
    /// 唯一例外是登出后——Keychain 学号被清但课表缓存还在，这里从账号列表
    /// （登录时间倒序，首位即上次账号）补回学号，保证「我的」页、埋点、
    /// SessionKeeper 自动重登都对准上次账号而不是空值。
    func enterWithCachedSession() {
        CookieSession.shared.restore()
        if AccountStore.currentID == nil, let last = AccountStore.accounts.first {
            try? KeychainStore.setString(last.studentID, forKey: KeychainStore.Keys.studentID)
        }
        isLoggedIn = true
    }

    /// 清除登录页残留报错（如调试完教务故障返回登录页时调用）。
    func clearError() {
        errorMessage = nil
        isServerSideError = false
    }

    func logout() {
        authService.logout()
        isLoggedIn = false
        studentInfo = nil
        errorMessage = nil
        isServerSideError = false
        UserDefaults.standard.removeObject(forKey: Self.studentInfoKey)
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
