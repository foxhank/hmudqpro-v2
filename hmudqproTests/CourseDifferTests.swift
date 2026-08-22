import XCTest
@testable import hmudqpro

final class CourseDifferTests: XCTestCase {
    // entryKey 一致 → 无变化
    func testNoChange() {
        let a = Course(kcmc: "生理学", zc: "1", xq: "2", jxbdm: "B1", jcdm: "0102")
        XCTAssertEqual(CourseDiffer.diff(old: [a], new: [a]), .noChange)
    }

    // 纯新增
    func testAdded() {
        let result = CourseDiffer.diff(old: [], new: [
            Course(kcmc: "生化", zc: "2", xq: "3", jxbdm: "B2", jcdm: "0304"),
        ])
        guard case .changed(let added, let removed, let moved) = result else {
            return XCTFail("应为 changed")
        }
        XCTAssertEqual(added, ["生化（第2周 周三 9:55-11:30）"])
        XCTAssertTrue(removed.isEmpty)
        XCTAssertTrue(moved.isEmpty)
    }

    // 同门课时间调整 → 识别为移动而非新增+移除
    func testMoved() {
        let old = Course(kcmc: "系解", zc: "3", xq: "1", jxcdmc: "A101", jxbdm: "B1", jcdm: "0102")
        let new = Course(kcmc: "系解", zc: "4", xq: "5", jxcdmc: "A101", jxbdm: "B1", jcdm: "0506")
        let result = CourseDiffer.diff(old: [old], new: [new])
        guard case .changed(let added, let removed, let moved) = result else {
            return XCTFail("应为 changed")
        }
        XCTAssertTrue(added.isEmpty)
        XCTAssertTrue(removed.isEmpty)
        XCTAssertEqual(moved.count, 1)
        XCTAssertEqual(moved[0].courseName, "系解")
        XCTAssertEqual(moved[0].from, "第3周 周一 8:00-9:35")
        XCTAssertEqual(moved[0].to, "第4周 周五 13:30-15:05")
    }

    // 地点变化也标注
    func testMovedWithLocation() {
        let old = Course(kcmc: "药理", zc: "1", xq: "2", jxcdmc: "A101", jxbdm: "B1", jcdm: "0102")
        let new = Course(kcmc: "药理", zc: "1", xq: "2", jxcdmc: "B202", jxbdm: "B1", jcdm: "0102")
        guard case .changed(_, _, let moved) = CourseDiffer.diff(old: [old], new: [new]) else {
            return XCTFail("应为 changed")
        }
        XCTAssertEqual(moved.count, 1)
        XCTAssertTrue(moved[0].from.contains("A101"))
        XCTAssertTrue(moved[0].to.contains("B202"))
    }

    // 不同教学班的课互不干扰
    func testDifferentClassNoMove() {
        let old = Course(kcmc: "体育", zc: "1", xq: "1", jxbdm: "B1", jcdm: "0304")
        let new = Course(kcmc: "体育", zc: "2", xq: "3", jxbdm: "B9", jcdm: "0506")
        guard case .changed(let added, let removed, let moved) = CourseDiffer.diff(old: [old], new: [new]) else {
            return XCTFail("应为 changed")
        }
        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(removed.count, 1)
        XCTAssertTrue(moved.isEmpty)
    }

    func testAlertMessage() {
        XCTAssertNil(CourseDiffer.alertMessage(.noChange))
        let msg = CourseDiffer.alertMessage(.changed(added: ["X（第1周 周一 8:00-9:35）"], removed: [], moved: []))
        XCTAssertTrue(msg?.contains("新增") ?? false)
        XCTAssertTrue(msg?.contains("个人安排") ?? false)
    }

    func testScheduleDescription() {
        let c = Course(kcmc: "x", zc: "5", xq: "4", jcdm: "03040506")
        XCTAssertEqual(c.scheduleDescription, "第5周 周四 9:55-15:05")
    }
}
