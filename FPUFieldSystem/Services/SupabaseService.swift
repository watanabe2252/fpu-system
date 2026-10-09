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

    func updateProgramTitle(id: String, title: String) async throws {
        try await client.from("programs").update(["title": title]).eq("id", value: id).execute()
    }

    func duplicateProgram(sourceId: String, targetId: String, targetTitle: String) async throws {
        try await client.from("programs").insert(Program(id: targetId, title: targetTitle)).execute()

        let sourceLinks: [Link] = try await client.from("links")
            .select()
            .eq("program_id", value: sourceId)
            .execute()
            .value

        guard !sourceLinks.isEmpty else { return }

        struct DuplicatedLink: Encodable {
            let program_id: String
            let name: String
            let category: String
            let sort_order: Int
        }
        let payloads = sourceLinks.map {
            DuplicatedLink(program_id: targetId, name: $0.name, category: $0.category.rawValue, sort_order: $0.sortOrder)
        }
        try await client.from("links").insert(payloads).execute()
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

    struct LinkEditPayload: Encodable {
        let name: String
        let category: String
    }

    func updateLink(id: String, name: String, category: LinkCategory) async throws {
        try await client.from("links")
            .update(LinkEditPayload(name: name, category: category.rawValue))
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Records

    func fetchRecords(programId: String) async throws -> [Record] {
        try await client.from("records")
            .select()
            .eq("program_id", value: programId)
            .execute()
            .value
    }

    /// `value` is encoded manually so that `nil` is always sent as an explicit JSON
    /// `null` (meaning "not entered"), rather than Swift's synthesized `encodeIfPresent`
    /// silently omitting the key — which would leave an existing DB value untouched
    /// instead of clearing it.
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

        enum CodingKeys: String, CodingKey {
            case program_id, link_id, phase, value, field_memo, center_memo, fpu_channel, mod_type, preset_type, ts_rate, tx_model, rx_model
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(program_id, forKey: .program_id)
            try container.encode(link_id, forKey: .link_id)
            try container.encode(phase, forKey: .phase)
            if let value {
                try container.encode(value, forKey: .value)
            } else {
                try container.encodeNil(forKey: .value)
            }
            try container.encode(field_memo, forKey: .field_memo)
            try container.encode(center_memo, forKey: .center_memo)
            try container.encode(fpu_channel, forKey: .fpu_channel)
            try container.encode(mod_type, forKey: .mod_type)
            try container.encode(preset_type, forKey: .preset_type)
            try container.encode(ts_rate, forKey: .ts_rate)
            try container.encode(tx_model, forKey: .tx_model)
            try container.encode(rx_model, forKey: .rx_model)
        }
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

    /// Encodes explicitly as `{"value":null}`. A plain `let value: Int?` would use
    /// Swift's synthesized `encodeIfPresent`, which *omits* the key entirely when nil
    /// instead of sending JSON null — silently turning this into a no-op update.
    struct NullValuePayload: Encodable {
        enum CodingKeys: String, CodingKey { case value }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeNil(forKey: .value)
        }
    }

    /// Resets every record's electric field value back to "not entered" (NULL) for a program.
    func resetAllRecordValues(programId: String) async throws {
        try await client.from("records")
            .update(NullValuePayload())
            .eq("program_id", value: programId)
            .execute()
    }

    // MARK: - Locations (map)

    func fetchLocations(programId: String) async throws -> [MapLocation] {
        try await client.from("locations")
            .select()
            .eq("program_id", value: programId)
            .execute()
            .value
    }

    /// `elevation`/`height_above_ground`/`antenna_gain` are encoded manually so that `nil`
    /// is always sent as an explicit JSON `null` rather than Swift's synthesized
    /// `encodeIfPresent` silently omitting the key (see RecordUpsertPayload for the same fix).
    struct LocationUpsertPayload: Encodable {
        let program_id: String
        let name: String
        let latitude: Double
        let longitude: Double
        let elevation: Double?
        let height_above_ground: Double?
        let antenna_gain: Double?

        enum CodingKeys: String, CodingKey {
            case program_id, name, latitude, longitude, elevation, height_above_ground, antenna_gain
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(program_id, forKey: .program_id)
            try container.encode(name, forKey: .name)
            try container.encode(latitude, forKey: .latitude)
            try container.encode(longitude, forKey: .longitude)
            if let elevation { try container.encode(elevation, forKey: .elevation) } else { try container.encodeNil(forKey: .elevation) }
            if let height_above_ground { try container.encode(height_above_ground, forKey: .height_above_ground) } else { try container.encodeNil(forKey: .height_above_ground) }
            if let antenna_gain { try container.encode(antenna_gain, forKey: .antenna_gain) } else { try container.encodeNil(forKey: .antenna_gain) }
        }
    }

    func upsertLocation(
        programId: String,
        name: String,
        latitude: Double,
        longitude: Double,
        elevation: Double? = nil,
        heightAboveGround: Double? = nil,
        antennaGain: Double? = nil
    ) async throws {
        let payload = LocationUpsertPayload(
            program_id: programId,
            name: name,
            latitude: latitude,
            longitude: longitude,
            elevation: elevation,
            height_above_ground: heightAboveGround,
            antenna_gain: antennaGain
        )
        try await client.from("locations")
            .upsert(payload, onConflict: "program_id,name")
            .execute()
    }

    struct LocationCoordinatePayload: Encodable {
        let latitude: Double
        let longitude: Double
    }

    /// Updates only the coordinate of an existing location, leaving elevation/height/gain untouched.
    func updateLocationCoordinate(id: String, latitude: Double, longitude: Double) async throws {
        try await client.from("locations")
            .update(LocationCoordinatePayload(latitude: latitude, longitude: longitude))
            .eq("id", value: id)
            .execute()
    }

    func deleteLocation(id: String) async throws {
        try await client.from("locations").delete().eq("id", value: id).execute()
    }

    // MARK: - Spec masters

    func fetchSpecMasters() async throws -> [SpecMaster] {
        try await client.from("spec_masters")
            .select()
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    // MARK: - Account creation

    private static let supabaseURL = URL(string: "https://iyzadjupyejeyeeyvwqm.supabase.co")!
    private static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5emFkanVweWVqZXllZXl2d3FtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1OTE2NjgsImV4cCI6MjA5OTE2NzY2OH0.T6oXWP6s35wg77Nzuez7zrWVg49n6FFI0NzkW9z6QCQ"

    /// Creates a brand-new auth account without disturbing the currently signed-in (admin) session.
    /// Uses a throwaway client with an isolated storage key so it never touches the main client's
    /// persisted session.
    func createUserAccount(email: String, password: String, role: UserRoleType) async throws {
        let tempClient = SupabaseClient(
            supabaseURL: Self.supabaseURL,
            supabaseKey: Self.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(storageKey: "fpu-temp-signup-\(UUID().uuidString)")
            )
        )
        let response = try await tempClient.auth.signUp(email: email, password: password)
        let userId = response.user.id.uuidString

        struct Payload: Encodable {
            let id: String
            let email: String
            let role: String
        }
        try await client.from("user_roles")
            .upsert(Payload(id: userId, email: email, role: role.rawValue), onConflict: "id")
            .execute()
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

    func subscribeToRecords(onSubscribed: @escaping () -> Void, onChange: @escaping () -> Void) -> RealtimeChannelV2 {
        let channel = client.channel("live-records-pipeline")
        let changes = channel.postgresChange(AnyAction.self, schema: "public", table: "records")

        Task {
            do {
                try await channel.subscribeWithError()
                onSubscribed()
            } catch {
                return
            }
            for await _ in changes {
                onChange()
            }
        }

        return channel
    }
}
