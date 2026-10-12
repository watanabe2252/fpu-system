import Foundation

enum AppVersion {
    /// e.g. "v1.0 (2026101201)": marketing version + date-based build number.
    static var text: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }
}
