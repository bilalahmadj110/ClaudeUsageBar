import SwiftUI
import AppKit

/// The dropdown panel: the real `/usage` limits up top, local token activity below.
struct MenuBarView: View {
    @ObservedObject var store: UsageStore
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showSettings {
                SettingsPane(showSettings: $showSettings, store: store)
            } else {
                mainPane
            }
        }
        .frame(width: 320)
        .padding(12)
        .onAppear { store.onDropdownOpen() }
    }

    private var mainPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            limitsSection
            if !store.snapshot.todayByModel.isEmpty {
                Divider()
                activitySection
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "gauge.medium").foregroundStyle(.tint)
            Text("Claude Usage").font(.headline)
            Spacer()
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Settings")
        }
    }

    @ViewBuilder private var limitsSection: some View {
        if let limits = store.limits {
            if let err = limits.error {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(err).foregroundStyle(.secondary)
                }
                .font(.subheadline)
            } else {
                VStack(spacing: 10) {
                    if let l = limits.session { LimitRow(title: "Session · 5 hours", line: l) }
                    if let l = limits.weeklyAll { LimitRow(title: "Weekly · all models", line: l) }
                    ForEach(limits.scoped) { s in
                        LimitRow(title: "Weekly · \(s.label)", line: s.line)
                    }
                }
            }
        } else {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking usage…").foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Activity today").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Format.tokens(store.snapshot.todayTotal)) tokens")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            ForEach(store.snapshot.todayByModel.prefix(4), id: \.model) { m in
                HStack {
                    Text(m.model)
                    Spacer()
                    Text(Format.tokens(m.tokens)).monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            Text("Local token counts from your logs (this machine only).")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        HStack {
            Button { store.refresh(force: true) } label: { Label(refreshLabel, systemImage: "arrow.clockwise") }
                .buttonStyle(.borderless)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .font(.caption)
    }

    private var refreshLabel: String {
        guard let d = store.limits?.fetchedAt else { return "Refresh" }
        let s = Int(Date().timeIntervalSince(d))
        return s < 5 ? "Just now" : "\(s)s ago"
    }
}

/// One real limit line: title, big percentage, colored meter, and reset time.
struct LimitRow: View {
    var title: String
    var line: LimitLine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(line.percent)%").font(.subheadline).bold().monospacedDigit()
                    .foregroundStyle(color)
            }
            MeterBar(fraction: line.fraction, color: color)
            Text(resetText).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch line.percent {
        case ..<60: return .green
        case ..<85: return .yellow
        default: return .red
        }
    }

    private var resetText: String {
        if let at = line.resetsAt {
            let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none
            let day = Calendar.current.isDateInToday(at) ? "" : dayPrefix(at) + " "
            let remaining = line.remaining.map { " · in \(Format.time($0))" } ?? ""
            return "resets \(day)\(f.string(from: at))\(remaining)"
        }
        if let t = line.resetsText { return "resets \(t)" }
        return " "
    }

    private func dayPrefix(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: d)
    }
}

/// A thin meter with a colored fill.
struct MeterBar: View {
    var fraction: Double
    var color: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.18))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(3, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 8)
    }
}

/// The inline settings pane, reachable via the gear button.
struct SettingsPane: View {
    @Binding var showSettings: Bool
    @ObservedObject var store: UsageStore

    @AppStorage(Settings.Keys.limitChoice) private var limitChoice = LimitChoice.session.rawValue
    @AppStorage(Settings.Keys.refreshInterval) private var refreshInterval = 600.0
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { showSettings = false } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                Text("Settings").font(.headline)
                Spacer()
            }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, v in LoginItem.setEnabled(v) }

            VStack(alignment: .leading, spacing: 4) {
                Text("Menu bar shows").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $limitChoice) {
                    ForEach(LimitChoice.allCases) { c in Text(c.label).tag(c.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: limitChoice) { _, _ in store.settingsChanged() }
                Text("“Highest” shows whichever limit is closest to running out.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Background refresh").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $refreshInterval) {
                    Text("5m").tag(300.0)
                    Text("10m").tag(600.0)
                    Text("20m").tag(1200.0)
                    Text("30m").tag(1800.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: refreshInterval) { _, _ in store.settingsChanged() }
                Text("It also refreshes when you open this menu. The usage endpoint rate-limits hard, so slower is safer.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            Text("Live figures from Claude Code's /usage. Nothing leaves your machine except the same usage check Claude Code already makes.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
