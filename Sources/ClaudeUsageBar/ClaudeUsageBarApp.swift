import SwiftUI

/// Menu-bar-only app (no Dock icon; `LSUIElement` is set in Info.plist). The label shows
/// the compact usage string; clicking it opens the dropdown panel.
struct ClaudeUsageBarApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(store: store)
        } label: {
            // The label MUST be its own view that observes the store via @ObservedObject.
            // Reading store.barText directly in the App/Scene body does not reliably
            // re-render the menu-bar item — the text freezes at its first value.
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The compact menu-bar label. As an `@ObservedObject` view it re-renders whenever the
/// store publishes (timer refresh, or a settings change), keeping the text live.
struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        Label(store.barText, systemImage: "gauge.medium")
            .labelStyle(.titleAndIcon)
    }
}
