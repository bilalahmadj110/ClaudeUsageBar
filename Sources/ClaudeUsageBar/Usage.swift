import Foundation

/// A bucket of token counts, summed however we need (per day, per model, per block).
struct Usage: Codable, Equatable {
    var input = 0
    var output = 0
    var cacheCreation = 0
    var cacheRead = 0

    /// Total billable tokens — input + output + both cache flavors.
    var totalTokens: Int { input + output + cacheCreation + cacheRead }

    static func += (lhs: inout Usage, rhs: Usage) {
        lhs.input += rhs.input
        lhs.output += rhs.output
        lhs.cacheCreation += rhs.cacheCreation
        lhs.cacheRead += rhs.cacheRead
    }

    static func + (lhs: Usage, rhs: Usage) -> Usage {
        var r = lhs; r += rhs; return r
    }
}

/// One assistant message's usage, with when it happened and which model produced it.
struct UsageEvent: Codable {
    let date: Date
    let model: String
    let usage: Usage
}

/// Per-file read cursor so each refresh only tails what changed.
struct FileCursor: Codable, Equatable {
    var size: Int
    var mtime: Double
    var offset: Int
}
