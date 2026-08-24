import SwiftUI

/// 打赏页（v1 DonationView 移植）：看广告献爱心。
/// 黄色主题；项目简介 + 今日/历史贡献 + 激励广告按钮 + 爱心排行榜 + 昵称设置。
struct SponsorView: View {
    @StateObject private var adManager = AdManager.shared
    @State private var nickname: String
    @State private var rankings: [DonationService.DonationRanking] = []
    @State private var me: DonationService.DonationRanking?
    @State private var todayCount = 0
    @State private var showNicknameEdit = false
    @State private var showThanks = false
    @State private var toast: String?
    @State private var errorMessage: String?
    @State private var isLoading = true

    private let yellow = Color(red: 0.9, green: 0.7, blue: 0.0)
    private let service = DonationService()

    init() {
        _nickname = State(initialValue: UserDefaults.standard.string(forKey: "donation.nickname") ?? "")
        _todayCount = State(initialValue: UserDefaults.standard.integer(forKey: "donation.today.\(Self.todayKey())"))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 标题
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(yellow)
                    Text(String(localized: "donation.title")).font(.title.bold())
                    Text(String(localized: "donation.subtitle"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 16)

                // 项目简介
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "donation.about")).font(.headline)
                    aboutBullet("lightbulb.fill", "donation.about.1")
                    aboutBullet("heart.circle.fill", "donation.about.2")
                    aboutBullet("hand.raised.fill", "donation.about.3")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // 统计
                HStack(spacing: 12) {
                    statCard(titleKey: "donation.today", value: todayCount, tint: yellow)
                    statCard(titleKey: "donation.total", value: me?.donationCount ?? 0, tint: .blue)
                }
                .padding(.horizontal)

                // 看广告按钮
                Button {
                    watchAd()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill").font(.title2)
                        VStack(spacing: 2) {
                            Text(buttonTitle).font(.headline)
                            Text(adManager.isAdLoaded
                                 ? String(localized: "donation.button.ready")
                                 : String(localized: "donation.button.wait"))
                                .font(.caption)
                        }
                        Image(systemName: "heart.fill").font(.title2)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(adManager.isAdLoaded ? yellow : Color(.systemGray3),
                                in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!adManager.isAdLoaded)
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote).foregroundStyle(.red)
                        .padding(.horizontal)
                }

                // 排行榜
                VStack(spacing: 12) {
                    HStack {
                        Text(String(localized: "donation.leaderboard")).font(.headline)
                        Spacer()
                        Button {
                            Task { await load() }
                        } label: {
                            Label(String(localized: "donation.refresh"), systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .foregroundStyle(yellow)
                    }
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else if rankings.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 36)).foregroundStyle(.secondary)
                            Text(String(localized: "donation.leaderboard.empty"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else {
                        ForEach(Array(rankings.enumerated()), id: \.element.id) { index, row in
                            RankingRow(rank: index + 1, row: row)
                        }
                        if let me, !rankings.contains(where: \.isCurrentUser) {
                            RankingRow(rank: nil, row: me)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // 昵称入口
                Button {
                    showNicknameEdit = true
                } label: {
                    Label(nickname.isEmpty ? String(localized: "donation.setNickname")
                                           : nickname,
                          systemImage: "person.circle")
                        .font(.subheadline)
                }
                .foregroundStyle(yellow)
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "tool.sponsor"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNicknameEdit = true
                } label: {
                    Image(systemName: "person.circle")
                }
                .foregroundStyle(yellow)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showNicknameEdit) {
            NicknameEditSheet(nickname: nickname) { newName in
                Task {
                    do {
                        let msg = try await service.rename(nickname: newName)
                        nickname = newName
                        UserDefaults.standard.set(newName, forKey: "donation.nickname")
                        toast = msg
                        await load()
                    } catch {
                        toast = error.localizedDescription
                    }
                }
            }
        }
        .alert(String(localized: "donation.thanks.title"), isPresented: $showThanks) {
            Button(String(localized: "common.done"), role: .cancel) {}
        } message: {
            Text(String(localized: "donation.thanks.message"))
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.footnote)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 12)
            }
        }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.toast = nil
        }
        .onAppear {
            adManager.onReward = {
                Task { await submitDonation() }
            }
        }
    }

    private var buttonTitle: String {
        if adManager.isAdLoaded { return String(localized: "donation.button.ready.title") }
        if adManager.isLoadingAd { return String(localized: "donation.button.loading") }
        return String(localized: "donation.button.load")
    }

    private func aboutBullet(_ icon: String, _ key: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(yellow).font(.subheadline).padding(.top, 2)
            Text(NSLocalizedString(key, comment: ""))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func statCard(titleKey: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(.caption).foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(tint)
            Text(String(localized: "donation.times"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(tint.opacity(0.6)))
    }

    // MARK: - 动作

    private func watchAd() {
        adManager.presentRewardedAd()
    }

    private func submitDonation() async {
        do {
            _ = try await service.submitDonation(nickname: nickname)
            todayCount += 1
            UserDefaults.standard.set(todayCount, forKey: "donation.today.\(Self.todayKey())")
            showThanks = true
            await load()
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func load() async {
        isLoading = rankings.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.leaderboard()
            rankings = result.list
            me = result.me
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }
}

// MARK: - 排行行

private struct RankingRow: View {
    let rank: Int?          // nil = 榜外当前用户
    let row: DonationService.DonationRanking

    var body: some View {
        HStack(spacing: 10) {
            if let rank {
                Text(rankBadge(rank))
                    .font(.subheadline.bold())
                    .foregroundStyle(badgeColor)
                    .frame(width: 34)
            } else {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.nickname.isEmpty ? String(localized: "donation.anonymous") : row.nickname)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if row.isCurrentUser {
                    Text(String(localized: "donation.me")).font(.caption2).foregroundStyle(yellow2)
                }
            }
            Spacer()
            Text("\(row.donationCount)")
                .font(.subheadline.bold())
                .monospacedDigit()
            Text(String(localized: "donation.times"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .background(row.isCurrentUser ? Color.yellow.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var yellow2: Color { Color(red: 0.9, green: 0.7, blue: 0.0) }

    private func rankBadge(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    private var badgeColor: Color {
        switch rank {
        case 1, 2, 3: return yellow2
        default: return .secondary
        }
    }
}

// MARK: - 昵称编辑

private struct NicknameEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var text: String
    let onSave: (String) -> Void

    init(nickname: String, onSave: @escaping (String) -> Void) {
        _text = State(initialValue: nickname)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "donation.nickname.placeholder"), text: $text)
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text(String(localized: "donation.nickname.hint"))
                }
            }
            .navigationTitle(String(localized: "donation.setNickname"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) {
                        onSave(text.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
