import Foundation

struct ScanResult {
    var events: [UsageEvent]
    var fileState: [String: FileCursor]
}

/// Streams the Claude Code JSONL logs and extracts token-usage events.
///
/// Only `type == "assistant"` lines carry `message.usage`. We cheap-prefilter on the
/// `input_tokens` substring before doing any JSON work, and tail each file from a saved
/// byte offset so a refresh only re-reads what was appended.
enum LogParser {
    static let projectsDir: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)

    /// Only the fields we need; JSONDecoder ignores everything else on the line.
    private struct Line: Decodable {
        let type: String?
        let timestamp: String?
        let message: Message?
        struct Message: Decodable {
            let model: String?
            let usage: Usage?
            struct Usage: Decodable {
                let input_tokens: Int?
                let output_tokens: Int?
                let cache_creation_input_tokens: Int?
                let cache_read_input_tokens: Int?
            }
        }
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static func parseDate(_ s: String) -> Date? {
        isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }

    private static let needle = Data("input_tokens".utf8)

    static func scan(previousState: [String: FileCursor]) -> ScanResult {
        var events: [UsageEvent] = []
        var newState: [String: FileCursor] = [:]
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ScanResult(events: [], fileState: previousState)
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let path = url.path
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let size = attrs?.fileSize ?? 0
            let mtime = attrs?.contentModificationDate?.timeIntervalSince1970 ?? 0

            var startOffset = 0
            if let prev = previousState[path] {
                if prev.size == size && prev.mtime == mtime {
                    newState[path] = prev          // unchanged — skip entirely
                    continue
                }
                // If the file shrank (rotated/truncated), re-read from the start.
                startOffset = size >= prev.offset ? prev.offset : 0
            }

            let (newEvents, consumedTo) = parseFile(url: url, from: startOffset)
            events.append(contentsOf: newEvents)
            newState[path] = FileCursor(size: size, mtime: mtime, offset: consumedTo)
        }

        return ScanResult(events: events, fileState: newState)
    }

    /// Reads `url` from byte `offset`, parses complete lines, and returns the events plus
    /// the new offset (just past the last complete newline — a partial trailing line waits).
    private static func parseFile(url: URL, from offset: Int) -> ([UsageEvent], Int) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return ([], offset) }
        defer { try? handle.close() }
        if offset > 0 {
            do { try handle.seek(toOffset: UInt64(offset)) } catch { return ([], offset) }
        }
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return ([], offset) }

        var events: [UsageEvent] = []
        let decoder = JSONDecoder()
        var searchStart = data.startIndex   // 0 for a freshly read Data
        var consumed = 0

        while let nl = data[searchStart...].firstIndex(of: 0x0A) {
            let lineData = data[searchStart..<nl]
            if let ev = decode(lineData, decoder: decoder) { events.append(ev) }
            let next = data.index(after: nl)
            consumed = next            // absolute index just past this newline
            searchStart = next
        }

        return (events, offset + consumed)
    }

    private static func decode(_ lineData: Data, decoder: JSONDecoder) -> UsageEvent? {
        guard !lineData.isEmpty, lineData.range(of: needle) != nil else { return nil }
        guard let line = try? decoder.decode(Line.self, from: Data(lineData)) else { return nil }
        guard line.type == "assistant",
              let msg = line.message,
              let model = msg.model, model != "<synthetic>",
              let u = msg.usage,
              let ts = line.timestamp,
              let date = parseDate(ts)
        else { return nil }

        let usage = Usage(
            input: u.input_tokens ?? 0,
            output: u.output_tokens ?? 0,
            cacheCreation: u.cache_creation_input_tokens ?? 0,
            cacheRead: u.cache_read_input_tokens ?? 0
        )
        return UsageEvent(date: date, model: model, usage: usage)
    }
}
