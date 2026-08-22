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
            let courses: [Course]
            do {
                courses = try ScheduleParser.parse(body)
            } catch ScheduleParser.ParseError.htmlResponse {
                // 登录态失效 → 自动重登一次后重试
                guard await SessionKeeper.shared.reloginIfPossible() else {
                    throw ScheduleError.sessionExpired
                }
                let retryBody = try await requestCalendar(start: range.start, end: range.end)
                courses = try ScheduleParser.parse(retryBody)
            }
            // 本地兜底过滤：只保留开始日期落在查询范围内的课程。
            // 实测教务端对日期参数解析失败时会返回全部学期数据（大一到现在的课混在一起），
            // 这里按 qsrq 过滤保证显示的总是当前查询学期。
            return courses.filter { course in
                course.qsrq >= range.start && course.qsrq <= range.end
            }
        } catch let e as ScheduleError {
            throw e
        } catch {
            // 取消错误原样透传（调用方静默处理），不包装成"获取失败"
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw error
            }
            throw ScheduleError.fetchFailed(error.localizedDescription)
        }
    }

    private func requestCalendar(start: String, end: String) async throws -> String {
        // 注意：空格保持原样不编码（%20 会导致教务端解析失败、忽略日期过滤返回全部数据），
        // 与 v1 行为一致；表单其余字段无特殊字符。
        let body = "d1=\(start) 00:00:00&d2=\(end) 00:00:00".data(using: .utf8)
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
