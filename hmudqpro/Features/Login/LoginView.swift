import SwiftUI

/// 登录页（对齐安卓）：大标题 + 分离的圆角输入框 + 密码可见切换 + 默认密码提示 +
/// 保存密码/协议勾选 + 免责声明 + 登录按钮；失败页内报错 + 弹窗，带防呆提示。
struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var studentID = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var savePassword = true
    @State private var agreed = false
    @State private var showFailureAlert = false
    @State private var showAgreement = false
    @State private var showPrivacy = false
    @FocusState private var focusedField: Field?

    private enum Field { case studentID, password }

    /// 输入中的防呆提示（橙字）。
    private var liveHint: String? { PasswordAdvisor.hint(for: password) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(String(localized: "app.name"))
                    .font(.largeTitle.bold())
                    .padding(.top, 48)

                VStack(spacing: 16) {
                    // 学号
                    inputField(text: $studentID, placeholderKey: "login.studentId")
                        .keyboardType(.numberPad)
                        .textContentType(.username)
                        .focused($focusedField, equals: .studentID)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                    // 密码 + 可见切换
                    HStack(spacing: 0) {
                        Group {
                            if showPassword {
                                TextField(NSLocalizedString("login.password", comment: ""), text: $password)
                            } else {
                                SecureField(NSLocalizedString("login.password", comment: ""), text: $password)
                            }
                        }
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await login() } }

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: showPassword ? "login.passwordHide" : "login.passwordShow"))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 6) {
                        // 默认密码提示
                        Text(String(localized: "login.passwordTip"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        // 防呆提示（输错了马上提示）
                        if let hint = liveHint {
                            Text(hint)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Button {
                            savePassword.toggle()
                        } label: {
                            Image(systemName: savePassword ? "checkmark.square.fill" : "square")
                                .foregroundStyle(savePassword ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        Text(String(localized: "login.savePassword"))
                            .font(.subheadline)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { savePassword.toggle() }

                    agreementRow
                }
                .padding(.horizontal, 24)

                // 免责声明
                Text(String(localized: "login.securityNotice"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // 登录按钮
                Button {
                    Task { await login() }
                } label: {
                    HStack {
                        Spacer()
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(String(localized: "login.submit")).bold()
                        }
                        Spacer()
                    }
                    .frame(height: 50)
                    .background(canSubmit ? Color.accentColor : Color(.systemGray4),
                                in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 24)

                // 页内错误
                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // 回填上次学号（密码在 Keychain，自动登录由 SessionKeeper 处理）
            studentID = KeychainStore.string(forKey: KeychainStore.Keys.studentID) ?? ""
        }
        .sheet(isPresented: $showAgreement) { docSheet(key: "about.agreement", url: APIConfig.agreementDocURL) }
        .sheet(isPresented: $showPrivacy) { docSheet(key: "about.privacy", url: APIConfig.privacyDocURL) }
        .alert(String(localized: "login.failed.title"), isPresented: $showFailureAlert) {
            Button(String(localized: "common.done"), role: .cancel) {}
        } message: {
            if let hint = failureHint {
                Text("\(auth.errorMessage ?? "")\n\n\(hint)")
            } else {
                Text(auth.errorMessage ?? "")
            }
        }
    }

    private var canSubmit: Bool {
        !auth.isLoading && !studentID.isEmpty && !password.isEmpty
    }

    /// 登录失败时结合输入给防呆提示。
    private var failureHint: String? { PasswordAdvisor.hint(for: password) }

    /// 协议勾选行：勾选框 + 超链接文案。
    private var agreementRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                agreed.toggle()
            } label: {
                Image(systemName: agreed ? "checkmark.square.fill" : "square")
                    .font(.body)
                    .foregroundStyle(agreed ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            (Text(String(localized: "login.agreementPrefix"))
             + Text(String(localized: "about.agreement")).underline().foregroundColor(.accentColor)
             + Text(String(localized: "login.and"))
             + Text(String(localized: "about.privacy")).underline().foregroundColor(.accentColor))
                .font(.subheadline)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { showAgreement = true }
    }

    /// 学号输入框样式（圆角分离卡片）。
    private func inputField(text: Binding<String>, placeholderKey: String) -> some View {
        TextField(NSLocalizedString(placeholderKey, comment: ""), text: text)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    /// 协议/隐私文档弹层（内置 WebView）。
    private func docSheet(key: String, url: URL) -> some View {
        NavigationStack {
            WebViewScreen(titleKey: key, url: url)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.done")) { showAgreement = false; showPrivacy = false }
                    }
                }
        }
    }

    private func login() async {
        guard agreed else {
            auth.errorMessage = String(localized: "login.suggestAgreement")
            return
        }
        await auth.login(studentID: studentID, password: password)
        if auth.errorMessage != nil {
            showFailureAlert = true
        } else if !savePassword {
            // 未勾选保存密码：登录成功后清除密码（学号保留方便回填），代价是自动重登不可用
            KeychainStore.remove(forKey: KeychainStore.Keys.password)
        }
    }
}
