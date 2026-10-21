import AppKit
import Foundation

enum GamePaths {
    static let bundleID = "com.whoosh.whooshgame"

    static let container = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Containers/\(bundleID)/Data", isDirectory: true)
    static let configDir = container.appendingPathComponent(
        "Library/Application Support/Epic/MyWhoosh/Saved/Config/Mac", isDirectory: true)
    static let engineIni = configDir.appendingPathComponent("Engine.ini")
    static let gameUserSettingsIni = configDir.appendingPathComponent("GameUserSettings.ini")
    static let gameData = configDir.deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("SaveGames/GameData.sav")
    /// The game's preferences domain inside its sandbox container (without the .plist extension, as `defaults` wants it).
    static let preferencesDomain = container.appendingPathComponent("Library/Preferences/\(bundleID)").path
    static let log = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/PimpMyWhoosh.log")

    static var gameApp: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            ?? existing(URL(fileURLWithPath: "/Applications/MyWhoosh Indoor Cycling App.app"))
    }

    private static func existing(_ url: URL) -> URL? {
        FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

/// Minimal editing of Unreal-style .ini files: `[Name]` sections and `key=value` lines.
enum Ini {
    static let systemSettings = "SystemSettings"
    static let userInterface = "/Script/Engine.UserInterfaceSettings"
    static let audio = "Audio"
    static let gameUserSettings = "/Script/Engine.GameUserSettings"

    private static func sectionName(_ line: Substring) -> String? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("["), t.hasSuffix("]") else { return nil }
        return String(t.dropFirst().dropLast())
    }

    /// Key/value pairs of a section.
    static func values(in text: String, section: String) -> [String: String] {
        var result: [String: String] = [:]
        var inside = false
        for line in text.split(separator: "\n") {
            if let name = sectionName(line) { inside = name == section; continue }
            guard inside else { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { result[parts[0]] = parts[1] }
        }
        return result
    }

    /// Drops the given sections entirely and appends the new blocks (empty ones are skipped).
    static func replacingSections(_ text: String, remove names: Set<String>, append blocks: [(String, [(String, String)])]) -> String {
        var kept: [Substring] = []
        var skipping = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if let name = sectionName(line) { skipping = names.contains(name) }
            if !skipping { kept.append(line) }
        }
        var out = kept.joined(separator: "\n")
        while out.hasSuffix("\n\n") { out.removeLast() }
        for (name, pairs) in blocks where !pairs.isEmpty {
            if !out.isEmpty && !out.hasSuffix("\n") { out += "\n" }
            out += "\n[\(name)]\n" + pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "\n") + "\n"
        }
        return out
    }

    /// Sets keys inside a section (creating it if needed) and removes `removing`, leaving everything else untouched.
    static func settingKeys(_ text: String, section: String, values: [(String, String)], removing: Set<String> = []) -> String {
        guard !values.isEmpty || !removing.isEmpty else { return text }
        var lines = text.components(separatedBy: "\n")
        var pending = values
        var start: Int?
        var end = lines.count
        for (i, line) in lines.enumerated() {
            if let name = sectionName(Substring(line)) {
                if start != nil { end = i; break }
                if name == section { start = i }
            }
        }
        guard let start else {
            // Nothing to remove from a missing section; leave the file byte-for-byte unchanged unless there's something to add.
            return values.isEmpty ? text : replacingSections(text, remove: [], append: [(section, values)])
        }
        for i in ((start + 1)..<end).reversed() {
            let key = lines[i].split(separator: "=", maxSplits: 1).first.map(String.init) ?? ""
            if let idx = pending.firstIndex(where: { $0.0 == key }) {
                lines[i] = "\(key)=\(pending[idx].1)"
                pending.remove(at: idx)
            } else if removing.contains(key) {
                lines.remove(at: i)
            }
        }
        lines.insert(contentsOf: pending.map { "\($0.0)=\($0.1)" }, at: start + 1)
        return lines.joined(separator: "\n")
    }
}

struct ConfigPlan {
    var systemSettings: [(String, String)] = []
    var userInterface: [(String, String)] = []
    var audio: [(String, String)] = []
    var gameUserSettings: [(String, String)] = []
    /// macOS preferences of the game: nil removes the key.
    var appPreferences: [(String, String?)] = []

    private var unsetAudioKeys: Set<String> {
        Set(Catalog.all.filter { $0.target == .audio }.map(\.key)).subtracting(audio.map(\.0))
    }

