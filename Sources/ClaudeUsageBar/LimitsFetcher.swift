import Foundation

/// Fetches the real `/usage` limit percentages, exactly like Claude Code does — but with a
/// deliberately tiny footprint: read the OAuth token Claude Code already stored in the
/// Keychain, then `GET https://api.anthropic.com/api/oauth/usage`. That's the only network
/// call, and the only files it ever touches are its own Keychain item and the log folder.
///
/// It never launches other programs and never refreshes the token itself — refreshing could
/// rotate the token out from under Claude Code and break its sign-in. When the token is
/// expired the app simply asks the user to open Claude Code (which refreshes it), and keeps
/// showing the last-known-good numbers in the meantime.
///
/// Blocking (Process for the Keychain read, URLSession via semaphore) — call off the main thread.
enum LimitsFetcher {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let keychainService = "Claude Code-credentials"

    static func fetch() -> UsageLimits {
        guard let (token, exp) = keychainToken() else {
            return failure("Open Claude Code and sign in to see your usage.")
        }
        if let exp, exp < Date().addingTimeInterval(30) {
            return failure("Token expired — open Claude Code to refresh.")
        }
        let (limits, status) = httpUsage(token: token)
        if let limits { return limits }
        switch status {
        case 429: return failure("Usage check rate-limited — retrying shortly.")
        case 401, 403: return failure("Open Claude Code to refresh your sign-in.")
        default: return failure("Usage temporarily unavailable — retrying.")
        }
    }

    private static func failure(_ message: String) -> UsageLimits {
        UsageLimits(session: nil, weeklyAll: nil, scoped: [], fetchedAt: Date(), source: "none", error: message)
    }

    // MARK: - Keychain (read-only; the `security` tool touches only the Keychain, not TCC folders)

    private static func keychainToken() -> (token: String, expiresAt: Date?)? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", keychainService, "-w"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String
        else { return nil }
        var exp: Date?
        if let ms = oauth["expiresAt"] as? Double { exp = Date(timeIntervalSince1970: ms / 1000) }
        else if let ms = oauth["expiresAt"] as? Int { exp = Date(timeIntervalSince1970: Double(ms) / 1000) }
        return (token, exp)
    }

    // MARK: - Direct HTTP

    private static func httpUsage(token: String) -> (UsageLimits?, Int?) {
        var req = URLRequest(url: usageURL)
        req.httpMethod = "GET"
        req.timeoutInterval = 8
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var out: UsageLimits?
        var status: Int?
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            defer { sem.signal() }
            status = (resp as? HTTPURLResponse)?.statusCode
            guard status == 200, let data else { return }
            out = parseJSON(data)
        }.resume()
        _ = sem.wait(timeout: .now() + 10)
        return (out, status)
    }

    private static func parseJSON(_ data: Data) -> UsageLimits? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limits = obj["limits"] as? [[String: Any]] else { return nil }

        var session: LimitLine?, weeklyAll: LimitLine?
        var scoped: [ScopedLimit] = []
        for l in limits {
            guard let kind = l["kind"] as? String, let pct = intVal(l["percent"]) else { continue }
            let line = LimitLine(percent: pct, resetsAt: isoDate(l["resets_at"] as? String), resetsText: nil)
            switch kind {
            case "session": session = line
            case "weekly_all": weeklyAll = line
            case "weekly_scoped":
                // Plan-agnostic: whatever model this scoped limit is for (Fable, Opus, …).
                let label = ((l["scope"] as? [String: Any])?["model"] as? [String: Any])?["display_name"] as? String
                scoped.append(ScopedLimit(label: label ?? "scoped", line: line))
            default: break
            }
        }
        guard session != nil || weeklyAll != nil else { return nil }
        return UsageLimits(session: session, weeklyAll: weeklyAll, scoped: scoped,
                           fetchedAt: Date(), source: "api", error: nil)
    }

    // MARK: - Helpers

    private static func intVal(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let d = v as? Double { return Int(d.rounded()) }
        return nil
    }

    /// Parses an ISO-8601 timestamp with an offset. The API sends microsecond fractions
    /// (`.227434`) which `ISO8601DateFormatter` chokes on, so strip fractional seconds first.
    private static func isoDate(_ s: String?) -> Date? {
        guard var str = s else { return nil }
        if let r = str.range(of: #"\.\d+"#, options: .regularExpression) { str.removeSubrange(r) }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }
}
