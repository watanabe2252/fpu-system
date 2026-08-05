import SwiftUI
import Supabase

@MainActor
final class WorkspaceViewModel: ObservableObject {
    let program: Program
    private let supabase: SupabaseService

    @Published var programTitle: String
    @Published var links: [Link] = []
    @Published var records: [Record] = []
    @Published var specMasters: [SpecMaster] = []
    @Published var realtimeConnected = false
    @Published var isLoading = true
    @Published var errorMessage: String?

    @Published var wlLow = 81
    @Published var wlHigh = 60
    @Published var optLow = 21
    @Published var optHigh = 15

    private var channel: RealtimeChannelV2?

    init(program: Program, supabase: SupabaseService) {
        self.program = program
        self.programTitle = program.title
        self.supabase = supabase
    }

    func updateProgramTitle(_ newTitle: String) async throws {
        try await supabase.updateProgramTitle(id: program.id, title: newTitle)
        programTitle = newTitle
    }

    func linksByCategory(_ category: LinkCategory) -> [Link] {
        links.filter { $0.category == category }
    }

    func record(linkId: String, phase: Phase) -> Record? {
        records.first { $0.linkId == linkId && $0.phase == phase }
    }

    func thresholds(for category: LinkCategory) -> (low: Int, high: Int) {
        category == .opt ? (optLow, optHigh) : (wlLow, wlHigh)
    }

    func statusColor(category: LinkCategory, value: Int) -> Color {
        let (low, high) = thresholds(for: category)
        if value >= low { return Theme.rose }
        if value > high { return Theme.amber }
        return Theme.accentGreen
    }

    func statusBackground(category: LinkCategory, value: Int?) -> Color {
        guard let value else { return Theme.bgDark.opacity(0.4) }
        let (low, high) = thresholds(for: category)
        if value >= low { return Theme.rose.opacity(0.12) }
        if value > high { return Theme.amber.opacity(0.1) }
        return Theme.accentGreen.opacity(0.1)
    }

