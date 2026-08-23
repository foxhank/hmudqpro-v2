import SwiftUI
import WebKit


/// 智慧考核 Tab：WKWebView 承载 zhcp（webvpn SSO）。
///
/// 登录策略（实测浏览器验证）：
/// 1. 预灌 Cookie：把 App 会话的 webvpn Cookie 灌进 WKWebView → 打开 login.aspx
///    会自动 302 到 zhcp-83 首页，全程无感；
/// 2. Cookie 失效：会被踢到 webvpn 的 /vpn_key/update?reason=site...not+found ——
///    检测到该 URL 自动走 SessionKeeper 重登（熔断保护），重灌 Cookie 后重载一次；
/// 3. 仍失败：停在统一认证登录页时，自动帮用户填充学号/密码（不代点登录，防误触）。
struct AssessmentView: View {
    @State private var loadFailed = false
    @State private var cameraDenied = false

    var body: some View {
        NavigationStack {
            ZStack {
                if loadFailed {
                    ErrorRetryView { loadFailed = false }
                } else {
                    CookieWebView(url: APIConfig.zhcpBase,
                                  onHardFailure: { loadFailed = true },
                                  onCameraDenied: { cameraDenied = true })
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle(String(localized: "tab.assessment"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(String(localized: "assessment.cameraDenied.title"),
                   isPresented: $cameraDenied) {
                Button(String(localized: "assessment.cameraDenied.settings")) {
                    let url = URL(string: UIApplication.openSettingsURLString)!
                    UIApplication.shared.open(url)
                }
                Button(String(localized: "common.done"), role: .cancel) {}
            } message: {
                Text(String(localized: "assessment.cameraDenied.message"))
            }
        }
    }
}

// MARK: - 失败重试

private struct ErrorRetryView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(String(localized: "assessment.loadFailed"))
                .foregroundStyle(.secondary)
            Button(String(localized: "common.retry"), action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    AssessmentView()
}
