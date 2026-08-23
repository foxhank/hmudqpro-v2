import SwiftUI

/// 设置页：账号 / 小组件 / 应用 / 链接 / 关于。
struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var toast: String?

    var body: some View {
        List {
            // MARK: 账号
            Section(String(localized: "settings.account")) {
                Button {
                    auth.logout()
                } label: {
                    LabeledContent(String(localized: "settings.switchAccount"),
                                   value: auth.studentInfo?.studentID ?? "")
                }
                Button(String(localized: "settings.refreshSession")) {
                    Task {
                        let ok = await SessionKeeper.shared.reloginIfPossible()
                        toast = ok
                            ? String(localized: "settings.refreshSession.ok")
                            : String(localized: "settings.refreshSession.fail")
                    }
                }
                Button(String(localized: "settings.logout"), role: .destructive) {
                    auth.logout()
                }
            }

            // MARK: 小组件
            Section {
                NavigationLink { WidgetGuideView() } label: {
                    Label(String(localized: "settings.addWidget"), systemImage: "square.grid.2x2")
                }
            } header: {
                Text(String(localized: "settings.widget"))
            } footer: {
                Text(String(localized: "settings.widget.footer"))
            }

            // MARK: 应用
            Section(String(localized: "settings.app")) {
                NavigationLink { UpdateCheckView() } label: {
                    Label(String(localized: "settings.checkUpdate"), systemImage: "arrow.down.circle")
                }
                Link(destination: APIConfig.feedbackURL) {
                    Label(String(localized: "settings.feedback"), systemImage: "bubble.left.and.exclamationmark.bubble.right")
                }
                ShareLink(item: URL(string: "https://apps.apple.com/app/id\(APIConfig.appStoreID)")!) {
                    Label(String(localized: "settings.share"), systemImage: "square.and.arrow.up")
                }
            }

            // MARK: 链接
            Section(String(localized: "settings.links")) {
                NavigationLink {
                    WebViewScreen(titleKey: "settings.homepage", url: APIConfig.homepageURL)
                } label: {
                    Label(String(localized: "settings.homepage"), systemImage: "house.fill")
                }
                Link(destination: APIConfig.giteeRepo) {
                    Label(String(localized: "settings.source"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
                NavigationLink { AboutView() } label: {
                    Label(String(localized: "settings.about"), systemImage: "info.circle")
                }
            }
        }
        .navigationTitle(String(localized: "settings.title"))
        .navigationBarTitleDisplayMode(.inline)
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
    }
}

// MARK: - 检查更新

/// 更新信息（后端 /update?platform=ios）。
struct UpdateInfo: Decodable, Equatable {
    let version: String
    let versionCode: Int
    let forceUpdate: Bool
    let updateLog: String
    let downloadLink: String

    enum CodingKeys: String, CodingKey {
        case version, versionCode
        case forceUpdate = "force_update"
        case updateLog = "update_log"
        case downloadLink = "download_link"
    }
}

enum UpdateService {
    /// 检查更新；nil = 已是最新或接口异常（异常抛出）。
    static func check() async throws -> UpdateInfo? {
        let path = APIConfig.updatePath.contains("?")
            ? APIConfig.updatePath + "&versionCode=\(currentVersionCode)"
            : APIConfig.updatePath + "?versionCode=\(currentVersionCode)"
        let url = URL(string: APIConfig.backendBase.absoluteString + path)!
        let (data, _) = try await APIClient.shared.request(url, userAgent: APIConfig.appUserAgent)
        let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
        return info.versionCode > currentVersionCode ? info : nil
    }

    static var currentVersionCode: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1") ?? 1
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

struct UpdateCheckView: View {
    @State private var isLoading = false
    @State private var info: UpdateInfo?
    @State private var upToDate = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text(UpdateService.currentVersion).font(.headline)
                        Text(String(localized: "update.currentVersion"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(String(localized: "update.check")) {
                        Task { await check() }
                    }
                    .disabled(isLoading)
                }
            }
            if isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
            if let error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }
            if upToDate {
                Label(String(localized: "update.upToDate"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            if let info {
                Section(String(format: String(localized: "update.newVersion"), info.version)) {
                    Text(info.updateLog).font(.footnote)
                    if let url = URL(string: info.downloadLink.isEmpty
                                     ? "https://apps.apple.com/app/id\(APIConfig.appStoreID)"
                                     : info.downloadLink) {
                        Link(destination: url) {
                            Label(String(localized: "update.download"), systemImage: "arrow.down.circle.fill")
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.checkUpdate"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func check() async {
        isLoading = true
        error = nil
        info = nil
        upToDate = false
        defer { isLoading = false }
        do {
            if let result = try await UpdateService.check() {
                info = result
            } else {
                upToDate = true
            }
        } catch is CancellationError {
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - 关于

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text(String(localized: "app.name")).font(.title3.bold())
                    Text("v\(UpdateService.currentVersion) (\(UpdateService.currentVersionCode))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section(String(localized: "settings.about")) {
                NavigationLink {
                    WebViewScreen(titleKey: "about.privacy",
                                  url: APIConfig.privacyDocURL)
                } label: {
                    Text(String(localized: "about.privacy"))
                }
                NavigationLink {
                    WebViewScreen(titleKey: "about.agreement",
                                  url: APIConfig.agreementDocURL)
                } label: {
                    Text(String(localized: "about.agreement"))
                }
            }
        }
        .navigationTitle(String(localized: "settings.about"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
