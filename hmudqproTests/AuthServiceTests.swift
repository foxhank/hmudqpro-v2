import XCTest
@testable import hmudqpro

final class AuthServiceTests: XCTestCase {
    // MARK: - 纯函数解析

    func testExtractExecution() {
        let html = """
        <form><input type="hidden" name="execution" value="e1s1ABCDEFGHIJKLMNOPQRSTUVWXYZ123"/>
        <input name="username"/></form>
        """
        XCTAssertEqual(AuthService.extractExecution(from: html), "e1s1ABCDEFGHIJKLMNOPQRSTUVWXYZ123")
    }

    func testExtractExecutionMissing() {
        XCTAssertNil(AuthService.extractExecution(from: "<html><body>已登录</body></html>"))
    }

    func testCasRSAEncryptRoundTripShape() throws {
        // 512-bit 模数示例（hex）， exponent 10001
        let modulus = String(repeating: "a", count: 128)
        let cipher = try CasRSA.encrypt(password: "Hmudq@233617", modulusHex: modulus, exponentHex: "10001")
        // 密文应为一块（密码 11 字节 < 62 字节 chunk），128 hex 小写字符
        XCTAssertFalse(cipher.isEmpty)
        XCTAssertFalse(cipher.contains(" "))
        XCTAssertEqual(cipher.count, 128)
        XCTAssertTrue(cipher.allSatisfy { $0.isHexDigit })
        XCTAssertTrue(cipher == cipher.lowercased())
    }

    func testCasRSAInvalidModulus() {
        XCTAssertThrowsError(try CasRSA.encrypt(password: "x", modulusHex: "zz", exponentHex: "10001"))
    }

    // MARK: - 真实登录（集成测试，需要网络）

    /// 用真实账号验证完整 CAS 登录链路。学校服务器不可达时跳过。
    func testRealLogin() async throws {
        try XCTSkipUnless(Self.schoolReachable, "学校 webvpn 不可达，跳过真实登录测试")
        let service = AuthService()
        let result = try await service.login(studentID: "2316820123", password: "Hmudq@233617")
        XCTAssertTrue(result.success, result.message)
        XCTAssertTrue(CookieSession.shared.hasWebvpnCookie, "登录后应有 webvpn Cookie")
        // 清理
        service.logout()
    }

    /// 简单 TCP 探测 webvpn 443 端口。
    nonisolated static var schoolReachable: Bool {
        let host = APIConfig.webvpnBase.host ?? ""
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(443).bigEndian
        guard inet_pton(AF_INET, "0.0.0.0", &addr.sin_addr) != nil else { return false }
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        // 用 URL 解析出的 IP 直接连不太可靠，改用 DNS 解析
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, "443", &hints, &res) == 0, let first = res else { return false }
        defer { freeaddrinfo(res) }
        let s = socket(first.pointee.ai_family, first.pointee.ai_socktype, first.pointee.ai_protocol)
        guard s >= 0 else { return false }
        defer { close(s) }
        let connected = connect(s, first.pointee.ai_addr, first.pointee.ai_addrlen) == 0
        return connected
    }
}
