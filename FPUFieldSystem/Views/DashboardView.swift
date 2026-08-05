import SwiftUI

struct DashboardView: View {
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
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        quickUpdatePanel

                        ForEach(LinkCategory.allCases, id: \.self) { category in
                            let categoryLinks = vm.linksByCategory(category)
                            if !categoryLinks.isEmpty {
                                categorySection(category: category, categoryLinks: categoryLinks)
                            }
                        }
                        if vm.links.isEmpty {
                            Text("この大会にはまだ受信点が登録されていません。")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Theme.bgDark.ignoresSafeArea())
        .task {
            if vm.links.isEmpty { await vm.loadAll() }
            vm.subscribeRealtime()
            if quickLinkId == nil { quickLinkId = vm.links.first?.id }
        }
    }

    private var quickUpdatePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("センターメモ・Ch更新", systemImage: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(Theme.accentBlue)

            HStack(spacing: 8) {
                Picker("リンク", selection: $quickLinkId) {
                    ForEach(vm.links) { link in
                        Text(link.name).tag(Optional(link.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Picker("フェーズ", selection: $quickPhase) {
                    ForEach(Phase.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
                .padding(8)
                .background(Theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 8) {
                TextField("Ch (例: C2H)", text: $quickChannel)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Theme.amber)
                    .padding(8)
                    .frame(width: 100)
                    .background(Theme.bgDark)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                TextField("状況メモを入力", text: $quickCenterMemo)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Theme.bgDark)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    Task { await submitQuickUpdate() }
                } label: {
                    if isQuickSubmitting {
                        ProgressView().tint(Theme.bgDark)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .frame(width: 40, height: 36)
                .background(Theme.accentBlue)
                .foregroundStyle(Theme.bgDark)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(quickLinkId == nil || isQuickSubmitting)
            }
        }
        .padding(12)
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

    private func categorySection(category: LinkCategory, categoryLinks: [Link]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.label)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(category.accentColor)

            VStack(spacing: 10) {
                ForEach(categoryLinks) { link in
                    linkCard(link: link)
                }
            }
        }
        .padding(12)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.borderStroke))
    }

    private func linkCard(link: Link) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(link.name)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Phase.allCases) { phase in
                        phaseCell(link: link, phase: phase)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func phaseCell(link: Link, phase: Phase) -> some View {
        let record = vm.record(linkId: link.id, phase: phase)
        let value = record?.value

        return VStack(alignment: .leading, spacing: 4) {
            Text(phase.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.gray)

            HStack {
                if let ch = record?.fpuChannel, !ch.isEmpty {
                    Text(ch)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Theme.amber)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Theme.amber.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Text("-- Ch").font(.system(size: 9)).foregroundStyle(.gray.opacity(0.6))
                }
                Spacer()
                if let value {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("-\(value)")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(vm.statusColor(category: link.category, value: value))
                        Text("dBm")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.gray)
                    }
                } else {
                    Text("--")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }

            specBlock(record: record)

            if let memo = record?.fieldMemo, !memo.isEmpty {
                Text("現:\(memo)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accentGreen)
                    .lineLimit(1)
            }
            if let memo = record?.centerMemo, !memo.isEmpty {
                Text("セ:\(memo)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accentBlue)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(width: 150, alignment: .leading)
        .background(vm.statusBackground(category: link.category, value: value))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.borderStroke))
    }

    private func specBlock(record: Record?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            specRow(label: "変調", value: record?.modType)
            specRow(label: "プリセット", value: record?.presetType)
            specRow(label: "TSレート", value: record?.tsRate)
                .padding(.bottom, 1)
                .overlay(alignment: .bottom) {
                    Divider().opacity(0.4)
                }
            specRow(label: "TX", value: record?.txModel)
            specRow(label: "RX", value: record?.rxModel)
        }
        .padding(5)
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
        .font(.system(size: 8, weight: .medium, design: .monospaced))
    }
}
