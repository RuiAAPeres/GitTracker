import SwiftUI

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
                    HStack(spacing: 8) {
                        Text(row.isBreached ? "⚠︎" : "•")
                        Text(row.name)
                        Spacer(minLength: 10)
                        Text("+\(row.addedLines) -\(row.removedLines)")
                            .monospacedDigit()
                    }
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

        SettingsLink {
            Text("Open Settings…")
        }

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
}
