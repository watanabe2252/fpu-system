#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct MacMaintenanceView: View {
    @ObservedObject var vm: WorkspaceViewModel

    @State private var mainLinks: [Link] = []
    @State private var relayLinks: [Link] = []
    @State private var optLinks: [Link] = []
    @State private var orderStatus: String?

    @State private var newLinkName = ""
    @State private var newLinkCategory: LinkCategory = .main
    @State private var addLinkStatus: String?

    @State private var showCSVImporter = false
    @State private var csvStatus: String?
    @State private var isImportingCSV = false

    @State private var showUserAdmin = false
    @State private var editingLink: Link?

    var body: some View {
        Form {
            Section("動的アラートしきい値集中管理") {
                Text("FPU無線系統 (main / relay)")
                    .font(.headline)
                    .foregroundStyle(Theme.accentOrange)
                thresholdSlider(label: "赤判定(障害ライン)", value: wlLowBinding, range: 65...95, color: Theme.rose)
                thresholdSlider(label: "緑判定(良好ライン)", value: wlHighBinding, range: 35...75, color: Theme.accentGreen)

                Text("光回線系統 (opt)")
                    .font(.headline)
                    .foregroundStyle(Theme.accentGreen)
                thresholdSlider(label: "赤判定(障害ライン)", value: optLowBinding, range: 16...30, color: Theme.rose)
                thresholdSlider(label: "緑判定(良好ライン)", value: optHighBinding, range: 2...18, color: Theme.accentGreen)
            }

            Section("CSVから受信点＆スペックを一括登録") {
                Text("フォーマット(UTF-8、1行目は見出しとして無視):")
                    .foregroundStyle(.secondary)
                Text("受信点名,カテゴリ,初期Ch,変調方式,プリセット,TSレート,TX型番,RX型番")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Theme.amber)

                Button {
                    showCSVImporter = true
                } label: {
                    if isImportingCSV {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("CSVファイルを選択してインポート", systemImage: "doc.badge.arrow.up")
                    }
                }
                .disabled(isImportingCSV)

                if let csvStatus {
                    Text(csvStatus).foregroundStyle(Theme.accentGreen)
                }
            }

            Section("受信点(リンク)の新規手動追加") {
                TextField("受信点名(矢印で改行可)", text: $newLinkName)

                Picker("カテゴリ", selection: $newLinkCategory) {
                    Text("本線系統 (main)").tag(LinkCategory.main)
                    Text("リレー系統 (relay)").tag(LinkCategory.relay)
                    Text("光回線系統 (opt)").tag(LinkCategory.opt)
                }
                .pickerStyle(.segmented)

                Button("この大会に受信点を追加") {
                    Task { await addLink() }
                }
                .disabled(newLinkName.trimmingCharacters(in: .whitespaces).isEmpty)

                if let addLinkStatus {
                    Text(addLinkStatus).foregroundStyle(Theme.rose)
                }
            }

            Section("並び替え・削除") {
                reorderList(title: "本線", color: Theme.accentBlue, links: $mainLinks)
                reorderList(title: "リレー", color: Theme.accentOrange, links: $relayLinks)
                reorderList(title: "光回線", color: Theme.accentGreen, links: $optLinks)

                Button("並び順を一括確定して同期") {
                    Task { await saveOrder() }
                }

                if let orderStatus {
                    Text(orderStatus).foregroundStyle(Theme.accentGreen)
                }
            }

            Section("ポジション別 アカウント権限管理") {
                Text("アプリ内での動的権限昇格・降格画面へ遷移します。")
                    .foregroundStyle(.secondary)
                Button("管理画面を開く") {
                    showUserAdmin = true
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bgDark)
        .navigationTitle("メンテナンス")
        .onAppear(perform: syncLocalOrder)
        .onChange(of: vm.links) { _, _ in syncLocalOrder() }
        .fileImporter(isPresented: $showCSVImporter, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            handleCSVImport(result)
        }
        .sheet(isPresented: $showUserAdmin) {
            NavigationStack { UserAdminView() }
                .frame(minWidth: 480, minHeight: 420)
        }
        .sheet(item: $editingLink) { link in
            EditLinkSheet(link: link) { name, category in
                Task { try? await vm.updateLink(link, name: name, category: category) }
            }
            .frame(minWidth: 380, minHeight: 260)
        }
    }

    private func thresholdSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text("-\(Int(value.wrappedValue)) dBm")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(color)
            }
            Slider(value: value, in: range).tint(color)
        }
    }

    private var wlLowBinding: Binding<Double> {
        Binding(get: { Double(vm.wlLow) }, set: { vm.wlLow = Int($0); if vm.wlLow <= vm.wlHigh { vm.wlHigh = vm.wlLow - 1 } })
    }
    private var wlHighBinding: Binding<Double> {
        Binding(get: { Double(vm.wlHigh) }, set: { vm.wlHigh = Int($0); if vm.wlLow <= vm.wlHigh { vm.wlLow = vm.wlHigh + 1 } })
    }
    private var optLowBinding: Binding<Double> {
        Binding(get: { Double(vm.optLow) }, set: { vm.optLow = Int($0); if vm.optLow <= vm.optHigh { vm.optHigh = vm.optLow - 1 } })
    }
    private var optHighBinding: Binding<Double> {
        Binding(get: { Double(vm.optHigh) }, set: { vm.optHigh = Int($0); if vm.optLow <= vm.optHigh { vm.optLow = vm.optHigh + 1 } })
    }

    private func addLink() async {
        addLinkStatus = nil
        do {
            try await vm.addLink(name: newLinkName.trimmingCharacters(in: .whitespaces), category: newLinkCategory)
            newLinkName = ""
        } catch {
            addLinkStatus = error.localizedDescription
        }
    }

    private func handleCSVImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            Task {
                isImportingCSV = true
                csvStatus = nil
                defer { isImportingCSV = false }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    let count = try await vm.importCSV(text: text)
                    csvStatus = "✔ \(count)件の受信点をインポートしました"
                } catch {
                    csvStatus = "❌ \(error.localizedDescription)"
                }
            }
        case .failure(let error):
            csvStatus = "❌ \(error.localizedDescription)"
        }
    }

    @ViewBuilder
    private func reorderList(title: String, color: Color, links: Binding<[Link]>) -> some View {
        if !links.wrappedValue.isEmpty {
            DisclosureGroup {
                List {
                    ForEach(links.wrappedValue) { link in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                            Text(link.name)
                            Spacer()
                            Button {
                                editingLink = link
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(Theme.accentBlue)
                            }
                            .buttonStyle(.plain)
                            Button {
                                Task { try? await vm.deleteLink(link) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(Theme.rose)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { indices, newOffset in
                        links.wrappedValue.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .frame(height: CGFloat(links.wrappedValue.count) * 32 + 12)
            } label: {
                Text("【\(title)】(\(links.wrappedValue.count)件)").foregroundStyle(color)
            }
        }
    }

    private func syncLocalOrder() {
        mainLinks = vm.linksByCategory(.main)
        relayLinks = vm.linksByCategory(.relay)
        optLinks = vm.linksByCategory(.opt)
    }

    private func saveOrder() async {
        orderStatus = nil
        let orderedIds = (mainLinks + relayLinks + optLinks).map(\.id)
        do {
            try await vm.persistSortOrder(orderedIds: orderedIds)
            orderStatus = "✔ クラウド順序同期完了"
        } catch {
            orderStatus = "❌ \(error.localizedDescription)"
        }
    }
}

private struct EditLinkSheet: View {
    let link: Link
    let onSave: (String, LinkCategory) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: LinkCategory

    init(link: Link, onSave: @escaping (String, LinkCategory) -> Void) {
        self.link = link
        self.onSave = onSave
        _name = State(initialValue: link.name)
        _category = State(initialValue: link.category)
    }

    var body: some View {
        Form {
            Section("受信点の編集") {
                TextField("受信点名", text: $name)
                Picker("カテゴリ", selection: $category) {
                    Text("本線系統 (main)").tag(LinkCategory.main)
                    Text("リレー系統 (relay)").tag(LinkCategory.relay)
                    Text("光回線系統 (opt)").tag(LinkCategory.opt)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bgDark)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(name.trimmingCharacters(in: .whitespaces), category)
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
#endif
