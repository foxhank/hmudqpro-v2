import Foundation
import SwiftUI

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
        } catch {
            errorMessage = String(localized: "login.error \(error.localizedDescription)")
        }
    }

    func logout() {
        authService.logout()
        isLoggedIn = false
        studentInfo = nil
    }
}
