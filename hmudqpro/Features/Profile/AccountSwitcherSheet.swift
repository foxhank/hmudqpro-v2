import SwiftUI

/// 账号管理：已保存账号列表（当前 ✓），点击切换（清会话后重登），
/// 左滑删除；「使用其他账号」回登录页。
struct AccountSwitcherSheet: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var accounts = AccountStore.accounts
    @State private var switching: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(accounts) { account in
                        Button {
                            guard account.studentID != AccountStore.currentID else { return }
                            switching = account.studentID
                            Task {
                                await auth.switchAccount(to: account.studentID)
                                switching = nil
                                dismiss()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name.isEmpty ? account.studentID : account.name)
                                        .foregroundStyle(.primary)
                                    Text(account.studentID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if account.studentID == AccountStore.currentID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if switching == account.studentID {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(switching != nil)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            AccountStore.remove(studentID: accounts[index].studentID)
                        }
                        accounts = AccountStore.accounts
                    }
                } footer: {
                    Text(String(localized: "account.switch.hint"))
                }
                Section {
                    Button {
                        dismiss()
                        auth.logout()   // 账号列表保留，登录页可输入新账号
                    } label: {
                        Label(String(localized: "account.useOther"), systemImage: "person.badge.plus")
                    }
                }
            }
            .navigationTitle(String(localized: "settings.switchAccount"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.done")) { dismiss() }
                }
            }
        }
    }
}
