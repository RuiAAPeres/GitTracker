import AppKit
import SwiftUI

struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 20, height: 20)
            .onReceive(NotificationCenter.default.publisher(for: .gitTrackerOpenSettings)) { _ in
                Task { @MainActor in
                    openSettings()
                }
            }
            .onAppear {
                guard let window = NSApp.windows.first(where: { $0.title == "GitTrackerLifecycleKeepalive" }) else {
                    return
                }
                // Keep SwiftUI lifecycle alive without showing a visible app window.
                window.styleMask = [.borderless]
                window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
                window.isExcludedFromWindowsMenu = true
                window.level = .floating
                window.isOpaque = false
                window.alphaValue = 0
                window.backgroundColor = .clear
                window.hasShadow = false
                window.ignoresMouseEvents = true
                window.canHide = false
                window.setContentSize(NSSize(width: 1, height: 1))
                window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
            }
    }
}
