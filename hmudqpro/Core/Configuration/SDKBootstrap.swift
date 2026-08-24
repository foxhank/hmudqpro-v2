import Foundation
import Bugly
import BUAdSDK

/// 第三方 SDK 统一引导（Bugly 崩溃上报 / 百度统计 MTJ / 穿山甲 GroMore 广告）。
/// 所有 ID 来自 APIConfig（缺配置会 fail loud），App 启动时调用一次。
enum SDKBootstrap {
    /// app 启动时调用（didFinishLaunching 语义）。
    static func setupAll() {
        CrashLog.install()   // 未捕获的 ObjC 异常打到 stderr，--console 可见
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
        // Debug 用穿山甲官方测试应用 5000546（配套 iOS 测试代码位，见 AdManager）；
        // Release 用正式 App + GroMore 聚合。
        #if DEBUG
        config.appID = "5000546"
        config.useMediation = false
        #else
        config.appID = APIConfig.gromoreAppID
        config.useMediation = true
        #endif
        config.sdkdebug = true
        print("🛠 [AdSDK] 开始初始化 BUAdSDK appID=\(config.appID ?? "") mediation=\(config.useMediation)")
        BUAdSDKManager.start(asyncCompletionHandler: { success, error in
            print("🛠 [AdSDK] 初始化完成 success=\(success) error=\(error.map(String.init(describing:)) ?? "nil")")
            if success { AdManager.sdkDidStart() }
        })
    }
}


/// 未捕获 ObjC 异常 → stderr（终端 --console 直接收得到）。
enum CrashLog {
    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            let msg = """
            💥 UNCAUGHT EXCEPTION \(exception.name.rawValue)
            reason: \(exception.reason ?? "")
            \(exception.callStackSymbols.joined(separator: "\n"))
            """
            FileHandle.standardError.write(Data((msg + "\n").utf8))
        }
    }
}
