import Foundation
import ServiceManagement

/// Registers the app as a macOS login item via `SMAppService`.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("ClaudeUsageBar: login item toggle failed: \(error.localizedDescription)")
        }
    }
}
