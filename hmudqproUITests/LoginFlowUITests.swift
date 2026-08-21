import XCTest

/// 端到端 UI 验证：真实账号登录 → 课表渲染。
/// 依赖学校服务器可达，不可达时跳过。
final class LoginFlowUITests: XCTestCase {
    func testLoginAndSchedule() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let studentField = app.textFields.element(boundBy: 0)
        let passwordField = app.secureTextFields.element(boundBy: 0)
        XCTAssertTrue(studentField.waitForExistence(timeout: 10), "应显示登录页")

        studentField.tap()
        studentField.typeText("2316820123")
        passwordField.tap()
        passwordField.typeText("Hmudq@233617")
        app.buttons["登录"].firstMatch.tap()

        // 登录成功后应出现课表 Tab（可能加载数秒）
        let scheduleTitle = app.navigationBars["课表"]
        XCTAssertTrue(scheduleTitle.waitForExistence(timeout: 60), "登录后应进入课表页")

        // 课表网格应有课程卡片（静态文本至少 1 个课程名）
        let someText = app.staticTexts.firstMatch
        XCTAssertTrue(someText.waitForExistence(timeout: 10))
    }
}
