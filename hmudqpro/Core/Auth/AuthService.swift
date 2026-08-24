import Foundation

/// CAS + webvpn SSO 登录服务（从 v1 NetworkManager.login 移植重构）。
///
/// v1 把登录、SSO、学生信息、课表、Cookie、熔断全部塞在一个 1100 行的类里；
/// v2 只保留登录职责：拿 CAS 会话 → SSO 进教务 → 验证可访问性。
/// 课表/成绩等由各自的 Service 负责。
final class AuthService {
    enum AuthError: Error, LocalizedError {
        case webvpnUnreachable
        case pubKeyUnavailable
        case pubKeyParseFailed
        case loginPageUnavailable
        case executionMissing
        case badCredentials
        case casRejected(status: Int)
        case ssoFailed(String)

        var errorDescription: String? {
            switch self {
            case .webvpnUnreachable: return "无法访问 WebVPN，请检查网络连接"
            case .pubKeyUnavailable: return "无法获取登录公钥"
            case .pubKeyParseFailed: return "登录公钥解析失败"
            case .loginPageUnavailable: return "无法访问登录页面"
            case .executionMissing: return "无法获取登录参数（可能已有登录态）"
            case .badCredentials: return "用户名或密码错误"
            case .casRejected(let s): return "CAS 登录失败，状态码：\(s)"
            case .ssoFailed(let m): return "教务系统 SSO 登录失败：\(m)"
            }
        }
    }

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// 完整登录流程：CAS RSA 登录 → webvpn SSO → 教务可达性验证。
    /// 成功后凭据写入 Keychain、Cookie 持久化由调用方（AuthViewModel）决定。
    func login(studentID: String, password: String) async throws -> LoginResult {
        CookieSession.shared.clearAll()

        // 1. webvpn 主页（建立初始 Cookie）
        _ = try await client.get(APIConfig.webvpnBase)

        // 2. 获取 RSA 公钥
        let (pubKeyData, pubKeyResp) = try await client.request(
            APIConfig.casPubKeyURL, userAgent: APIConfig.webUserAgentShort)
        guard pubKeyResp.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: pubKeyData) as? [String: String],
              let modulus = json["modulus"], !modulus.isEmpty,
              let exponent = json["exponent"], !exponent.isEmpty
        else { throw AuthError.pubKeyUnavailable }

        // 3. 登录页面拿 execution 参数
        let (pageData, pageResp) = try await client.request(
            APIConfig.casLoginServiceURL, userAgent: APIConfig.webUserAgentShort)
        guard pageResp.statusCode == 200,
              let html = String(data: pageData, encoding: .utf8)
        else { throw AuthError.loginPageUnavailable }
        guard let execution = Self.extractExecution(from: html) else { throw AuthError.executionMissing }

        // 4. 提交登录表单（密码 RSA 加密）
        let encrypted = try CasRSA.encrypt(password: password, modulusHex: modulus, exponentHex: exponent)
        let loginURL = URL(string: "\(APIConfig.casLoginURL.absoluteString)?v=\(Int(Date().timeIntervalSince1970))")!
        let (loginData, loginResp) = try await client.request(
            loginURL, method: "POST",
            body: Self.formBody([
                ("username", studentID),
                ("password", encrypted),
                ("authcode", ""),
                ("rememberMe", "true"),
                ("execution", execution),
                ("_eventId", "submit"),
            ]),
            userAgent: APIConfig.webUserAgentShort)
        switch loginResp.statusCode {
        case 302:
            break // CAS 成功，跳转
        case 200:
            let body = String(data: loginData, encoding: .utf8) ?? ""
            if body.contains("用户名或密码错误") || body.contains("登录失败") {
                throw AuthError.badCredentials
            }
        default:
            throw AuthError.casRejected(status: loginResp.statusCode)
        }

        // 5. SSO 进教务
        let (_, ssoResp) = try await client.request(APIConfig.jwcSsoLoginURL,
                                                    userAgent: APIConfig.webUserAgentShort)
        guard (200...302).contains(ssoResp.statusCode) else {
            throw AuthError.ssoFailed("HTTP \(ssoResp.statusCode)")
        }

