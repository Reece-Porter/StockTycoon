# Stock Tycoon

Roblox tycoon game. Game rules and working agreements are in [`CLAUDE.md`](CLAUDE.md); numbers and build order are in [`docs/design.md`](docs/design.md).

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder. That installs the pinned versions of Rojo, Wally, Selene and StyLua from `rokit.toml`.
2. Run `rojo plugin install` to install the matching Rojo plugin in Studio.
3. Run `wally install`. It creates `ServerPackages/` (ProfileStore) and `wally.lock`. Commit `wally.lock`, but not the package folders.
4. Open the **Test** place in Studio (never Live), run `rojo serve`, and press Connect in the Rojo plugin.

Rojo refuses to start if `ServerPackages/` is missing, so run `wally install` first after a fresh clone.

`servePlaceIds` in `default.project.json` limits syncing to the Test place (88809294007206). The Rojo plugin refuses to connect from any other place, including Live.

## Checks

```sh
stylua --check src   # formatting (run `stylua src` to fix)
selene src           # linting
rojo build -o build/StockTycoon.rbxl   # project file builds
```

## Where code syncs

| Folder           | In Studio                                   |
| ---------------- | ------------------------------------------- |
| `src/server`     | `ServerScriptService.Server`                |
| `src/client`     | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared`     | `ReplicatedStorage.Shared`                  |
| `ServerPackages` | `ServerScriptService.ServerPackages`        |

Rojo only manages these folders. The map in `Workspace.Map` and models in `ReplicatedStorage.Assets` are built by hand in Studio, and Rojo leaves them alone.
