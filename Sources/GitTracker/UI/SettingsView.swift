import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        TabView {
            ProjectsSettingsTab(store: store)
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            ThresholdSettingsTab(store: store)
                .tabItem {
                    Label("Thresholds", systemImage: "slider.horizontal.3")
                }

            AlertsSettingsTab(store: store)
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }
        }
        .padding(16)
    }
}

private struct ProjectsSettingsTab: View {
    @ObservedObject var store: AppStore
    @State private var rawInput = ""
    @State private var editingSpec: ProjectSpec?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Track folders")
                .font(.title3.weight(.semibold))

            HStack(spacing: 8) {
                TextField("/path/to/repo or /path/to/root/*", text: $rawInput)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    store.addProject(from: rawInput)
                    rawInput = ""
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }

            List {
                ForEach(store.settings.projectSpecs) { spec in
                    HStack(spacing: 12) {
                        Toggle("", isOn: Binding(
                            get: { spec.enabled },
                            set: { store.setProjectEnabled(id: spec.id, enabled: $0) }
                        ))
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(spec.input.displayValue)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)

                            TextField(
                                "Optional display name",
                                text: Binding(
                                    get: { spec.nameOverride ?? "" },
                                    set: { store.setProjectNameOverride(id: spec.id, nameOverride: $0) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }

                        Spacer(minLength: 8)

                        Button("Override…") {
                            editingSpec = spec
                        }

                        Button(role: .destructive) {
                            store.removeProject(id: spec.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 280)

            Text("Use `folder/*` to track direct child repositories under that folder.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .sheet(item: $editingSpec) { spec in
            ProjectOverrideSheet(
                spec: spec,
                onSave: { threshold in
                    store.setProjectThresholdOverride(id: spec.id, threshold: threshold)
                }
            )
        }
    }
}

private struct ThresholdSettingsTab: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Global thresholds")
                .font(.title3.weight(.semibold))

            ThresholdEditor(rule: store.settings.globalThreshold) { updated in
                store.setGlobalThreshold(updated)
            }

            Text("Default values are +200 / -200 / total 300.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

private struct AlertsSettingsTab: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle("Enable breach notifications", isOn: Binding(
                get: { store.settings.notificationsEnabled },
                set: { store.setNotificationsEnabled($0) }
            ))

            VStack(alignment: .leading, spacing: 6) {
                Text("Refresh interval")
                    .font(.headline)

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
            }

            Text("Notifications trigger only when a project transitions from non-breached to breached.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
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
        VStack(alignment: .leading, spacing: 10) {
            thresholdRow(title: "Max +++", value: $maxAdded)
            thresholdRow(title: "Max ---", value: $maxRemoved)
            thresholdRow(title: "Max total", value: $maxTotal)
        }
        .onChange(of: maxAdded) { _, _ in apply() }
        .onChange(of: maxRemoved) { _, _ in apply() }
        .onChange(of: maxTotal) { _, _ in apply() }
    }

    private func thresholdRow(title: String, value: Binding<Int>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: 90, alignment: .leading)
            Stepper(value: value, in: 0...100_000, step: 10) {
                Text("\(value.wrappedValue)")
                    .frame(width: 80, alignment: .leading)
                    .monospacedDigit()
            }
        }
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
