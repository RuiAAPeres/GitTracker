import SwiftUI

@main
struct GitTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var store: AppStore

    init() {
        let liveStore = AppStore.live()
        self.store = liveStore
        Task { await liveStore.startIfNeeded() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(store: store)
                .frame(width: 760, height: 540)
        }
    }
}
