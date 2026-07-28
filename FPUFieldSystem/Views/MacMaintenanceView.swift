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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("メンテナンス")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)

                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 16) {
                        thresholdCard
                        addLinkCard
                        userAdminCard
                    }
                    .frame(width: 380)

                    VStack(spacing: 16) {
                        csvCard
                        reorderCard
                    }
                    .frame(width: 420)

                    Spacer(minLength: 0)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bgDark)
        .onAppear(perform: syncLocalOrder)
        .onChange(of: vm.links) { _, _ in syncLocalOrder() }
        .fileImporter(isPresented: $showCSVImporter, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            handleCSVImport(result)
        }
        .sheet(isPresented: $showUserAdmin) {
            NavigationStack { UserAdminView() }
                .frame(minWidth: 480, minHeight: 420)
        }
    }

    // MARK: - しきい値

    private var thresholdCard: some View {
        card(title: "動的アラートしきい値集中管理") {
            VStack(alignment: .leading, spacing: 12) {
                Text("FPU無線系統 (main / relay)")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.accentOrange)
                thresholdSlider(label: "赤判定(障害ライン)", value: wlLowBinding, range: 65...95, color: Theme.rose)
                thresholdSlider(label: "緑判定(良好ライン)", value: wlHighBinding, range: 35...75, color: Theme.accentGreen)

                Divider().background(Theme.borderStroke)

                Text("光回線系統 (opt)")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Theme.accentGreen)
                thresholdSlider(label: "赤判定(障害ライン)", value: optLowBinding, range: 16...30, color: Theme.rose)
                thresholdSlider(label: "緑判定(良好ライン)", value: optHighBinding, range: 2...18, color: Theme.accentGreen)
            }
        }
    }

    private func thresholdSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                Spacer()
                Text("-\(Int(value.wrappedValue)) dBm").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(color)
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

    // MARK: - 受信点追加

    private var addLinkCard: some View {
        card(title: "受信点(リンク)の新規手動追加") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("受信点名(矢印で改行可)", text: $newLinkName)
                    .textFieldStyle(.roundedBorder)

                Picker("カテゴリ", selection: $newLinkCategory) {
                    Text("本線系統 (main)").tag(LinkCategory.main)
                    Text("リレー系統 (relay)").tag(LinkCategory.relay)
                    Text("光回線系統 (opt)").tag(LinkCategory.opt)
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Button {
                    Task { await addLink() }
                } label: {
                    Text("この大会に受信点を追加")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentGreen)
                .disabled(newLinkName.trimmingCharacters(in: .whitespaces).isEmpty)

                if let addLinkStatus {
                    Text(addLinkStatus).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.rose)
                }
            }
        }
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

    // MARK: - ユーザー管理

    private var userAdminCard: some View {
        card(title: "ポジション別 アカウント権限管理") {
            VStack(alignment: .leading, spacing: 8) {
                Text("アプリ内での動的権限昇格・降格画面へ遷移します。")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.gray)
                Button {
                    showUserAdmin = true
                } label: {
                    Text("管理画面を開く").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.amber)
            }
        }
    }

    // MARK: - CSVインポート

    private var csvCard: some View {
        card(title: "CSVから受信点＆スペックを一括登録") {
            VStack(alignment: .leading, spacing: 10) {
                Text("フォーマット(UTF-8、1行目は見出しとして無視):")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.gray)
                Text("受信点名,カテゴリ,初期Ch,変調方式,プリセット,TSレート,TX型番,RX型番")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.amber)

                Button {
                    showCSVImporter = true
                } label: {
                    if isImportingCSV {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("CSVファイルを選択してインポート", systemImage: "doc.badge.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentBlue)
                .disabled(isImportingCSV)

                if let csvStatus {
                    Text(csvStatus).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accentGreen)
                }
            }
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

    // MARK: - 並び替え・削除

    private var reorderCard: some View {
        card(title: "ドラッグ順序入れ替え・削除") {
            VStack(alignment: .leading, spacing: 14) {
                reorderList(title: "本線", color: Theme.accentBlue, links: $mainLinks)
                reorderList(title: "リレー", color: Theme.accentOrange, links: $relayLinks)
                reorderList(title: "光回線", color: Theme.accentGreen, links: $optLinks)

                Button {
                    Task { await saveOrder() }
                } label: {
                    Text("並び順を一括確定して同期").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentBlue)

                if let orderStatus {
                    Text(orderStatus).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accentGreen)
                }
            }
        }
    }

    @ViewBuilder
    private func reorderList(title: String, color: Color, links: Binding<[Link]>) -> some View {
        if !links.wrappedValue.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("【\(title)】").font(.system(size: 11, weight: .black)).foregroundStyle(color)
                List {
                    ForEach(links.wrappedValue) { link in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.gray.opacity(0.5))
                                .font(.system(size: 10))
                            Text(link.name)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                Task { try? await vm.deleteLink(link) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(Theme.rose)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Theme.bgDark)
                    }
                    .onMove { indices, newOffset in
                        links.wrappedValue.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(links.wrappedValue.count) * 30 + 8)
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

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.accentBlue)
            content()
        }
        .padding(16)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.borderStroke))
    }
}
#endif
