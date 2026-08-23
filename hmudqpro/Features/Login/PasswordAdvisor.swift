import Foundation

/// 登录密码防呆提示（默认密码 Hmudq@身份证号后六位）。
/// 尽早识别常见手误，在输入时和登录失败时给出针对性提示。
enum PasswordAdvisor {

    static let defaultPattern = "^Hmudq@[0-9Xx]{6}$"

    /// 是否符合默认密码格式。
    static func looksLikeDefault(_ password: String) -> Bool {
        password.range(of: defaultPattern, options: .regularExpression) != nil
    }

    /// 针对性提示；nil = 看不出问题。
    static func hint(for password: String) -> String? {
        guard !password.isEmpty, !looksLikeDefault(password) else { return nil }

        // 1. 全角 ＠（先于「少 @」检查，否则会被吞掉）
        if password.contains("＠") {
            return String(localized: "login.hint.fullwidth")
        }

        let head = String(password.prefix(5))

        // 2. 前缀 hmudq 只差大小写 → 「H 没大写？」
        if head.lowercased() == "hmudq", head != "Hmudq" {
            return String(format: NSLocalizedString("login.hint.case", comment: ""), head)
        }

        // 3. @ 前的部分与 Hmudq 差一步（错拼/换位，如 Humdq、Hmduq、Hmydq、Hmud）
        if let at = password.firstIndex(of: "@") {
            let typed = String(password[password.startIndex..<at])
            if !typed.isEmpty, typed != "Hmudq", damerau(typed, "Hmudq") <= (typed.count > 4 ? 1 : 1) {
                return String(format: NSLocalizedString("login.hint.typo", comment: ""), typed)
            }
        } else if password.hasPrefix("Hmudq") {
            // 4. 有 Hmudq 前缀但没有 @ → 「少了 @？」
            return String(localized: "login.hint.atMissing")
        } else if head.count == 5, damerau(head, "Hmudq") == 1 {
            // 无 @ 且前缀差一步，也按错拼提示
            return String(format: NSLocalizedString("login.hint.typo", comment: ""), head)
        }

        // 5. @ 后长度不是 6 → 「多输/少输了？」
        if let at = password.firstIndex(of: "@") {
            let suffix = password[password.index(after: at)...]
            if !suffix.isEmpty, suffix.count != 6 {
                return String(localized: "login.hint.suffix")
            }
        }

        return nil
    }

    /// Damerau-Levenshtein 距离（比普通编辑距离多识别相邻换位：
    /// Humdq/Hmudq、Hmduq/Hmudq 互换两个字母在普通编辑距离里是 2，实际是一次手误）。
    static func damerau(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var dp = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { dp[i][0] = i }
        for j in 0...b.count { dp[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                dp[i][j] = min(dp[i-1][j] + 1, dp[i][j-1] + 1, dp[i-1][j-1] + cost)
                if i > 1, j > 1, a[i-1] == b[j-2], a[i-2] == b[j-1] {
                    dp[i][j] = min(dp[i][j], dp[i-2][j-2] + 1)   // 相邻换位
                }
            }
        }
        return dp[a.count][b.count]
    }
}
