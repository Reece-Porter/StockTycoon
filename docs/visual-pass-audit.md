# Visual pass: Phase 0 audit and Phase 1 plan

The brief is in `docs/visual-pass.md`. This is the Phase 0 report it asks for. Nothing visual has changed yet; Phase 1 starts once it's approved.

## How things are built now

- **Map.** Everything in the world is built by one Command Bar script, `studio/BuildMap.luau`: 8 bases, the street, the middle conveyor, the shops and upgrade station, the leaderboards, the tunnel arches and the hills (Terrain). Nothing is hand-placed. Parts are plain blocks, mostly SmoothPlastic, with a little Neon, Glass, Fabric and Pavement. Colours are constants at the top of that file.
- **Company models.** `ReplicatedStorage.Assets.Companies` has one `Default` blue box, used by all 30 companies. `src/server/Lib/CompanyModels.luau` clones a model named after the company if one exists, otherwise `Default`. It's the single place companies are cloned, for the conveyors, carrying, plots, the machine and dropped companies. Variants are layered on there too (`decorate`): a sparkle emitter, plus fire and a light on some variants.
- **Pets and weapons.** One `Default` round pet, tinted by rarity through parts with a `RarityTint` attribute. Five weapon Tools built from parts in BuildMap.
- **Definitions.** `src/shared/Config`: 30 companies (`Companies.luau`), 6 tiers with colours (`Tiers.luau`), 12 pets and 6 rarities with colours (`Pets.luau`), 6 variants with colours (`Variants.luau`), 5 weapons.
- **UI.** 24 client controllers, each building its own screen in code: dark panels (RGB 20, 20, 25), white BuilderSans text and small rounded corners. The only shared UI piece is `Ui/CompanyLabel` (the floating company label). There's no Theme module, and colours are hard-coded in 21 client files. `src/shared/Format.luau` already writes 1.2K, 3.4M, 5.6B, 7.8T and beyond.
- **Lighting.** Studio defaults. Nothing in code or BuildMap sets Atmosphere, Bloom, ColorCorrection or SunRays.
- **Rojo.** Syncs `src/shared`, `src/server` and `src/client` only. Lighting, the map and the Assets folder live in the place file.
- **Streaming.** The client code already copes with parts streaming in and out. I can't see the place's StreamingEnabled setting from here.

## What I'll reuse

- Every controller's logic, remotes and save data. Only the code that builds each screen changes.
- `CompanyModels.clone` and `decorate`, as the one entry point for company models and the variant layer (Phases 3 and 4).
- BuildMap, as the one builder for bases, the street and scenery (Phases 5, 6 and 8).
- `Format.luau` for numbers. The kit adds the count-up.
- The config files as the list of tiers, rarities and variants. Their colours move to Theme.

## What I'll replace

- Hard-coded colours and fonts everywhere: replaced by Theme and the UI kit.
- The shared Default box: replaced by a model per company (Phase 3).
- The variant decoration: replaced by the variant layer in the brief (Phase 4).
- Default lighting.

## Decisions I need from you

1. **Theme location.** I'd put it at `src/shared/Theme.luau`, so client UI, server-made signs and BuildMap all read the same colours. BuildMap would then require it from `ReplicatedStorage.Shared`, which means Rojo must be connected when you run BuildMap (it normally is).
2. **Lighting.** I'd set it in code when the server starts, so it's saved in git and identical in Test and Live. The alternative is setting it in BuildMap, where it's saved into the place file.
3. **Company models (asked again before Phase 3).** I'd build them in code from config entries with one shared builder when the server starts. There'd be no Studio step, and a hand-made model in `Assets.Companies` would still win. This changes how models are stored, so the brief says to ask.
4. **Variant lights (Phase 4).** Molten, Galaxy, Rainbow and Glitched currently get a light on any tier. The brief's budget allows lights only on Conglomerate and Monopoly, so on lower tiers I'd swap them for Neon accents.
5. **Fonts.** FredokaOne for titles, numbers and buttons; BuilderSans Bold (already used) for body text. Both are built in, so no assets are needed.
6. **Which rules win.** The brief says to ask before structural decisions, while CLAUDE.md says to make them myself. For the visual pass I'll follow the brief.

## What I can and can't check from here

I can run lint, type checks, every logic test and the banned-words search, and I can check part counts and particle and light budgets in code. I can't open Studio's device emulator or measure frame rate. At the end of each phase I'll give exact steps for checking those in Studio.

## Phase 1 plan: Theme, lighting and UI kit

1. **`src/shared/Theme.luau`.** The brief's palette (ink, panel, card, border, text, cash green, gold, blue, purple, red), every tier, rarity and variant colour, the two fonts, corner radii, stroke widths and tween timings. `Tiers`, `Pets` and `Variants` take their colours from Theme, so existing code keeps working. A test checks every tier, rarity and variant has a colour.
2. **Lighting**, set when the server starts:
   - fixed early-afternoon sun with warm ambient light;
   - Atmosphere: light haze with a slightly blue horizon;
   - Bloom: subtle, with a high threshold so only Neon glows;
   - ColorCorrection: a small lift to saturation and contrast;
   - gentle SunRays.

   The default sky stays as a stand-in until a custom skybox exists, which goes in ASSETS_NEEDED.md.
3. **UI kit** in `src/client/Ui/Kit`:
   - Button: chunky style, press and hover tweens, optional icon.
   - Window: coloured header, red round close button, optional tabs, scale-and-fade open, dimmed background.
   - Card: tier, rarity or variant border; viewport or icon; name, stat and badge.
   - Badge: small pills for tiers, rarities and variants.
   - Toast stack: slides in from the top with a coloured edge, at most three.
   - Cash count-up.
   - Icons drawn from UI shapes (cash, padlock, star, arrow, tick and so on).
4. **First use.** Notification toasts switch to the new toast stack. That's the one screen Phase 1 changes; Phase 2 rebuilds the rest.
5. **A kit gallery screen** in the admin debug panel, showing every component, so you can check them in the device emulator before Phase 2.
6. **`docs/ASSETS_NEEDED.md`**: the skybox and every icon that needs a real image later, with exact specs.
7. **Checks:** StyLua, Selene, luau-lsp, Rojo build, all tests and the banned-words search. No gameplay, remote or save changes.
