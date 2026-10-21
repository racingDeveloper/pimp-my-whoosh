import Foundation

/// How certain it is that a setting has an effect in MyWhoosh.
enum Effectiveness {
    /// The engine always applies it: visible or measurable on every route.
    case always
    /// Only works if the route (post-process, lights, foliage) uses that feature: level files are encrypted.
    case content
    /// A technique the project might not support: unpredictable result.
    case experimental

    var label: String {
        switch self {
        case .always: return L("Guaranteed effect")
        case .content: return L("Depends on the route")
        case .experimental: return L("Experimental")
        }
    }

    var symbol: String {
        switch self {
        case .always: return "checkmark.circle.fill"
        case .content: return "questionmark.circle.fill"
        case .experimental: return "flask.fill"
        }
    }
}

struct SettingInfo {
    let effect: Effectiveness
    let detail: String
}

extension Catalog {
    /// Defaults the cvars are registered with in the MyWhoosh 6.2.3 binary (UE 5.6), read from the registration calls.
    /// For scalability cvars this is the starting value, later overridden by the group level.
    static let engineDefaults: [String: String] = [
        "r.AntiAliasingMethod": "4", "r.DynamicGlobalIlluminationMethod": "0", "r.ReflectionMethod": "2",
        "r.FilmGrain": "1", "r.Shadow.Virtual.Enable": "0", "r.MaxAnisotropy": "4", "r.Shadow.MaxResolution": "2048",
        "r.Shadow.DistanceScale": "1.00", "r.ViewDistanceScale": "1.00", "r.StaticMeshLODDistanceScale": "1.00",
        "r.MotionBlurQuality": "4", "r.DepthOfFieldQuality": "2", "r.SceneColorFringeQuality": "1",
        "r.BloomQuality": "5", "r.LensFlareQuality": "2", "r.AmbientOcclusionLevels": "-1", "r.SSR.Quality": "3",
        "r.ContactShadows": "1", "r.LightShaftQuality": "1", "r.VolumetricRenderTarget.Mode": "0", "r.Streaming.PoolSize": L("automatic"), "foliage.DensityScale": "1.00",
        "foliage.LODDistanceScale": "1.00",
    ]

    static func info(for key: String) -> SettingInfo {
        if let info = infos[key] { return info }
        return SettingInfo(effect: .always, detail: "")
    }

