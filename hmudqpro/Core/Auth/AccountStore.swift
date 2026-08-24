import Foundation

/// 多账号管理（对齐安卓 SavedAccount）：账号列表 + 每账号密码存 Keychain。
enum AccountStore {
    struct SavedAccount: Codable, Identifiable, Equatable {
        let studentID: String
        var name: String
        var id: String { studentID }
    }

    /// 当前登录学号（会话凭据键）。
    static var currentID: String? {
        KeychainStore.string(forKey: KeychainStore.Keys.studentID)
    }

    /// 已保存账号列表（Keychain JSON，保持登录时间倒序：最近使用的在最前）。
    static var accounts: [SavedAccount] {
        guard let data = KeychainStore.data(forKey: KeychainStore.Keys.savedAccounts),
              let list = try? JSONDecoder().decode([SavedAccount].self, from: data) else { return [] }
        return list
    }

    /// 登录成功后调用：记录账号 + 该账号的密码，并置顶。
    static func record(studentID: String, name: String, password: String) {
        var list = accounts.filter { $0.studentID != studentID }
        list.insert(SavedAccount(studentID: studentID, name: name.isEmpty ? studentID : name), at: 0)
        if let data = try? JSONEncoder().encode(list) {
            try? KeychainStore.set(data, forKey: KeychainStore.Keys.savedAccounts)
        }
        try? KeychainStore.setString(password, forKey: passKey(studentID))
    }

    static func password(for studentID: String) -> String? {
        KeychainStore.string(forKey: passKey(studentID))
    }

    /// 删除账号（连同其保存的密码）。
    static func remove(studentID: String) {
        let list = accounts.filter { $0.studentID != studentID }
        if let data = try? JSONEncoder().encode(list) {
            try? KeychainStore.set(data, forKey: KeychainStore.Keys.savedAccounts)
        }
        KeychainStore.remove(forKey: passKey(studentID))
    }

    private static func passKey(_ studentID: String) -> String {
        "auth.pass.\(studentID)"
    }
}
