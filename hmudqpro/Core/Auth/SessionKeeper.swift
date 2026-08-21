import Foundation

/// 会话保持器：请求发现登录态失效时自动重登（带熔断）。
///
/// v1 的熔断逻辑散在 NetworkManager 里；v2 独立成类：
/// - 连续失败达到阈值后进入熔断，冷却时间内不再自动重登（防止账号被锁/CAS协议变更时死循环）
/// - 线程安全（锁保护状态），单例
final class SessionKeeper {
    static let shared = SessionKeeper()

    private let lock = NSLock()
    private let authService: AuthService

    /// 连续失败几次后熔断。
    private let maxConsecutiveFailures = 3
    /// 熔断冷却时间。
    private let cooldown: TimeInterval = 60

    private var consecutiveFailures = 0
    private var circuitOpenUntil: Date?

    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    /// 当前是否处于熔断状态（冷却中不自动重登）。
    var isCircuitOpen: Bool {
        lock.lock(); defer { lock.unlock() }
        if let until = circuitOpenUntil, Date() < until { return true }
        if circuitOpenUntil != nil { circuitOpenUntil = nil } // 冷却结束自动恢复
        return false
    }

    /// 尝试用 Keychain 中保存的凭据自动重登。返回是否成功。
    @discardableResult
    func reloginIfPossible() async -> Bool {
        guard !isCircuitOpen else { return false }
        guard let id = KeychainStore.string(forKey: KeychainStore.Keys.studentID),
              let password = KeychainStore.string(forKey: KeychainStore.Keys.password)
        else { return false }

        do {
            _ = try await authService.login(studentID: id, password: password)
            recordSuccess()
            return true
        } catch {
            recordFailure()
            return false
        }
    }

    /// app 启动时尝试恢复会话：先恢复 Cookie，失效则重登。
    /// 返回最终是否有有效会话。
    @discardableResult
    func restoreSessionOnLaunch() async -> Bool {
        if CookieSession.shared.restore(), CookieSession.shared.hasWebvpnCookie {
            return true
        }
        return await reloginIfPossible()
    }

    private func recordSuccess() {
        lock.lock(); defer { lock.unlock() }
        consecutiveFailures = 0
        circuitOpenUntil = nil
    }

    private func recordFailure() {
        lock.lock(); defer { lock.unlock() }
        consecutiveFailures += 1
        if consecutiveFailures >= maxConsecutiveFailures {
            circuitOpenUntil = Date().addingTimeInterval(cooldown)
        }
    }
}
