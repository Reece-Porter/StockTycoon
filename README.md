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
| `/spawn <tier> [shared] [variant]`  | Rolls your Stock Spinner with a company of that tier first, or puts one on the shared conveyor (e.g. `/spawn bluechip galaxy`, `/spawn monopoly shared`) |
| `/roll`                             | Rolls your Stock Spinner now instead of waiting for the next roll                                       |
| `/takeover [start [minutes] \| stop]` | Starts a Hostile Takeover now (5 minutes, or as many as you say), stops one, or (on its own) says when the next one is |
| `/testvariants [rolls]`             | Simulates variant rolls with your Variant Chance upgrade and compares them with Config                  |
| `/setupgrade <upgrade> <level> [player]` | Sets an upgrade station level for free (e.g. `/setupgrade walkspeed 5`)                            |
| `/testodds [shared] [rolls]`        | Simulates your Stock Spinner's rolls (with your rebirths and Spinner Luck), or the shared conveyor's, and compares the odds with Config |
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
| `/analytics`                        | Shows what this server has sent to Roblox analytics, newest first                                       |
| `/givepass <pass> [player]`         | Gives a game pass for this session (`doubleincome`, `vip` or `extrapetslot`)                            |
| `/removepass <pass> [player]`       | Takes a game pass away for this session                                                                 |
| `/buyproduct <product>`             | Gives a developer product as if it was bought (`cashsmall`, `cashmedium`, `cashlarge` or `locknow`)     |
| `/resetdata`                        | Wipes your save back to a new player's                                                                  |
| `/booth [back]`                     | Takes you to the photo booth for screenshots, or `back` home (see `docs/ART_BRIEFS.md`)                 |
| `/pose <hero, left or right> <company or pet> [variant] [size]` | Poses a company or pet on a booth podium; `/pose base` copies your base onto the stage; `/pose clear` |
| `/backdrop <colour>`                | Paints the booth's backdrop: sky, gold, green, blue, purple, teal, pink, white or night                 |
| `/boothcam <icon, wide, base, free or off>` | Looks through a booth camera with the HUD hidden; `free` only hides the HUD, anywhere in the map |

Admins also get a **Debug** button in the top right corner of the screen that shows live values, including whether saving is on and why their last attack was or wasn't allowed (LastAttack). Its **UI kit** button opens every piece of the visual pass's UI kit (buttons, windows, cards, badges, icons, toasts and the Cash count-up) on one screen, for checking the look in Studio's device emulator.

## Codes

Players type codes into the **Codes** window (the Codes button on the right of the screen). The list is in [`src/server/Config/Codes.luau`](src/server/Config/Codes.luau): a new code is one line there, with what it gives and an optional last day. Each code works once per player.

| Code         | Gives                          | Last day   |
| ------------ | ------------------------------ | ---------- |
| `STOCKS`     | $5K and a 10 minute 2x boost   | none       |
| `BULLMARKET` | 1 free pet spin                | 2026-12-31 |

## Setting up the store

The Store button sells three game passes and four developer products (`src/shared/Config/Monetisation.luau`). Until each has an id it shows as "Not on sale". To put them on sale:

1. On the [Creator Dashboard](https://create.roblox.com/dashboard/creations), open the game, then **Monetization > Passes**. Create 2x Income, VIP and Extra Pet Slot, give each a picture and a price, and put them on sale.
2. In **Monetization > Developer Products**, create Cash Pack, Big Cash Pack, Huge Cash Pack and Lock Base Now with their prices.
3. Copy each one's id into `id = 0` for the matching entry in `Config/Monetisation.luau`.

Purchases made in Studio are test purchases and cost nothing. Game passes bought in Studio only last for that test, so `/givepass` is the easiest way to try them.

## Building the map

The map and the models the game copies are made by one Studio script, [`studio/BuildMap.luau`](studio/BuildMap.luau). It puts every part in its exact place, so it fixes the map whatever state it is in, and it is safe to run again.

1. Stop the game if it is playing (changes made while playing are thrown away).
2. Make sure Rojo is connected to the Test place: the map reads the game's colours from `ReplicatedStorage.Shared.Theme` and the parody company names for the billboards from `ReplicatedStorage.Shared.Config.Companies`, which Rojo syncs. Without Theme, the script stops with a message saying so.
3. Clear the Command Bar completely (Cmd+A or Ctrl+A, then Delete).
4. Paste the whole of `studio/BuildMap.luau` and press Run, without typing anything else into the Command Bar. It takes a little while: the Output shows lines starting `BuildMap:` as it goes, then `Map built`.
5. Save the place.

If the Output shows a red error instead of `Map built`, the map may be left half-built. Read the error: if it says the Theme is out of date, pull the latest code in GitHub Desktop and check Rojo is connected. Then clear the Command Bar, paste the script again and run it. A run that finishes rebuilds the whole map, whatever state it was left in.

When the map needs to change, this file changes, so run it again after pulling new code. If you forget, the Output says "The map is out of date" when you press Play, and admins see the same notice on screen. Never paste older map scripts alongside it.

## Where code syncs

| Folder           | In Studio                                   |
| ---------------- | ------------------------------------------- |
| `src/server`     | `ServerScriptService.Server`                |
| `src/client`     | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared`     | `ReplicatedStorage.Shared`                  |
| `ServerPackages` | `ServerScriptService.ServerPackages`        |

Rojo only manages these folders. The map in `Workspace.Map` and models in `ReplicatedStorage.Assets` live in the place itself (see "Building the map"), and Rojo leaves them alone.
