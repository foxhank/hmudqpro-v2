import Foundation

/// 全局 API 端点与配置的唯一来源。
///
/// 读取 `APIConfig.plist`（真实文件不入库，模板见 `APIConfig.plist.example`）。
/// 设计原则：**不提供任何 fallback**——缺少 key 直接 fatalError 并指明缺失项，
/// 保证配置错误在启动瞬间暴露，而不是运行到某个功能才静默失败。
enum APIConfig {
    private static let config: [String: String] = {
        guard let path = Bundle.main.path(forResource: "APIConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            fatalError("[APIConfig] APIConfig.plist 缺失：请 cp APIConfig.plist.example APIConfig.plist 并填入真实值")
        }
        return dict
    }()

    private static func value(_ key: String) -> String {
        guard let v = config[key], !v.isEmpty, !v.hasPrefix("PLACEHOLDER") else {
            fatalError("[APIConfig] 缺少或未填写配置项: \(key)")
        }
        return v
    }

    // MARK: - 自建后端
    static var backendBase: URL { URL(string: value("backend_base"))! }
    static var backendFileBase: URL { URL(string: value("backend_file_base"))! }
    static var holidayPath: String { value("api_holiday_path") }
    static var analysisPath: String { value("api_analysis_path") }
    static var updatePath: String { value("api_update_path") }
    static var examsPath: String { value("api_exams_path") }
    static var classroomPath: String { value("api_classroom_path") }
    static var donatePath: String { value("api_donate_path") }
    static var donateLeaderboardPath: String { value("api_donate_leaderboard") }
    static var donateRenamePath: String { value("api_donate_rename") }
    static var donateOverviewPath: String { value("api_donate_overview") }
    static var donateSecretKey: String { value("donate_secret_key") }
    static var privacyHTML: String { value("privacy_html") }
    static var agreementHTML: String { value("agreement_html") }

    // MARK: - 学校 webvpn / CAS / 教务
    static var webvpnBase: URL { URL(string: value("webvpn_base"))! }
    static var casBase: URL { URL(string: value("cas_base"))! }
    static var casLoginServiceURL: URL { URL(string: value("cas_login_service_url"))! }
    static var jwcBase: URL { URL(string: value("jwc_base"))! }
    static var jwcDesktopPath: String { value("jwc_desktop_path") }
    static var jwcAcademicPath: String { value("jwc_academic_path") }
    static var jwcXsxkBase: String { value("jwc_xsxk_base") }
    static var jwcXsxkTimecheck: String { value("jwc_xsxk_timecheck") }
    static var jwcCalendarAction: String { value("jwc_calendar_action") }
    static var jwcGradesAction: String { value("jwc_grades_action") }
    static var jwcExamGradesAction: String { value("jwc_examgrades_action") }
    static var jwcStudentInfoAction: String { value("jwc_studentinfo_action") }
    static var jwcSsoLogin: String { value("jwc_ssologin") }
    static var zhcpBase: URL { URL(string: value("zhcp_base"))! }
    static var bsdtBase: URL { URL(string: value("bsdt_base"))! }

    // MARK: - 第三方外链
    static var cnkiWebvpn: URL { URL(string: value("cnki_webvpn"))! }
    static var wanfangWebvpn: URL { URL(string: value("wanfang_webvpn"))! }
    static var schoolHome: URL { URL(string: value("school_home"))! }
    static var homepageURL: URL { URL(string: value("homepage_url"))! }
    static var giteeRepo: URL { URL(string: value("gitee_repo"))! }
    static var feedbackURL: URL { URL(string: value("feedback_url"))! }
    static var beianURL: URL { URL(string: value("beian_url"))! }
    static var mikecrmRepair: URL { URL(string: value("mikecrm_repair"))! }
    static var ebookURL: URL { URL(string: value("ebook_url"))! }

    // MARK: - 请求头
    static var webUserAgent: String { value("web_user_agent") }
    static var webUserAgentShort: String { value("web_user_agent_short") }
    static var appUserAgent: String { value("app_user_agent_static") }

    // MARK: - 派生 URL（由 base + path 组合，不引入新配置项）
    private static func join(_ base: URL, _ path: String) -> URL {
        // 注意不能用 URL(string:relativeTo:)：以 / 开头的相对路径会丢弃 base 的路径段（如 /cas）
        let p = path.hasPrefix("/") ? path : "/" + path
        return URL(string: base.absoluteString + p)!
    }
    static var casLoginURL: URL { join(casBase, "/login") }
    static var casPubKeyURL: URL { join(casBase, "/v2/getPubKey") }
    static var jwcDesktopURL: URL { join(jwcBase, jwcDesktopPath) }
    static var jwcCalendarURL: URL { join(jwcBase, jwcCalendarAction) }
    static var jwcStudentInfoURL: URL { join(jwcBase, jwcStudentInfoAction) }
    static var jwcSsoLoginURL: URL { join(jwcBase, jwcSsoLogin) }
    static var jwcGradesURL: URL { join(jwcBase, jwcGradesAction) }
    static var jwcExamGradesURL: URL { join(jwcBase, jwcExamGradesAction) }
    static var jwcXsxkURL: URL { join(jwcBase, jwcXsxkBase) }
    static var jwcXsxkSelectedURL: URL { join(jwcBase, jwcXsxkBase + "/yxkc") }
    static var jwcXsxkAvailableURL: URL { join(jwcBase, jwcXsxkBase + "/kxkc") }
    static var jwcXsxkAddURL: URL { join(jwcBase, jwcXsxkBase + "/add") }
    static var jwcXsxkCancelURL: URL { join(jwcBase, jwcXsxkBase + "/cancel") }
    static var jwcTeacherEvalPageURL: URL { join(jwcBase, "/new/student/teapj") }
    static var jwcTeacherEvalListURL: URL { join(jwcBase, "/new/student/teapj/pjDatas") }
    static var classroomURL: URL { join(backendBase, classroomPath) }
    static var donateOverviewURL: URL { join(backendBase, donateOverviewPath) }

    // MARK: - SDK
    static var buglyAppID: String { value("bugly_app_id") }
    static var baiduStatAppID: String { value("baidu_stat_app_id") }
    static var gromoreAppID: String { value("gromore_app_id") }
    static var appStoreID: String { value("app_store_id") }
}
