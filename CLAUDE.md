# Stock Tycoon (working title)

Roblox tycoon game in the style of Steal a Brainrot. Parody companies come out of each base's Stock Spinner and along a shared conveyor, players buy them, carry them back to their base, optionally run them through the Valuation Machine, then place them on plots where they generate Cash per second. Bases grow upwards: players upgrade to unlock more plots and new floors. A central weapon shop sells weapons for fighting other players, mainly over the shared conveyor. A pet shop next to it sells pet spins; pets are placed on a floor to give that floor a modifier. During an hourly Hostile Takeover, other players can steal placed companies. Rebirth gives up your Cash for a permanent income multiplier and more plots. Gold, a second currency that rebirth never takes, buys upgrades.

Full game design, numbers and build order: `docs/design.md`. Read it before starting any feature. Values marked as starting assumptions are tunable and live in Config, never hard-coded.

## Core loop
1. Companies come from two places:
   a. a Stock Spinner machine at each player's base: the player walks up to it and plays it, a slot-style pop-up rolls 3 different companies with the player's Luck (which grows with each rebirth and shows on their base's sign), and those companies come out onto the base's belt, where only that player can buy them, until the machine is played again, and
   b. one shared conveyor in the middle of the map (any player can buy) with better rarity odds and two tiers found nowhere else.
2. Player buys a company; the character physically carries it back to their base.
3. At the base, the player either places it straight onto a free plot, or puts it into the Valuation Machine first (free the first time, Cash to run it again).
4. Placed companies generate Cash per second. Cash buys more companies and plots.
5. Cash also buys base upgrades (more plots on floors 1 and 2, and floor 2 itself), weapons and pet spins. Gold, earned from Index challenges and the battle arena, buys the upgrade station's upgrades.
6. During a Hostile Takeover (5 minutes at the start of every hour), other players can enter a base, pick up a placed company and carry it to their own base. Owners defend with a timed base lock and by tagging thieves. Outside a takeover, bases can't be stolen from.
7. Rebirth takes only the player's Cash, for a permanent income multiplier, more Stock Spinner Luck and 2 more plots on floors 3 and 4 (which only rebirths open). Each rebirth needs one or two particular companies, a little rarer every rebirth or two (Kittygram for the first). Companies, plots, floors, pets, upgrades and Gold are kept. (Changed by Reece, October 2026; it used to reset companies and base upgrades too.)
8. Playtime milestones and a daily login streak give Cash, temporary income boosts and free pet spins.

## Companies
- Each company instance stores: instanceId, companyId, tier, baseIncome, valuationMultiplier (default 1.0), hasBeenValued (bool), ownerUserId.
- Income per second = baseIncome x valuationMultiplier x floor pet modifier x rebirth multiplier x active reward boost (x any game pass multiplier).
- A stolen company keeps its valuationMultiplier and hasBeenValued.

## Valuation Machine rules (non-negotiable)
- Optional. A company's first run is free and costs nothing to start.
- After that (including after being stolen), the owner can pay Cash to run it again (a respin), priced by the company's tier. The new multiplier replaces the old one, higher or lower. (Changed by Reece, October 2026; it used to be once per company, ever.)
- Multiplier starts at 1.0x, rises to a hidden peak, then falls back past 1.0x towards the floor.
- Floor = 0.5x: the machine can reduce a company to as little as half its base income, never lower. (Changed by Reece, October 2026; it used to be 1.0x.) The battle arena's machine works the same way.
- Peak multiplier: random, 1.2x to 5x, weighted towards the low end (tunable).
- Duration: random, 10 to 45 seconds. Never longer than 45.
- Peak time: random, between 20% and 70% of duration.
- Small random noise on the path so the peak is not obvious.
- Player presses Take to lock the current multiplier. If they never press it, the company gets the value shown when time runs out.
- A company inside the machine cannot be stolen.
- No Robux purchases may affect the machine in any way (no rerolls, no boosted odds, no extra runs). Respins are Cash only.
- Never use the words bet, wager, gamble, crash, jackpot or casino in code, UI or assets.

## Server authority
- The SERVER owns all company instances, ownership, carrying state, base locks and plot placement.
- The server generates the whole machine path (duration, peak, peak time, noise seed) when a run starts and sends seed and params to the client for rendering.
- On Take, the client sends only "take". The server works out the multiplier from its own clock. Never trust a value from the client.
- Validate every purchase, pick-up, steal and placement on the server (cash, availability, distance, lock state, carry state).
- Shared conveyor purchases: first valid request processed by the server wins; others get a "too slow" message.
- Ownership changes from stealing are saved immediately.
- Combat is server-validated: the server checks weapon ownership, cooldown, range and line of sight before applying damage. Client hit detection is a request, never a result.
- Pet spins are rolled on the server only.
- Playtime and daily rewards are tracked and validated on the server using server time. The client only asks to claim.
- Rate-limit all RemoteEvents.

## Pet spins (non-negotiable)
- Pet spins cost in-game Cash only, unless I explicitly approve Robux spins.
- If Robux spins are ever added: show the odds for every pet before purchase, and check PolicyService ArePaidRandomItemsRestricted per player, hiding Robux spins where it is true.
- Pets never affect the Valuation Machine.

## Combat
- Cartoon style only: knockback, stun, ragdoll. No blood, no realistic weapons.
- No damage inside a player's own base (attackers can still be hit there by the owner).

## Environments
- Two Roblox places: a Test place and the Live place. All work is synced and tested in Test. Never point Rojo at Live unless I say so.
- Admin commands and the debug panel exist only for user IDs listed in `src/shared/Config/Admins.luau`, checked on the server.

## Parody companies
- Obvious pun names only, original logos and colours.
- Never use real logos, wordmarks, fonts or brand colour schemes.

## Tooling
- Rojo for syncing files into Studio
- Wally for packages
- ProfileStore for player data
- Selene for linting, StyLua for formatting
- Roblox Studio MCP server for testing in Studio
- Luau with `--!strict` in every file

## Structure
```
src/
  server/      -- services: Data, Conveyor, Spinner, Purchase, Carry, Base, Upgrade, Steal, Takeover, Combat, WeaponShop, PetShop, Machine, Income, Rebirth, Rewards, Codes, Analytics, Admin, Monetisation
  client/      -- controllers and UI
  shared/      -- Config, types, pure maths (machine path, prices, income, spawn rolls)
docs/
  design.md    -- game design, numbers, build order
```
- Machine path maths goes in `shared` as a pure, deterministic function of (seed, params, time) so server and client draw the same curve.
- Map, models and the machine are built by hand in Studio. Code finds them by name under `Workspace.Map` (see design.md). If something expected is missing, stop and tell me rather than generating placeholder geometry silently.

## UI
- Mobile first: touch-sized buttons, portrait and landscape.
- Machine screen: line chart, current multiplier shown large, one big Take button, no visible countdown.
- Plot billboards show company name, tier and income per second.

## Working rules
- Read the existing code before changing anything.
- Make structural decisions (new services, data schema changes, new packages) yourself without asking, and explain them in the summary afterwards.
- Never change the saved data schema without a migration.
- Work one build slice at a time from design.md. Do not start the next slice until I confirm the current one passes its checks.
- After each feature, tell me how to test it in Studio.