        // 6. 验证教务学生信息页可达（同时拿学生信息）
        let info = try? await fetchStudentInfo()

        // 7. 持久化凭据与会话
        try KeychainStore.setString(studentID, forKey: KeychainStore.Keys.studentID)
        try KeychainStore.setString(password, forKey: KeychainStore.Keys.password)
        try CookieSession.shared.persist()

        return LoginResult(success: true,
                           message: "登录成功",
                           studentInfo: info)
    }

    /// 抓取学生信息页并解析（登录流程第 6 步，也供 Profile 使用）。
    func fetchStudentInfo() async throws -> StudentInfo {
        let (data, resp) = try await client.request(APIConfig.jwcStudentInfoURL,
                                                    userAgent: APIConfig.webUserAgentShort)
        guard resp.statusCode == 200,
              let html = String(data: data, encoding: .utf8),
              html.contains("学生基本信息")
        else { throw AuthError.loginPageUnavailable }
        guard let info = Self.parseStudentInfo(html) else { throw AuthError.pubKeyParseFailed }
        return info
    }

    /// 登出：清凭据 + 清会话。
    func logout() {
        KeychainStore.clearCredentials()
        CookieSession.shared.clearAll()
    }

    // MARK: - 解析（纯函数，独立可测）

    /// 从 CAS 登录页 HTML 提取 execution 隐藏域。
    static func extractExecution(from html: String) -> String? {
        guard let range = html.range(of: "name=\"execution\" value=\"([^\"]+)\"", options: .regularExpression) else {
            return nil
        }
        let matched = String(html[range])
        guard let v = matched.range(of: "value=\"[^\"]+\"", options: .regularExpression) else { return nil }
        return String(matched[v]).replacingOccurrences(of: "value=\"", with: "").replacingOccurrences(of: "\"", with: "")
    }

    /// 解析学生基本信息页面 HTML（页面结构：`<td>姓名：</td><td>黄永康</td>` 表格，
    /// 部分字段值在 `<input value="…">` 或 `<option selected>` 里）。
    static func parseStudentInfo(_ html: String) -> StudentInfo? {
        /// 取「label：」单元格后紧跟的值单元格内容（纯文本 / input value / selected option）。
        func cell(_ label: String) -> String? {
            // 锚定 ">标签："，避免匹配到「监护人姓名1：」「辅修专业：」这类包含关系
            let pattern = "(?s)>[\\s]*\(label)[\\s]*：?[\\s]*</td>[\\s]*<td[^>]*>(.*?)</td>"
            guard let r = html.range(of: pattern, options: [.regularExpression]) else {
                return nil
            }
            // 去掉命中的开头标签段，留下值单元格内容
            var value = String(html[r])
            if let open = value.range(of: #"<td[^>]*>"#, options: .regularExpression) {
                value = String(value[open.upperBound...])
            }
            // <input value="…">（出生日期等禁用输入框）
            if let v = value.range(of: #"value="([^"]*)""#, options: .regularExpression) {
                return String(value[v]).replacingOccurrences(of: "value=", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            // <option selected>男</option>（性别等下拉）
            if let s = value.range(of: "selected[^>]*>[^<]+", options: .regularExpression) {
                return String(value[s]).split(separator: ">").last.map {
                    String($0).trimmingCharacters(in: .whitespaces)
                } ?? ""
            }
            // 纯文本，剥掉残余标签
            return value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let name = cell("姓名"), !name.isEmpty else { return nil }
        return StudentInfo(
            name: name,
            studentID: cell("学号") ?? "",
            college: cell("院系名称") ?? cell("院系") ?? cell("学院") ?? "",
            major: cell("专业") ?? "",
            className: cell("班级") ?? "",
            grade: cell("所在年级") ?? cell("年级") ?? "",
            birthday: cell("出生日期") ?? "",
            gender: cell("性别") ?? ""
        )
    }

    /// form body 构造（严格 RFC3986 编码，execution/密文含特殊字符）。
    private static func formBody(_ fields: [(String, String)]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let joined = fields
            .map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
        return joined.data(using: .utf8) ?? Data()
    }
}
