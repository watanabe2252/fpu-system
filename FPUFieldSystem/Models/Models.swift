import Foundation

struct Program: Codable, Identifiable, Hashable {
    let id: String
    var title: String
}

enum LinkCategory: String, Codable, CaseIterable {
    case main
    case relay
    case opt
}

struct Link: Codable, Identifiable, Hashable {
    let id: String
    let programId: String
    var name: String
    var category: LinkCategory
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case programId = "program_id"
        case name
        case category
        case sortOrder = "sort_order"
    }
}

enum Phase: String, Codable, CaseIterable, Identifiable {
    case run
    case tech
    case rehe
    case prod

    var id: String { rawValue }

    var label: String {
        switch self {
        case .run: return "走行"
        case .tech: return "技術"
        case .rehe: return "総合リハ"
        case .prod: return "本番"
        }
    }
}

struct Record: Codable, Identifiable, Hashable {
    let id: Int
    let programId: String
    let linkId: String
    var phase: Phase
    var value: Int?
    var fieldMemo: String?
    var centerMemo: String?
    var fpuChannel: String?
    var modType: String?
    var presetType: String?
    var tsRate: String?
    var txModel: String?
    var rxModel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case programId = "program_id"
        case linkId = "link_id"
        case phase
        case value
        case fieldMemo = "field_memo"
        case centerMemo = "center_memo"
        case fpuChannel = "fpu_channel"
        case modType = "mod_type"
        case presetType = "preset_type"
        case tsRate = "ts_rate"
        case txModel = "tx_model"
        case rxModel = "rx_model"
    }
}

enum UserRoleType: String, Codable {
    case admin
    case staff
}

struct UserRoleRecord: Codable, Identifiable, Hashable {
    let id: String
    var email: String
    var role: UserRoleType
}

enum SpecMasterCategory: String, Codable {
    case modulation
    case preset
    case tsRate = "ts_rate"
}

struct MapLocation: Codable, Identifiable, Hashable {
    let id: String
    let programId: String
    var name: String
    var latitude: Double
    var longitude: Double

    enum CodingKeys: String, CodingKey {
        case id
        case programId = "program_id"
        case name
        case latitude
        case longitude
    }
}

struct SpecMaster: Codable, Identifiable, Hashable {
    let id: Int
    var category: SpecMasterCategory
    var value: String
    var label: String
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case value
        case label
        case sortOrder = "sort_order"
    }
}
