#if os(macOS)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("電界データ＆スペック入力")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.accentBlue)

                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 16) {
                        fieldBlock(title: "対象回線 (リンク)") {
                            Picker("リンク", selection: $selectedLinkId) {
                                Text("-- 選択 --").tag(String?.none)
                                ForEach(vm.links) { link in
                                    Text(link.name.replacingOccurrences(of: "\n", with: " ")).tag(Optional(link.id))
                                }
                            }
                            .labelsHidden()
                        }

                        fieldBlock(title: "現在のフェーズ (日程)") {
                            Picker("フェーズ", selection: $phase) {
                                ForEach(Phase.allCases) { p in
                                    Text(p.label).tag(p)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }

                        fieldBlock(title: "使用FPUチャンネル", color: Theme.amber) {
                            HStack(spacing: 8) {
                                Picker("Ch", selection: $channelBase) {
                                    Text("--").tag("")
                                    ForEach(channelOptions, id: \.self) { Text($0).tag($0) }
                                }
                                .labelsHidden()

                                Picker("偏波", selection: $polarization) {
                                    Text("--").tag("")
                                    Text("H").tag("H")
                                    Text("V").tag("V")
                                }
                                .labelsHidden()
                                .frame(width: 70)

                                TextField("手入力可", text: $customChannel)
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundStyle(Theme.amber)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .onChange(of: channelBase) { _, _ in syncChannel() }
                            .onChange(of: polarization) { _, _ in syncChannel() }
                        }

                        fieldBlock(title: "電界強度数値入力") {
                            HStack(spacing: 12) {
                                stepButton("-5") { changeValue(-5) }
                                stepButton("-1") { changeValue(-1) }
                                HStack(spacing: 4) {
                                    Text("-").foregroundStyle(.gray)
                                    TextField("", value: $dbValue, format: .number)
                                        .multilineTextAlignment(.center)
                                        .textFieldStyle(.plain)
                                        .frame(width: 50)
                                        .font(.system(size: 26, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white)
                                    Text("dBm").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.bgDark)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.borderStroke))
                                stepButton("+1") { changeValue(1) }
                                stepButton("+5") { changeValue(5) }
                                Spacer()
                            }
                        }
                    }
                    .frame(width: 360)

                    VStack(spacing: 16) {
                        fieldBlock(title: "回線スペック＆機器パラメータ") {
                            VStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    specPicker(title: "変調方式", category: .modulation, selection: $modType)
                                    specPicker(title: "プリセット", category: .preset, selection: $presetType)
                                    specPicker(title: "TS-Rate", category: .tsRate, selection: $tsRate)
                                }
                                HStack(spacing: 10) {
                                    labeledTextField(title: "送信機型番 (TX)", placeholder: "例: PF-900", text: $txModel)
                                    labeledTextField(title: "受信機型番 (RX)", placeholder: "例: FR-800", text: $rxModel)
                                }
                                Toggle("このスペック情報を全日程に一括反映する", isOn: $applyAll)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .tint(Theme.accentBlue)
                            }
                        }

                        fieldBlock(title: "現場・センターメモ") {
                            VStack(spacing: 10) {
                                labeledTextField(title: "現場メモ", placeholder: "例: アンテナ追尾完了、安定", text: $fieldMemo, color: Theme.accentGreen)
                                labeledTextField(title: "センターメモ", placeholder: "例: センター側DAdown確認", text: $centerMemo, color: Theme.accentBlue)
                            }
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            if isSubmitting {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("データと機器情報を送信", systemImage: "icloud.and.arrow.up.fill")
                                    .font(.system(size: 14, weight: .black))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accentGreen)
                        .controlSize(.large)
                        .disabled(selectedLinkId == nil || isSubmitting)

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.accentGreen)
                        }
                    }
                    .frame(width: 360)

                    Spacer(minLength: 0)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bgDark)
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

    private func changeValue(_ amount: Int) {
        dbValue = max(0, min(99, dbValue + amount))
    }

    private func loadCurrentRecord() {
        guard let linkId = selectedLinkId else { return }
        if let rec = vm.record(linkId: linkId, phase: phase) {
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
                value: dbValue,
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(color)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.borderStroke))
    }

    @ViewBuilder
    private func specPicker(title: String, category: SpecMasterCategory, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundStyle(.gray)
            Picker(title, selection: selection) {
                Text("未設定").tag("")
                ForEach(vm.specMasters.filter { $0.category == category }) { item in
                    Text(item.label).tag(item.value)
                }
            }
            .labelsHidden()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func labeledTextField(title: String, placeholder: String, text: Binding<String>, color: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundStyle(.gray)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderStroke))
        }
        .buttonStyle(.plain)
    }
}
#endif