    private static let infos: [String: SettingInfo] = [
        "sg.ViewDistanceQuality": .init(effect: .always, detail: L("How far objects, buildings and riders are drawn, and when they switch to simpler models. Higher = less pop-in in the distance. Mostly costs CPU.")),
        "sg.AntiAliasingQuality": .init(effect: .always, detail: L("Quality of temporal anti-aliasing (samples and frame history). Higher = steadier edges on cables, fences and barriers, without shimmering. Moderate GPU cost.")),
        "sg.ShadowQuality": .init(effect: .always, detail: L("Resolution, distance and cascades of the sun's shadows. One of the heaviest groups for the GPU; at 4 the trees' shadows on the road are sharper and reach further.")),
        "sg.GlobalIlluminationQuality": .init(effect: .content, detail: L("Indirect light (how much surfaces light up their surroundings). If routes use baked lighting, the difference is small.")),
        "sg.ReflectionQuality": .init(effect: .content, detail: L("Quality of reflections on water and shiny surfaces. Water was found in the packages of AlWathba and Japan; elsewhere the difference is small.")),
        "sg.PostProcessQuality": .init(effect: .always, detail: L("Bloom, motion blur, depth of field, ambient occlusion, exposure adaptation. Raising it also re-enables motion blur and depth of field unless you force them to 0 in Effects.")),
        "sg.TextureQuality": .init(effect: .always, detail: L("Resolution of loaded textures and their memory budget. Costs memory more than speed: with Apple Silicon's unified memory it's worth keeping high.")),
        "sg.EffectsQuality": .init(effect: .always, detail: L("Particles, translucent materials, refraction and scene color precision. Includes rain and weather particles, found in AlWathba, AlUla, California, Colombia, Australia, Switzerland and Belgium. Medium cost.")),
        "sg.FoliageQuality": .init(effect: .always, detail: L("Density and distance of trees and bushes. Instanced foliage was found in practically every world, most of all AlWathba, AlUla, Tour of Arabia and Japan: one of the most expensive groups for GPU and CPU.")),
        "sg.ShadingQuality": .init(effect: .always, detail: L("Material precision (specular highlights, skin, fabrics). Low-to-medium cost, subtle difference.")),
        "sg.LandscapeQuality": .init(effect: .always, detail: L("Detail of the terrain surface in the distance (hills, mountains). Low cost.")),

        "r.ScreenPercentage": .init(effect: .always, detail: L("The most important lever for sharpness. The game renders at the logical resolution and macOS scales it ×2; above 100% it computes more pixels and averages them down, which gives cleaner edges and finer textures, though not true Retina detail (the game's bundle doesn't allow it). GPU cost grows with pixels: 150% = 2.25× vs 100%, 200% = 4×.")),
        "r.AntiAliasingMethod": .init(effect: .always, detail: L("The engine starts from TSR (4), but the project might use something else. TSR = best quality and great at reconstructing resolution; TAA is lighter but a bit softer; FXAA is nearly free but leaves jaggies and shimmering; no AA leaves jagged edges. Above 130% resolution even TAA is very clean.")),
        "r.Tonemapper.Sharpen": .init(effect: .always, detail: L("Sharpening applied at the end of the frame: offsets the softness typical of TAA/TSR. 0.5–1 is a good range; above 1.5 bright halos appear around edges.")),
        "r.MaxAnisotropy": .init(effect: .always, detail: L("Sharpness of textures seen at a grazing angle: that's the road right in front of your rider. On Apple Silicon GPUs 16× costs next to nothing.")),

        "t.MaxFPS": .init(effect: .always, detail: L("The game sets 40 FPS at every launch (measured). This value has higher priority. On MacBook Pros with a ProMotion display you can try 120; more FPS means more heat and fan noise during long workouts.")),
        "r.VSync": .init(effect: .always, detail: L("Syncs frames to the display: no tearing (a horizontally split image), at the cost of a little latency. The game always turns it on.")),
        "r.OneFrameThreadLag": .init(effect: .always, detail: L("With On (default) CPU and GPU work on different frames in parallel: more FPS. Off removes about one frame of latency but may lower FPS. In a cycling app latency matters little: usually best left alone.")),
        "r.GTSyncType": .init(effect: .always, detail: L("What the game thread syncs with. 2 (swap chain) gives the lowest latency but can make the frame rate less even. Only useful if controls feel laggy.")),

        "r.ViewDistanceScale": .init(effect: .always, detail: L("Multiplier for the draw distance. Careful: forcing it replaces the value chosen by the View distance group, which at level 4 might already be higher.")),
        "r.StaticMeshLODDistanceScale": .init(effect: .always, detail: L("Below 1 objects keep full detail for longer, so you see fewer model swaps as you approach. Costs geometry and CPU.")),
        "r.SkeletalMeshLODBias": .init(effect: .always, detail: L("Detail of animated models: riders, bikes, avatars. -1 always keeps the best model, noticeable when riding in a group.")),
        "r.Shadow.MaxResolution": .init(effect: .always, detail: L("Maximum shadow map size (engine base 2048). 4096 makes shadows crisper; 8192 is heavy on memory and GPU.")),
        "r.Shadow.DistanceScale": .init(effect: .always, detail: L("How far the sun's dynamic shadows reach. Above 1 reduces shadows popping in on the road ahead.")),
        "foliage.DensityScale": .init(effect: .content, detail: L("Multiplies foliage, but only for foliage types where the level designers enabled density scaling. Foliage is in every world, but whether scaling is enabled can't be read from the packages.")),
        "grass.densityScale": .init(effect: .experimental, detail: L("Grass generated automatically on landscape terrain. No trace of it was found in any world's packages, so it most likely has no effect in MyWhoosh.")),
        "foliage.LODDistanceScale": .init(effect: .always, detail: L("Distance at which trees and bushes switch to simpler models. Higher values = detailed vegetation further away. Foliage is in practically every world.")),
        "r.Streaming.PoolSize": .init(effect: .always, detail: L("Memory reserved for textures (the default lets the engine decide). If too small, textures stay blurry or \"load in\" while you ride. On Macs with 32 GB or more, 3000–4000 MB is safe.")),

        "r.MotionBlurQuality": .init(effect: .always, detail: L("Motion blur (engine base 4 = very high). At a steady riding speed it blurs the scenery on the sides: many prefer Off, which also saves a little GPU.")),
        "r.DepthOfFieldQuality": .init(effect: .content, detail: L("Background or foreground blur, used mostly in menus, the garage and cinematic shots. 0 keeps everything sharp.")),
        "r.SceneColorFringeQuality": .init(effect: .content, detail: L("Chromatic aberration: colored fringes toward the screen edges, like a cheap lens. Off = cleaner image, zero cost. Only acts if the post-process uses it.")),
        "r.BloomQuality": .init(effect: .content, detail: L("Glow around strong lights and the sun. 0 gives a flatter image. Intensity is set by the level designers: here you only change the quality.")),
        "r.LensFlareQuality": .init(effect: .content, detail: L("Lens reflections when looking toward the sun. Found only in the game's main package, not in specific worlds: if the effect is there, it's likely the same on every route.")),
        "r.FilmGrain": .init(effect: .content, detail: L("Film grain. Found only in the game's main package, not in specific worlds; Off guarantees a clean image everywhere.")),
        "r.AmbientOcclusionLevels": .init(effect: .always, detail: L("Soft shading in corners and where objects touch (SSAO). -1 lets the Post-processing group decide; 0 turns it off for a few extra FPS, but the image gets flatter.")),
        "r.SSR.Quality": .init(effect: .content, detail: L("Screen-space reflections on water and wet roads. Only works if the reflection method is SSR (the engine default). Water was found in AlWathba and Japan.")),
        "r.ContactShadows": .init(effect: .content, detail: L("Small contact shadows (wheels on asphalt, objects on the ground). Lights using them were found in France and Bhutan.")),
        "r.LightShaftQuality": .init(effect: .content, detail: L("Sun rays through trees and buildings. Found in AlWathba, AlUla, Japan, UCI 2024, Colombia, France and Belgium. Off gives a few FPS on those routes.")),
        "r.VolumetricRenderTarget.Mode": .init(effect: .content, detail: L("Resolution of the volumetric clouds. The sky system with volumetric clouds is in the game's main package, so it's likely used on every route. Half resolution makes clouds sharper; full resolution is very expensive.")),
        "r.VolumetricFog": .init(effect: .content, detail: L("Volumetric fog. Found only in shared content, not in any specific world: probably used rarely, if at all.")),

        "r.DynamicGlobalIlluminationMethod": .init(effect: .experimental, detail: L("Engine base 0 (none). 1 enables Lumen: real-time indirect light, very heavy, and without the data the project has to generate it can cause artifacts. 2 enables SSGI, lighter and limited to what's on screen.")),
        "r.ReflectionMethod": .init(effect: .experimental, detail: L("Engine base 2 (SSR). 1 = Lumen reflections, which only make sense with Lumen global illumination on; 0 removes them.")),
        "r.Shadow.Virtual.Enable": .init(effect: .experimental, detail: L("Virtual Shadow Maps: very sharp shadows designed for Nanite geometry. Expensive; on non-Nanite content they can look worse than classic shadows.")),

        "FullscreenMode": .init(effect: .always, detail: L("0 = fullscreen in a separate Space, 1 = borderless window covering the screen, 2 = regular window (handy to keep other apps beside it). The game doesn't reset it at launch.")),
        "bUseHDRDisplayOutput": .init(effect: .experimental, detail: L("Turns on Unreal's HDR output, for displays like the MacBook Pro's Liquid Retina XDR or an HDR monitor. Colors and brightness may look off if the game's content or UI wasn't tuned for HDR.")),
        "HDRDisplayOutputNits": .init(effect: .experimental, detail: L("Peak brightness the HDR output targets. Only used when HDR output is on; 1000 matches most XDR and HDR monitors.")),
        "ApplicationScale": .init(effect: .experimental, detail: L("Scale of the whole interface (panels, numbers, map). Useful for a more compact UI or one that's easier to read from the bike. Not verified on MyWhoosh: the game might ignore it.")),

        "UnfocusedVolumeMultiplier": .init(effect: .always, detail: L("Unreal lowers the game's volume while another app is in front: by default it mutes it. Set 1 to keep hearing the game while you use a browser or a video in another window.")),
        "NSAppSleepDisabled": .init(effect: .experimental, detail: L("App Nap is how macOS slows down apps that are hidden or behind other windows. While measuring, MyWhoosh dropped to 8–16 FPS in the background. On keeps it running at full speed, at the cost of more energy use.")),
    ]
}
