import SwiftUI

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
