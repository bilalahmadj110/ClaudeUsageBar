import Foundation

/// Which real limit the compact menu-bar label shows.
enum LimitChoice: String, CaseIterable, Identifiable {
    case session, weekly, highest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .session: return "Session"
        case .weekly: return "Weekly"
        case .highest: return "Highest"
        }
    }
}

/// Typed access to the handful of user-tunable settings, backed by UserDefaults.
/// Views bind to the same keys via `@AppStorage`.
enum Settings {
    private static let d = UserDefaults.standard
    enum Keys {
        static let limitChoice = "limitChoice"
        static let refreshInterval = "refreshInterval"
    }

    static var limitChoice: LimitChoice {
        LimitChoice(rawValue: d.string(forKey: Keys.limitChoice) ?? "") ?? .session
    }
    static var refreshInterval: TimeInterval {
        let v = d.double(forKey: Keys.refreshInterval)
        return v > 0 ? v : 120   // usage % changes slowly; be gentle on the endpoint
    }
}
