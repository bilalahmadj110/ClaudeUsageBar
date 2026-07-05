import Foundation
import SwiftUI

/// Owns two things and publishes them for the UI:
///  1. `limits` — the real `/usage` percentages (session / weekly / scoped), fetched live.
///  2. `snapshot` — local token activity from the logs (secondary "what have I run" info).
/// The menu-bar label reflects the real limit the user picked. A single timer polls both.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var limits: UsageLimits?
    @Published private(set) var snapshot = UsageSnapshot()
    @Published private(set) var barText = "…"

    private var dailyByModel: [String: [String: Usage]] = [:]
    private var fileState: [String: FileCursor] = [:]
    private var timer: Timer?
    private var isScanning = false
    private var isFetchingLimits = false

    init() {
        loadCache()
        rebuildActivity()
        refresh()
        startTimer()
    }

    // MARK: - Refresh (both the real limits and the local activity)

    func refresh() {
        refreshLimits()
        refreshLogs()
    }

    func refreshLimits() {
        guard !isFetchingLimits else { return }
        isFetchingLimits = true
        Task.detached(priority: .utility) {
            let result = LimitsFetcher.fetch()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isFetchingLimits = false
                // A transient failure (429 / network blip) shouldn't blank good numbers we
                // already have — keep the last good ones and only show an error if we have none.
                if result.error == nil || self.limits == nil || self.limits?.error != nil {
                    self.limits = result
                }
                self.updateBarText()
            }
        }
    }

    private func refreshLogs() {
        guard !isScanning else { return }
        isScanning = true
        let prev = fileState
        Task.detached(priority: .utility) {
            let result = LogParser.scan(previousState: prev)
            await MainActor.run { [weak self] in self?.applyLogs(result) }
        }
    }

    private func applyLogs(_ result: ScanResult) {
        isScanning = false
        for ev in result.events {
            let day = Aggregator.dayKey(ev.date)
            dailyByModel[day, default: [:]][ev.model, default: Usage()] += ev.usage
        }
        pruneOldDays()
        fileState = result.fileState
        rebuildActivity()
        saveCache()
    }

    /// Called when a setting changes: re-time the poll and re-render immediately.
    func settingsChanged() {
        startTimer()
        updateBarText()
    }

    // MARK: - Derived

    private func rebuildActivity() {
        snapshot = Aggregator.todayActivity(dailyByModel: dailyByModel, now: Date())
    }

    private func updateBarText() {
        guard let limits else { barText = "…"; return }
        if let line = limits.line(for: Settings.limitChoice) {
            barText = "\(line.percent)%"
        } else {
            barText = limits.error != nil ? "!" : "—"
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = max(15, Settings.refreshInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func pruneOldDays() {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -62, to: cal.startOfDay(for: Date())) else { return }
        for day in dailyByModel.keys {
            if let dd = Aggregator.date(fromKey: day), dd < cutoff { dailyByModel[day] = nil }
        }
    }

    // MARK: - Cache (local activity only; limits are always fetched fresh)

    private struct CacheData: Codable {
        var dailyByModel: [String: [String: Usage]]
        var fileState: [String: FileCursor]
    }

    private static var cacheURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeUsageBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("cache.json")
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let cache = try? JSONDecoder().decode(CacheData.self, from: data) else { return }
        dailyByModel = cache.dailyByModel
        fileState = cache.fileState
    }

    private func saveCache() {
        let cache = CacheData(dailyByModel: dailyByModel, fileState: fileState)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
    }
}
