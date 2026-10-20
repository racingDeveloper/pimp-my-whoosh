import Foundation

/// Localized string; the English text is the key, translations live in <lang>.lproj/Localizable.strings.
func L(_ value: String.LocalizationValue) -> String {
    String(localized: value)
}

/// Where a setting is written.
enum IniTarget {
    /// Engine.ini → [SystemSettings]: higher priority than the values the game sets itself.
    case systemSettings
    /// Engine.ini → [/Script/Engine.UserInterfaceSettings]
    case userInterface
    /// Engine.ini → [Audio]
    case audio
    /// GameUserSettings.ini → [/Script/Engine.GameUserSettings]
    case gameUserSettings
    /// The game's macOS preferences (its sandbox container plist).
    case appPreferences
}

struct Option: Hashable {
    let value: String
    let label: String
}

enum Control {
    case choice([Option])
    case slider(min: Double, max: Double, step: Double, decimals: Int, unit: String)
}

struct SettingDef: Identifiable {
    let key: String
    let title: String
    let help: String
    let section: SettingSection
    let control: Control
    var target: IniTarget = .systemSettings
    var id: String { key }

    /// Normalizes a value and accepts it only if it is one of the allowed values.
    func validated(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch control {
        case .choice(let options):
            return options.contains { $0.value == raw } ? raw : nil
        case .slider(let min, let max, let step, let decimals, _):
            guard let v = Double(raw), v >= min - 1e-9, v <= max + 1e-9 else { return nil }
            let snapped = (min + ((v - min) / step).rounded() * step)
            return SettingDef.format(snapped, decimals: decimals)
        }
    }

    /// Human-readable label for a value (the picker's label, when there is one).
    func label(for value: String) -> String {
        switch control {
        case .choice(let options):
            return options.first { $0.value == value }?.label ?? value
        case .slider(_, _, _, _, let unit):
            return value + unit
        }
    }

    static func format(_ v: Double, decimals: Int) -> String {
        decimals == 0 ? String(Int(v.rounded())) : String(format: "%.\(decimals)f", v)
    }
}

enum SettingSection: String, CaseIterable, Identifiable {
    case quality, resolution, fps, detail, effects, lighting, display, system
    var id: String { rawValue }

    var title: String {
        switch self {
        case .quality: return L("Quality")
        case .resolution: return L("Resolution")
        case .fps: return L("FPS & latency")
        case .detail: return L("Distance & detail")
        case .effects: return L("Effects")
        case .lighting: return L("Lighting")
        case .display: return L("Display & window")
        case .system: return L("Audio & system")
        }
    }

    var symbol: String {
        switch self {
        case .quality: return "slider.horizontal.3"
        case .resolution: return "viewfinder"
        case .fps: return "speedometer"
        case .detail: return "mountain.2"
        case .effects: return "sparkles"
        case .lighting: return "sun.max"
        case .display: return "macwindow"
        case .system: return "speaker.wave.2"
        }
    }

    var note: String? {
        switch self {
        case .quality:
            return L("MyWhoosh's own menu tops out at level 3: its \"High\" is Unreal's Epic. 4 = Cinematic.")
        case .resolution:
            return L("MyWhoosh isn't Retina-aware: it renders at the logical resolution (e.g. 1440×900 on a 2880×1800 display) and macOS scales it up ×2. Above 100% the game renders more pixels and scales them down, so the image is sharper (at a GPU cost).")
        case .fps:
            return L("At every launch the game forces VSync on and a 40 FPS cap; t.MaxFPS here has higher priority. Check the result with the in-game stats.")
        case .lighting:
            return L("It's unknown whether the project supports these techniques: they may cost a lot of performance or have no effect.")
        case .system:
            return L("Settings that change how the game behaves when it isn't the frontmost app.")
        default:
            return nil
        }
    }
}

private func levels(_ labels: [String], from start: Int = 0) -> [Option] {
    labels.enumerated().map { Option(value: String($0.offset + start), label: $0.element) }
}

private let scalabilityLevels = levels([
    L("0 · Low"), L("1 · Medium"), L("2 · High"), L("3 · Epic (= menu High)"), L("4 · Cinematic"),
])
private let onOff = [Option(value: "0", label: L("Off")), Option(value: "1", label: L("On"))]
private let quality5 = levels([L("0 · Off"), L("1 · Low"), L("2 · Medium"), L("3 · High"), L("4 · Very high")])

private func sg(_ key: String, _ title: String) -> SettingDef {
    SettingDef(key: "sg.\(key)", title: title, help: L("Scalability group sg.\(key) (0–4)."),
               section: .quality, control: .choice(scalabilityLevels))
}

