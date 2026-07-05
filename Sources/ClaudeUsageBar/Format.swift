import Foundation

/// Compact, glanceable formatting for the menu bar and dropdown.
enum Format {
    static func cost(_ v: Double) -> String {
        v >= 100 ? String(format: "$%.0f", v) : String(format: "$%.2f", v)
    }

    static func tokens(_ n: Int) -> String {
        let d = Double(n)
        if d >= 1_000_000 { return String(format: "%.1fM", d / 1_000_000) }
        if d >= 1_000 { return String(format: "%.0fk", d / 1_000) }
        return "\(n)"
    }

    static func time(_ interval: TimeInterval) -> String {
        let m = Int(interval / 60)
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }
}
