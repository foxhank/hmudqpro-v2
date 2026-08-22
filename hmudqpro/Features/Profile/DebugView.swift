import SwiftUI

/// 调试页面：真机功能测试入口（更新检查、课表刷新、缓存/会话状态）。
struct DebugView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var resultText: String?
    @State private var running = false

    var body: some View {
        NavigationStack {
            List {
                Section("debug.section.test") {
                    Button {
                        run("更新检查") { try await testUpdateCheck() }
                    } label: {
                        Label("debug.test.update", systemImage: "arrow.down.circle")
                    }
                    Button {
                        run("课表刷新") { try await testScheduleRefresh() }
                    } label: {
                        Label("debug.test.schedule", systemImage: "calendar.badge.clock")
                    }
                    Button {
                        run("登录状态") { try await testSession() }
                    } label: {
                        Label("debug.test.session", systemImage: "person.badge.key")
                    }
                }

                Section("debug.section.data") {
                    Button(role: .destructive) {
                        ScheduleStore.shared?.save([])
                        resultText = "课表缓存已清空（重启 app 后生效）"
                    } label: {
                        Label("debug.data.clearCache", systemImage: "trash")
                    }
                }

                if running {
                    Section { HStack { ProgressView(); Text("debug.running") } }
                }
                if let resultText {
                    Section("debug.section.result") {
                        Text(resultText).font(.footnote.monospaced()).textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("debug.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private func run(_ name: String, _ op: @escaping () async throws -> String) {
        running = true
        resultText = nil
        Task {
            defer { running = false }
            do {
                resultText = "【\(name)】\n" + (try await op())
            } catch {
                resultText = "【\(name)】失败\n\(error.localizedDescription)"
            }
        }
    }

    // MARK: - 测试项

    /// 请求自建后端更新检查接口，展示原始响应。
    private func testUpdateCheck() async throws -> String {
        let url = URL(string: APIConfig.backendBase.absoluteString + APIConfig.updatePath)!
        let (data, resp) = try await APIClient.shared.request(url, userAgent: APIConfig.appUserAgent)
        let body = String(data: data.prefix(500), encoding: .utf8) ?? "(空)"
        return "HTTP \(resp.statusCode)\n\(body)"
    }

    /// 拉一次课表，展示数量与首条课程。
    private func testScheduleRefresh() async throws -> String {
        let courses = try await ScheduleService().fetchCourses()
        let first = courses.first.map { "\($0.kcmc) 第\($0.zc)周 周\($0.xq) \($0.jcdm)" } ?? "(无)"
        return "共 \(courses.count) 条\n首条: \(first)\n范围: \(ScheduleParser.currentSemesterRange().start) ~ \(ScheduleParser.currentSemesterRange().end)"
    }

    /// 会话状态：Cookie、Keychain 凭据、熔断器。
    private func testSession() async throws -> String {
        let cookies = CookieSession.shared.currentCookies()
        let hasID = KeychainStore.string(forKey: KeychainStore.Keys.studentID) != nil
        let hasPwd = KeychainStore.string(forKey: KeychainStore.Keys.password) != nil
        return """
        webvpn Cookie: \(CookieSession.shared.hasWebvpnCookie ? "有效" : "无")
        Cookie 总数: \(cookies.count)
        Keychain 学号: \(hasID ? "已存" : "无")
        Keychain 密码: \(hasPwd ? "已存" : "无")
        重登熔断: \(SessionKeeper.shared.isCircuitOpen ? "打开（冷却中）" : "关闭")
        """
    }
}