enum Catalog {
    static let all: [SettingDef] = [
        // Quality
        sg("ViewDistanceQuality", L("View distance")),
        sg("AntiAliasingQuality", L("Anti-aliasing")),
        sg("ShadowQuality", L("Shadows")),
        sg("GlobalIlluminationQuality", L("Global illumination")),
        sg("ReflectionQuality", L("Reflections")),
        sg("PostProcessQuality", L("Post-processing")),
        sg("TextureQuality", L("Textures")),
        sg("EffectsQuality", L("Effects")),
        sg("FoliageQuality", L("Foliage")),
        sg("ShadingQuality", L("Shading")),
        sg("LandscapeQuality", L("Landscape")),

        // Resolution
        SettingDef(key: "r.ScreenPercentage", title: L("Render resolution"),
                   help: L("r.ScreenPercentage. Above 100 = supersampling. Also sets sg.ResolutionQuality so the game can't lower it based on its own benchmark."),
                   section: .resolution, control: .slider(min: 50, max: 200, step: 5, decimals: 0, unit: "%")),
        SettingDef(key: "r.AntiAliasingMethod", title: L("Anti-aliasing method"),
                   help: L("r.AntiAliasingMethod: 0 none, 1 FXAA, 2 TAA, 4 TSR."),
                   section: .resolution, control: .choice([
                       Option(value: "0", label: L("None")), Option(value: "1", label: "FXAA"),
                       Option(value: "2", label: "TAA"), Option(value: "4", label: "TSR"),
                   ])),
        SettingDef(key: "r.Tonemapper.Sharpen", title: L("Sharpening"),
                   help: L("r.Tonemapper.Sharpen: 0 off, 1 full strength (the engine accepts up to 10)."),
                   section: .resolution, control: .slider(min: 0, max: 3, step: 0.1, decimals: 1, unit: "")),
        SettingDef(key: "r.MaxAnisotropy", title: L("Anisotropic filtering"),
                   help: L("r.MaxAnisotropy: 1 to 16 (default 4)."),
                   section: .resolution, control: .choice(["1", "2", "4", "8", "16"].map { Option(value: $0, label: "\($0)×") })),

        // FPS
        SettingDef(key: "t.MaxFPS", title: L("Frame rate cap"),
                   help: L("t.MaxFPS: ≤0 = uncapped. The game's menu offers 30/40/60/90."),
                   section: .fps, control: .choice([
                       Option(value: "30", label: "30"), Option(value: "40", label: "40"),
                       Option(value: "60", label: "60"), Option(value: "90", label: "90"),
                       Option(value: "120", label: "120"), Option(value: "0", label: L("Uncapped")),
                   ])),
        SettingDef(key: "r.VSync", title: "VSync", help: L("r.VSync: 0 off, 1 on."),
                   section: .fps, control: .choice(onOff)),
        SettingDef(key: "r.OneFrameThreadLag", title: L("One-frame render thread lag"),
                   help: L("r.OneFrameThreadLag: 0 = lower latency, 1 = more throughput (default)."),
                   section: .fps, control: .choice(onOff)),
        SettingDef(key: "r.GTSyncType", title: L("Game thread sync"),
                   help: L("r.GTSyncType: 0 render thread (default), 1 RHI thread, 2 swap chain flip (lowest latency)."),
                   section: .fps, control: .choice(levels([L("0 · Render thread"), L("1 · RHI thread"), L("2 · Swap chain")]))),

        // Distance & detail
        SettingDef(key: "r.ViewDistanceScale", title: L("View distance scale"),
                   help: L("r.ViewDistanceScale: multiplies the maximum draw distance (default 1)."),
                   section: .detail, control: .slider(min: 0.5, max: 3, step: 0.25, decimals: 2, unit: "×")),
        SettingDef(key: "r.StaticMeshLODDistanceScale", title: L("Object LOD distance"),
                   help: L("r.StaticMeshLODDistanceScale: lower values keep full detail longer (default 1)."),
                   section: .detail, control: .slider(min: 0.25, max: 2, step: 0.25, decimals: 2, unit: "×")),
        SettingDef(key: "r.SkeletalMeshLODBias", title: L("Rider LOD"),
                   help: L("r.SkeletalMeshLODBias: -1 = more detail, positive = less."),
                   section: .detail, control: .choice(["-1", "0", "1", "2"].map { Option(value: $0, label: $0) })),
        SettingDef(key: "r.Shadow.MaxResolution", title: L("Shadow resolution"),
                   help: L("r.Shadow.MaxResolution in texels (default 2048)."),
                   section: .detail, control: .choice(["512", "1024", "2048", "4096", "8192"].map { Option(value: $0, label: $0) })),
        SettingDef(key: "r.Shadow.DistanceScale", title: L("Shadow distance"),
                   help: L("r.Shadow.DistanceScale: <1 shorter, >1 longer (default 1)."),
                   section: .detail, control: .slider(min: 0.5, max: 3, step: 0.25, decimals: 2, unit: "×")),
        SettingDef(key: "foliage.DensityScale", title: L("Foliage density"),
                   help: L("foliage.DensityScale: only applies to foliage that supports it."),
                   section: .detail, control: .slider(min: 0, max: 2, step: 0.25, decimals: 2, unit: "×")),
        SettingDef(key: "grass.densityScale", title: L("Grass density"),
                   help: L("grass.densityScale: multiplies grass density."),
                   section: .detail, control: .slider(min: 0, max: 2, step: 0.25, decimals: 2, unit: "×")),
        SettingDef(key: "foliage.LODDistanceScale", title: L("Foliage LOD distance"),
                   help: L("foliage.LODDistanceScale: higher values = full detail further away."),
                   section: .detail, control: .slider(min: 0.5, max: 3, step: 0.25, decimals: 2, unit: "×")),
        SettingDef(key: "r.Streaming.PoolSize", title: L("Texture memory"),
                   help: L("r.Streaming.PoolSize in MB."),
                   section: .detail, control: .choice(["1000", "2000", "3000", "4000", "6000"].map { Option(value: $0, label: "\($0) MB") })),

        // Effects
        SettingDef(key: "r.MotionBlurQuality", title: L("Motion blur"),
                   help: L("r.MotionBlurQuality: 0 off … 4 very high."),
                   section: .effects, control: .choice(quality5)),
        SettingDef(key: "r.DepthOfFieldQuality", title: L("Depth of field"),
                   help: L("r.DepthOfFieldQuality: 0 off, 1 low, 2 high; 3–4 are meant for cinematics."),
                   section: .effects, control: .choice(levels([L("0 · Off"), L("1 · Low"), L("2 · High"), L("3 · Very high"), L("4 · Extreme")]))),
        SettingDef(key: "r.SceneColorFringeQuality", title: L("Chromatic aberration"),
                   help: L("r.SceneColorFringeQuality: 0 off, 1 on."),
                   section: .effects, control: .choice(onOff)),
        SettingDef(key: "r.BloomQuality", title: L("Bloom"),
                   help: L("r.BloomQuality: 0 off … 5 best."),
                   section: .effects, control: .choice(levels([L("0 · Off"), "1", "2", "3", "4", L("5 · Best")]))),
        SettingDef(key: "r.LensFlareQuality", title: L("Lens flares"),
                   help: L("r.LensFlareQuality: 0 off … 3 very good."),
                   section: .effects, control: .choice(levels([L("0 · Off"), L("1 · Low"), L("2 · Good"), L("3 · Very good")]))),
        SettingDef(key: "r.FilmGrain", title: L("Film grain"), help: L("r.FilmGrain: 0 off, 1 on."),
                   section: .effects, control: .choice(onOff)),
        SettingDef(key: "r.AmbientOcclusionLevels", title: L("Ambient occlusion"),
                   help: L("r.AmbientOcclusionLevels: -1 automatic, 0 off, 1–3 levels."),
                   section: .effects, control: .choice(levels([L("-1 · Auto"), L("0 · Off"), "1", "2", "3"], from: -1))),
        SettingDef(key: "r.SSR.Quality", title: L("Screen-space reflections"),
                   help: L("r.SSR.Quality: 0 off … 4 very high."),
                   section: .effects, control: .choice(quality5)),
        SettingDef(key: "r.ContactShadows", title: L("Contact shadows"), help: L("r.ContactShadows: 0 off, 1 on."),
                   section: .effects, control: .choice(onOff)),
        SettingDef(key: "r.VolumetricFog", title: L("Volumetric fog"), help: L("r.VolumetricFog: 0 off, 1 on."),
                   section: .effects, control: .choice(onOff)),

        // Lighting
        SettingDef(key: "r.DynamicGlobalIlluminationMethod", title: L("Dynamic global illumination"),
                   help: L("r.DynamicGlobalIlluminationMethod: 0 none, 1 Lumen, 2 SSGI."),
                   section: .lighting, control: .choice(levels([L("0 · None"), "1 · Lumen", "2 · SSGI"]))),
        SettingDef(key: "r.ReflectionMethod", title: L("Reflection method"),
                   help: L("r.ReflectionMethod: 0 none, 1 Lumen, 2 SSR."),
                   section: .lighting, control: .choice(levels([L("0 · None"), "1 · Lumen", "2 · SSR"]))),
        SettingDef(key: "r.Shadow.Virtual.Enable", title: "Virtual Shadow Maps",
                   help: L("r.Shadow.Virtual.Enable: 0 off, 1 on."),
                   section: .lighting, control: .choice(onOff)),

        // Display & window
        SettingDef(key: "FullscreenMode", title: L("Window mode"),
                   help: L("GameUserSettings.ini: 0 fullscreen, 1 borderless fullscreen window, 2 windowed."),
                   section: .display, control: .choice(levels([L("Fullscreen"), L("Borderless window"), L("Windowed")])),
                   target: .gameUserSettings),
        SettingDef(key: "bUseHDRDisplayOutput", title: L("HDR output"),
                   help: L("GameUserSettings.ini bUseHDRDisplayOutput: HDR output on displays that support it (e.g. Liquid Retina XDR)."),
                   section: .display, control: .choice([Option(value: "False", label: L("Off")), Option(value: "True", label: L("On"))]),
                   target: .gameUserSettings),
        SettingDef(key: "HDRDisplayOutputNits", title: L("HDR peak brightness"),
                   help: L("GameUserSettings.ini HDRDisplayOutputNits: Unreal supports 1000 and 2000 nits."),
                   section: .display, control: .choice(["1000", "2000"].map { Option(value: $0, label: "\($0) nit") }),
                   target: .gameUserSettings),
        SettingDef(key: "ApplicationScale", title: L("Interface scale"),
                   help: L("[/Script/Engine.UserInterfaceSettings] ApplicationScale. Not verified on MyWhoosh."),
                   section: .display, control: .slider(min: 0.75, max: 1.5, step: 0.05, decimals: 2, unit: "×"),
                   target: .userInterface),

        // Audio & system
        SettingDef(key: "UnfocusedVolumeMultiplier", title: L("Volume in background"),
                   help: L("Engine.ini [Audio] UnfocusedVolumeMultiplier: game volume while another app is in front (0 = muted, 1 = unchanged)."),
                   section: .system, control: .slider(min: 0, max: 1, step: 0.1, decimals: 1, unit: "×"),
                   target: .audio),
        SettingDef(key: "NSAppSleepDisabled", title: L("Prevent App Nap"),
                   help: L("macOS preference NSAppSleepDisabled in the game's container: stops macOS from throttling the game while it's hidden or behind other windows."),
                   section: .system, control: .choice(onOff),
                   target: .appPreferences),
    ]

