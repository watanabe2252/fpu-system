import SwiftUI

struct UserAdminView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @State private var users: [UserRoleRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
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
}
