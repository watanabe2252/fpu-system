import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoggingIn = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Label("固定回線システム ログイン", systemImage: "lock.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                Text("ポジション別アカウントでログインしてください")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("メールアドレス / Email")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.gray)
                TextField("example@fpu.system", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding(12)
                    .background(Theme.bgDark)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderStroke))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("パスワード / Password")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.gray)
                SecureField("••••••••", text: $password)
                    .padding(12)
                    .background(Theme.bgDark)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderStroke))
                    .foregroundStyle(.white)
            }

            Button {
                Task { await login() }
            } label: {
                if isLoggingIn {
                    ProgressView().tint(Theme.bgDark)
                } else {
                    Text("ログイン認証")
                        .font(.system(size: 14, weight: .black))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.accentBlue)
            .foregroundStyle(Theme.bgDark)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(email.isEmpty || password.isEmpty || isLoggingIn)

            if let errorMessage {
                Text("⚠️ \(errorMessage)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.rose)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Theme.rose.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.borderStroke))
        .padding(.horizontal, 24)
        .frame(maxWidth: 400)
    }

    private func login() async {
        errorMessage = nil
        isLoggingIn = true
        defer { isLoggingIn = false }
        do {
            try await supabase.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
