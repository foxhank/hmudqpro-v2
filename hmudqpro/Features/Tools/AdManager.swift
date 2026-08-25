import Foundation
import SwiftUI
import BUAdSDK
import AppTrackingTransparency

/// 穿山甲 GroMore 激励视频管理器（打赏页「看广告献爱心」）。
/// 广告位 ID 来自 APIConfig（口袋工厂：App 5856020 / 激励位 104379830）。
@MainActor
final class AdManager: NSObject, ObservableObject {
    static let shared = AdManager()

    @Published var isAdLoaded = false
    @Published var isLoadingAd = false

    private var rewardedVideoAd: BUNativeExpressRewardedVideoAd?
    private var rewardReceived = false  // 追踪本次播放是否已获得奖励

    /// BUAdSDK 是异步启动的：未就绪就创建广告对象会抛 ObjC 异常闪退。
    /// SDKBootstrap 启动完成回调里调 sdkDidStart()，之前进来的加载请求先挂起。
    private static var isSDKStarted = false
    private var pendingLoad = false

    /// 奖励发放回调（客户端模式：播放完整即触发）。
    var onReward: (() -> Void)?

    /// 广告关闭回调（无论用户是否看完、是否获得奖励都会触发）。
    var onAdClose: ((Bool) -> Void)?

    /// 展示广告前的顶层 VC，用于判断广告页是否已真正关闭
    private var baseTopVC: UIViewController?
    /// 本次播放是否已触发过 onAdClose（奖励轮询与 didClose 双保险去重）
    private var closeNotified = false

    nonisolated static func sdkDidStart() {
        Task { @MainActor in
            Self.isSDKStarted = true
            if shared.pendingLoad {
                shared.pendingLoad = false
                shared.loadRewardedAd()
            }
        }
    }

    /// ATT 授权后预加载（SDKBootstrap 启动链路里调用）。
    func requestATTThenLoadAd() {
        ATTrackingManager.requestTrackingAuthorization { _ in
            Task { @MainActor in self.loadRewardedAd() }
        }
    }

    // MARK: - 加载

    func loadRewardedAd() {
        guard !isLoadingAd else { return }
        guard Self.isSDKStarted else {
            pendingLoad = true   // SDK 还没起来，等就绪后自动加载
            return
        }
        isLoadingAd = true
        isAdLoaded = false

        // 当前：Debug 也直接用正式 GroMore 广告位验证真实广告
        // TODO: 验证通过后恢复 Debug=官方 iOS 测试位 945113162（配套测试应用 5000546）
        let slotID = APIConfig.gromoreRewardSlotID
        print("🛠 [Ad] loadRewardedAd slot=\(slotID) sdkStarted=\(Self.isSDKStarted)")
        let slot = BUAdSlot()
        slot.id = slotID
        slot.adType = .rewardVideo
        slot.position = .bottom

        let model = BURewardedVideoModel()
        model.rewardName = String(localized: "sponsor.rewardName")
        model.rewardAmount = 1

        rewardedVideoAd = BUNativeExpressRewardedVideoAd(slot: slot, rewardedVideoModel: model)
        rewardedVideoAd?.delegate = self
        rewardedVideoAd?.loadData()
    }

    // MARK: - 展示

    func presentRewardedAd() {
        guard let ad = rewardedVideoAd else {
            loadRewardedAd()
            return
        }
        // 从当前顶部的 viewController 展示（SwiftUI 环境下取 root）
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { return }
        let top = Self.topmost(from: root)
        baseTopVC = top
        closeNotified = false
        if !ad.show(fromRootViewController: top) {
            isAdLoaded = false
            loadRewardedAd()
        }
    }

    private static func topmost(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController { return topmost(from: presented) }
        if let nav = vc as? UINavigationController, let last = nav.visibleViewController { return topmost(from: last) }
        return vc
    }

    /// 展示前记录了 app 侧的顶层 VC；轮询到它重新成为顶层，说明广告页已关闭，
    /// 此时再触发 onAdClose，避免弹窗被还挂在屏幕上的广告页吞掉。
    private func notifyCloseWhenAdDismissed(rewarded: Bool) {
        Task { @MainActor in
            for _ in 0..<120 {  // 最多等 30 秒
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let base = self.baseTopVC,
                      let root = UIApplication.shared.connectedScenes
                          .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                          .first else { return }
                if Self.topmost(from: root) === base { break }
            }
            guard !self.closeNotified else { return }
            self.closeNotified = true
            print("🛠 [Ad] 广告页已关闭（轮询检测），触发 onAdClose(\(rewarded))")
            self.onAdClose?(rewarded)
        }
    }
}

// MARK: - 激励视频代理（SDK 内部线程回调，切回主线程更新状态）

extension AdManager: BUNativeExpressRewardedVideoAdDelegate {
    nonisolated func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in
            self.isLoadingAd = false
            print("🛠 [Ad] 广告数据加载成功（等待素材下载）")
        }
    }

    nonisolated func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        Task { @MainActor in
            self.isLoadingAd = false
            self.isAdLoaded = false
            print("🛠 [Ad] ❌ 广告加载失败: \(error.map(String.init(describing:)) ?? "nil")")
        }
    }

    nonisolated func nativeExpressRewardedVideoAdDidDownLoadVideo(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in
            self.isAdLoaded = true
            print("🛠 [Ad] ✅ 素材就绪，可展示")
        }
    }

    nonisolated func nativeExpressRewardedVideoAdDidVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {}

    /// 客户端奖励回调：用户完整看完广告时触发（无需服务端验证）。
    nonisolated func nativeExpressRewardedVideoAdServerRewardDidSucceed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, verify: Bool) {
        Task { @MainActor in
            print("🛠 [Ad] ✅ 奖励回调触发 verify=\(verify)")
            self.onReward?()
            self.rewardReceived = true
            // 穿山甲看完后跳过可能不回调 didClose，轮询等广告页真正关闭后再触发感谢弹窗
            self.notifyCloseWhenAdDismissed(rewarded: true)
        }
    }

    nonisolated func nativeExpressRewardedVideoAdServerRewardDidFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error?) {}

    /// 广告关闭回调：无论用户是否看完、是否获得奖励都会触发。
    nonisolated func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in
            let rewarded = self.rewardReceived

            self.isAdLoaded = false
            self.rewardReceived = false  // 重置状态

            print("🛠 [Ad] 广告关闭 rewarded=\(rewarded)")
            if !self.closeNotified {
                self.closeNotified = true
                self.onAdClose?(rewarded)
            }

            // 延迟 0.5 秒后预加载下一次广告，让 SDK 有时间清理旧对象
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 秒
                self.loadRewardedAd()
            }
        }
    }

    nonisolated func nativeExpressRewardedVideoAdViewRenderFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error?) {
        Task { @MainActor in
            self.isLoadingAd = false
            self.isAdLoaded = false
            self.loadRewardedAd()
        }
    }
}
