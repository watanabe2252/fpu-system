import SwiftUI

struct ProgramSelectView: View {
    @EnvironmentObject private var supabase: SupabaseService
    let onSelect: (Program) -> Void

    @State private var programs: [Program] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var duplicateSource: Program?
    @State private var deleteTarget: Program?

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
                            HStack(spacing: 8) {
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
                                }

                                if supabase.currentUserRole == .admin {
                                    Button {
                                        duplicateSource = program
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundStyle(.gray)
                                            .padding(8)
                                            .background(Theme.bgDark)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    Button {
                                        deleteTarget = program
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(Theme.rose)
                                            .padding(8)
                                            .background(Theme.bgDark)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                            .padding(14)
                            .background(Theme.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderStroke))
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
        .sheet(item: $duplicateSource) { source in
            DuplicateProgramSheet(source: source) { targetId, targetTitle in
                Task {
                    try? await supabase.duplicateProgram(sourceId: source.id, targetId: targetId, targetTitle: targetTitle)
                    await loadPrograms()
                }
            }
            .presentationDetents([.medium])
        }
        .alert("大会を削除しますか?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("キャンセル", role: .cancel) { deleteTarget = nil }
            Button("削除する", role: .destructive) {
                if let target = deleteTarget {
                    Task {
                        try? await supabase.deleteProgram(id: target.id)
                        await loadPrograms()
                    }
                }
                deleteTarget = nil
            }
        } message: {
            if let target = deleteTarget {
                Text("「\(target.title)」を完全にクラウドから消去します。この操作は取り消せません。")
            }
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
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
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

private struct DuplicateProgramSheet: View {
    let source: Program
    let onDuplicate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var id: String
    @State private var title: String

    init(source: Program, onDuplicate: @escaping (String, String) -> Void) {
        self.source = source
        self.onDuplicate = onDuplicate
        _id = State(initialValue: source.id + "-copy")
        _title = State(initialValue: source.title + " - コピー")
    }

    var body: some View {
        ZStack {
            Theme.bgDark.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("大会の複製(受信点構成のみコピー)")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.accentBlue)
                Text("「\(source.title)」の受信点構成を新しい大会にコピーします。電界データ・メモは引き継がれません。")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text("新しい番組ID (半角英数字)").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    TextField("番組ID", text: $id)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .padding(12)
                        .background(Theme.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("新しい番組名・大会名称").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    TextField("番組名", text: $title)
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
                    Button("複製する") {
                        onDuplicate(id, title)
                        dismiss()
                    }
                    .disabled(id.isEmpty || title.isEmpty)
                    .foregroundStyle(Theme.bgDark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
    }
}
