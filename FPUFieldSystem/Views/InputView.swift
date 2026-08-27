import SwiftUI

struct InputView: View {
    @ObservedObject var vm: WorkspaceViewModel

    @State private var selectedLinkId: String?
    @State private var phase: Phase = .run
    @State private var channelBase = ""
    @State private var polarization = ""
    @State private var customChannel = ""
    @State private var modType = ""
    @State private var presetType = ""
    @State private var tsRate = ""
    @State private var txModel = ""
    @State private var rxModel = ""
    @State private var dbValue = 60
    @State private var hasEnteredValue = false
    @State private var fieldMemo = ""
    @State private var centerMemo = ""
    @State private var applyAll = false
    @State private var statusMessage: String?
    @State private var isSubmitting = false
    @State private var showDetails = false

    private let channelOptions = ["C1", "C2", "C3", "C4", "E1", "E2", "E3", "E4", "E5", "E6", "E7", "E8", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8"]

    private var selectedLink: Link? {
        vm.links.first { $0.id == selectedLinkId }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("電界データ＆スペック入力")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.accentBlue)

                fieldBlock(title: "① 対象回線 (リンク)") {
                    HStack(spacing: 8) {
                        Button {
                            stepLink(-1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(selectedLinkIndex.map { $0 > 0 } ?? false ? .white : .gray.opacity(0.3))
                                .frame(width: 36, height: 36)
                                .background(Theme.bgDark)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(!(selectedLinkIndex.map { $0 > 0 } ?? false))

                        Picker("リンク", selection: $selectedLinkId) {
                            Text("-- 選択 --").tag(String?.none)
                            ForEach(vm.links) { link in
                                Text(link.name.replacingOccurrences(of: "\n", with: " ")).tag(Optional(link.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .frame(maxWidth: .infinity)

                        Button {
                            stepLink(1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(selectedLinkIndex.map { $0 < vm.links.count - 1 } ?? false ? .white : .gray.opacity(0.3))
                                .frame(width: 36, height: 36)
                                .background(Theme.bgDark)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(!(selectedLinkIndex.map { $0 < vm.links.count - 1 } ?? false))
                    }
                }

                fieldBlock(title: "② 現在のフェーズ (日程)") {
                    Picker("フェーズ", selection: $phase) {
                        ForEach(Phase.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(spacing: 8) {
                    Text("③ 電界強度数値入力")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.gray)
                    HStack(spacing: 10) {
                        stepButton("-5") { changeValue(-5) }
                        stepButton("-1") { changeValue(-1) }
                        HStack(spacing: 2) {
                            if hasEnteredValue {
                                Text("-").foregroundStyle(.gray)
                                TextField("", value: dbValueBinding, format: .number)
                                    #if os(iOS)
                                    .keyboardType(.numberPad)
                                    #endif
                                    .multilineTextAlignment(.center)
                                    .frame(width: 44)
                                    .font(.system(size: 22, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                            } else {
                                Text("未入力")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(.gray)
                                    .frame(width: 44)
                                    .onTapGesture { hasEnteredValue = true }
                            }
                            Text("dBm").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.bgDark)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderStroke))
                        stepButton("+1") { changeValue(1) }
                        stepButton("+5") { changeValue(5) }
                    }
                    if hasEnteredValue {
                        Button {
                            hasEnteredValue = false
                        } label: {
                            Text("未入力に戻す")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.rose)
                        }
                    }
                }

                DisclosureGroup(isExpanded: $showDetails) {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("使用FPUチャンネル")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Theme.amber)
                            HStack(spacing: 8) {
                                Picker("Ch", selection: $channelBase) {
                                    Text("--").tag("")
                                    ForEach(channelOptions, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .tint(Theme.amber)

                                Picker("偏波", selection: $polarization) {
                                    Text("--").tag("")
                                    Text("H").tag("H")
                                    Text("V").tag("V")
                                }
                                .pickerStyle(.menu)
                                .tint(Theme.amber)

                                TextField("手入力可", text: $customChannel)
                                    #if os(iOS)
                                    .textInputAutocapitalization(.characters)
                                    #endif
                                    .padding(10)
                                    .background(Theme.bgDark)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.amber.opacity(0.4)))
                                    .foregroundStyle(Theme.amber)
                            }
                            .onChange(of: channelBase) { _, _ in syncChannel() }
                            .onChange(of: polarization) { _, _ in syncChannel() }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("回線スペック＆機器パラメータ")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Theme.accentBlue)
                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    specPicker(title: "変調方式", category: .modulation, selection: $modType)
                                    specPicker(title: "プリセット", category: .preset, selection: $presetType)
                                    specPicker(title: "TS-Rate", category: .tsRate, selection: $tsRate)
                                }
                                HStack(spacing: 8) {
                                    labeledTextField(title: "送信機型番 (TX)", placeholder: "例: PF-900", text: $txModel)
                                    labeledTextField(title: "受信機型番 (RX)", placeholder: "例: FR-800", text: $rxModel)
                                }
                                Toggle("このスペック情報を全日程に一括反映する", isOn: $applyAll)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .tint(Theme.accentBlue)
                            }
                        }
                    }
                    .padding(.top, 10)
                } label: {
                    Text("チャンネル・スペック設定")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.gray)
                }
                .padding(12)
                .background(Theme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.borderStroke))
                .tint(.white)

                VStack(spacing: 8) {
                    labeledTextField(title: "現場メモ", placeholder: "例: アンテナ追尾完了、安定", text: $fieldMemo, color: Theme.accentGreen)
                    labeledTextField(title: "センターメモ", placeholder: "例: センター側DAdown確認", text: $centerMemo, color: Theme.accentBlue)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().tint(Theme.bgDark)
                    } else {
                        Label("データと機器情報を送信", systemImage: "icloud.and.arrow.up.fill")
                            .font(.system(size: 14, weight: .black))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedLinkId == nil ? Theme.accentGreen.opacity(0.4) : Theme.accentGreen)
                .foregroundStyle(Theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(selectedLinkId == nil || isSubmitting)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accentGreen)
                }
            }
            .padding(16)
        }
        .background(Theme.bgDark.ignoresSafeArea())
        .onAppear {
            if selectedLinkId == nil {
                let savedId = UserDefaults.standard.string(forKey: savedLinkKey)
                selectedLinkId = vm.links.first { $0.id == savedId }?.id ?? vm.links.first?.id
            }
            loadCurrentRecord()
        }
        .onChange(of: selectedLinkId) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: savedLinkKey)
            loadCurrentRecord()
        }
        .onChange(of: phase) { _, _ in loadCurrentRecord() }
        .onChange(of: vm.pendingInputSelection) { _, newValue in
            applyPendingSelection(newValue)
        }
        .onAppear {
            if vm.pendingInputSelection != nil {
                applyPendingSelection(vm.pendingInputSelection)
            }
        }
    }

    private var savedLinkKey: String { "fpu_saved_link_\(vm.program.id)" }

    private var selectedLinkIndex: Int? {
        guard let selectedLinkId else { return nil }
        return vm.links.firstIndex { $0.id == selectedLinkId }
    }

    private func stepLink(_ delta: Int) {
        guard let index = selectedLinkIndex else { return }
        let newIndex = index + delta
        guard vm.links.indices.contains(newIndex) else { return }
        selectedLinkId = vm.links[newIndex].id
    }

    private func applyPendingSelection(_ selection: WorkspaceViewModel.InputSelection?) {
        guard let selection else { return }
        selectedLinkId = selection.linkId
        phase = selection.phase
        vm.pendingInputSelection = nil
    }

    private func syncChannel() {
        if !channelBase.isEmpty || !polarization.isEmpty {
            customChannel = channelBase + polarization
        }
    }

    private var dbValueBinding: Binding<Int> {
        Binding(
            get: { dbValue },
            set: { newValue in
                dbValue = newValue
                hasEnteredValue = true
            }
        )
    }

    private func changeValue(_ amount: Int) {
        dbValue = max(0, min(99, dbValue + amount))
        hasEnteredValue = true
    }

    private func loadCurrentRecord() {
        guard let linkId = selectedLinkId else { return }
        if let rec = vm.record(linkId: linkId, phase: phase) {
            hasEnteredValue = rec.value != nil
            dbValue = rec.value ?? vm.defaultValue(for: selectedLink?.category ?? .opt)
            fieldMemo = rec.fieldMemo ?? ""
            centerMemo = rec.centerMemo ?? ""
            customChannel = rec.fpuChannel ?? ""
            modType = rec.modType ?? ""
            presetType = rec.presetType ?? ""
            tsRate = rec.tsRate ?? ""
            txModel = rec.txModel ?? ""
            rxModel = rec.rxModel ?? ""
        } else {
            hasEnteredValue = false
            dbValue = vm.defaultValue(for: selectedLink?.category ?? .opt)
            fieldMemo = ""
            centerMemo = ""
            customChannel = ""
            modType = ""
            presetType = ""
            tsRate = ""
            txModel = ""
            rxModel = ""
        }
        channelBase = ""
        polarization = ""
    }

    private func submit() async {
        guard let linkId = selectedLinkId else { return }
        isSubmitting = true
        statusMessage = nil
        do {
            try await vm.submitRecord(
                linkId: linkId,
                phase: phase,
                value: hasEnteredValue ? dbValue : nil,
                fieldMemo: fieldMemo.trimmingCharacters(in: .whitespaces),
                centerMemo: centerMemo.trimmingCharacters(in: .whitespaces),
                fpuChannel: customChannel.trimmingCharacters(in: .whitespaces),
                modType: modType,
                presetType: presetType,
                tsRate: tsRate,
                txModel: txModel.trimmingCharacters(in: .whitespaces),
                rxModel: rxModel.trimmingCharacters(in: .whitespaces),
                applyToAllPhases: applyAll
            )
            statusMessage = applyAll ? "✔ 全日程への一括送信成功" : "✔ 送信成功"
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
        isSubmitting = false
    }

    @ViewBuilder
    private func fieldBlock<Content: View>(title: String, color: Color = Theme.accentBlue, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(color)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.borderStroke))
    }

    @ViewBuilder
    private func specPicker(title: String, category: SpecMasterCategory, selection: Binding<String>) -> some View {
        let options = vm.specMasters.filter { $0.category == category }
        let currentLabel = options.first { $0.value == selection.wrappedValue }?.label ?? "未設定"

        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.gray)
            Menu {
                Button("未設定") { selection.wrappedValue = "" }
                ForEach(options) { item in
                    Button(item.label) { selection.wrappedValue = item.value }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(Theme.bgDark)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func labeledTextField(title: String, placeholder: String, text: Binding<String>, color: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(.gray)
            TextField(placeholder, text: text)
                .padding(8)
                .background(Theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderStroke))
        }
    }
}
