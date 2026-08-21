import Foundation

/// 第三方 SDK 统一引导入口。
///
/// P1 阶段只搭骨架；SDK 二进制（Bugly / 百度统计 / GroMore）在 P4 通过 SPM/Pods 接入时，
/// 在对应的 bootstrap 方法里填初始化调用。所有 key 来自 APIConfig（无 fallback），
/// 届时取消注释即自动启用配置校验。
enum SDKBootstrap {
    /// app 启动时调用（didFinishLaunching 语义）。
    static func setupAll() {
        setupBugly()
        setupBaiduStat()
        setupGroMore()
    }

    /// Bugly 崩溃上报。
    /// TODO(P4): 接入 Bugly SDK 后取消注释；plist 已有真实 bugly_app_id
    static func setupBugly() {
        // Bugly.start(withAppId: APIConfig.buglyAppID)
    }

    /// 百度移动统计。
    /// TODO(P4): 需先在 plist 填入真实 baidu_stat_app_id
    static func setupBaiduStat() {
        // BaiduStat.start(withAppId: APIConfig.baiduStatAppID)
    }

    /// GroMore（穿山甲聚合）广告，替代 v1 的 Google Ads。
    /// TODO(P4): 需先在 plist 填入真实 gromore_app_id
    static func setupGroMore() {
        // PAGSdk.startWith(...)
    }
}
