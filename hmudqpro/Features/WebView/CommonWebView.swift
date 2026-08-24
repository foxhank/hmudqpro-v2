import SwiftUI
import WebKit
import AVFoundation

/// 通用内置 WebView（智慧考核 / 快捷跳转共用）：
/// 预灌 App 会话 Cookie（webvpn SSO 自动登录）、失效自动重登重试、登录页自动填充、
/// 摄像头/麦克风对接系统授权、文件上传原生支持。
// MARK: - WKWebView

struct CookieWebView: UIViewRepresentable {
    let url: URL
    let onHardFailure: () -> Void
    let onCameraDenied: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()   // 持久化：站内产生的会话下次仍在
        config.applicationNameForUserAgent = " " + APIConfig.webUserAgent

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView

        Task { await context.coordinator.load(url: url) }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(onHardFailure: onHardFailure, onCameraDenied: onCameraDenied)
    }
}

// MARK: - 导航协调器（自动登录状态机）

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    let onHardFailure: () -> Void
    let onCameraDenied: () -> Void
    weak var webView: WKWebView?
    /// 重登重试只做一次，避免「失败→重载→又失败」死循环
    private var retriedAfterRelogin = false
    private var filledCredentials = false

    init(onHardFailure: @escaping () -> Void, onCameraDenied: @escaping () -> Void) {
        self.onHardFailure = onHardFailure
        self.onCameraDenied = onCameraDenied
    }

    func load(url: URL) async {
        await Self.seedCookies()
        webView?.load(URLRequest(url: url))
    }

    /// 清空 WKWebView 共享 cookie store（切换账号时清旧会话）。
    static func purgeCookieStore() {
        let store = WKWebsiteDataStore.default().httpCookieStore
        store.getAllCookies { cookies in
            cookies.forEach { store.delete($0) }
        }
    }

    /// 把 App 会话 Cookie（HTTPCookieStorage）灌进 WKWebView 的 cookie store。
    static func seedCookies() async {
        let store = WKWebsiteDataStore.default().httpCookieStore
        for cookie in CookieSession.shared.currentCookies() {
            await store.setCookie(cookie)
        }
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }

        // Cookie 失效特征：被踢到 webvpn 的 vpn_key/update（reason=site not found）
        if url.absoluteString.contains("/vpn_key/update") {
            guard !retriedAfterRelogin else {
                onHardFailure()
                return
            }
            retriedAfterRelogin = true
            Task {
                if await SessionKeeper.shared.reloginIfPossible() {
                    await Self.seedCookies()
                    webView.load(URLRequest(url: APIConfig.zhcpBase))
                } else {
                    onHardFailure()
                }
            }
            return
        }

        // 兜底：停在统一认证登录页 → 自动填充学号/密码（不代点登录）
        if !filledCredentials, isUnifiedLoginPage(url) {
            filledCredentials = true
            fillCredentials()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onHardFailure()
    }

    // MARK: 摄像头/麦克风（扫码签到用 getUserMedia）

    /// iOS 15+：网页请求 getUserMedia 时回调。
    /// 对接系统级 AVCaptureDevice 授权：系统弹窗只出现一次，决定会被记住，
    /// 之后按授权状态直接放行/拒绝，不再反复骚扰。
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let mediaType: AVMediaType = type == .microphone ? .audio : .video
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            decisionHandler(.grant)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                DispatchQueue.main.async {
                    decisionHandler(granted ? .grant : .deny)
                }
            }
        case .denied, .restricted:
            // 已被拒（含早期无用途描述版本被系统自动拒绝的存量状态）→ 引导去设置
            DispatchQueue.main.async { self.onCameraDenied() }
            decisionHandler(.deny)
        @unknown default:
            decisionHandler(.deny)
        }
    }

    // MARK: 文件上传

    /// iOS 14+：网页 <input type="file"> 点开系统文件选择器由 WKWebView 原生处理，
    /// 这里无需代理；相册/相机的用途描述在 Info.plist（NSPhotoLibraryUsageDescription 等）。


    private func isUnifiedLoginPage(_ url: URL) -> Bool {
        let s = url.absoluteString
        return s.contains("/users/auth") || s.contains("cas/login") || s.contains("login")
    }

    /// 统一认证表单自动填充：优先常见 id/name，兜底取页面第一个文本框 + 密码框。
    private func fillCredentials() {
        guard let studentID = KeychainStore.string(forKey: KeychainStore.Keys.studentID),
              let password = KeychainStore.string(forKey: KeychainStore.Keys.password),
              let webView else { return }
        let js = """
        (function() {
            function pick(selectors) {
                for (var i = 0; i < selectors.length; i++) {
                    var el = document.querySelector(selectors[i]);
                    if (el) return el;
                }
                return null;
            }
            var user = pick(['#username', 'input[name="username"]', 'input[name="user"]',
                             'input[placeholder*="学号"]', 'input[placeholder*="账号"]']);
            var pass = pick(['#password', 'input[name="password"]',
                             'input[type="password"]']);
            if (!user) user = pick(['input[type="text"]', 'input:not([type])']);
            if (!user || !pass) return 'no-fields';
            user.value = '\(studentID)';
            user.dispatchEvent(new Event('input', {bubbles: true}));
            pass.value = '\(password)';
            pass.dispatchEvent(new Event('input', {bubbles: true}));
            return 'filled';
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}


// MARK: - 可推入的通用网页页（工具页快捷跳转用）

struct WebViewScreen: View {
    let titleKey: String
    let url: URL
    @State private var loadFailed = false
    @State private var cameraDenied = false

    var body: some View {
        ZStack {
            if loadFailed {
                WebRetryView { loadFailed = false }
            } else {
                CookieWebView(url: url,
                              onHardFailure: { loadFailed = true },
                              onCameraDenied: { cameraDenied = true })
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle(NSLocalizedString(titleKey, comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "assessment.cameraDenied.title"), isPresented: $cameraDenied) {
            Button(String(localized: "assessment.cameraDenied.settings")) {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button(String(localized: "common.done"), role: .cancel) {}
        } message: {
            Text(String(localized: "assessment.cameraDenied.message"))
        }
    }
}

private struct WebRetryView: View {
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
