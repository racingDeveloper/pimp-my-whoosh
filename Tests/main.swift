// Tests for the .ini writer and the settings catalog. Run with ./test.sh
import Foundation

var failures = 0
func check(_ name: String, _ ok: Bool) {
    print(ok ? "PASS" : "FAIL", name)
    if !ok { failures += 1 }
}

let base = ";METADATA=(Diff=true, UseCommands=true)\n[GameNetDriver StatelessConnectHandlerComponent]\nCachedClientID=15\n"
// 1. Game default: nothing forced → file unchanged
check("game default leaves untouched file", ConfigPlan(values: [:]).engineIni(from: base) == base)
// 2. Max preset → idempotent, section present once
let max = ConfigPlan(values: Catalog.validated(Preset.builtIn.first { $0.id == "max" }!.values))
let e1 = max.engineIni(from: base), e2 = max.engineIni(from: e1)
check("max idempotent", e1 == e2)
check("one SystemSettings section", e1.components(separatedBy: "[SystemSettings]").count == 2)
check("sg.ResolutionQuality capped at 100", e1.contains("sg.ResolutionQuality=100") && e1.contains("r.ScreenPercentage=150"))
check("other sections preserved", e1.contains("CachedClientID=15"))
// 3. Switching back to game default removes our section
let back = ConfigPlan(values: [:]).engineIni(from: e1)
check("game default removes SystemSettings", !back.contains("[SystemSettings]") && back.contains("CachedClientID=15"))
// 4. Audio: set, keep foreign keys, then unset
let withAudio = "[Audio]\nUseAudioThread=true\n\n[Other]\nx=1\n"
let a1 = ConfigPlan(values: ["UnfocusedVolumeMultiplier": "1.0"]).engineIni(from: withAudio)
check("audio key added in existing section", a1.contains("[Audio]\nUnfocusedVolumeMultiplier=1.0") && a1.contains("UseAudioThread=true"))
let a2 = ConfigPlan(values: [:]).engineIni(from: a1)
check("audio key removed, foreign key kept", !a2.contains("UnfocusedVolumeMultiplier") && a2.contains("UseAudioThread=true") && a2.contains("x=1"))
let a3 = ConfigPlan(values: ["UnfocusedVolumeMultiplier": "0.5"]).engineIni(from: base)
check("audio section created when missing", a3.contains("[Audio]\nUnfocusedVolumeMultiplier=0.5"))
// 5. GameUserSettings: replace in place, no duplicates
let gus = "[ScalabilityGroups]\nsg.ShadowQuality=3\n\n[/Script/Engine.GameUserSettings]\nFullscreenMode=1\nLastConfirmedFullscreenMode=1\nPreferredFullscreenMode=1\nbUseHDRDisplayOutput=False\n"
let g1 = ConfigPlan(values: ["FullscreenMode": "2", "bUseHDRDisplayOutput": "True"]).gameUserSettingsIni(from: gus)
check("GUS replaced in place", g1.components(separatedBy: "FullscreenMode=2").count == 4 && !g1.contains("FullscreenMode=1") && g1.contains("bUseHDRDisplayOutput=True") && g1.contains("sg.ShadowQuality=3"))
// 6. Validation rejects out-of-range and snaps sliders
check("invalid values dropped", Catalog.validated(["r.MaxAnisotropy": "7", "t.MaxFPS": "999", "foo": "1"]).isEmpty)
check("slider snapped", Catalog.validated(["r.Tonemapper.Sharpen": "0.83", "r.ScreenPercentage": "151"]) == ["r.Tonemapper.Sharpen": "0.8", "r.ScreenPercentage": "150"])
check("slider out of range dropped", Catalog.validated(["r.ScreenPercentage": "400"]).isEmpty)
// 7. Every preset value is valid
for p in Preset.builtIn { check("preset \(p.id) fully valid", Catalog.validated(p.values).count == p.values.count) }
// 8. Empty file
check("empty file gets section", ConfigPlan(values: ["r.VSync": "1"]).engineIni(from: "") == "\n[SystemSettings]\nr.VSync=1\n")
// 9. App Nap preference planned
check("app nap delete when unset", ConfigPlan(values: [:]).appPreferences.first?.1 == nil)

exit(failures == 0 ? 0 : 1)
