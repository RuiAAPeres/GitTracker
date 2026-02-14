import SwiftUI

@main
struct GitTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AppStore

    init() {
        let liveStore = AppStore.live()
        _store = StateObject(wrappedValue: liveStore)
        Task { await liveStore.startIfNeeded() }
    }

    var body: some Scene {
        WindowGroup("GitTrackerLifecycleKeepalive") {
            HiddenWindowView()
        }
        .defaultSize(width: 20, height: 20)
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarContentView(store: store)
        } label: {
            MenuBarLabelView(store: store)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(store: store)
        }
        .defaultSize(width: 820, height: 560)
        .windowResizability(.contentSize)
    }
}
