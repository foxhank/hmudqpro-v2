import SwiftUI

/// 赞助开发者（v1 SponsorView 移植）：看激励广告支持开发者，回收苹果开发者年费。
/// 纯广告变现，不涉及后端支付；展示年费支付凭证与成本收回进度。
struct SponsorView: View {
    @StateObject private var adManager = AdManager.shared
    @State private var showThanks = false
    @State private var errorMessage: String?

    private let pink = Color.pink

    /// 成本收回计划（后端接口预留，暂 0/688 占位；单位：分，避免浮点）。
    private let recoveredAmount = 0
    private let totalCost = 68800

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(pink)
                    Text(String(localized: "sponsor.watchAd.title")).font(.title2.bold())
                    Text(String(localized: "sponsor.watchAd.subtitle"))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)

                // 看广告按钮
                Button {
                    adManager.presentRewardedAd()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill").font(.title2)
                        VStack(spacing: 2) {
                            Text(buttonTitle).font(.headline)
                            Text(adManager.isAdLoaded
                                 ? String(localized: "sponsor.button.ready")
                                 : String(localized: "sponsor.button.wait"))
                                .font(.caption)
                        }
                        Image(systemName: "heart.fill").font(.title2)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(adManager.isAdLoaded ? pink : Color(.systemGray3),
                                in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!adManager.isAdLoaded)
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote).foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // 开发者年费支付凭证
                VStack(spacing: 8) {
                    Image("sponsor_qr")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4)))
                    Text(String(localized: "sponsor.qr.hint"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                // 成本收回计划
                VStack(spacing: 8) {
                    HStack {
                        Text(String(localized: "sponsor.recovery.title"))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(String(format: "¥%.2f / ¥%.0f",
                                    Double(recoveredAmount) / 100, Double(totalCost) / 100))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(pink)
                    }
                    ProgressView(value: progress)
                        .tint(pink)
                        .scaleEffect(y: 1.3)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "tool.sponsor"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            adManager.onReward = { showThanks = true }
            // ATT 只在这里申请（系统全局只弹一次）；已授权/拒绝过则直接拉广告
            adManager.requestATTThenLoadAd()
        }
        .alert(String(localized: "sponsor.thanks.title"), isPresented: $showThanks) {
            Button(String(localized: "sponsor.thanks.ok"), role: .cancel) {}
        } message: {
            Text(String(localized: "sponsor.thanks.message"))
        }
    }

    private var progress: Double {
        min(1.0, Double(recoveredAmount) / Double(totalCost))
    }

    private var buttonTitle: String {
        if adManager.isAdLoaded { return String(localized: "sponsor.button.ready.title") }
        if adManager.isLoadingAd { return String(localized: "sponsor.button.loading") }
        return String(localized: "sponsor.button.load")
    }
}

#Preview {
    NavigationStack { SponsorView() }
}
