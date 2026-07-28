import SwiftUI

struct ProgramSelectView: View {
    @EnvironmentObject private var supabase: SupabaseService
    let onSelect: (Program) -> Void

    @State private var programs: [Program] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label("大会ファイルを選択", systemImage: "folder.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                if supabase.currentUserRole == .admin {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("新規作成", systemImage: "plus")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Theme.accentGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.accentGreen.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.accentGreen))
                }
            }

            if isLoading {
                ProgressView().tint(Theme.accentBlue)
                Spacer()
            } else if programs.isEmpty {
                Text("ファイルが存在しません。")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.gray)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(programs) { program in
                            Button {
                                onSelect(program)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(program.title)
                                            .font(.system(size: 13, weight: .black))
                                            .foregroundStyle(.white)
                                        Text("ID: \(program.id)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.gray)
                                    }
                                    Spacer()
                                    Text("接続")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Theme.amber)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Theme.bgDark)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .padding(14)
                                .background(Theme.cardBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderStroke))
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.rose)
            }

            Button {
                Task { await supabase.signOut() }
            } label: {
                Label("アカウントサインアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.gray)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderStroke))
        }
        .padding(20)
        .frame(maxWidth: 480)
        .task { await loadPrograms() }
        .sheet(isPresented: $showCreateSheet) {
            CreateProgramSheet { id, title in
                Task {
                    try? await supabase.createProgram(id: id, title: title)
                    await loadPrograms()
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func loadPrograms() async {
        isLoading = true
        errorMessage = nil
        do {
            programs = try await supabase.fetchPrograms()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct CreateProgramSheet: View {
    let onCreate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var id = ""
    @State private var title = ""

    var body: some View {
        ZStack {
            Theme.bgDark.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("新しい中継番組・大会の作成")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.accentBlue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("番組ID (半角英数字)").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    TextField("例: ekiden-2026", text: $id)
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(Theme.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("番組名・大会名称").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    TextField("例: 全日本大学駅伝2026", text: $title)
                        .padding(12)
                        .background(Theme.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Spacer()

                HStack {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.gray)
                    Spacer()
                    Button("保存して登録") {
                        onCreate(id, title)
                        dismiss()
                    }
                    .disabled(id.isEmpty || title.isEmpty)
                    .foregroundStyle(Theme.bgDark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
    }
}
