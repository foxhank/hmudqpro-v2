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

    /// BUAdSDK 是异步启动的：未就绪就创建广告对象会抛 ObjC 异常闪退。
    /// SDKBootstrap 启动完成回调里调 sdkDidStart()，之前进来的加载请求先挂起。
    private static var isSDKStarted = false
    private var pendingLoad = false

    /// 奖励发放成功回调（服务端校验通过后触发）。
    var onReward: (() -> Void)?

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

        print("🛠 [Ad] loadRewardedAd slot=\(APIConfig.gromoreRewardSlotID) sdkStarted=\(Self.isSDKStarted)")
        let slot = BUAdSlot()
        slot.id = APIConfig.gromoreRewardSlotID
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
}

// MARK: - 激励视频代理（SDK 内部线程回调，切回主线程更新状态）

extension AdManager: BUNativeExpressRewardedVideoAdDelegate {
    nonisolated func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in self.isLoadingAd = false }
    }

    nonisolated func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        Task { @MainActor in
            self.isLoadingAd = false
            self.isAdLoaded = false
        }
    }

    nonisolated func nativeExpressRewardedVideoAdDidDownLoadVideo(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in self.isAdLoaded = true }
    }

    nonisolated func nativeExpressRewardedVideoAdDidVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {}

    nonisolated func nativeExpressRewardedVideoAdServerRewardDidSucceed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, verify: Bool) {
        Task { @MainActor in self.onReward?() }
    }

    nonisolated func nativeExpressRewardedVideoAdServerRewardDidFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error?) {}

    nonisolated func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Task { @MainActor in
            self.isAdLoaded = false
            self.loadRewardedAd()   // 看完立刻为下一次预加载
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
