import SwiftUI

/// Read-only overview of every receive point (link): name, category, map
/// coordinates, and current spec — so anyone can check this without digging
/// through Maintenance or the Input screen's collapsed detail section.
struct LinkInfoView: View {
    @ObservedObject var vm: WorkspaceViewModel
    @EnvironmentObject private var supabase: SupabaseService

    @State private var phase: Phase = .run
    @State private var editingLink: Link?
    @State private var locationEditSelection: Set<String>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("受信点情報")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Theme.accentBlue)
                    Spacer()
                    Picker("フェーズ", selection: $phase) {
                        ForEach(Phase.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }

                if vm.links.isEmpty {
                    Text("この大会にはまだ受信点が登録されていません。")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    ForEach(LinkCategory.allCases, id: \.self) { category in
                        let categoryLinks = vm.linksByCategory(category)
                        if !categoryLinks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(category.label)
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(category.accentColor)

                                VStack(spacing: 10) {
                                    ForEach(categoryLinks) { link in
                                        linkRow(link: link)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.bgDark.ignoresSafeArea())
        .sheet(item: $editingLink) { link in
            NavigationStack {
                LinkEditSheet(link: link) { name, category in
                    Task { try? await vm.updateLink(link, name: name, category: category) }
                }
            }
        }
        .sheet(item: locationSheetBinding) { selection in
            NavigationStack {
                LocationEditSheet(vm: vm, initialSelection: selection.names)
            }
            #if os(macOS)
            .frame(minWidth: 640, minHeight: 560)
            #endif
        }
    }

    /// Wraps the Set<String> in an Identifiable box so it can drive `.sheet(item:)`.
    private struct LocationSelection: Identifiable {
        let names: Set<String>
        var id: String { names.sorted().joined(separator: ",") }
    }

    private var locationSheetBinding: Binding<LocationSelection?> {
        Binding(
            get: { locationEditSelection.map { LocationSelection(names: $0) } },
            set: { locationEditSelection = $0?.names }
        )
    }

    private func linkRow(link: Link) -> some View {
        let record = vm.record(linkId: link.id, phase: phase)
        let endpoints = vm.endpoints(for: link.name)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(link.name)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                Spacer()
                if supabase.currentUserRole == .admin {
                    Button {
                        editingLink = link
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("座標")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.gray)
                        if supabase.currentUserRole == .admin, let endpoints {
                            Button {
                                locationEditSelection = Set([endpoints.from, endpoints.to])
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.accentBlue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let endpoints {
                        coordinateLine(label: endpoints.from, point: vm.location(named: endpoints.from))
                        coordinateLine(label: endpoints.to, point: vm.location(named: endpoints.to))
                    } else {
                        Text("未設定")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.gray.opacity(0.6))
                    }
                }
                .frame(minWidth: 140, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("現在のスペック")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.gray)
                        Button {
                            vm.requestInput(linkId: link.id, phase: phase)
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.accentBlue)
                        }
                        .buttonStyle(.plain)
                    }
                    specRow(label: "Ch", value: record?.fpuChannel)
                    specRow(label: "変調", value: record?.modType)
                    specRow(label: "プリセット", value: record?.presetType)
                    specRow(label: "TSレート", value: record?.tsRate)
                    specRow(label: "TX", value: record?.txModel)
                    specRow(label: "RX", value: record?.rxModel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Theme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.borderStroke))
    }

    private func coordinateLine(label: String, point: MapLocation?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                if let point {
                    Text(String(format: "(%.4f, %.4f)", point.latitude, point.longitude))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("未設定")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.gray.opacity(0.6))
                }
            }
            if let point, let antennaMeta = antennaMetaText(point) {
                Text(antennaMeta)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
    }

    private func antennaMetaText(_ point: MapLocation) -> String? {
        var parts: [String] = []
        if let elevation = point.elevation { parts.append("標高\(elevation)m") }
        if let height = point.heightAboveGround { parts.append("地上高\(height)m") }
        if let gain = point.antennaGain { parts.append("利得\(gain)dBi") }
        return parts.isEmpty ? nil : parts.joined(separator: " / ")
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

private struct LinkEditSheet: View {
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
        ZStack {
            Theme.bgDark.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("受信点の編集")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.accentBlue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("受信点名").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    TextField("受信点名", text: $name)
                        .padding(12)
                        .background(Theme.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("カテゴリ").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    Picker("カテゴリ", selection: $category) {
                        Text("本線系統 (main)").tag(LinkCategory.main)
                        Text("リレー系統 (relay)").tag(LinkCategory.relay)
                        Text("光回線系統 (opt)").tag(LinkCategory.opt)
                    }
                    .pickerStyle(.segmented)
                }

                Spacer()

                HStack {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.gray)
                    Spacer()
                    Button("保存") {
                        onSave(name.trimmingCharacters(in: .whitespaces), category)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(Theme.bgDark)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 260)
        #endif
    }
}
