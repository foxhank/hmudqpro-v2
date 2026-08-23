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

        // 1. 前缀 hmudq 只差大小写 → 「H 没大写？」
        let head = String(password.prefix(5))
        if head.lowercased() == "hmudq", head != "Hmudq" {
            let wrong = head
            return String(format: NSLocalizedString("login.hint.case", comment: ""), wrong)
        }

        // 2. 有 Hmudq 前缀但没有 @ → 「少了 @？」
        if password.hasPrefix("Hmudq"), !password.contains("@") {
            return String(localized: "login.hint.atMissing")
        }

        // 3. 与 Hmudq 编辑距离 1 的前缀 → 「输成《xxx》了？」（如 Humdq / Hmydq / Hmduq / mudq）
        if head.count == 5, editDistance(head, "Hmudq") == 1 {
            return String(format: NSLocalizedString("login.hint.typo", comment: ""), head)
        }
        // 前面几个字母就错了（如 Humdq@123456 整体取前 7 位比对前缀）
        let head7 = String(password.prefix(7))
        if head7.contains("@"), editDistance(String(head7.dropLast()), "Hmudq") == 1 {
            return String(format: NSLocalizedString("login.hint.typo", comment: ""),
                          String(head7.dropLast()))
        }

        // 4. @ 后长度不对 → 「后六位是不是输多了/输少了？」
        if let at = password.firstIndex(of: "@") {
            let suffix = password[password.index(after: at)...]
            if !suffix.isEmpty, suffix.count != 6 {
                return String(localized: "login.hint.suffix")
            }
        }

        // 5. 用了全角 ＠ 或全角字母
        if password.contains("＠") {
            return String(localized: "login.hint.fullwidth")
        }

        return nil
    }

    /// 通用编辑距离（小输入，O(mn) 足够）。
    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var dp = Array(0...b.count)
        for i in 1...a.count {
            var prev = dp[0]
            dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                dp[j] = a[i-1] == b[j-1] ? prev : min(prev, dp[j], dp[j-1]) + 1
                prev = temp
            }
        }
        return dp[b.count]
    }
}