    static let byKey: [String: SettingDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })

    /// Where the game gets the value from when the app doesn't force one.
    static func baseline(for key: String) -> Baseline {
        if key.hasPrefix("sg.") { return .scalabilityGroup }
        return baselines[key] ?? .project
    }

    private static let baselines: [String: Baseline] = [
        "r.ScreenPercentage": .renderScale,
        "t.MaxFPS": .forcedAtBoot("40"),
        "r.VSync": .forcedAtBoot("1"),
        "r.OneFrameThreadLag": .engine("1"),
        "r.GTSyncType": .engine("0"),
        "r.Tonemapper.Sharpen": .engineText(L("inherits from post-process")),
        "r.StaticMeshLODDistanceScale": .engine("1.00"),
        "ApplicationScale": .engine("1.00"),
        "FullscreenMode": .gameUserSetting("FullscreenMode"),
        "bUseHDRDisplayOutput": .gameUserSetting("bUseHDRDisplayOutput"),
        "HDRDisplayOutputNits": .gameUserSetting("HDRDisplayOutputNits"),
        "UnfocusedVolumeMultiplier": .engineText(L("0, muted in background (the project may differ)")),
        "NSAppSleepDisabled": .engineText(L("macOS decides (App Nap allowed)")),
        "r.ViewDistanceScale": .follows("sg.ViewDistanceQuality"),
        "r.SkeletalMeshLODBias": .follows("sg.ViewDistanceQuality"),
        "r.Shadow.MaxResolution": .follows("sg.ShadowQuality"),
        "r.Shadow.DistanceScale": .follows("sg.ShadowQuality"),
        "r.VolumetricFog": .follows("sg.ShadowQuality"),
        "r.MaxAnisotropy": .follows("sg.TextureQuality"),
        "r.Streaming.PoolSize": .follows("sg.TextureQuality"),
        "foliage.DensityScale": .follows("sg.FoliageQuality"),
        "grass.densityScale": .follows("sg.FoliageQuality"),
        "foliage.LODDistanceScale": .follows("sg.FoliageQuality"),
        "r.MotionBlurQuality": .follows("sg.PostProcessQuality"),
        "r.DepthOfFieldQuality": .follows("sg.PostProcessQuality"),
        "r.SceneColorFringeQuality": .follows("sg.PostProcessQuality"),
        "r.BloomQuality": .follows("sg.PostProcessQuality"),
        "r.LensFlareQuality": .follows("sg.PostProcessQuality"),
        "r.AmbientOcclusionLevels": .follows("sg.PostProcessQuality"),
        "r.SSR.Quality": .follows("sg.ReflectionQuality"),
        "r.ContactShadows": .scalable,
        "r.Shadow.Virtual.Enable": .scalable,
    ]

    static func validated(_ values: [String: String]) -> [String: String] {
        values.reduce(into: [:]) { result, pair in
            if let v = byKey[pair.key]?.validated(pair.value) { result[pair.key] = v }
        }
    }
}

