import SwiftUI

// MARK: - 检查更新

/// 更新信息（后端 /update?platform=ios，实测字段全小写：version/versioncode/
/// forceupdate("True"/"False")/updatelog/downloadlink；兼容旧蛇形字段名与布尔类型）。
struct UpdateInfo: Codable, Equatable {
    let version: String
    let versionCode: Int
    let forceUpdate: Bool
    let updateLog: String
    let downloadLink: String

    enum CodingKeys: String, CodingKey {
        case version
        case versionCode = "versioncode"
        case forceUpdate = "forceupdate"
        case updateLog = "updatelog"
        case downloadLink = "downloadlink"
    }

    init(version: String, versionCode: Int, forceUpdate: Bool, updateLog: String, downloadLink: String) {
        self.version = version
        self.versionCode = versionCode
        self.forceUpdate = forceUpdate
        self.updateLog = updateLog
        self.downloadLink = downloadLink
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(String.self, forKey: .version) ?? ""
        versionCode = try c.decodeIfPresent(Int.self, forKey: .versionCode)
            ?? Int(try c.decodeIfPresent(String.self, forKey: .versionCode) ?? "") ?? 0
        // 后端把布尔序列化成字符串 "True"/"False"，也兼容真布尔
        if let s = try c.decodeIfPresent(String.self, forKey: .forceUpdate) {
            forceUpdate = (s as NSString).boolValue
        } else {
            forceUpdate = try c.decodeIfPresent(Bool.self, forKey: .forceUpdate) ?? false
        }
        updateLog = try c.decodeIfPresent(String.self, forKey: .updateLog) ?? ""
        downloadLink = try c.decodeIfPresent(String.self, forKey: .downloadLink) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(versionCode, forKey: .versionCode)
        try c.encode(forceUpdate, forKey: .forceUpdate)
        try c.encode(updateLog, forKey: .updateLog)
        try c.encode(downloadLink, forKey: .downloadLink)
    }
}

enum UpdateService {
    /// 检查更新；nil = 已是最新 / 被用户忽略 / 接口异常（异常抛出）。
    static func check() async throws -> UpdateInfo? {
        let path = APIConfig.updatePath.contains("?")
            ? APIConfig.updatePath + "&versionCode=\(currentVersionCode)"
            : APIConfig.updatePath + "?versionCode=\(currentVersionCode)"
        let url = URL(string: APIConfig.backendBase.absoluteString + path)!
        let (data, _) = try await APIClient.shared.request(url, userAgent: APIConfig.appUserAgent)
        let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
        guard info.versionCode > currentVersionCode, info.versionCode != ignoredVersionCode
        else { return nil }
        return info
    }

    static var currentVersionCode: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1") ?? 1
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private static let ignoreKey = "update.ignoredVersionCode"

    /// 用户点了「忽略此版本」的 versionCode（只忽略该版本，更新版本仍会提示）。
    static var ignoredVersionCode: Int {
        UserDefaults.standard.integer(forKey: ignoreKey)
    }

    static func ignoreVersion(code: Int) {
        UserDefaults.standard.set(code, forKey: ignoreKey)
    }
}

// MARK: - 关于

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 2, y: 1)
                    Text(String(localized: "app.name")).font(.title3.bold())
                    Text("v\(UpdateService.currentVersion) (\(UpdateService.currentVersionCode))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section("about.intro.title") {
                Text("about.intro.content")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("about.ack.title") {
                Text("about.ack.content")
                    .font(.subheadline)
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
