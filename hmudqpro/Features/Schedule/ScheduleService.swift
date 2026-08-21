import Foundation

/// 课表服务：从教务 getCalendar.action 抓取课程数据（带登录态检测与自动重登）。
final class ScheduleService {
    enum ScheduleError: Error, LocalizedError {
        case sessionExpired
        case fetchFailed(String)
        var errorDescription: String? {
            switch self {
            case .sessionExpired: return "登录已失效，请重新登录"
            case .fetchFailed(let m): return "课表获取失败：\(m)"
            }
        }
    }

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// 抓取指定日期范围的课表。nil 范围 = 当前学期。
    /// 假期查下学期时传入自定义范围，空数据 = 下学期尚未排课。
    func fetchCourses(dateRange: (start: String, end: String)? = nil) async throws -> [Course] {
        let range = dateRange ?? ScheduleParser.currentSemesterRange()
        do {
            let body = try await requestCalendar(start: range.start, end: range.end)
            do {
                return try ScheduleParser.parse(body)
            } catch ScheduleParser.ParseError.htmlResponse {
                // 登录态失效 → 自动重登一次后重试
                guard await SessionKeeper.shared.reloginIfPossible() else {
                    throw ScheduleError.sessionExpired
                }
                let retryBody = try await requestCalendar(start: range.start, end: range.end)
                return try ScheduleParser.parse(retryBody)
            }
        } catch let e as ScheduleError {
            throw e
        } catch {
            throw ScheduleError.fetchFailed(error.localizedDescription)
        }
    }

    private func requestCalendar(start: String, end: String) async throws -> String {
        let body = "d1=\(start)%2000:00:00&d2=\(end)%2000:00:00".data(using: .utf8)
        let (data, _) = try await client.request(
            APIConfig.jwcCalendarURL, method: "POST", body: body,
            userAgent: APIConfig.webUserAgentShort,
            headers: [
                "Referer": APIConfig.jwcDesktopURL.absoluteString,
                "X-Requested-With": "XMLHttpRequest",
            ])
        return String(data: data, encoding: .utf8) ?? ""
    }
}
