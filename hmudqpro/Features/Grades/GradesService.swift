import Foundation

/// 成绩服务：教务成绩/等级考试查询（带登录态检测与自动重登，复用课表同款链路）。
final class GradesService {
    enum GradesError: Error, LocalizedError {
        case sessionExpired
        case fetchFailed(String)
        var errorDescription: String? {
            switch self {
            case .sessionExpired: return String(localized: "error.sessionExpired")
            case .fetchFailed(let m): return m
            }
        }
    }

    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// 查询某学期课程成绩（xnxqdm 如 "202401"）。
    func fetchGrades(semesterCode: String) async throws -> [GradeRecord] {
        let body = "xnxqdm=\(semesterCode)&jhlxdm=&page=1&rows=100&sort=xnxqdm&order=asc"
            .data(using: .utf8)
        let text = try await post(APIConfig.jwcGradesURL, body: body)
        do {
            return try GradeRecord.parse(text)
        } catch {
            return try await reloginAndRetry { try GradeRecord.parse(try await self.post(APIConfig.jwcGradesURL, body: body)) }
        }
    }

    /// 查询等级考试成绩（四六级等）。
    func fetchExamGrades() async throws -> [ExamGradeRecord] {
        let body = "page=1&rows=100&sort=xnxqdm&order=desc".data(using: .utf8)
        let text = try await post(APIConfig.jwcExamGradesURL, body: body)
        do {
            return try ExamGradeRecord.parse(text)
        } catch {
            return try await reloginAndRetry { try ExamGradeRecord.parse(try await self.post(APIConfig.jwcExamGradesURL, body: body)) }
        }
    }

    /// HTML 响应（解析失败）= 登录失效 → 重登一次后重试。
    private func reloginAndRetry<T>(_ retry: () async throws -> T) async throws -> T {
        guard await SessionKeeper.shared.reloginIfPossible() else { throw GradesError.sessionExpired }
        do {
            return try await retry()
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            throw GradesError.fetchFailed(error.localizedDescription)
        }
    }

    private func post(_ url: URL, body: Data?) async throws -> String {
        do {
            let (data, _) = try await client.request(
                url, method: "POST", body: body,
                userAgent: APIConfig.webUserAgentShort,
                headers: [
                    "Referer": APIConfig.jwcDesktopURL.absoluteString,
                    "X-Requested-With": "XMLHttpRequest",
                ])
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            throw GradesError.fetchFailed(error.localizedDescription)
        }
    }
}
