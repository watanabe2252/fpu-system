import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: WorkspaceViewModel

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView().tint(Theme.accentBlue)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
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
        }
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
                    Text("-\(value)")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(vm.statusColor(category: link.category, value: value))
                } else {
                    Text("--")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.gray.opacity(0.5))
                }
            }

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
}
