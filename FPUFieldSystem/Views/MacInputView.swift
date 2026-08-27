import SwiftUI

struct MacInputView: View {
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

    private let channelOptions = ["C1", "C2", "C3", "C4", "E1", "E2", "E3", "E4", "E5", "E6", "E7", "E8", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8"]

    private var selectedLink: Link? {
        vm.links.first { $0.id == selectedLinkId }
    }

    var body: some View {
        Form {
            Section("対象回線・フェーズ") {
                Picker("対象回線 (リンク)", selection: $selectedLinkId) {
                    Text("-- 選択 --").tag(String?.none)
                    ForEach(vm.links) { link in
                        Text(link.name.replacingOccurrences(of: "\n", with: " ")).tag(Optional(link.id))
                    }
                }
                Picker("現在のフェーズ (日程)", selection: $phase) {
                    ForEach(Phase.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("使用FPUチャンネル") {
                HStack {
                    Picker("Ch", selection: $channelBase) {
                        Text("--").tag("")
                        ForEach(channelOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 90)

                    Picker("偏波", selection: $polarization) {
                        Text("--").tag("")
                        Text("H").tag("H")
                        Text("V").tag("V")
                    }
                    .labelsHidden()
                    .frame(width: 70)

                    TextField("手入力可", text: $customChannel)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Theme.amber)
                }
                .onChange(of: channelBase) { _, _ in syncChannel() }
                .onChange(of: polarization) { _, _ in syncChannel() }
            }

            Section("回線スペック＆機器パラメータ") {
                Picker("変調方式", selection: $modType) {
                    Text("未設定").tag("")
                    ForEach(vm.specMasters.filter { $0.category == .modulation }) { item in
                        Text(item.label).tag(item.value)
                    }
                }
                Picker("プリセット", selection: $presetType) {
                    Text("未設定").tag("")
                    ForEach(vm.specMasters.filter { $0.category == .preset }) { item in
                        Text(item.label).tag(item.value)
                    }
                }
                Picker("TS-Rate", selection: $tsRate) {
                    Text("未設定").tag("")
                    ForEach(vm.specMasters.filter { $0.category == .tsRate }) { item in
                        Text(item.label).tag(item.value)
                    }
                }
                TextField("送信機型番 (TX)", text: $txModel, prompt: Text("例: PF-900"))
                TextField("受信機型番 (RX)", text: $rxModel, prompt: Text("例: FR-800"))
                Toggle("このスペック情報を全日程に一括反映する", isOn: $applyAll)
            }

            Section("電界強度数値入力") {
                HStack(spacing: 12) {
                    stepButton("-5") { changeValue(-5) }
                    stepButton("-1") { changeValue(-1) }
                    HStack(spacing: 4) {
                        if hasEnteredValue {
                            Text("-").foregroundStyle(.secondary)
                            TextField("", value: dbValueBinding, format: .number)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.plain)
                                .frame(width: 50)
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                        } else {
                            Text("未入力")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(.secondary)
                                .frame(width: 50)
                                .onTapGesture { hasEnteredValue = true }
                        }
                        Text("dBm").foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.bgDark)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    stepButton("+1") { changeValue(1) }
                    stepButton("+5") { changeValue(5) }
                    if hasEnteredValue {
                        Button("未入力に戻す") { hasEnteredValue = false }
                            .buttonStyle(.plain)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.rose)
                    }
                    Spacer()
                }
            }

            Section("現場・センターメモ") {
                TextField("現場メモ", text: $fieldMemo, prompt: Text("例: アンテナ追尾完了、安定"))
                    .foregroundStyle(Theme.accentGreen)
                TextField("センターメモ", text: $centerMemo, prompt: Text("例: センター側DAdown確認"))
                    .foregroundStyle(Theme.accentBlue)
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("データと機器情報を送信", systemImage: "icloud.and.arrow.up.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentGreen)
                .disabled(selectedLinkId == nil || isSubmitting)

                if let statusMessage {
                    Text(statusMessage).foregroundStyle(Theme.accentGreen)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bgDark)
        .navigationTitle("データ入力")
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
    }

    private var savedLinkKey: String { "fpu_saved_link_\(vm.program.id)" }

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
    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .black))
                .frame(width: 42, height: 30)
        }
        .buttonStyle(.bordered)
    }
}
