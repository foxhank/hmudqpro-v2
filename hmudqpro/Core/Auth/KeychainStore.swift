import Foundation
import Security

/// Keychain 负责敏感数据（学号、密码、CAS/webvpn Cookie）的存取。

enum KeychainStore {
    private static let service = "cn.foxhank.hmudqpro"

    enum KeychainError: Error, LocalizedError {
        case unexpectedStatus(OSStatus)
        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let s): return "Keychain error: \(s)"
            }
        }
    }

    // MARK: - 基础读写

    static func set(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func data(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func remove(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - String 便捷方法

    static func setString(_ value: String, forKey key: String) throws {
        try set(Data(value.utf8), forKey: key)
    }

    static func string(forKey key: String) -> String? {
        data(forKey: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - 业务语义 Key

    /// 这里是Key 常量。
    enum Keys {
        static let studentID = "auth.studentID"
        static let password = "auth.password"
        static let cookies = "auth.cookies"
        static let savedAccounts = "auth.savedAccounts"
    }

    /// 登出时清除本设备上的所有凭据。
    static func clearCredentials() {
        remove(forKey: Keys.studentID)
        remove(forKey: Keys.password)
        remove(forKey: Keys.cookies)
    }
}
