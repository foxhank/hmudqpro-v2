import Foundation

/// 在线选课（移植安卓）：可选课程列表 + 选课/退课 + 批量选课。
struct SelectableCourse: Identifiable, Equatable {
    var id: String { kcrwdm }
    let kcrwdm: String     // 课程任务代码
    let kcmc: String
    let xf: String         // 学分
    let zxs: String        // 总学时
    let jxbrs: Int         // 教学班人数
    let pkrs: Int          // 排课人数
    let teaxm: String
    let jxbdm: String
    let isSelected: Bool
}

/// 选课服务：页面探测限选数 + 已选/可选列表 + 选退操作（登录失效自动重登）。
final class CourseSelectionService {
    enum SelectionError: Error, LocalizedError {
        case sessionExpired
        case failed(String)
        var errorDescription: String? {
            switch self {
            case .sessionExpired: return String(localized: "error.sessionExpired")
            case .failed(let m): return m
            }
        }
    }

    struct SelectionData {
        let maxSelection: Int
        let alreadySelected: Int
        let courses: [SelectableCourse]
    }

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func fetchData() async throws -> SelectionData {
        do {
            return try await fetchDataOnce()
        } catch is SelectionError {
            guard await SessionKeeper.shared.reloginIfPossible() else { throw SelectionError.sessionExpired }
            return try await fetchDataOnce()
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            throw SelectionError.failed(error.localizedDescription)
        }
    }

    private func fetchDataOnce() async throws -> SelectionData {
        // 选课首页：探测限选数 + 登录态
        let (pageData, _) = try await client.request(
            APIConfig.jwcXsxkURL, userAgent: APIConfig.webUserAgentShort,
            headers: ["Referer": APIConfig.jwcDesktopURL.absoluteString])
        let pageHtml = String(data: pageData, encoding: .utf8) ?? ""
        if pageHtml.contains("login-form") || pageHtml.contains("密码登录") {
            throw SelectionError.sessionExpired
        }
        let maxSel = pageHtml.range(of: #"限选\s*(\d+)"#, options: .regularExpression)
            .flatMap { Int(pageHtml[$0].trimmingCharacters(in: CharacterSet(charactersIn: "限选 "))) } ?? 8

        // 已选
        let selectedJson = try await postJSON(APIConfig.jwcXsxkSelectedURL, body: "page=1&rows=100&sort=kcrwdm&order=asc")
        let selectedCodes = try Self.codes(from: selectedJson)
        let total = try Self.total(from: selectedJson)

        // 可选
        let availableJson = try await postJSON(APIConfig.jwcXsxkAvailableURL, body: "page=1&rows=100&sort=kcrwdm&order=asc")
        let courses = try Self.parseCourses(availableJson, selectedCodes: selectedCodes)
        return SelectionData(maxSelection: maxSel, alreadySelected: total, courses: courses)
    }

    /// 选课。返回 (成功, 服务端消息)。
    func select(course: SelectableCourse) async throws -> (Bool, String) {
        let body = "kcrwdm=\(course.kcrwdm)&kcmc=\(Self.urlEncoded(course.kcmc))&hlct=0"
        return try await action(APIConfig.jwcXsxkAddURL, body: body)
    }

    /// 退课。
    func cancel(course: SelectableCourse) async throws -> (Bool, String) {
        let body = "jxbdm=\(course.jxbdm)&kcrwdm=\(course.kcrwdm)&kcmc=\(Self.urlEncoded(course.kcmc))"
        return try await action(APIConfig.jwcXsxkCancelURL, body: body)
    }

    private func action(_ url: URL, body: String) async throws -> (Bool, String) {
        do {
            let json = try await postJSON(url, body: body)
            return try Self.parseActionResult(json)
        } catch is SelectionError {
            guard await SessionKeeper.shared.reloginIfPossible() else { throw SelectionError.sessionExpired }
            let json = try await postJSON(url, body: body)
            return try Self.parseActionResult(json)
        }
    }

    private func postJSON(_ url: URL, body: String) async throws -> String {
        let (data, _) = try await client.request(
            url, method: "POST", body: body.data(using: .utf8),
            userAgent: APIConfig.webUserAgentShort,
            headers: [
                "Referer": APIConfig.jwcXsxkURL.absoluteString + "/",
                "X-Requested-With": "XMLHttpRequest",
            ])
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func parseActionResult(_ json: String) throws -> (Bool, String) {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SelectionError.failed(json)
        }
        return ((obj["code"] as? Int ?? -1) == 0, obj["message"] as? String ?? "")
    }

    private static func total(from json: String) throws -> Int {
        let data = json.data(using: .utf8) ?? Data()
        let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return obj?["total"] as? Int ?? 0
    }

    private static func codes(from json: String) throws -> Set<String> {
        let data = json.data(using: .utf8) ?? Data()
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = obj["rows"] as? [[String: Any]] else { return [] }
        return Set(rows.compactMap { $0["kcrwdm"] as? String })
    }

    static func parseCourses(_ json: String, selectedCodes: Set<String>) throws -> [SelectableCourse] {
        let data = json.data(using: .utf8) ?? Data()
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = obj["rows"] as? [[String: Any]] else {
            throw SelectionError.failed("parse error")
        }
        return rows.map { item in
            let kcrwdm = item["kcrwdm"] as? String ?? ""
            return SelectableCourse(
                kcrwdm: kcrwdm,
                kcmc: item["kcmc"] as? String ?? "",
                xf: (item["xf"] as? Double).map { String($0) } ?? "0",
                zxs: item["zxs"] as? String ?? "0",
                jxbrs: item["jxbrs"] as? Int ?? 0,
                pkrs: item["pkrs"] as? Int ?? 0,
                teaxm: item["teaxm"] as? String ?? "",
                jxbdm: item["jxbdm"] as? String ?? "",
                isSelected: selectedCodes.contains(kcrwdm))
        }
    }

    private static func urlEncoded(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) ?? s
    }
}
