import Foundation

/// One rate-limit line as shown by `/usage` — a percentage plus when it resets.
struct LimitLine {
    var percent: Int
    var resetsAt: Date?        // precise, from the JSON endpoint
    var resetsText: String?    // human phrase, from the CLI fallback ("Jul 5 at 4:29pm …")

    var fraction: Double { min(1, max(0, Double(percent) / 100)) }
    var remaining: TimeInterval? { resetsAt.map { max(0, $0.timeIntervalSinceNow) } }
}

/// A model-scoped weekly limit (e.g. "Fable" on Max; could be "Opus"/"Sonnet" on other plans).
struct ScopedLimit: Identifiable {
    var label: String
    var line: LimitLine
    var id: String { label }
}

/// The real server-side usage picture, mirroring Claude Code's `/usage`. Plan-agnostic:
/// `session` and `weeklyAll` appear on every subscription; `scoped` holds whatever
/// model-specific weekly limits the account's plan returns (zero or more).
struct UsageLimits {
    var session: LimitLine?
    var weeklyAll: LimitLine?
    var scoped: [ScopedLimit]
    var fetchedAt: Date
    var source: String            // "api" | "none"
    var error: String?
    var rateLimited = false        // true when the endpoint returned 429 → back off

    /// The line the menu-bar label should reflect, per the user's choice.
    func line(for choice: LimitChoice) -> LimitLine? {
        switch choice {
        case .session: return session
        case .weekly: return weeklyAll
        case .highest:
            let all = [session, weeklyAll].compactMap { $0 } + scoped.map { $0.line }
            return all.max { $0.percent < $1.percent }
        }
    }
}