    init(values: [String: String]) {
        for def in Catalog.all {
            guard let value = values[def.key] else {
                if def.target == .appPreferences { appPreferences.append((def.key, nil)) }
                continue
            }
            switch def.target {
            case .systemSettings:
                if def.key == "r.ScreenPercentage", let p = Double(value) {
                    // Lock the scalability group too, otherwise the game recomputes it from its benchmark.
                    systemSettings.append(("sg.ResolutionQuality", SettingDef.format(min(p, 100), decimals: 0)))
                }
                systemSettings.append((def.key, value))
            case .userInterface:
                userInterface.append((def.key, value))
            case .audio:
                audio.append((def.key, value))
            case .gameUserSettings:
                if def.key == "FullscreenMode" {
                    gameUserSettings += ["FullscreenMode", "LastConfirmedFullscreenMode", "PreferredFullscreenMode"].map { ($0, value) }
                } else {
                    gameUserSettings.append((def.key, value))
                }
            case .appPreferences:
                appPreferences.append((def.key, value))
            }
        }
    }

    func engineIni(from original: String) -> String {
        let replaced = Ini.replacingSections(original, remove: [Ini.systemSettings, Ini.userInterface],
                                             append: [(Ini.systemSettings, systemSettings), (Ini.userInterface, userInterface)])
        return Ini.settingKeys(replaced, section: Ini.audio, values: audio, removing: unsetAudioKeys)
    }

    func gameUserSettingsIni(from original: String) -> String {
        Ini.settingKeys(original, section: Ini.gameUserSettings, values: gameUserSettings)
    }

    var preview: String {
        var parts: [String] = []
        if !systemSettings.isEmpty || !userInterface.isEmpty || !audio.isEmpty {
            let blocks = Ini.replacingSections("", remove: [], append: [
                (Ini.systemSettings, systemSettings), (Ini.userInterface, userInterface), (Ini.audio, audio),
            ])
            parts.append("# Engine.ini\n" + blocks.trimmingCharacters(in: .newlines))
        }
        if !gameUserSettings.isEmpty {
            parts.append("# GameUserSettings.ini\n[\(Ini.gameUserSettings)]\n" + gameUserSettings.map { "\($0.0)=\($0.1)" }.joined(separator: "\n"))
        }
        let prefs = appPreferences.compactMap { pair in pair.1.map { "\(pair.0) = \($0 == "1" ? "YES" : "NO")" } }
        if !prefs.isEmpty {
            parts.append("# " + L("macOS preferences of MyWhoosh") + "\n" + prefs.joined(separator: "\n"))
        }
        return parts.isEmpty ? L("No changes: Engine.ini is cleaned up and the game decides.") : parts.joined(separator: "\n\n")
    }
}

/// What the game decided on its own, read from its files (read-only).
struct GameSnapshot {
    /// sg.* levels saved by the game: its own choices, not the ones forced by this app.
    var scalability: [String: String] = [:]
    var gameUserSettings: [String: String] = [:]
    /// The menu's "Render Scale" (40/60/80/100), nil if never changed.
    var renderScale: String?

    static func load() -> GameSnapshot? {
        guard let gus = try? String(contentsOf: GamePaths.gameUserSettingsIni, encoding: .utf8) else { return nil }
        var snapshot = GameSnapshot()
        snapshot.scalability = Ini.values(in: gus, section: "ScalabilityGroups")
        snapshot.gameUserSettings = Ini.values(in: gus, section: Ini.gameUserSettings)
        // Only the enum name is looked up: the rest of the save (account data included) is neither parsed nor kept.
        if let save = try? Data(contentsOf: GamePaths.gameData),
           let marker = "ERenderScaleState::E_".data(using: .utf8),
           let range = save.range(of: marker) {
            let digits = save[range.upperBound...].prefix { (0x30...0x39).contains($0) }
            snapshot.renderScale = String(decoding: digits, as: UTF8.self)
        }
        return snapshot
    }

    /// Describes the value the game uses when the app doesn't force `def`.
    /// `forced` are the values chosen in the app: needed for cvars that follow a forced sg.* group.
    func describe(_ def: SettingDef, forced: [String: String]) -> String {
        let engine = Catalog.engineDefaults[def.key].map { def.label(for: $0) }
        switch Catalog.baseline(for: def.key) {
        case .scalable:
            return L("engine: \(engine ?? "?"), may change with the quality groups")
        case .follows(let group):
            let base = engine.map { L(" · engine base \($0)") } ?? ""
            return followsText(group, forced: forced) + base
        case .project:
            return engine.map { L("engine: \($0); the project may have changed it (encrypted files)") }
                ?? L("decided by the project (encrypted files, unreadable)")
        default:
            return describeGame(def)
        }
    }

    private func followsText(_ group: String, forced: [String: String]) -> String {
        let name = Catalog.byKey[group]?.title ?? group
        if let level = forced[group] {
            return L("follows \(name), level \(level) forced here")
        }
        return scalability[group].map { L("follows \(name), game level \($0)") } ?? L("follows \(name)")
    }

