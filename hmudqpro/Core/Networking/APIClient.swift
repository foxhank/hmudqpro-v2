import Foundation

/// 通用网络客户端：只负责发请求，业务 Service（AuthService、ScheduleService…）通过它发请求。
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession

    enum APIError: Error, LocalizedError {
        case invalidURL
        case http(status: Int, url: String, body: String?)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的 URL"
            case .http(let status, let url, _): return "HTTP \(status) \(url)"
            case .emptyResponse: return "服务器返回为空"
            }
        }
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// 通用请求。默认带浏览器 UA（教务系统校验）。
    func request(_ url: URL, method: String = "GET", body: Data? = nil,
                 userAgent: String? = nil, headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        req.setValue(userAgent ?? APIConfig.webUserAgent, forHTTPHeaderField: "User-Agent")
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        if body != nil && req.value(forHTTPHeaderField: "Content-Type") == nil {
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.emptyResponse }
        guard !(300...399).contains(http.statusCode) else {
            // 教务系统大量用 302 表达业务状态，由调用方决定如何处理，这里原样返回。
            return (data, http)
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, url: url.absoluteString,
                                body: String(data: data.prefix(200), encoding: .utf8))
        }
        return (data, http)
    }

    func get(_ url: URL) async throws -> Data {
        try await request(url).0
    }

    /// form-urlencoded POST。
    /// 注意：`.urlQueryAllowed` 不转义 `@` 等保留字（密码常含），必须用 RFC3986 未保留字符集。
    private static let formAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    func postForm(_ url: URL, fields: [(String, String)]) async throws -> Data {
        let body = fields
            .map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: Self.formAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        return try await request(url, method: "POST", body: body).0
    }
}
