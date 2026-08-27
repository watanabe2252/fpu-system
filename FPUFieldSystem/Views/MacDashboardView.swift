import SwiftUI

struct MacDashboardView: View {
    @ObservedObject var vm: WorkspaceViewModel

    @State private var quickLinkId: String?
    @State private var quickPhase: Phase = .run
    @State private var quickChannel = ""
    @State private var quickCenterMemo = ""
    @State private var isQuickSubmitting = false

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView().tint(Theme.accentBlue)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        quickUpdatePanel

                        ForEach(LinkCategory.allCases, id: \.self) { category in
                            let categoryLinks = vm.linksByCategory(category)
                            if !categoryLinks.isEmpty {
                                categoryTable(category: category, categoryLinks: categoryLinks)
                            }
                        }

                        if vm.links.isEmpty {
                            Text("この大会にはまだ受信点が登録されていません。")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                        }
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Theme.bgDark)
        .task {
            if vm.links.isEmpty { await vm.loadAll() }
            vm.subscribeRealtime()
            if quickLinkId == nil { quickLinkId = vm.links.first?.id }
        }
    }

    private var quickUpdatePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("センターメモ・Ch更新", systemImage: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.accentBlue)

            HStack(spacing: 10) {
                Picker("リンク", selection: $quickLinkId) {
                    ForEach(vm.links) { link in
                        Text(link.name).tag(Optional(link.id))
                    }
                }
                .labelsHidden()
                .frame(width: 260)

                Picker("フェーズ", selection: $quickPhase) {
                    ForEach(Phase.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)

                TextField("Ch (例: C2H)", text: $quickChannel)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.amber)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)

                TextField("状況メモを入力", text: $quickCenterMemo)
                    .font(.system(size: 13, weight: .medium))
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await submitQuickUpdate() }
                } label: {
                    if isQuickSubmitting {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("更新", systemImage: "paperplane.fill")
                            .font(.system(size: 13, weight: .black))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentBlue)
                .disabled(quickLinkId == nil || isQuickSubmitting)
            }
        }
        .padding(16)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.borderStroke))
    }

    private func submitQuickUpdate() async {
        guard let linkId = quickLinkId else { return }
        isQuickSubmitting = true
        defer { isQuickSubmitting = false }
        let channel = quickChannel.trimmingCharacters(in: .whitespaces)
        let memo = quickCenterMemo.trimmingCharacters(in: .whitespaces)
        try? await vm.submitCenterMemoQuickUpdate(
            linkId: linkId,
            phase: quickPhase,
            centerMemo: memo.isEmpty ? nil : memo,
            fpuChannel: channel.isEmpty ? nil : channel
        )
        quickChannel = ""
        quickCenterMemo = ""
    }

    private func categoryTable(category: LinkCategory, categoryLinks: [Link]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(category.label)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(category.accentColor)

            Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 14) {
                GridRow {
                    Text("対象回線")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.gray)
                    ForEach(Phase.allCases) { phase in
                        Text(phase.label)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.gray)
                    }
                }

                Divider().gridCellColumns(5)

                ForEach(categoryLinks) { link in
                    GridRow {
                        Text(link.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 160, alignment: .leading)

                        ForEach(Phase.allCases) { phase in
                            phaseCell(link: link, phase: phase)
                        }
                    }
                    Divider().gridCellColumns(5).opacity(0.3)
                }
            }
        }
        .padding(20)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.borderStroke))
    }

    private func phaseCell(link: Link, phase: Phase) -> some View {
        let record = vm.record(linkId: link.id, phase: phase)
        let value = record?.value

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let ch = record?.fpuChannel, !ch.isEmpty {
                    Text(ch)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.amber)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.amber.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                if let value {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("-\(value)")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(vm.statusColor(category: link.category, value: value))
                        Text("dBm")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                } else {
                    Text("--")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.4))
                }
            }

            specBlock(record: record)

            if let memo = record?.fieldMemo, !memo.isEmpty {
                Text("現:\(memo)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accentGreen)
                    .lineLimit(1)
            }
            if let memo = record?.centerMemo, !memo.isEmpty {
                Text("セ:\(memo)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accentBlue)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 180, alignment: .leading)
        .padding(10)
        .background(vm.statusBackground(category: link.category, value: value))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture {
            vm.requestInput(linkId: link.id, phase: phase)
        }
    }

    private func specBlock(record: Record?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            specRow(label: "変調", value: record?.modType)
            specRow(label: "プリセット", value: record?.presetType)
            specRow(label: "TSレート", value: record?.tsRate)
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.4)
                }
            specRow(label: "TX", value: record?.txModel)
            specRow(label: "RX", value: record?.rxModel)
        }
        .padding(6)
        .background(Theme.bgDark.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func specRow(label: String, value: String?) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.gray)
            Spacer()
            Text((value?.isEmpty ?? true) ? "-" : value!)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
    }
}
