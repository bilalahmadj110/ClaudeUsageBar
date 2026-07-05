import Foundation

/// The local token-activity view the UI renders (secondary to the real limits).
struct UsageSnapshot {
    var todayTotal = 0
    var todayByModel: [(model: String, tokens: Int)] = []
}

/// Rolls per-day/per-model token aggregates into today's activity summary.
enum Aggregator {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func date(fromKey key: String) -> Date? { dayFormatter.date(from: key) }

    static func todayActivity(dailyByModel: [String: [String: Usage]], now: Date) -> UsageSnapshot {
        let models = dailyByModel[dayKey(now)] ?? [:]
        var total = 0
        var byModel: [(model: String, tokens: Int)] = []
        for (model, u) in models {
            total += u.totalTokens
            byModel.append((prettyModel(model), u.totalTokens))
        }
        byModel.sort { $0.tokens > $1.tokens }
        return UsageSnapshot(todayTotal: total, todayByModel: byModel)
    }

    /// "claude-opus-4-8" -> "Opus 4.8"; "claude-haiku-4-5-20251001" -> "Haiku 4.5".
    static func prettyModel(_ id: String) -> String {
        var s = id
        if s.hasPrefix("claude-") { s.removeFirst("claude-".count) }
        var kept: [String] = []
        for p in s.split(separator: "-") {
            if p.count == 8, Int(p) != nil { continue }   // drop a trailing yyyymmdd snapshot
            kept.append(String(p))
        }
        guard let family = kept.first else { return id }
        let name = family.prefix(1).uppercased() + family.dropFirst()
        let ver = kept.dropFirst().joined(separator: ".")
        return ver.isEmpty ? name : "\(name) \(ver)"
    }
}
