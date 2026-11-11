import SwiftUI

/// PatchDesk — a native macOS front-end for the Issue-to-Patch Agent CLI.
/// Pick an issue file and a repo folder, press Run, and review the
/// validated patch draft. Nothing is ever applied to the real repo:
/// the CLI writes `patch.diff` for a human to review and apply.
@main
struct PatchDeskApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
