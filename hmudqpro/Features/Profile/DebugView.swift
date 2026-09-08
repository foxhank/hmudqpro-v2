import SwiftUI

/// 调试页面：真机功能测试入口（更新检查、课表刷新、缓存/会话状态）。
struct DebugView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var resultText: String?
    @State private var running = false

    // 调试：课程调换（两个 Picker 选课名）
    @State private var swapA = ""
    @State private var swapB = ""
    // 调试：伪造更新
    @State private var fakeVersion = "9.9.9"
    @State private var fakeForce = false
    @State private var fakeUpdateOn = false
    // 调试：模拟教务故障（0 = 关闭）
    @State private var jwcFault = DebugStore.jwcFailureStatus ?? 0
    // 调试：开屏彩蛋
    @State private var forceHoliday = DebugStore.forceHoliday
    @State private var forceBirthday = DebugStore.forceBirthday

    private var courseNames: [String] {
        Array(Set((ScheduleStore.shared?.load() ?? []).map(\.kcmc))).sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                Section("debug.section.simulate") {
                    // MARK: 课程调换（重启后课表刷新 → 弹「课表变动」提醒）
                    Picker("debug.sim.swapA", selection: $swapA) {
                        Text("common.none").tag("")
                        ForEach(courseNames, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("debug.sim.swapB", selection: $swapB) {
                        Text("common.none").tag("")
                        ForEach(courseNames, id: \.self) { Text($0).tag($0) }
                    }
                    Button("debug.sim.applySwap") {
                        DebugStore.setCourseSwap([swapA, swapB])
                        resultText = "已设置调换：\(swapA) ⇄ \(swapB)（重启生效，课表页刷新后弹变动提醒）"
                    }
                    .disabled(swapA.isEmpty || swapB.isEmpty || swapA == swapB)
                    Button("debug.sim.clearSwap", role: .destructive) {
                        DebugStore.setCourseSwap(nil)
                        resultText = "已清除课程调换"
                    }
                    .disabled(DebugStore.courseSwap.isEmpty)
                }

                // MARK: 模拟教务故障（立即生效）
                Section("debug.section.jwcFault") {
                    Picker("debug.sim.jwcFaultCode", selection: $jwcFault) {
                        Text("common.none").tag(0)
                        Text("弱网：慢 4 秒").tag(-4)
                        Text("极弱网：慢 8 秒").tag(-8)
                        Text("挂起（不响应）").tag(-1)
                        Text("404").tag(404)
                        Text("500").tag(500)
                        Text("502").tag(502)
                        Text("503").tag(503)
                    }
                    .onChange(of: jwcFault) { code in
                        DebugStore.setJwcFailureStatus(code == 0 ? nil : code)
                        resultText = code == 0 ? "已关闭教务故障模拟，后续请求恢复正常"
                                               : "已开启模拟教务故障：\(code == -1 ? "挂起（不响应）" : code < 0 ? "延迟 \(abs(code)) 秒弱网" : "返回 HTTP \(code)")"
                    }
                    Text("立即生效。登录/课表/成绩等所有教务请求都会收到该状态码，后端与内置网页不受影响。退出登录后重新登录，可测试登录报错与「看缓存课表」入口。选「挂起」模拟连接挂死：请求 10 秒无响应被强制终止并提示超时，整条登录链 15 秒兜底。弱网档延迟后转发真实请求（响应是真的，只是慢）：单步 10 秒内能过，登录链总时长超 15 秒会被总闸截断。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: 开屏彩蛋（重启生效）
                Section("debug.section.splash") {
                    Toggle("debug.sim.holiday", isOn: $forceHoliday)
                        .onChange(of: forceHoliday) { DebugStore.forceHoliday = $0 }
                    Toggle("debug.sim.birthday", isOn: $forceBirthday)
                        .onChange(of: forceBirthday) { DebugStore.forceBirthday = $0 }
                }

                // MARK: 伪造更新（重启生效）
                Section("debug.section.fakeUpdate") {
                    TextField("debug.sim.version", text: $fakeVersion)
                        .keyboardType(.decimalPad)
                    Toggle("debug.sim.force", isOn: $fakeForce)
                    Toggle("debug.sim.fakeOn", isOn: $fakeUpdateOn)
                        .onChange(of: fakeUpdateOn) { on in
                            if on {
                                DebugStore.setFakeUpdate(UpdateInfo(
                                    version: fakeVersion,
                                    versionCode: 9999,
                                    forceUpdate: fakeForce,
                                    updateLog: "【调试】伪造的更新日志：用于测试更新弹窗。",
                                    downloadLink: "https://apps.apple.com/app/id\(APIConfig.appStoreID)"))
                                resultText = "已启用伪造更新 v\(fakeVersion)（重启生效，课表页弹更新框）"
                            } else {
                                DebugStore.setFakeUpdate(nil)
                                resultText = "已关闭伪造更新"
                            }
                        }
                }

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
            .onAppear {
                fakeUpdateOn = DebugStore.fakeUpdate != nil
                if let f = DebugStore.fakeUpdate { fakeVersion = f.version; fakeForce = f.forceUpdate }
                forceHoliday = DebugStore.forceHoliday
                forceBirthday = DebugStore.forceBirthday
            }
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
