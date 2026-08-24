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
        // 穿山甲不在启动链路初始化（启动即初始化会被系统 SIGKILL），
        // 改为首次进入赞助页时 setupGroMoreIfNeeded()
    }

    /// Bugly 崩溃上报。
    static func setupBugly() {
        Bugly.start(withAppId: APIConfig.buglyAppID)
    }

    /// 百度移动统计（MTJ 无埋点）。
    static func setupBaiduStat() {
        BaiduMobStat().start(withAppId: APIConfig.baiduStatAppID)
    }

    private static var groMoreStarted = false

    /// 首次进入赞助页时调用：初始化 SDK → 就绪后自动加载激励视频。
    /// ATT 也只在这里申请（不赞助的用户既不初始化广告也不弹跟踪授权）。
    static func setupGroMoreIfNeeded() {
        guard !groMoreStarted else { return }
        groMoreStarted = true
        let config = BUAdSDKConfiguration.configuration()
        config.appID = APIConfig.gromoreAppID
        config.sdkdebug = false
        config.useMediation = true   // GroMore 聚合
        BUAdSDKManager.start(asyncCompletionHandler: { success, _ in
            if success { AdManager.sdkDidStart() }
        })
    }
}
