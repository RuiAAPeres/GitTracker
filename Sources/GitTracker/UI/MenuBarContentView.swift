import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @ObservedObject var store: AppStore

    private var summaryText: String {
        "\(store.breachedCount) breached / \(store.projectRows.count) tracked"
    }

    var body: some View {
        Text(summaryText)
            .font(.system(size: 12, weight: .semibold))

        if let lastRefreshAt = store.lastRefreshAt {
            Text("Last refresh: \(lastRefreshAt.formatted(date: .omitted, time: .shortened))")
                .font(.system(size: 11))
        }

        Divider()

        if store.projectRows.isEmpty {
            Text("No projects tracked")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        } else {
            ForEach(store.projectRows) { row in
                Button {
                    store.revealProjectInFinder(path: row.path)
                } label: {
                    Text(projectAttributedTitle(for: row))
                }
                .help("\(row.path)\n\(statusText(for: row.status))")
            }
        }

        Divider()

        Button {
            Task { await store.refreshNow() }
        } label: {
            if store.isRefreshing {
                Text("Refreshing…")
            } else {
                Text("Refresh now")
            }
        }
        .disabled(store.isRefreshing)

        Button("Open Settings…") {
            openSettingsWindow()
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func statusText(for status: MetricsStatus) -> String {
        switch status {
        case .ok:
            return "OK"
        case .gitUnavailable:
            return "Git unavailable"
        case .notRepo:
            return "Not a git repository"
        case .pathUnavailable:
            return "Path unavailable"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    private func projectAttributedTitle(for row: ProjectRow) -> AttributedString {
        let marker = row.isBreached ? "⚠︎" : "•"
        var title = AttributedString("\(marker) \(row.name)  ")

        var plus = AttributedString("+\(row.addedLines)")
        plus.foregroundColor = .green

        let spacer = AttributedString(" ")

        var minus = AttributedString("-\(row.removedLines)")
        minus.foregroundColor = .red

        title.append(plus)
        title.append(spacer)
        title.append(minus)

        return title
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .gitTrackerOpenSettings, object: nil)
    }
}
