import Foundation

/// Terminal diagnostic: fetch the real limits and scan the logs, print both.
enum DumpTool {
    static func run() {
        print("Fetching /usage limits …")
        let limits = LimitsFetcher.fetch()
        print("  source: \(limits.source)")
        if let err = limits.error { print("  error: \(err)") }
        func lrow(_ label: String, _ line: LimitLine?) {
            guard let line else { return }
            let reset = line.resetsAt.map { ISO8601DateFormatter().string(from: $0) } ?? (line.resetsText ?? "")
            print(String(format: "  %-20@ %3d%%   resets %@", label as NSString, line.percent, reset))
        }
        lrow("Session (5h)", limits.session)
        lrow("Weekly (all)", limits.weeklyAll)
        for s in limits.scoped { lrow("Weekly (\(s.label))", s.line) }

        print("\nScanning logs for token activity …")
        let result = LogParser.scan(previousState: [:])
        var daily: [String: [String: Usage]] = [:]
        for ev in result.events {
            daily[Aggregator.dayKey(ev.date), default: [:]][ev.model, default: Usage()] += ev.usage
        }
        let snap = Aggregator.todayActivity(dailyByModel: daily, now: Date())
        print("  today: \(Format.tokens(snap.todayTotal)) tokens")
        for m in snap.todayByModel {
            print("    \(m.model): \(Format.tokens(m.tokens)) tok")
        }
    }
}
