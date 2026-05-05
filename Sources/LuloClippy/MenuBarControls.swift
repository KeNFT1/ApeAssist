import SwiftUI
import AppKit

struct MenuBarControls: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(appState.buddyVisible ? "Hide Desktop Buddy" : "Show Desktop Buddy") {
            appState.setBuddyVisible(!appState.buddyVisible)
        }

        Button("Open Chat Panel") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "chat")
        }

        Menu("Animation State") {
            ForEach(AssistantStatus.allCases) { status in
                Button {
                    appState.setStatus(status)
                } label: {
                    Label(status.label, systemImage: status.systemImage)
                }
            }

            Divider()

            Toggle("Show Buddy Debug Controls", isOn: $appState.showAnimationDebug)
        }

        Divider()

        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }

        Divider()

        Button("Quit Lulo Clippy") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
