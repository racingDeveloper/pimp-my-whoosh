import SwiftUI

// No @State in this file: with only the Command Line Tools the SwiftUIMacros plugin is missing; state lives in AppState.

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            VStack(spacing: 0) {
                if let notice = state.notice { NoticeBar(notice: notice) }
                detail
            }
        }
        .searchable(text: $state.search, placement: .sidebar, prompt: "Search settings")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Save") { state.applyOnly() }
                    .help("Writes the settings without launching the game")
                Button {
                    state.launch()
                } label: {
                    Label("Launch MyWhoosh", systemImage: "play.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(state.busy)
                .help("Writes the settings and launches MyWhoosh (⌘R)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refresh()
        }
    }

    @ViewBuilder private var detail: some View {
        if !state.search.trimmingCharacters(in: .whitespaces).isEmpty {
            SearchResultsPane()
        } else {
            switch state.pane ?? .overview {
            case .overview: OverviewPane()
            case .section(let section): SectionPane(section: section)
            case .preview: PreviewPane()
            }
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        List(selection: $state.pane) {
            Label("Overview", systemImage: "gauge.with.dots.needle.67percent")
                .tag(Pane.overview)
            Section("Settings") {
                ForEach(SettingSection.allCases) { section in
                    Label(section.title, systemImage: section.symbol)
                        .badge(state.forcedCount(in: section))
                        .tag(Pane.section(section))
                }
            }
            Section {
                Label("File preview", systemImage: "doc.text")
                    .tag(Pane.preview)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) { status }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            if state.accessProblem != nil {
                Label("Permission missing", systemImage: "lock.fill").foregroundStyle(.orange)
            } else {
                Label("File access OK", systemImage: "checkmark.circle").foregroundStyle(.secondary)
            }
            Label(state.gameRunning ? L("MyWhoosh running") : L("MyWhoosh closed"),
                  systemImage: state.gameRunning ? "circle.fill" : "circle")
                .foregroundStyle(state.gameRunning ? .green : .secondary)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

// MARK: - Overview

struct OverviewPane: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            if let problem = state.accessProblem { AccessSection(problem: problem) }

            Section {
                ForEach(Preset.builtIn) { preset in
                    PresetRow(preset: preset, selected: state.presetID == preset.id) {
                        state.apply(preset)
                    }
                }
                if state.presetID == Preset.customID {
                    PresetRow(preset: .custom, selected: true) {}
                }
            } header: {
                Text("Preset")
            } footer: {
                Text("A preset fills in every section; you can then fine-tune individual settings.")
                    .foregroundStyle(.secondary)
            }

            Section("What will be applied") {
                LabeledContent("Render resolution", value: state.values["r.ScreenPercentage"].map { "\($0)%" } ?? L("game decides"))
                LabeledContent("Frame rate cap", value: fpsSummary)
                LabeledContent("Quality", value: qualitySummary)
                LabeledContent("Forced values", value: L("\(String(state.values.count)) of \(String(Catalog.all.count))"))
            }

            Section {
                Toggle("Quit Pimp My Whoosh after launching", isOn: $state.quitAfterLaunch)
                Toggle(isOn: $state.performanceHUD) {
                    Text("Show performance overlay")
                    Text("Apple's Metal HUD in a corner of the game: frame rate, frame time and GPU memory. Handy to see what each setting costs. Applies to the next launch from here.")
                }
            } header: {
                Text("Launch")
            } footer: {
                Text("MyWhoosh erases these settings when it quits, so they are rewritten at every launch from here. A .pimpmywhoosh.bak copy is saved before each write.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Overview")
    }

    private var fpsSummary: String {
        guard let fps = state.values["t.MaxFPS"] else { return L("40, forced by the game") }
        return fps == "0" ? L("uncapped") : fps
    }

    private var qualitySummary: String {
        if let level = state.commonScalability, let def = Catalog.byKey["sg.ShadowQuality"] {
            return L("all groups at \(def.label(for: level))")
        }
        let forced = state.forcedCount(in: .quality)
        return forced == 0 ? L("game decides") : L("\(String(forced)) groups forced, mixed levels")
    }
}

private struct PresetRow: View {
    let preset: Preset
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name).fontWeight(selected ? .semibold : .regular)
                    Text(preset.summary).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct AccessSection: View {
    let problem: ConfigError

    var body: some View {
        Section {
            Label {
                Text(problem.localizedDescription)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            if case .noPermission = problem {
                Button("Open Full Disk Access…") { SystemSettingsLink.openFullDiskAccess() }
            }
        }
    }
}

// MARK: - Sections

struct SectionPane: View {
    @EnvironmentObject private var state: AppState
    let section: SettingSection

    var body: some View {
        Form {
            if let note = section.note {
                Section {
                    Text(note).font(.callout).foregroundStyle(.secondary)
                }
            }
            Section {
                if section == .quality { AllGroupsRow() }
                ForEach(Catalog.all.filter { $0.section == section }) { def in
                    SettingRow(def: def)
                }
            } footer: {
                HStack {
                    Spacer()
                    Button("Force nothing in this section") { state.resetSection(section) }
                        .disabled(state.forcedCount(in: section) == 0)
                        .help("Let the game decide every setting in this section")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(section.title)
    }
}

struct SearchResultsPane: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            let results = state.searchResults
            if results.isEmpty {
                Text("No settings match “\(state.search)”.").foregroundStyle(.secondary)
            }
            ForEach(SettingSection.allCases) { section in
                let matches = results.filter { $0.section == section }
                if !matches.isEmpty {
                    Section(section.title) {
                        ForEach(matches) { SettingRow(def: $0) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Search")
    }
}

private struct AllGroupsRow: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        LabeledContent {
            Picker("All groups", selection: Binding(
                get: { state.commonScalability },
                set: { if let level = $0 { state.setAllScalability(level) } })) {
                ForEach(0..<5) { Text(String($0)).tag(Optional(String($0))) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            .frame(width: SettingRow.controlWidth, alignment: .trailing)
        } label: {
            Text("All groups")
            Text("Sets the same level everywhere").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct SettingRow: View {
    @EnvironmentObject private var state: AppState
    let def: SettingDef

    private var value: Binding<String?> { state.binding(for: def) }
    private var info: SettingInfo { Catalog.info(for: def.key) }
    private var isForced: Bool { state.values[def.key] != nil }

    var body: some View {
        LabeledContent {
            control
        } label: {
            HStack(spacing: 6) {
                Text(def.title)
                if info.effect != .always {
                    Image(systemName: info.effect.symbol)
                        .foregroundStyle(info.effect.color)
                        .help(info.effect.label)
                        .accessibilityLabel(info.effect.label)
                }
                infoButton
            }
            Text(state.gameValue(for: def))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Fixed-width control column, so pickers and sliders line up across rows.
    static let controlWidth: CGFloat = 290

    private var infoButton: some View {
        Button {
            state.infoKey = def.key
        } label: {
            Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help("What it does")
        .accessibilityLabel("About \(def.title)")
        .popover(isPresented: Binding(
            get: { state.infoKey == def.key },
            set: { if !$0 && state.infoKey == def.key { state.infoKey = nil } }),
                 arrowEdge: .trailing) {
            InfoPopover(def: def, info: info, gameValue: state.gameValue(for: def))
        }
    }

    @ViewBuilder private var control: some View {
        switch def.control {
        case .choice(let options):
            Picker(def.title, selection: value) {
                Text("Don't force").tag(String?.none)
                Divider()
                ForEach(options, id: \.value) { Text($0.label).tag(Optional($0.value)) }
            }
            .labelsHidden()
            .fixedSize()
            .frame(width: Self.controlWidth, alignment: .trailing)
        case .slider(let min, let max, let step, let decimals, let unit):
            HStack(spacing: 10) {
                Toggle("Force", isOn: Binding(
                    get: { isForced },
                    set: { value.wrappedValue = $0 ? SettingDef.format(neutral(min, max), decimals: decimals) : nil }))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .help(isForced ? L("Back to the game's value") : L("Force a value"))
                Slider(value: Binding(
                    get: { value.wrappedValue.flatMap(Double.init) ?? neutral(min, max) },
                    set: { value.wrappedValue = SettingDef.format($0, decimals: decimals) }),
                       in: min...max, step: step)
                    .frame(width: 150)
                    .disabled(!isForced)
                Text(value.wrappedValue.map { "\($0)\(unit)" } ?? "—")
                    .monospacedDigit()
                    .foregroundStyle(isForced ? .primary : .secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            .frame(width: Self.controlWidth, alignment: .trailing)
        }
    }

    /// Starting point when a slider is enabled: 1× / 100% when within range.
    private func neutral(_ min: Double, _ max: Double) -> Double {
        let neutral: [String: Double] = ["r.ScreenPercentage": 100, "r.Tonemapper.Sharpen": 0.5, "r.MipMapLODBias": 0]
        let n = neutral[def.key] ?? 1
        return Swift.min(Swift.max(n, min), max)
    }
}

private struct InfoPopover: View {
    let def: SettingDef
    let info: SettingInfo
    let gameValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(def.title).font(.headline)
            Label(info.effect.label, systemImage: info.effect.symbol)
                .font(.caption)
                .foregroundStyle(info.effect.color)
            if !info.detail.isEmpty {
                Text(info.detail).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text("Not forced").foregroundStyle(.secondary)
                    Text(gameValue)
                }
                GridRow {
                    Text("Key").foregroundStyle(.secondary)
                    Text(def.key).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }
            }
            .font(.caption)
            Text(def.help).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 340)
    }
}

// MARK: - Preview and notices

struct PreviewPane: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ScrollView {
            Text(state.plan.preview)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle("File preview")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(state.plan.preview, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }
}

struct NoticeBar: View {
    @EnvironmentObject private var state: AppState
    let notice: AppState.Notice

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: notice.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(notice.isError ? .orange : .green)
            Text(notice.text).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                state.notice = nil
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss notice")
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

extension Effectiveness {
    var color: Color {
        switch self {
        case .always: return .green
        case .content: return .orange
        case .experimental: return .purple
        }
    }
}
