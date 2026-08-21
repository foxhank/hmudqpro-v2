import XCTest
@testable import hmudqpro

final class ScheduleIntegrationTests: XCTestCase {
    /// 真实登录 + 真实抓课表（需要网络与学校服务器可达）。
    func testRealFetchSchedule() async throws {
        try XCTSkipUnless(AuthServiceTests.schoolReachable, "学校 webvpn 不可达，跳过")
        _ = try await AuthService().login(studentID: "2316820123", password: "Hmudq@233617")
        let courses = try await ScheduleService().fetchCourses()
        XCTAssertFalse(courses.isEmpty, "当前学期应有课程数据")
        // 验证字段合理性（真实数据存在 zc/xq 为空的行，如整学期备注，过滤后再验证）
        for c in courses {
            XCTAssertFalse(c.kcmc.isEmpty)
            if !c.zc.isEmpty { XCTAssertNotNil(c.week, "周次应为数字: \(c.zc)") }
            if !c.xq.isEmpty { XCTAssertNotNil(c.weekday, "星期应为数字: \(c.xq)") }
        }
        // 至少存在带周次的正常课程
        XCTAssertTrue(courses.contains { $0.week != nil && $0.weekday != nil })
        // 缓存往返
        let store = ScheduleStore()
        store?.save(courses)
        XCTAssertEqual(store?.load().count, courses.count)
        XCTAssertEqual(store?.isSameAsCache(courses), true)
    }
}
