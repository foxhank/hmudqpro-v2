import SwiftUI

/// 登录页：原生表单风格（HIG Form）。
struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var studentID = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case studentID, password }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("app.name")
                .font(.title2.bold())

            Form {
                Section {
                    TextField("login.studentId", text: $studentID)
                        .textContentType(.username)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .studentID)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                    SecureField("login.password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await login() } }
                }
                Section {
                    Button {
                        Task { await login() }
                    } label: {
                        HStack {
                            Spacer()
                            if auth.isLoading {
                                ProgressView()
                            } else {
                                Text("login.submit").bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(auth.isLoading || studentID.isEmpty || password.isEmpty)
                }
            }
            .scrollDisabled(true)

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .onAppear {
            // 回填上次学号（密码在 Keychain，自动登录由 SessionKeeper 处理）
            studentID = KeychainStore.string(forKey: KeychainStore.Keys.studentID) ?? ""
        }
    }

    private func login() async {
        await auth.login(studentID: studentID, password: password)
    }
}
