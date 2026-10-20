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

## Admin commands

Type these in chat. They only work for user IDs in `src/shared/Config/Admins.luau` (and, inside Studio, for Player1 in a local server test).

| Command                             | What it does                                                                                            |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `/givecash <amount> [player]`       | Adds Cash to you, or to another player (e.g. `/givecash 1000 Player2`)                                  |
| `/setcash <amount>`                 | Sets Cash to an exact amount                                                                            |
| `/spawn <tier> [shared]`            | Puts a company of that tier on your conveyor, or the shared one (e.g. `/spawn monopoly shared`)         |
| `/testodds [shared] [rolls]`        | Simulates conveyor spawns and compares the odds with Config                                             |
| `/racetest`                         | Every player tries to buy the same shared-conveyor company in the same instant; shows who got it        |
| `/protect [player] [seconds]`       | Protects a player from stealing as if they were new (default 300 s; `0` removes it)                     |
| `/giveweapon <weapon> [player]`     | Gives and equips a weapon for free (e.g. `/giveweapon gavel`, `/giveweapon goldencalculator Player2`)   |
| `/setrebirths <count> [player]`     | Sets the rebirth count without resetting anything (e.g. `/setrebirths 3 Player2`)                       |
| `/givepet <pet or rarity> [player]` | Gives a pet for free (e.g. `/givepet coffeecat`, or `/givepet mythic` for a random Mythic)              |
| `/testspins [rolls]`                | Simulates pet spins (default 10,000) and compares the odds with Config                                  |
| `/skipplaytime <minutes>`           | Adds minutes to today's playtime (e.g. `/skipplaytime 60`)                                              |
| `/shiftday [days]`                  | Acts as if days have passed: playtime resets and the daily reward is ready (`/shiftday 2` misses a day) |
| `/discover <count>`                 | Adds that many random companies to your Index                                                           |
| `/refreshboards`                    | Saves everyone's leaderboard values and reloads the boards now, instead of within a minute              |
| `/resetdata`                        | Wipes your save back to a new player's                                                                  |

Admins also get a **Debug** button at the top of the screen that shows live values, including whether saving is on and why their last attack was or wasn't allowed (LastAttack).

## Codes

Players type codes into the **Codes** box at the bottom of the Rewards window. The list is in [`src/server/Config/Codes.luau`](src/server/Config/Codes.luau): a new code is one line there, with what it gives and an optional last day. Each code works once per player.

| Code         | Gives                          | Last day   |
| ------------ | ------------------------------ | ---------- |
| `STOCKS`     | $5K and a 10 minute 2x boost   | none       |
| `BULLMARKET` | 1 free pet spin                | 2026-12-31 |

## Building the map

The map and the models the game copies are made by one Studio script, [`studio/BuildMap.luau`](studio/BuildMap.luau). It puts every part in its exact place, so it fixes the map whatever state it is in, and it is safe to run again.

1. Stop the game if it is playing (changes made while playing are thrown away).
2. Clear the Command Bar completely (Cmd+A or Ctrl+A, then Delete).
3. Paste the whole of `studio/BuildMap.luau` and press Run. The Output says `Map built`.
4. Save the place.

When the map needs to change, this file changes. Never paste older map scripts alongside it.

## Where code syncs

| Folder           | In Studio                                   |
| ---------------- | ------------------------------------------- |
| `src/server`     | `ServerScriptService.Server`                |
| `src/client`     | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared`     | `ReplicatedStorage.Shared`                  |
| `ServerPackages` | `ServerScriptService.ServerPackages`        |

Rojo only manages these folders. The map in `Workspace.Map` and models in `ReplicatedStorage.Assets` live in the place itself (see "Building the map"), and Rojo leaves them alone.
