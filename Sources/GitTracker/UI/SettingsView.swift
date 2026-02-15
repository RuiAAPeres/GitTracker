import AppKit
import Foundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        TabView {
            ProjectsSettingsTab(store: store)
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            RulesSettingsTab(store: store)
                .tabItem {
                    Label("Rules", systemImage: "slider.horizontal.3")
                }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ProjectsSettingsTab: View {
    private let suggestionLimit = 200

    @ObservedObject var store: AppStore
    @State private var rawInput = ""
    @State private var editingSpec: ProjectSpec?
    @State private var pathSuggestions: [String] = []
    @State private var selectedSuggestionIndex: Int?
    @State private var keyEventMonitor: Any?
    @State private var selectedSpecID: UUID?
    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionCard("Track folders") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("/path/to/repo or /path/to/root/*", text: $rawInput)
                            .textFieldStyle(.roundedBorder)
                            .focused($inputIsFocused)
                            .frame(maxWidth: .infinity)
                            .onChange(of: rawInput) { _, updated in
                                refreshSuggestions(for: updated)
                            }

                        Button {
                            guard let path = pickFolderPath() else {
                                return
                            }
                            rawInput = path
                            refreshSuggestions(for: path)
                            inputIsFocused = true
                        } label: {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .frame(width: 36)
                        .help("Choose folder")

                        Button {
                            addProjectUsingInputOrPicker()
                        } label: {
                            HStack(spacing: 6) {
                                Text("Add")
                                Text("⇧↩")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .keyboardShortcut(.return, modifiers: [.shift])
                        .buttonStyle(.borderedProminent)
                        .fixedSize()
                    }

                    if !pathSuggestions.isEmpty {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(pathSuggestions.enumerated()), id: \.offset) { index, suggestion in
                                        let isSelected = index == selectedSuggestionIndex

                                        Button {
                                            rawInput = suggestion
                                            refreshSuggestions(for: suggestion)
                                            inputIsFocused = true
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: suggestion.hasSuffix("/*") ? "folder.badge.gearshape" : "folder")
                                                    .foregroundStyle(.secondary)
                                                Text(suggestion)
                                                    .lineLimit(1)
                                                    .font(.system(size: 12, design: .monospaced))
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 6)
                                            .background(
                                                isSelected
                                                    ? Color.accentColor.opacity(0.20)
                                                    : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 6)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .id(index)
                                    }
                                }
                            }
                            .onChange(of: selectedSuggestionIndex) { _, newValue in
                                guard let newValue else { return }
                                withAnimation(.easeOut(duration: 0.12)) {
                                    proxy.scrollTo(newValue, anchor: .center)
                                }
                            }
                        }
                        .frame(maxHeight: 160)
                        .padding(8)
                        .background(.quaternary.opacity(0.30), in: RoundedRectangle(cornerRadius: 8))
                    }

                    Text("Use `folder/*` to track immediate child repositories.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 1)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                trackedSourcesSidebar
                    .frame(width: 290)

                projectDashboard
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $editingSpec) { spec in
            ProjectOverrideSheet(
                spec: spec,
                onSave: { threshold in
                    store.setProjectThresholdOverride(id: spec.id, threshold: threshold)
                }
            )
        }
        .onAppear {
            installKeyboardMonitorIfNeeded()
            selectInitialSpecIfNeeded()
            preloadSelectedInsightsIfNeeded()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: store.settings.projectSpecs) { _, _ in
            selectInitialSpecIfNeeded()
            preloadSelectedInsightsIfNeeded()
        }
        .onChange(of: selectedSpecID) { _, _ in
            preloadSelectedInsightsIfNeeded()
        }
        .onChange(of: store.resolvedProjects) { _, _ in
            preloadSelectedInsightsIfNeeded()
        }
    }

    private func addProjectUsingInputOrPicker() {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            guard let path = pickFolderPath() else {
                return
            }
            store.addProject(from: path)
            rawInput = ""
            pathSuggestions = []
            selectedSuggestionIndex = nil
            return
        }

        let resolved = PathSuggestionEngine.resolvedInputForAdd(rawInput: trimmed, suggestions: pathSuggestions)
        store.addProject(from: resolved)
        rawInput = ""
        pathSuggestions = []
        selectedSuggestionIndex = nil
    }

    private func pickFolderPath() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Select Folder"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    private func installKeyboardMonitorIfNeeded() {
        guard keyEventMonitor == nil else {
            return
        }

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if shouldHandleKeyEvent(event) {
                return nil
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        guard let keyEventMonitor else {
            return
        }
        NSEvent.removeMonitor(keyEventMonitor)
        self.keyEventMonitor = nil
    }

    private func shouldHandleKeyEvent(_ event: NSEvent) -> Bool {
        guard inputIsFocused else {
            return false
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) {
            return false
        }

        switch Int(event.keyCode) {
        case 36 where modifiers.contains(.shift): // return + shift
            addProjectUsingInputOrPicker()
            return true
        case 76 where modifiers.contains(.shift): // keypad enter + shift
            addProjectUsingInputOrPicker()
            return true
        case 125: // down
            guard !pathSuggestions.isEmpty else { return false }
            moveSelection(step: 1)
            return true
        case 126: // up
            guard !pathSuggestions.isEmpty else { return false }
            moveSelection(step: -1)
            return true
        case 48: // tab
            guard !pathSuggestions.isEmpty else { return false }
            autocompleteSelection(descendIntoDirectory: false)
            return true
        case 36, 76: // return, enter
            guard !pathSuggestions.isEmpty else { return false }
            autocompleteSelection(descendIntoDirectory: true)
            return true
        case 53: // escape
            selectedSuggestionIndex = nil
            return true
        default:
            return false
        }
    }

    private func moveSelection(step: Int) {
        guard !pathSuggestions.isEmpty else {
            selectedSuggestionIndex = nil
            return
        }

        let current = selectedSuggestionIndex ?? 0
        let newIndex = max(0, min(pathSuggestions.count - 1, current + step))
        selectedSuggestionIndex = newIndex
    }

    private func autocompleteSelection(descendIntoDirectory: Bool) {
        guard !pathSuggestions.isEmpty else {
            return
        }
        let index = selectedSuggestionIndex ?? 0
        guard pathSuggestions.indices.contains(index) else {
            return
        }
        rawInput = PathSuggestionEngine.inputAfterAcceptingSuggestion(
            pathSuggestions[index],
            descendIntoDirectory: descendIntoDirectory
        )
        refreshSuggestions(for: rawInput)
    }

    private func refreshSuggestions(for input: String) {
        pathSuggestions = PathSuggestionEngine.suggestions(for: input, limit: suggestionLimit)
        if let selectedSuggestionIndex, pathSuggestions.indices.contains(selectedSuggestionIndex) {
            return
        }
        selectedSuggestionIndex = pathSuggestions.isEmpty ? nil : 0
    }

    @ViewBuilder
    private var trackedSourcesSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tracked")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(store.settings.projectSpecs.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.settings.projectSpecs) { spec in
                        sourceRow(spec)
                    }
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var projectDashboard: some View {
        if let selectedSpec = selectedSpec {
            let summary = summary(for: selectedSpec)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsSectionCard("Selected source") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .center, spacing: 10) {
                                Circle()
                                    .fill(summary.breachedRepoCount > 0 ? Color(nsColor: MenuBarPalette.warning) : Color(nsColor: MenuBarPalette.success))
                                    .frame(width: 8, height: 8)

                                Text(sourceTitle(for: selectedSpec))
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Toggle("Enabled", isOn: Binding(
                                    get: { selectedSpec.enabled },
                                    set: { store.setProjectEnabled(id: selectedSpec.id, enabled: $0) }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }

                            Text(selectedSpec.input.displayValue)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)

                            TextField(
                                "Optional display name",
                                text: Binding(
                                    get: { selectedSpec.nameOverride ?? "" },
                                    set: { store.setProjectNameOverride(id: selectedSpec.id, nameOverride: $0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)

                            HStack(spacing: 8) {
                                Button("Threshold override…") {
                                    editingSpec = selectedSpec
                                }
                                .buttonStyle(.bordered)

                                Button("Reveal in Finder") {
                                    store.revealProjectInFinder(path: selectedSpec.input.path)
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                Button(role: .destructive) {
                                    store.removeProject(id: selectedSpec.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }

                    SettingsSectionCard("Repository metrics") {
                        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                            metricTile("Repositories", "\(summary.repoCount)", "Detected from this source")
                            metricTile("Breaching", "\(summary.breachedRepoCount)", "Threshold violations now")
                            metricTile("Commits (7d)", "\(summary.commits7d)", "Recent velocity")
                            metricTile("Commits (30d)", "\(summary.commits30d)", "Monthly volume")
                            metricTile("Avg commit size", "\(summary.avgCommitDelta) lines", "Added + removed")
                            metricTile("Avg files/commit", summary.avgFilesPerCommitText, "In the last 30 days")
                            metricTile("Pending delta", "+\(summary.pendingAdded)  -\(summary.pendingRemoved)", "Uncommitted lines")
                            metricTile("Pending files", "\(summary.pendingFiles)", "Files in working tree")
                            metricTile("Active days (30d)", "\(summary.avgActiveDaysText)", "Average days with commits")
                            metricTile("Branches", summary.branchSummary, "Detected heads")
                        }

                        if summary.loadingRepoCount > 0 {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading detailed metrics for \(summary.loadingRepoCount) repos…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 6)
                        }
                    }

                    SettingsSectionCard("Commit recency") {
                        HStack {
                            Text("Most recent commit")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(summary.lastCommitText)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No tracked folders yet")
                    .font(.title3.weight(.semibold))
                Text("Add a repository path above to see live commit metrics and health.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(.quaternary.opacity(0.20), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func sourceRow(_ spec: ProjectSpec) -> some View {
        let isSelected = spec.id == selectedSpecID
        let summary = summary(for: spec)

        return Button {
            selectedSpecID = spec.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(summary.breachedRepoCount > 0 ? Color(nsColor: MenuBarPalette.warning) : Color(nsColor: MenuBarPalette.success))
                        .frame(width: 8, height: 8)
                    Text(sourceTitle(for: spec))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    if !spec.enabled {
                        Text("Off")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(spec.input.displayValue)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(summary.repoCount) repos • \(summary.commits7d) commits / 7d")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
    }

    private func metricTile(_ title: String, _ value: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 19, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.quaternary.opacity(0.24), in: RoundedRectangle(cornerRadius: 10))
    }

    private var selectedSpec: ProjectSpec? {
        guard let selectedSpecID else {
            return store.settings.projectSpecs.first
        }
        return store.settings.projectSpecs.first(where: { $0.id == selectedSpecID }) ?? store.settings.projectSpecs.first
    }

    private func selectInitialSpecIfNeeded() {
        if let selectedSpecID, store.settings.projectSpecs.contains(where: { $0.id == selectedSpecID }) {
            return
        }
        selectedSpecID = store.settings.projectSpecs.first?.id
    }

    private func sourceTitle(for spec: ProjectSpec) -> String {
        if let override = spec.nameOverride, !override.isEmpty {
            return override
        }
        let path = spec.input.path
        let base = URL(fileURLWithPath: path).lastPathComponent
        let displayBase = base.isEmpty ? path : base
        if case .childrenOf = spec.input {
            return "\(displayBase)/*"
        }
        return displayBase
    }

    private func resolvedProjects(for spec: ProjectSpec) -> [ResolvedProject] {
        store.resolvedProjects.filter { $0.sourceSpecID == spec.id }
    }

    private func preloadSelectedInsightsIfNeeded() {
        guard let selectedSpec else { return }
        for project in resolvedProjects(for: selectedSpec) {
            store.loadInsightsIfNeeded(for: project.path)
        }
    }

    private func summary(for spec: ProjectSpec) -> ProjectInsightsSummary {
        let resolved = resolvedProjects(for: spec)
        let rowByPath = Dictionary(uniqueKeysWithValues: store.projectRows.map { ($0.path, $0) })
        let rows = resolved.compactMap { rowByPath[$0.path] }
        let insights = resolved.compactMap { store.projectInsightsByPath[$0.path] }.filter(\.available)

        let commits7d = insights.reduce(0) { $0 + $1.commitsLast7Days }
        let commits30d = insights.reduce(0) { $0 + $1.commitsLast30Days }
        let totalCommitDelta30d = insights.reduce(0) { $0 + ($1.averageCommitDeltaLast30Days * $1.commitsLast30Days) }
        let totalCommitFiles30d = insights.reduce(0.0) { $0 + ($1.averageFilesPerCommitLast30Days * Double($1.commitsLast30Days)) }
        let totalActiveDays30d = insights.reduce(0) { $0 + $1.activeCommitDaysLast30Days }
        let avgCommitDelta = commits30d > 0 ? totalCommitDelta30d / commits30d : 0
        let avgFilesPerCommit = commits30d > 0 ? totalCommitFiles30d / Double(commits30d) : 0
        let avgActiveDays = insights.isEmpty ? 0 : Double(totalActiveDays30d) / Double(insights.count)
        let branchNames = Set(insights.compactMap(\.branchName).filter { !$0.isEmpty })
        let pendingFiles = insights.reduce(0) { $0 + $1.workingTreeChangedFiles }

        return ProjectInsightsSummary(
            repoCount: resolved.count,
            breachedRepoCount: rows.filter(\.isBreached).count,
            commits7d: commits7d,
            commits30d: commits30d,
            avgCommitDelta: avgCommitDelta,
            avgFilesPerCommit: avgFilesPerCommit,
            avgActiveDays: avgActiveDays,
            pendingAdded: rows.reduce(0) { $0 + $1.addedLines },
            pendingRemoved: rows.reduce(0) { $0 + $1.removedLines },
            pendingFiles: pendingFiles,
            loadingRepoCount: resolved.filter { store.insightsLoadingPaths.contains($0.path) }.count,
            lastCommitAt: rows.compactMap(\.lastCommitAt).max(),
            branchSummary: branchSummary(from: branchNames)
        )
    }

    private func branchSummary(from names: Set<String>) -> String {
        guard !names.isEmpty else {
            return "Unavailable"
        }
        if names.count == 1, let name = names.first {
            return name
        }
        return "\(names.count) branches"
    }

    private struct ProjectInsightsSummary {
        var repoCount: Int
        var breachedRepoCount: Int
        var commits7d: Int
        var commits30d: Int
        var avgCommitDelta: Int
        var avgFilesPerCommit: Double
        var avgActiveDays: Double
        var pendingAdded: Int
        var pendingRemoved: Int
        var pendingFiles: Int
        var loadingRepoCount: Int
        var lastCommitAt: Date?
        var branchSummary: String

        var avgFilesPerCommitText: String {
            String(format: "%.1f", avgFilesPerCommit)
        }

        var avgActiveDaysText: String {
            String(format: "%.1f", avgActiveDays)
        }

        var lastCommitText: String {
            guard let lastCommitAt else {
                return "Unavailable"
            }
            return lastCommitAt.formatted(.relative(presentation: .named))
        }
    }
}

private struct RulesSettingsTab: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSectionCard("Global thresholds") {
                    ThresholdEditor(rule: store.settings.globalThreshold) { updated in
                        store.setGlobalThreshold(updated)
                    }
                }

                SettingsSectionCard("Info") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Default values are +200 / -200 / total 300.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)

                        Divider()

                        Text("Projects can override these values from the Projects tab.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                    .foregroundStyle(.secondary)
                }

                SettingsSectionCard("Notifications") {
                    SettingToggleRow(
                        title: "Enable breach notifications",
                        subtitle: "Notifications trigger only when a project transitions from non-breached to breached.",
                        isOn: Binding(
                            get: { store.settings.notificationsEnabled },
                            set: { store.setNotificationsEnabled($0) }
                        )
                    )
                }

                SettingsSectionCard("Startup") {
                    SettingToggleRow(
                        title: "Start at login",
                        subtitle: store.launchAtLoginSupported
                            ? "Launch GitTracker automatically when you sign in."
                            : "Available when running from an app bundle.",
                        isOn: Binding(
                            get: { store.settings.launchAtLogin },
                            set: { store.setLaunchAtLogin($0) }
                        )
                    )
                    .disabled(!store.launchAtLoginSupported)
                }

                SettingsSectionCard("Refresh") {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Refresh interval")
                                .font(.system(size: 14, weight: .semibold))
                            Text("How often tracked projects are re-evaluated.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 10)

                        Picker("Refresh interval", selection: Binding(
                            get: { store.settings.refreshInterval },
                            set: { store.setRefreshInterval($0) }
                        )) {
                            ForEach(RefreshInterval.allCases, id: \.self) { interval in
                                Text(interval.label).tag(interval)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 180)
                    }
                }

                SettingsSectionCard("Current status") {
                    HStack {
                        Text("\(store.breachedCount) breached")
                            .foregroundStyle(store.breachedCount > 0 ? .red : .primary)
                        Spacer()
                        Text("\(store.projectRows.count) tracked")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private struct SettingToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }

            Divider()

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ThresholdEditor: View {
    @State private var maxAdded: Int
    @State private var maxRemoved: Int
    @State private var maxTotal: Int
    let onChange: (ThresholdRule) -> Void

    init(rule: ThresholdRule, onChange: @escaping (ThresholdRule) -> Void) {
        _maxAdded = State(initialValue: rule.maxAddedLines ?? 0)
        _maxRemoved = State(initialValue: rule.maxRemovedLines ?? 0)
        _maxTotal = State(initialValue: rule.maxTotalDelta ?? 0)
        self.onChange = onChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thresholdRow(title: "Max +++", value: $maxAdded)
            thresholdRow(title: "Max ---", value: $maxRemoved)
            thresholdRow(title: "Max total", value: $maxTotal)
        }
        .onChange(of: maxAdded) { _, _ in apply() }
        .onChange(of: maxRemoved) { _, _ in apply() }
        .onChange(of: maxTotal) { _, _ in apply() }
    }

    private func thresholdRow(title: String, value: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 90, alignment: .leading)
                .font(.system(size: 14, weight: .semibold))

            Text("\(value.wrappedValue)")
                .frame(width: 70, alignment: .trailing)
                .monospacedDigit()
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            Stepper("", value: value, in: 0...100_000, step: 10)
                .labelsHidden()
                .fixedSize()
        }
        .padding(.vertical, 4)
    }

    private func apply() {
        onChange(
            ThresholdRule(
                maxAddedLines: maxAdded,
                maxRemovedLines: maxRemoved,
                maxTotalDelta: maxTotal
            )
        )
    }
}

private struct ProjectOverrideSheet: View {
    let spec: ProjectSpec
    let onSave: (ThresholdRule?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var useOverride: Bool
    @State private var maxAdded: Int
    @State private var maxRemoved: Int
    @State private var maxTotal: Int

    init(spec: ProjectSpec, onSave: @escaping (ThresholdRule?) -> Void) {
        self.spec = spec
        self.onSave = onSave

        let override = spec.thresholdOverride
        _useOverride = State(initialValue: override != nil)
        _maxAdded = State(initialValue: override?.maxAddedLines ?? ThresholdRule.v1Default.maxAddedLines ?? 200)
        _maxRemoved = State(initialValue: override?.maxRemovedLines ?? ThresholdRule.v1Default.maxRemovedLines ?? 200)
        _maxTotal = State(initialValue: override?.maxTotalDelta ?? ThresholdRule.v1Default.maxTotalDelta ?? 300)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Project override")
                .font(.title3.weight(.semibold))

            Text(spec.input.displayValue)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            Toggle("Use custom threshold for this project", isOn: $useOverride)

            if useOverride {
                VStack(alignment: .leading, spacing: 10) {
                    editorRow(title: "Max +++", value: $maxAdded)
                    editorRow(title: "Max ---", value: $maxRemoved)
                    editorRow(title: "Max total", value: $maxTotal)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    if useOverride {
                        onSave(
                            ThresholdRule(
                                maxAddedLines: maxAdded,
                                maxRemovedLines: maxRemoved,
                                maxTotalDelta: maxTotal
                            )
                        )
                    } else {
                        onSave(nil)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private func editorRow(title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .frame(width: 90, alignment: .leading)
            Stepper(value: value, in: 0...100_000, step: 10) {
                Text("\(value.wrappedValue)")
                    .monospacedDigit()
            }
        }
    }
}