    private func describeGame(_ def: SettingDef) -> String {
        switch Catalog.baseline(for: def.key) {
        case .scalabilityGroup:
            return scalability[def.key].map { L("game: \(def.label(for: $0))") } ?? L("game: not saved yet")
        case .follows, .scalable, .project:
            return ""
        case .forcedAtBoot(let value):
            return L("game: \(def.label(for: value)), forced at every launch")
        case .renderScale:
            let level = renderScale ?? L("default")
            return L("game: menu Render Scale \(level), lowered based on its benchmark")
        case .gameUserSetting(let key):
            return gameUserSettings[key].map { L("game: \(def.label(for: $0))") } ?? L("game: not saved")
        case .engine(let value):
            return L("engine: \(def.label(for: value))")
        case .engineText(let text):
            return L("engine: \(text)")
        }
    }
}

enum ConfigError: LocalizedError {
    case noPermission
    case gameNeverLaunched
    case io(String)

    var errorDescription: String? {
        switch self {
        case .noPermission:
            return L("Pimp My Whoosh isn't allowed to change MyWhoosh's settings. Add it in System Settings › Privacy & Security › Full Disk Access, then reopen the app.")
        case .gameNeverLaunched:
            return L("MyWhoosh's settings folder wasn't found: launch the game at least once.")
        case .io(let message):
            return message
        }
    }
}

enum ConfigWriter {
    static func checkAccess() -> ConfigError? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        // Without Full Disk Access macOS hides the app's container: even its existence is a clue.
        guard fm.fileExists(atPath: GamePaths.configDir.path, isDirectory: &isDir), isDir.boolValue else {
            if (try? fm.contentsOfDirectory(atPath: GamePaths.configDir.deletingLastPathComponent().path)) == nil,
               fm.fileExists(atPath: GamePaths.container.deletingLastPathComponent().path) {
                return .noPermission
            }
            return .gameNeverLaunched
        }
        for url in [GamePaths.engineIni, GamePaths.gameUserSettingsIni] where fm.fileExists(atPath: url.path) {
            do { try FileHandle(forUpdating: url).close() } catch { return .noPermission }
        }
        return nil
    }

    static func apply(_ plan: ConfigPlan) throws {
        if let problem = checkAccess() { throw problem }
        try rewrite(GamePaths.engineIni, plan.engineIni(from:))
        if !plan.gameUserSettings.isEmpty {
            try rewrite(GamePaths.gameUserSettingsIni, plan.gameUserSettingsIni(from:))
        }
        for (key, value) in plan.appPreferences {
            setPreference(key, value)
        }
        Log.write("Applied \(plan.systemSettings.count + plan.userInterface.count + plan.audio.count + plan.gameUserSettings.count) ini keys")
    }

    /// Goes through `defaults` so cfprefsd sees the change (editing the plist file directly could be overwritten).
    private static func setPreference(_ key: String, _ value: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        if let value {
            process.arguments = ["write", GamePaths.preferencesDomain, key, "-bool", value == "1" ? "YES" : "NO"]
        } else {
            process.arguments = ["delete", GamePaths.preferencesDomain, key]
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        // waitUntilExit() on a process that never started raises an exception, so only wait after a successful launch.
        guard (try? process.run()) != nil else { return }
        process.waitUntilExit()
    }

    private static func rewrite(_ url: URL, _ transform: (String) -> String) throws {
        let fm = FileManager.default
        let original = fm.fileExists(atPath: url.path) ? ((try? String(contentsOf: url, encoding: .utf8)) ?? "") : ""
        let updated = transform(original)
        guard updated != original else { return }
        do {
            if fm.fileExists(atPath: url.path) {
                let backup = url.appendingPathExtension("pimpmywhoosh.bak")
                try? fm.removeItem(at: backup)
                try fm.copyItem(at: url, to: backup)
            }
            try updated.write(to: url, atomically: false, encoding: .utf8)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError {
            throw ConfigError.noPermission
        } catch {
            throw ConfigError.io(L("Couldn't write \(url.lastPathComponent): \(error.localizedDescription)"))
        }
    }
}

enum GameLauncher {
    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: GamePaths.bundleID).isEmpty
    }

    /// `performanceHUD` turns on Apple's Metal Performance HUD for this launch only (FPS, frame time, GPU memory).
    static func launch(performanceHUD: Bool = false) async throws {
        guard let app = GamePaths.gameApp else {
            throw ConfigError.io(L("MyWhoosh isn't installed in /Applications."))
        }
        let configuration = NSWorkspace.OpenConfiguration()
        if performanceHUD {
            configuration.environment = ["MTL_HUD_ENABLED": "1"]
        }
        try await NSWorkspace.shared.openApplication(at: app, configuration: configuration)
        Log.write("Launched \(app.lastPathComponent)")
    }
}

enum Log {
    static func write(_ message: String) {
        let line = "\(Date()) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: GamePaths.log) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: GamePaths.log)
        }
    }
}

enum SystemSettingsLink {
    static func openFullDiskAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
