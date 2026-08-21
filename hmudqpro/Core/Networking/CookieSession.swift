import Foundation

/// 跨域 Cookie 会话管理
/// 统一从 HTTPCookieStorage 收集指定域的 Cookie，序列化到 Keychain 持久化（app 冷启动恢复会话）、登出时清空。
final class CookieSession {
    static let shared = CookieSession()

    private let storage = HTTPCookieStorage.shared

    /// 需要 Cookie 的域
    private var trackedHosts: [String] {
        [APIConfig.webvpnBase, APIConfig.casBase, APIConfig.jwcBase, APIConfig.zhcpBase, APIConfig.bsdtBase]
            .compactMap(\.host)
    }

    private init() {}

    // MARK: - 收集与恢复

    /// 当前所有被跟踪域上的 Cookie（发送诊断或持久化前调用）。
    func currentCookies() -> [HTTPCookie] {
        let hosts = Set(trackedHosts)
        return (storage.cookies ?? []).filter { cookie in
            hosts.contains(where: { cookie.domain.hasSuffix($0) })
        }
    }

    // MARK: - 持久化（Keychain）

    enum CookieError: Error, LocalizedError {
        case serializationFailed
        var errorDescription: String? { "Cookie 序列化失败" }
    }

    /// 把当前会话 Cookie 存入 Keychain，供下次启动免登录。
    func persist() throws {
        let cookies = currentCookies()
        guard !cookies.isEmpty else { return }
        // cookie.properties 可能含 NSDate（expires）/NSNumber，需转成 JSON 安全类型
        let props: [[String: Any]] = cookies.map { cookie in
            cookie.properties?.reduce(into: [:]) { result, pair in
                switch pair.value {
                case let date as Date:
                    result[pair.key.rawValue] = date.timeIntervalSince1970
                case let number as NSNumber:
                    result[pair.key.rawValue] = number.boolValue ? "TRUE" : number
                default:
                    result[pair.key.rawValue] = pair.value
                }
            } ?? [:]
        }
        let data = try JSONSerialization.data(withJSONObject: props)
        try KeychainStore.set(data, forKey: KeychainStore.Keys.cookies)
    }

    /// 启动时从 Keychain 恢复 Cookie。返回是否恢复了任何 Cookie。
    @discardableResult
    func restore() -> Bool {
        guard let data = KeychainStore.data(forKey: KeychainStore.Keys.cookies) else { return false }
        guard let propsList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return false }
        let cookies = propsList.compactMap { props -> HTTPCookie? in
            // 还原 expires（Double 秒 → Date）
            var restored = props
            if let expires = restored[HTTPCookiePropertyKey.expires.rawValue] as? Double {
                restored[HTTPCookiePropertyKey.expires.rawValue] = Date(timeIntervalSince1970: expires)
            }
            return HTTPCookie(properties: restored.mapKeys { HTTPCookiePropertyKey(rawValue: $0) })
        }
        cookies.forEach { storage.setCookie($0) }
        return !cookies.isEmpty
    }

    /// 仅清空内存中的 Cookie（模拟 app 重启后的状态，Keychain 持久化不受影响）。
    func clearInMemory() {
        currentCookies().forEach { storage.deleteCookie($0) }
    }

    /// 登出：清内存、Keychain 及系统存储。
    func clearAll() {
        clearInMemory()
        KeychainStore.remove(forKey: KeychainStore.Keys.cookies)
    }

    /// 会话是否看起来还有效（存在 webvpn 域的 Cookie）。
    var hasWebvpnCookie: Bool {
        let webvpnHost = APIConfig.webvpnBase.host ?? ""
        return currentCookies().contains { $0.domain.hasSuffix(webvpnHost) }
    }
}

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (k, v) in self { result[transform(k)] = v }
        return result
    }
}
