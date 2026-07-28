import Foundation
import Supabase

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let client: SupabaseClient

    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    @Published var currentUserEmail: String?
    @Published var currentUserRole: UserRoleType = .staff

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://iyzadjupyejeyeeyvwqm.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5emFkanVweWVqZXllZXl2d3FtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1OTE2NjgsImV4cCI6MjA5OTE2NzY2OH0.T6oXWP6s35wg77Nzuez7zrWVg49n6FFI0NzkW9z6QCQ"
        )
    }

    // MARK: - Auth

    func restoreSession() async {
        do {
            let session = try await client.auth.session
            await handleSignedIn(userId: session.user.id.uuidString, email: session.user.email)
        } catch {
            isAuthenticated = false
        }
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        await handleSignedIn(userId: session.user.id.uuidString, email: session.user.email)
    }

    func signOut() async {
        try? await client.auth.signOut()
        isAuthenticated = false
        currentUserId = nil
        currentUserEmail = nil
        currentUserRole = .staff
    }

    private func handleSignedIn(userId: String, email: String?) async {
        currentUserId = userId
        currentUserEmail = email

        if email == "admin@fpu.system" {
            currentUserRole = .admin
            struct UpsertRole: Encodable {
                let id: String
                let email: String
                let role: String
            }
            _ = try? await client.from("user_roles")
                .upsert(UpsertRole(id: userId, email: email ?? "", role: "admin"), onConflict: "id")
                .execute()
        } else {
            let role: UserRoleRecord? = try? await client.from("user_roles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            currentUserRole = role?.role ?? .staff
        }
        isAuthenticated = true
    }

    // MARK: - Programs

    func fetchPrograms() async throws -> [Program] {
        try await client.from("programs").select().execute().value
    }

    func createProgram(id: String, title: String) async throws {
        try await client.from("programs").insert(Program(id: id, title: title)).execute()
    }

    func deleteProgram(id: String) async throws {
        try await client.from("records").delete().eq("program_id", value: id).execute()
        try await client.from("links").delete().eq("program_id", value: id).execute()
        try await client.from("programs").delete().eq("id", value: id).execute()
    }

    // MARK: - Links

    func fetchLinks(programId: String) async throws -> [Link] {
        try await client.from("links")
            .select()
            .eq("program_id", value: programId)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    struct LinkUpsertPayload: Encodable {
        let program_id: String
        let name: String
        let category: String
        let sort_order: Int
    }

    @discardableResult
    func upsertLink(programId: String, name: String, category: LinkCategory, sortOrder: Int) async throws -> Link {
        let payload = LinkUpsertPayload(program_id: programId, name: name, category: category.rawValue, sort_order: sortOrder)
        let result: [Link] = try await client.from("links")
            .upsert(payload, onConflict: "program_id,name")
            .select()
            .execute()
            .value
        guard let link = result.first else {
            throw NSError(domain: "SupabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "リンクの作成に失敗しました"])
        }
        return link
    }

    func deleteLink(id: String) async throws {
        try await client.from("records").delete().eq("link_id", value: id).execute()
        try await client.from("links").delete().eq("id", value: id).execute()
    }

    func updateLinkSortOrder(id: String, order: Int) async throws {
        try await client.from("links").update(["sort_order": order]).eq("id", value: id).execute()
    }

    // MARK: - Records

    func fetchRecords(programId: String) async throws -> [Record] {
        try await client.from("records")
            .select()
            .eq("program_id", value: programId)
            .execute()
            .value
    }

    struct RecordUpsertPayload: Encodable {
        let program_id: String
        let link_id: String
        let phase: String
        let value: Int?
        let field_memo: String
        let center_memo: String
        let fpu_channel: String
        let mod_type: String
        let preset_type: String
        let ts_rate: String
        let tx_model: String
        let rx_model: String
    }

    func upsertRecord(_ payload: RecordUpsertPayload) async throws {
        try await client.from("records")
            .upsert(payload, onConflict: "program_id,link_id,phase")
            .execute()
    }

    func upsertRecords(_ payloads: [RecordUpsertPayload]) async throws {
        try await client.from("records")
            .upsert(payloads, onConflict: "program_id,link_id,phase")
            .execute()
    }

    // MARK: - Spec masters

    func fetchSpecMasters() async throws -> [SpecMaster] {
        try await client.from("spec_masters")
            .select()
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    // MARK: - User roles

    func fetchManagedUserRoles() async throws -> [UserRoleRecord] {
        try await client.from("user_roles")
            .select()
            .neq("email", value: "admin@fpu.system")
            .order("email", ascending: true)
            .execute()
            .value
    }

    func setUserRole(id: String, role: UserRoleType) async throws {
        try await client.from("user_roles").update(["role": role.rawValue]).eq("id", value: id).execute()
    }

    // MARK: - Realtime

    func subscribeToRecords(onChange: @escaping () -> Void) -> RealtimeChannelV2 {
        let channel = client.channel("live-records-pipeline")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "records")

        Task {
            try? await channel.subscribeWithError()
            for await _ in changes {
                onChange()
            }
        }

        return channel
    }
}
