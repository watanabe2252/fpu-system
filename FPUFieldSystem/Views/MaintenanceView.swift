import SwiftUI
import UniformTypeIdentifiers

struct MaintenanceView: View {
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

    @State private var isReordering = false

    var body: some View {
        List {
            thresholdSection
            csvSection
            addLinkSection
            reorderSection
            userAdminSection
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.plain)
        #endif
        .scrollContentBackground(.hidden)
        .background(Theme.bgDark)
        #if os(iOS)
        .environment(\.editMode, .constant(isReordering ? .active : .inactive))
        .toolbarBackground(Theme.cardBg, for: .navigationBar)
        #endif
        .navigationTitle("メンテナンス")
        .onAppear(perform: syncLocalOrder)
        .onChange(of: vm.links) { _, _ in syncLocalOrder() }
        .fileImporter(isPresented: $showCSVImporter, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            handleCSVImport(result)
        }
    }

    // MARK: - しきい値

    private var thresholdSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("FPU無線系統 (main / relay)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.accentOrange)
                thresholdSlider(label: "赤判定(障害ライン)", value: wlLowBinding, range: 65...95, color: Theme.rose, suffix: " dBm")
                thresholdSlider(label: "緑判定(良好ライン)", value: wlHighBinding, range: 35...75, color: Theme.accentGreen, suffix: " dBm")

                Divider().background(Theme.borderStroke)

                Text("光回線系統 (opt)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Theme.accentGreen)
                thresholdSlider(label: "赤判定(障害ライン)", value: optLowBinding, range: 16...30, color: Theme.rose, suffix: " dBm")
                thresholdSlider(label: "緑判定(良好ライン)", value: optHighBinding, range: 2...18, color: Theme.accentGreen, suffix: " dBm")
            }
            .listRowBackground(Theme.cardBg)
        } header: {
            Text("動的アラートしきい値集中管理").foregroundStyle(Theme.accentBlue)
        }
    }

    private func thresholdSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, color: Color, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(.gray)
                Spacer()
                Text("-\(Int(value.wrappedValue))\(suffix)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(color)
            }
            Slider(value: value, in: range).tint(color)
        }
    }

    private var wlLowBinding: Binding<Double> {
        Binding(
            get: { Double(vm.wlLow) },
            set: { newValue in
                vm.wlLow = Int(newValue)
                if vm.wlLow <= vm.wlHigh { vm.wlHigh = vm.wlLow - 1 }
            }
        )
    }
    private var wlHighBinding: Binding<Double> {
        Binding(
            get: { Double(vm.wlHigh) },
            set: { newValue in
                vm.wlHigh = Int(newValue)
                if vm.wlLow <= vm.wlHigh { vm.wlLow = vm.wlHigh + 1 }
            }
        )
    }
    private var optLowBinding: Binding<Double> {
        Binding(
            get: { Double(vm.optLow) },
            set: { newValue in
                vm.optLow = Int(newValue)
                if vm.optLow <= vm.optHigh { vm.optHigh = vm.optLow - 1 }
            }
        )
    }
    private var optHighBinding: Binding<Double> {
        Binding(
            get: { Double(vm.optHigh) },
            set: { newValue in
                vm.optHigh = Int(newValue)
                if vm.optLow <= vm.optHigh { vm.optLow = vm.optHigh + 1 }
            }
        )
    }

    // MARK: - CSVインポート

    private var csvSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("フォーマット(UTF-8、1行目は見出しとして無視):")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.gray)
                Text("受信点名,カテゴリ,初期Ch,変調方式,プリセット,TSレート,TX型番,RX型番")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Theme.amber)

                Button {
                    showCSVImporter = true
                } label: {
                    if isImportingCSV {
                        ProgressView().tint(Theme.bgDark)
                    } else {
                        Label("CSVファイルを選択してインポート", systemImage: "doc.badge.arrow.up")
                            .font(.system(size: 12, weight: .black))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.accentBlue)
                .foregroundStyle(Theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(isImportingCSV)

                if let csvStatus {
                    Text(csvStatus).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.accentGreen)
                }
            }
            .listRowBackground(Theme.cardBg)
        } header: {
            Text("CSVから受信点＆スペックを一括登録").foregroundStyle(Theme.accentBlue)
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

    // MARK: - 受信点の新規追加

    private var addLinkSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                TextField("受信点名(矢印で改行可)", text: $newLinkName)
                    .padding(10)
                    .background(Theme.bgDark)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)

                Picker("カテゴリ", selection: $newLinkCategory) {
                    Text("本線系統 (main)").tag(LinkCategory.main)
                    Text("リレー系統 (relay)").tag(LinkCategory.relay)
                    Text("光回線系統 (opt)").tag(LinkCategory.opt)
                }
                .pickerStyle(.segmented)

                Button {
                    Task { await addLink() }
                } label: {
                    Text("この大会に受信点を追加")
                        .font(.system(size: 12, weight: .black))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.accentGreen)
                .foregroundStyle(Theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(newLinkName.trimmingCharacters(in: .whitespaces).isEmpty)

                if let addLinkStatus {
                    Text(addLinkStatus).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.rose)
                }
            }
            .listRowBackground(Theme.cardBg)
        } header: {
            Text("受信点(リンク)の新規手動追加").foregroundStyle(Theme.accentBlue)
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

    // MARK: - 並び替え・削除

    private var reorderSection: some View {
        Section {
            Button {
                isReordering.toggle()
            } label: {
                Label(isReordering ? "並び替えモードを終了" : "並び替え・削除モードを開始", systemImage: isReordering ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle")
                    .font(.system(size: 12, weight: .black))
            }
            .foregroundStyle(isReordering ? Theme.accentGreen : Theme.accentBlue)
            .listRowBackground(Theme.cardBg)

            reorderGroup(title: "本線", color: Theme.accentBlue, links: $mainLinks)
            reorderGroup(title: "リレー", color: Theme.accentOrange, links: $relayLinks)
            reorderGroup(title: "光回線", color: Theme.accentGreen, links: $optLinks)

            Button {
                Task { await saveOrder() }
            } label: {
                Text("並び順を一括確定して同期")
                    .font(.system(size: 12, weight: .black))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Theme.accentBlue)
            .foregroundStyle(Theme.bgDark)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .listRowBackground(Theme.cardBg)

            if let orderStatus {
                Text(orderStatus)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accentGreen)
                    .listRowBackground(Theme.cardBg)
            }
        } header: {
            Text("ドラッグ順序入れ替え・削除").foregroundStyle(Theme.accentBlue)
        }
    }

    @ViewBuilder
    private func reorderGroup(title: String, color: Color, links: Binding<[Link]>) -> some View {
        if !links.wrappedValue.isEmpty {
            Text("【\(title)】")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(color)
                .listRowBackground(Theme.cardBg)

            ForEach(links.wrappedValue) { link in
                Text(link.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .listRowBackground(Theme.cardBg)
            }
            .onMove { indices, newOffset in
                links.wrappedValue.move(fromOffsets: indices, toOffset: newOffset)
            }
            .onDelete { indices in
                let toDelete = indices.map { links.wrappedValue[$0] }
                links.wrappedValue.remove(atOffsets: indices)
                Task {
                    for link in toDelete {
                        try? await vm.deleteLink(link)
                    }
                }
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

    // MARK: - ユーザー管理

    private var userAdminSection: some View {
        Section {
            NavigationLink {
                UserAdminView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ポジション別 アカウント権限管理")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.amber)
                    Text("アプリ内での動的権限昇格・降格画面へ遷移します。")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                }
            }
            .listRowBackground(Theme.cardBg)
        }
    }
}
