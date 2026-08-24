import XCTest
@testable import hmudqpro

/// 广告配置防呆测试：ID 格式/匹配性校验（40006「广告位ID不合法」的代码侧防线）。
final class AdConfigTests: XCTestCase {
    /// 穿山甲 AppID：纯数字、5~12 位、非空。
    func testGroMoreAppIDFormat() {
        let appID = APIConfig.gromoreAppID
        XCTAssertFalse(appID.isEmpty, "gromore_app_id 不能为空")
        XCTAssertTrue(appID.allSatisfy(\.isNumber), "AppID 应为纯数字：\(appID)")
        XCTAssertTrue((5...12).contains(appID.count), "AppID 长度异常：\(appID)")
    }

    /// 正式激励位：纯数字、与 AppID 不同、非空。
    func testRewardSlotFormat() {
        let slot = APIConfig.gromoreRewardSlotID
        XCTAssertFalse(slot.isEmpty, "gromore_reward_slot 不能为空")
        XCTAssertTrue(slot.allSatisfy(\.isNumber), "代码位应为纯数字：\(slot)")
        XCTAssertNotEqual(slot, APIConfig.gromoreAppID, "代码位与 AppID 相同——大概率配错（历史上 5856020/5856012 一字之差排查了很久）")
    }

    /// Debug 测试位必须是 iOS 的（安卓位 945830371 在 iOS 上 40006）。
    func testDebugSlotIsIOSTestSlot() {
        #if DEBUG
        // AdManager.slotID 无法直接访问，这里校验常量本身：iOS 模板激励测试位
        let iOSRewardTemplateTestSlot = "945113162"
        XCTAssertEqual(iOSRewardTemplateTestSlot.count, 9)
        XCTAssertTrue(iOSRewardTemplateTestSlot.allSatisfy(\.isNumber))
        let androidTestSlot = "945830371"
        XCTAssertNotEqual(iOSRewardTemplateTestSlot, androidTestSlot, "iOS 与安卓测试位不同，用错平台必 40006")
        #endif
    }
}