enum Baseline {
    /// sg.* level the game saved in GameUserSettings.ini.
    case scalabilityGroup
    /// Derived from an sg.* group level (the scalability tables live in the encrypted .pak).
    case follows(String)
    /// Registered as a scalability cvar, but which group changes it isn't known for sure.
    case scalable
    /// Value the game sets at every launch, regardless of its menu.
    case forcedAtBoot(String)
    /// Resolution decided by the menu's "Render Scale" (saved in GameData.sav).
    case renderScale
    /// Key read from GameUserSettings.ini.
    case gameUserSetting(String)
    /// Unreal engine default (the project might change it).
    case engine(String)
    case engineText(String)
    /// Project setting: lives in the encrypted .pak.
    case project
}

struct Preset: Identifiable, Hashable {
    /// Stable identifier, stored in UserDefaults; never shown.
    let id: String
    let name: String
    let summary: String
    let values: [String: String]

    static let customID = "custom"
    static var custom: Preset {
        Preset(id: customID, name: L("Custom"), summary: L("Hand-tuned values, remembered for the next launches."), values: [:])
    }

    private static func allSG(_ level: String) -> [String: String] {
        Catalog.all.filter { $0.section == .quality }.reduce(into: [:]) { $0[$1.key] = level }
    }

    private static let noBlur = ["r.MotionBlurQuality": "0", "r.SceneColorFringeQuality": "0", "r.DepthOfFieldQuality": "0"]

