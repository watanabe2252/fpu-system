import SwiftUI

struct UserAdminView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @Environment(\.dismiss) private var dismiss
    @State private var users: [UserRoleRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @State private var newEmail = ""
    @State private var newPassword = ""
    @State private var newRole: UserRoleType = .staff
    @State private var isCreating = false
    @State private var createStatus: String?

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            listContent
                .frame(maxWidth: 640)
            Spacer(minLength: 0)
        }
        .background(Theme.bgDark)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
        }
        #else
        listContent
        #endif
    }

    private var listContent: some View {
        List {
            Section {
                if isLoading {
                    ProgressView().tint(Theme.accentBlue)
                } else if users.isEmpty {
                    Text("管理可能なアカウントが存在しません。")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.gray)
                } else {
                    ForEach(users) { user in
                        HStack {
                            Text(user.email)
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(user.role == .admin ? "管理者" : "現場スタッフ")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(user.role == .admin ? Theme.amber.opacity(0.15) : Theme.borderStroke.opacity(0.5))
                                .foregroundStyle(user.role == .admin ? Theme.amber : .gray)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Button {
                                Task { await toggleRole(user) }
                            } label: {
                                Text("権限切替")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(Theme.accentBlue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.bgDark)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .listRowBackground(Theme.cardBg)
                }
            } header: {
                Text("アカウント権限管理").foregroundStyle(Theme.accentBlue)
            } footer: {
                Text("システム絶対権限の admin@fpu.system は保護されます。")
                    .font(.system(size: 9, weight: .bold))
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("メールアドレス", text: $newEmail)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                        .autocorrectionDisabled()
                    SecureField("パスワード(6文字以上)", text: $newPassword)
                    Picker("初期権限", selection: $newRole) {
                        Text("現場スタッフ").tag(UserRoleType.staff)
                        Text("管理者").tag(UserRoleType.admin)
                    }
                    .pickerStyle(.segmented)

                    Button {
                        Task { await createAccount() }
                    } label: {
                        if isCreating {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("アカウントを作成").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(newEmail.trimmingCharacters(in: .whitespaces).isEmpty || newPassword.count < 6 || isCreating)

                    if let createStatus {
                        Text(createStatus)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(createStatus.hasPrefix("✔") ? Theme.accentGreen : Theme.rose)
                    }
                }
                .listRowBackground(Theme.cardBg)
            } header: {
                Text("新規アカウント作成").foregroundStyle(Theme.accentBlue)
            } footer: {
                Text("作成したアカウントは、そのメールアドレス・パスワードでログインできるようになります。")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.plain)
        #endif
        .scrollContentBackground(.hidden)
        .background(Theme.bgDark)
        .navigationTitle("アカウント権限管理")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            users = try await supabase.fetchManagedUserRoles()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleRole(_ user: UserRoleRecord) async {
        let next: UserRoleType = user.role == .admin ? .staff : .admin
        do {
            try await supabase.setUserRole(id: user.id, role: next)
            if user.id == supabase.currentUserId {
                supabase.currentUserRole = next
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createAccount() async {
        isCreating = true
        createStatus = nil
        do {
            try await supabase.createUserAccount(
                email: newEmail.trimmingCharacters(in: .whitespaces),
                password: newPassword,
                role: newRole
            )
            createStatus = "✔ アカウントを作成しました"
            newEmail = ""
            newPassword = ""
            newRole = .staff
            await load()
        } catch {
            createStatus = "❌ \(error.localizedDescription)"
        }
        isCreating = false
    }
}
