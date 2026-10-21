import AppKit
import SwiftUI

@main
struct PimpMyWhooshApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Pimp My Whoosh") {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1000, height: 720)
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@MainActor
final class AppState: ObservableObject {
    @Published var values: [String: String] {
        didSet { UserDefaults.standard.set(values, forKey: Keys.values) }
    }
    @Published var presetID: String {
        didSet { UserDefaults.standard.set(presetID, forKey: Keys.preset) }
    }
    @Published var quitAfterLaunch: Bool {
        didSet { UserDefaults.standard.set(quitAfterLaunch, forKey: Keys.quit) }
    }
    @Published var performanceHUD: Bool {
        didSet { UserDefaults.standard.set(performanceHUD, forKey: Keys.hud) }
    }
    @Published var accessProblem: ConfigError?
    @Published var notice: Notice?
    @Published var gameRunning = GameLauncher.isRunning
    @Published var busy = false
    @Published var snapshot: GameSnapshot?
    // Navigation state lives here rather than in @State: with only the Command Line Tools the SwiftUIMacros plugin is missing.
    // `-InitialPane <section>` on the command line opens a section directly (used to take the README screenshots).
    @Published var pane: Pane? = UserDefaults.standard.string(forKey: "InitialPane")
        .flatMap { name in SettingSection(rawValue: name).map(Pane.section) ?? (name == "preview" ? .preview : nil) } ?? .overview
    @Published var infoKey: String?
    @Published var search = ""

    struct Notice: Equatable {
        let text: String
        let isError: Bool
    }

    private enum Keys {
        static let values = "values", preset = "preset", quit = "quitAfterLaunch", hud = "performanceHUD"
    }

    init() {
        let defaults = UserDefaults.standard
        let stored = defaults.dictionary(forKey: Keys.values) as? [String: String]
        // First run starts from the game's own settings: nothing is forced until the user picks something.
        let firstRun = Preset.builtIn.first { $0.id == "original" } ?? Preset.custom
        values = Catalog.validated(stored ?? firstRun.values)
        presetID = defaults.string(forKey: Keys.preset) ?? firstRun.id
        quitAfterLaunch = defaults.object(forKey: Keys.quit) as? Bool ?? true
        performanceHUD = defaults.bool(forKey: Keys.hud)
        refresh()
    }

    var plan: ConfigPlan { ConfigPlan(values: values) }

    var currentPreset: Preset {
        Preset.builtIn.first { $0.id == presetID } ?? .custom
    }

    func forcedCount(in section: SettingSection) -> Int {
        Catalog.all.filter { $0.section == section && values[$0.key] != nil }.count
    }

    var searchResults: [SettingDef] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return Catalog.all.filter {
            $0.title.lowercased().contains(query) || $0.key.lowercased().contains(query)
                || Catalog.info(for: $0.key).detail.lowercased().contains(query)
        }
    }

    /// The level shared by every sg.* group, if they all match.
    var commonScalability: String? {
        let levels = Set(Catalog.all.filter { $0.section == .quality }.map { values[$0.key] ?? "-" })
        return levels.count == 1 ? levels.first.flatMap { $0 == "-" ? nil : $0 } : nil
    }

    func refresh() {
        accessProblem = ConfigWriter.checkAccess()
        gameRunning = GameLauncher.isRunning
        snapshot = accessProblem == nil ? GameSnapshot.load() : nil
    }

    func gameValue(for def: SettingDef) -> String {
        snapshot?.describe(def, forced: values) ?? L("game value unreadable without permission")
    }

    func apply(_ preset: Preset) {
        values = Catalog.validated(preset.values)
        presetID = preset.id
    }

    func binding(for def: SettingDef) -> Binding<String?> {
        Binding(
            get: { self.values[def.key] },
            set: { newValue in
                self.values[def.key] = def.validated(newValue)
                self.presetID = Preset.customID
            })
    }

    func setAllScalability(_ level: String) {
        for def in Catalog.all where def.section == .quality { values[def.key] = level }
        presetID = Preset.customID
    }

    func resetSection(_ section: SettingSection) {
        for def in Catalog.all where def.section == section { values[def.key] = nil }
        presetID = Preset.customID
    }

    func applyOnly() {
        do {
            try ConfigWriter.apply(plan)
            notice = Notice(text: gameRunning
                ? L("Saved. MyWhoosh is open: this applies from the next launch, and the game erases these settings when it quits, so launch it from here.")
                : L("Settings written to Engine.ini."), isError: false)
        } catch {
            notice = Notice(text: error.localizedDescription, isError: true)
        }
        refresh()
    }

    func launch() {
        refresh()
        if gameRunning {
            notice = Notice(text: L("MyWhoosh is already open: quit it and relaunch it from here to apply the settings."), isError: true)
            return
        }
        busy = true
        Task {
            defer { busy = false }
            do {
                try ConfigWriter.apply(plan)
                try await GameLauncher.launch(performanceHUD: performanceHUD)
                if quitAfterLaunch {
                    NSApp.terminate(nil)
                } else {
                    notice = Notice(text: L("MyWhoosh launched."), isError: false)
                    refresh()
                }
            } catch {
                notice = Notice(text: error.localizedDescription, isError: true)
                refresh()
            }
        }
    }
}

enum Pane: Hashable {
    case overview
    case section(SettingSection)
    case preview
}