    static let builtIn: [Preset] = [
        Preset(id: "max", name: L("Max"), summary: L("Everything maxed out, rendering at 150% for a sharper image."),
               values: allSG("4").merging(noBlur) { $1 }.merging([
                   "r.ScreenPercentage": "150", "t.MaxFPS": "60", "r.VSync": "1",
                   "r.Tonemapper.Sharpen": "0.8", "r.MaxAnisotropy": "16", "r.Streaming.PoolSize": "3000",
                   "r.ViewDistanceScale": "2.00", "r.Shadow.MaxResolution": "4096", "r.Shadow.DistanceScale": "2.00",
                   "r.SkeletalMeshLODBias": "-1", "r.StaticMeshLODDistanceScale": "0.50", "grass.densityScale": "2.00",
               ]) { $1 }),
        Preset(id: "balanced", name: L("Balanced"), summary: L("Matches the menu's \"High\" at full resolution, without the superfluous effects."),
               values: allSG("3").merging(noBlur) { $1 }.merging([
                   "r.ScreenPercentage": "100", "t.MaxFPS": "60", "r.VSync": "1",
                   "r.Tonemapper.Sharpen": "0.5", "r.MaxAnisotropy": "8",
               ]) { $1 }),
        Preset(id: "performance", name: L("Performance"), summary: L("Medium quality and 85% rendering, for less powerful Macs or steadier FPS."),
               values: allSG("2").merging(noBlur) { $1 }.merging([
                   "r.ScreenPercentage": "85", "t.MaxFPS": "60", "r.VSync": "1",
                   "r.Tonemapper.Sharpen": "0.6", "r.MaxAnisotropy": "4", "r.Shadow.MaxResolution": "1024",
               ]) { $1 }),
        Preset(id: "original", name: L("Game default"), summary: L("No changes: the game decides, as if this app weren't there."),
               values: [:]),
    ]
}
