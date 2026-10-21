# Assets needed

Real images, meshes and sounds the game is waiting for. Until each one exists, the game uses a stand-in built from parts, UI shapes and built-in effects, so nothing here blocks play. Asset ids must never be made up: once an asset is uploaded, its real id goes in config.

Every asset must follow the hard rules in `docs/visual-pass.md`: parody only (no real logos, logo shapes, wordmarks, mascots, fonts or brand colours), cartoon style, and none of the banned words anywhere in the asset or its name.

Colours below are from `src/shared/Theme.luau`.

## Sky

**Skybox** (stand-in: Roblox's default sky)
- Purpose: the sky over the whole map, matching the fixed early-afternoon lighting.
- Size: six square faces (SkyboxBk, SkyboxDn, SkyboxFt, SkyboxLf, SkyboxRt, SkyboxUp), 1024 x 1024 each, seamless where they meet.
- Style: bright, friendly cartoon sky. Soft gradient from a pale hazy horizon (#CDDCF0) to a clear blue above, with a few big, soft, rounded clouds. No sun drawn in (Roblox draws its own), no text, no logos. The bottom face can be a plain soft blue.
- Background: opaque.

## Icons

All icons share one style: chunky and rounded, a thick dark outline (Ink, #1B1B2F), one strong colour plus white, and readable at 48 x 48 on a phone. Each is a 512 x 512 PNG with a transparent background and a little padding round the edge.

The first nine are drawn from UI shapes for now (`src/client/Ui/Kit/Icons.luau`):

| Icon | Purpose | Main colour |
| --- | --- | --- |
| Cash | Cash amounts, price tags, buy buttons | Cash green #3CCB5A, with a white "$" |
| Padlock | Locked items, the base lock | White on its button |
| Tick | Owned items, done | White on Cash green |
| Cross | Close buttons | White on Danger red #FF4D5E |
| Plus | Add, open more | White |
| Arrow (up) | Upgrades | White on Primary blue #3D8BFF |
| Home | Teleport home | White |
| Gem | Store and premium items | White on Gold #FFC83D |
| Notification dot | "Something new" marker on menu buttons | Danger red #FF4D5E (fine to stay a shape) |

These menu icons are needed for the Phase 2 screens. Until they exist, those buttons use the shape icons above or a labelled placeholder:

| Icon | Purpose | Suggested design |
| --- | --- | --- |
| Storage | Storage window | A cardboard box with the lid open |
| Weapons | Weapon shop and weapons | A rolled-up newspaper |
| Pets | Pets window and pet shop | A round paw print |
| Index | Collection book | A closed book with a star on the cover |
| Rebirth | Rebirth window | Two curved arrows in a circle |
| Rewards | Playtime and daily rewards | A wrapped gift with a bow |
| Codes | Codes window | A ticket stub |
| Boost | 2x income boost chip | A lightning bolt (Gold) |
| Collect | Cash pads | A coin with an arrow into it (Cash green) |
| Teleport: Upgrades | Teleport button | An up arrow on a pad |
| Teleport: Weapons | Teleport button | Crossed newspaper and gavel |

## Fonts

None needed: the two fonts (FredokaOne and BuilderSans Bold) are built into Roblox.

## Sounds

None requested yet. Later phases will list button clicks, collecting Cash, purchases, steals, hits and the rebirth celebration here.