    func defaultValue(for category: LinkCategory) -> Int {
        category == .opt ? 15 : 60
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        do {
            async let l = supabase.fetchLinks(programId: program.id)
            async let r = supabase.fetchRecords(programId: program.id)
            async let s = supabase.fetchSpecMasters()
            links = try await l
            records = try await r
            specMasters = try await s
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reloadLinks() async {
        do { links = try await supabase.fetchLinks(programId: program.id) } catch { errorMessage = error.localizedDescription }
    }

    func reloadRecords() async {
        do { records = try await supabase.fetchRecords(programId: program.id) } catch { errorMessage = error.localizedDescription }
    }

    func subscribeRealtime() {
        guard channel == nil else { return }
        channel = supabase.subscribeToRecords(
            onSubscribed: { [weak self] in
                Task { @MainActor in
                    self?.realtimeConnected = true
                }
            },
            onChange: { [weak self] in
                Task { @MainActor in
                    await self?.reloadRecords()
                }
            }
        )
    }

    func unsubscribeRealtime() {
        if let channel {
            Task { await channel.unsubscribe() }
        }
        channel = nil
        realtimeConnected = false
    }

    // MARK: - Mutations

    func submitRecord(
        linkId: String,
        phase: Phase,
        value: Int,
        fieldMemo: String,
        centerMemo: String,
        fpuChannel: String,
        modType: String,
        presetType: String,
        tsRate: String,
        txModel: String,
        rxModel: String,
        applyToAllPhases: Bool
    ) async throws {
        let targetPhases: [Phase] = applyToAllPhases ? Phase.allCases : [phase]
        var payloads: [SupabaseService.RecordUpsertPayload] = []
        for p in targetPhases {
            let existing = record(linkId: linkId, phase: p)
            let v = (p == phase) ? value : (existing?.value ?? defaultValue(for: links.first { $0.id == linkId }?.category ?? .opt))
            payloads.append(SupabaseService.RecordUpsertPayload(
                program_id: program.id,
                link_id: linkId,
                phase: p.rawValue,
                value: v,
                field_memo: fieldMemo,
                center_memo: centerMemo,
                fpu_channel: fpuChannel,
                mod_type: modType,
                preset_type: presetType,
                ts_rate: tsRate,
                tx_model: txModel,
                rx_model: rxModel
            ))
        }
        try await supabase.upsertRecords(payloads)
        await reloadRecords()
    }

    func submitCenterMemoQuickUpdate(linkId: String, phase: Phase, centerMemo: String?, fpuChannel: String?) async throws {
        let existing = record(linkId: linkId, phase: phase)
        let category = links.first { $0.id == linkId }?.category ?? .opt
        let payload = SupabaseService.RecordUpsertPayload(
            program_id: program.id,
            link_id: linkId,
            phase: phase.rawValue,
            value: existing?.value ?? defaultValue(for: category),
            field_memo: existing?.fieldMemo ?? "",
            center_memo: centerMemo ?? existing?.centerMemo ?? "",
            fpu_channel: fpuChannel ?? existing?.fpuChannel ?? "",
            mod_type: existing?.modType ?? "",
            preset_type: existing?.presetType ?? "",
            ts_rate: existing?.tsRate ?? "",
            tx_model: existing?.txModel ?? "",
            rx_model: existing?.rxModel ?? ""
        )
        try await supabase.upsertRecord(payload)
        await reloadRecords()
    }

    func addLink(name: String, category: LinkCategory) async throws {
        let nextOrder = (links.map(\.sortOrder).max() ?? -1) + 1
        try await supabase.upsertLink(programId: program.id, name: name, category: category, sortOrder: nextOrder)
        await reloadLinks()
    }

    func deleteLink(_ link: Link) async throws {
        try await supabase.deleteLink(id: link.id)
        await reloadLinks()
        await reloadRecords()
    }

    func persistSortOrder(orderedIds: [String]) async throws {
        for (index, id) in orderedIds.enumerated() {
            try await supabase.updateLinkSortOrder(id: id, order: index)
        }
        await reloadLinks()
    }

    func importCSV(text: String) async throws -> Int {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard lines.count > 1 else { return 0 }

        var nextOrder = (links.map(\.sortOrder).max() ?? -1) + 1
        let existingOrders = Dictionary(uniqueKeysWithValues: links.map { ($0.name, $0.sortOrder) })

        var seenNames = Set<String>()
        var importedLinks: [Link] = []

        for line in lines.dropFirst() {
            let columns = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let name = columns.first, !name.isEmpty, !seenNames.contains(name) else { continue }
            seenNames.insert(name)

            var categoryRaw = columns.count > 1 ? columns[1].lowercased() : "opt"
            if categoryRaw == "sub" { categoryRaw = "opt" }
            let category = LinkCategory(rawValue: categoryRaw) ?? .opt

            let fpuChannel = columns.count > 2 ? columns[2] : ""
            let modType = columns.count > 3 ? columns[3] : ""
            let presetType = columns.count > 4 ? columns[4] : ""
            let tsRate = columns.count > 5 ? columns[5] : ""
            let txModel = columns.count > 6 ? columns[6] : ""
            let rxModel = columns.count > 7 ? columns[7] : ""

            let order = existingOrders[name] ?? nextOrder
            if existingOrders[name] == nil { nextOrder += 1 }

            let link = try await supabase.upsertLink(programId: program.id, name: name, category: category, sortOrder: order)
            importedLinks.append(link)

            var recordPayloads: [SupabaseService.RecordUpsertPayload] = []
            for phase in Phase.allCases {
                recordPayloads.append(SupabaseService.RecordUpsertPayload(
                    program_id: program.id,
                    link_id: link.id,
                    phase: phase.rawValue,
                    value: defaultValue(for: category),
                    field_memo: "",
                    center_memo: "",
                    fpu_channel: fpuChannel,
                    mod_type: modType,
                    preset_type: presetType,
                    ts_rate: tsRate,
                    tx_model: txModel,
                    rx_model: rxModel
                ))
            }
            try await supabase.upsertRecords(recordPayloads)
        }

        await reloadLinks()
        await reloadRecords()
        return importedLinks.count
    }
}
