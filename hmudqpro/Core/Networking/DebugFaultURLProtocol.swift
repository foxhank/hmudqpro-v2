import Foundation

/// 调试用 URLProtocol：模拟教务故障——命中 webvpn 域的请求按
/// DebugStore.jwcFailureStatus 处理：
/// - 正数：直接返回该状态码（404/500/502/503），不真正联网
/// - -1：挂起，永不返回数据（测试超时强制终止）
/// - 负数（如 -4 / -8）：先延迟对应秒数，再转发真实请求并原样回传（模拟弱网慢响应，
///   响应是真实数据，登录链各步不会因解析失败而中断）
///
/// 注册在 APIClient 的 session（见 APIClient.defaultSession）；开关在
/// 我的 → 调试 → 模拟教务故障，读 UserDefaults，改动立即生效。
/// 范围说明：CAS / 教务 / 办事大厅 / 综合测评全是 *.webvpn.hmudq.edu.cn，
/// 后端 foxhank.cn 不受影响；内置 WKWebView 不走 URLSession 也不受影响。
final class DebugFaultURLProtocol: URLProtocol {
    private static let hostSuffix = "webvpn.hmudq.edu.cn"

    /// 挂起模式：不返回任何数据（连 HTTP 响应都没有），直到被超时机制取消。
    static let hangCode = -1

    override class func canInit(with request: URLRequest) -> Bool {
        DebugStore.jwcFailureStatus != nil
            && (request.url?.host?.hasSuffix(hostSuffix) ?? false)
    }

    /// 必须重写：基类实现是 NSRequestConcreteImplementation，直接抛 NSException 闪退
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let status = DebugStore.jwcFailureStatus ?? 503
        // 挂起模式：什么都不做，请求一直悬着，由 TimeoutGuard / URLSession 超时强制取消
        guard status != Self.hangCode else {
            print("🧪 [DebugFault] 挂起（不响应）→ \(request.url?.absoluteString ?? "")")
            return
        }
        // 弱网模式（-4 / -8 等）：延迟后转发真实请求，原样回传真实响应
        if status < 0 {
            print("🧪 [DebugFault] 弱网延迟 \(-status) 秒 → \(request.url?.absoluteString ?? "")")
            relayAfterDelay(seconds: TimeInterval(-status))
            return
        }
        print("🧪 [DebugFault] 注入 HTTP \(status) → \(request.url?.absoluteString ?? "")")
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status,
                                             httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("模拟教务故障 HTTP \(status)（DebugFaultURLProtocol）\n".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    /// 延迟后用独立 session 转发原请求（该 session 未注册本协议，不会递归），
    /// Cookie 写回共享存储，保证登录链的多步会话照常建立。
    private func relayAfterDelay(seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.httpCookieStorage = HTTPCookieStorage.shared
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }

        let semaphore = DispatchSemaphore(value: 0)
        var payload: (data: Data, response: HTTPURLResponse)?
        session.dataTask(with: request) { data, resp, _ in
            if let resp = resp as? HTTPURLResponse {
                payload = (data ?? Data(), resp)
            }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 60)

        guard let payload else {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            return
        }
        client?.urlProtocol(self, didReceive: payload.response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: payload.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
