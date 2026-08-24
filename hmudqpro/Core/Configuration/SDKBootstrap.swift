import Foundation
import Bugly
import BUAdSDK

/// 第三方 SDK 统一引导（Bugly 崩溃上报 / 百度统计 MTJ / 穿山甲 GroMore 广告）。
/// 所有 ID 来自 APIConfig（缺配置会 fail loud），App 启动时调用一次。
enum SDKBootstrap {
    /// app 启动时调用（didFinishLaunching 语义）。
    static func setupAll() {
        setupBugly()
        setupBaiduStat()
        setupGroMore()
    }

    /// Bugly 崩溃上报。
    static func setupBugly() {
        Bugly.start(withAppId: APIConfig.buglyAppID)
    }

    /// 百度移动统计（MTJ 无埋点）。
    static func setupBaiduStat() {
        BaiduMobStat().start(withAppId: APIConfig.baiduStatAppID)
    }

    /// 穿山甲 GroMore：SDK 起来后请求 ATT，再预加载激励视频（打赏页用）。
    static func setupGroMore() {
        let config = BUAdSDKConfiguration.configuration()
        config.appID = APIConfig.gromoreAppID
        config.sdkdebug = false
        config.useMediation = true   // GroMore 聚合

        BUAdSDKManager.start(asyncCompletionHandler: { _, _ in
            AdManager.shared.requestATTThenLoadAd()
        })
    }
}
