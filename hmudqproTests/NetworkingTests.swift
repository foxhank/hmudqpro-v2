import XCTest
@testable import hmudqpro

final class NetworkingTests: XCTestCase {
    // MARK: - CookieSession

    func testCookieRoundTrip() throws {
        let session = CookieSession.shared
        session.clearAll()

        let cookie = HTTPCookie(properties: [
            .domain: APIConfig.webvpnBase.host ?? "",
            .path: "/",
            .name: "wengine_vpn_ticket",
            .value: "test-ticket-123",
            .secure: "TRUE",
        ])!
        HTTPCookieStorage.shared.setCookie(cookie)

        // 持久化后模拟 app 重启：只清内存 Cookie，Keychain 保留
        try session.persist()
        session.clearInMemory()
        XCTAssertFalse(session.hasWebvpnCookie)

        XCTAssertTrue(session.restore())
        XCTAssertTrue(session.hasWebvpnCookie)

        session.clearAll()
        XCTAssertFalse(session.hasWebvpnCookie)
        XCTAssertNil(KeychainStore.data(forKey: KeychainStore.Keys.cookies))
    }

    // MARK: - APIClient（URL 构造与错误类型，不发真实网络请求）

    func testAPIErrorDescriptions() {
        XCTAssertEqual(APIClient.APIError.invalidURL.errorDescription, "无效的 URL")
        XCTAssertEqual(APIClient.APIError.http(status: 500, url: "https://x", body: nil).errorDescription, "HTTP 500 https://x")
    }

    func testPostFormEncoding() async throws {
        // 用本地 mock URLProtocol 验证 form 编码
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(session: URLSession(configuration: config))
        defer { MockURLProtocol.requestHandler = nil }

        MockURLProtocol.requestHandler = { req in
            let sent = String(data: MockURLProtocol.readBody(req), encoding: .utf8) ?? ""
            XCTAssertTrue(sent.contains("username=2316820123"))
            XCTAssertTrue(sent.contains("password=Hmudq%40233617"))
            XCTAssertEqual(req.value(forHTTPHeaderField: "User-Agent"), APIConfig.webUserAgent)
            return (Data("ok".utf8), TestHelpers.httpResponse(status: 200))
        }
        let data = try await client.postForm(URL(string: "https://example.com/login")!,
                                             fields: [("username", "2316820123"), ("password", "Hmudq@233617")])
        XCTAssertEqual(String(data: data, encoding: .utf8), "ok")
    }

    func testHTTPErrorThrown() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let client = APIClient(session: URLSession(configuration: config))
        defer { MockURLProtocol.requestHandler = nil }
        MockURLProtocol.requestHandler = { _ in
            (Data(), TestHelpers.httpResponse(status: 500))
        }
        do {
            _ = try await client.get(URL(string: "https://example.com/x")!)
            XCTFail("应抛出 http 错误")
        } catch let APIClient.APIError.http(status, _, _) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("错误类型不对: \(error)")
        }
    }
}

// MARK: - 测试辅助

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    /// URLProtocol 中 httpBody 会被转移成 stream，需要手动读取。
    static func readBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

enum TestHelpers {
    static func httpResponse(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: status,
                        httpVersion: nil, headerFields: nil)!
    }
}
