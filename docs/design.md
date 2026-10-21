# Stock Tycoon: game design

Decisions marked "Decided" come from Reece and should not be changed without asking. Everything marked "Starting assumption" is a first guess for balance and should live in `src/shared/Config` so it can be tuned.

## Decided
- Stealing is in, Steal a Brainrot style.
- Rebirth is in.
- Two conveyor types: personal (one per base) and shared (one in the middle of the map). The shared conveyor has better rarity odds and two tiers that only appear there.
- The Valuation Machine can never reduce a company below base income.
- Bases are upgraded to unlock more plots, then new floors with more plots.
- A weapon shop in the middle of the map sells weapons that damage other players, mainly for fighting over the shared conveyor.
- A pet shop next to the weapon shop sells pet spins. Pets are placed on a floor and give that floor a modifier.
- Playtime rewards at 5, 10, 15, 30, 60, 90 and 120 minutes, plus a daily login bonus.

## Tiers (starting assumption)
Price, base income per second, and where it spawns.
- **Startup**: 50 Cash, 2/s. Personal and shared.
- **Scale-up**: 500 Cash, 15/s. Personal and shared.
- **Unicorn**: 5,000 Cash, 120/s. Personal and shared.
- **Blue Chip**: 50,000 Cash, 900/s. Personal and shared.
- **Conglomerate**: 500,000 Cash, 7,000/s. Shared only.
- **Monopoly**: 5,000,000 Cash, 50,000/s. Shared only.

Each tier has several parody companies (aim for 4 to 6 per tier at launch). Companies within a tier can vary their price and income by up to plus or minus 20%.

## Spawn weights (starting assumption)
- **Personal conveyor**: Startup 70, Scale-up 22, Unicorn 7, Blue Chip 1.
- **Shared conveyor**: Startup 55, Scale-up 28, Unicorn 12, Blue Chip 4, Conglomerate 0.9, Monopoly 0.1.
- Weights scale with rebirth count: each rebirth shifts a small share of weight from lower tiers to higher ones (exact rule to be agreed before building).

## Conveyors (starting assumption)
- Personal conveyor spawns one company every 6 seconds; shared every 8.8 seconds. (Personal halved from 3 after playtesting: the belts were too busy. Shared went from 2 to 4, then 30% fewer when its belt was made 4 times longer, then 35% fewer again for more space between companies, at the same speed.)
- Companies move at a set speed: 1.6 studs per second on personal belts (about 20 seconds along a 32-stud belt), 2.4 on the shared belt (about 2 minutes 10 seconds along its 316 studs, which run the length of the map). They despawn at the End if unbought.
- Buying uses a ProximityPrompt on the company.
- Shared conveyor tier announcements: Conglomerate and Monopoly spawns trigger a server-wide message.

## Carrying (starting assumption)
- One company carried at a time.
- Walk speed while carrying: 75% of normal.
- If the carrier leaves the game or resets, a bought company returns to their base storage; a stolen company returns to its original owner's plot.
- A dropped company returns to its rightful place after 10 seconds.

## Base, plots and floors (starting assumption)
- Each player gets a base with a personal conveyor, the Valuation Machine, a lock button and floors of plots.
- Floor 1 starts with 6 plots. Plot upgrades add 1 plot at a time, up to 10 per floor.
- Once a floor is full (10 plots), the player can buy the next floor, which starts with 6 plots and upgrades to 10.
- Maximum 4 floors (40 plots) at launch.
- Upgrade cost rises with each plot and steeply with each floor. Exact curve in Config.
- Each floor has 1 pet slot; a second pet slot per floor can be bought later.
- Floors are reached by stairs or a lift pad; stealing works on every floor.
- A new base is just the ground floor. Each upper floor (its platform, stairs, plots, pet slots, glass and trim) appears only once the owner opens it, and the whole base goes back to the ground floor on rebirth or when the owner leaves. Until the next floor is open, a rail closes off the landing where its stairs would start.
- Plots stand near the side walls, either side of the walkway, each with a cash pad in front of it.
- Companies can be sold back for 50% of purchase price, and moved between plots and floors freely.
- Overflow storage holds up to 5 unplaced companies.

## Stealing (starting assumption)
- Any player can walk into another player's base and pick up a placed company via ProximityPrompt (hold 1.5 seconds).
- The thief must carry it back to their own base and place it to complete the steal.
- If the owner touches the thief while they're carrying the stolen company, it returns to the owner's plot.
- Weapons can also be used to knock a carried company out of a thief's hands (see Combat).
- Base lock: the owner presses a button at their base to block entry for 60 seconds. When it ends, they must press it again. Show the remaining lock time on the base.
- Companies inside the Valuation Machine cannot be stolen.
- New players get a 5-minute protection period on first join.
- Cannot steal from a player with zero rebirths if the thief has 3 or more (prevents veterans farming beginners). Exact rule to confirm.

## Combat and weapon shop (starting assumption)
- Players have 100 health. At 0 they ragdoll for 3 seconds and respawn at their own base, dropping anything they carry.
- A hit on a player carrying a company makes them drop it. A dropped company sits on the ground for 10 seconds and anyone can pick it up; if nobody does, it returns to its owner (the buyer, or the original owner if it was mid-steal).
- This is how players fight over the shared conveyor: buy a rare company, then get it home before someone knocks it off you.
- No damage taken inside your own base, so you can always get home safely once through the door. Attackers inside your base can still be hit by you.
- 10 seconds of spawn protection after respawning.
- Weapons are bought with Cash only, kept through rebirth, one equipped at a time.
- Corporate-themed weapons, cartoon style. Starting list:
  - **Rolled-up Newspaper**: free starter. 10 damage, short range, fast.
  - **Briefcase**: 2,500 Cash. 20 damage, knockback.
  - **Stapler Gun**: 25,000 Cash. 12 damage, short ranged projectile.
  - **Gavel**: 250,000 Cash. 35 damage, slow, big knockback.
  - **Golden Calculator**: 2,500,000 Cash. 30 damage, stuns for 1 second.
- Every weapon has a cooldown. Numbers in Config.
- This content needs declaring as violence in the Roblox maturity questionnaire. Cartoon knockback with no blood should stay at the mildest level.

## Pet shop (starting assumption)
- Next to the weapon shop.
- One spin gives one random pet. Spin cost: 10,000 Cash, plus 50% of that per rebirth (in step with the rebirth income multiplier).
- Rarity odds, shown in the shop UI: Common 60%, Uncommon 25%, Rare 10%, Epic 4%, Legendary 0.9%, Mythic 0.1%.
- Pets are placed in a floor's pet slot and modify that floor only.
- Two modifier types:
  - **Income pets**: boost income of every company on that floor. Common +5%, Uncommon +10%, Rare +20%, Epic +35%, Legendary +60%, Mythic +100%.
  - **Guard pets**: make companies on that floor harder to steal by adding to the pick-up hold time. Common +0.5s up to Mythic +4s.
- Multiple pets on the same floor stack additively.
- Pets cannot be stolen and are kept through rebirth.
- Pet inventory capped at 50; duplicates can be deleted.
- Pets never affect the Valuation Machine.
- Spins cost Cash only at launch. Robux spins would need odds disclosure and region checks (see CLAUDE.md), so don't add them without asking.

## Playtime and daily rewards (starting assumption)
Playtime rewards
- Milestones at 5, 10, 15, 30, 60, 90 and 120 minutes of play.
- Playtime counts per day, not per session, and resets at 00:00 UTC. Leaving and rejoining keeps progress, so there's no reason to rejoin-farm, and no penalty for disconnecting.
- Rewards are claimed with a button (a gift icon with a badge when one is ready), not auto-granted, so the player sees them.
- Unclaimed rewards stay claimable until the daily reset.
- Cash rewards are worth a number of seconds of the player's current income at claim time, with a minimum so new players still get something useful:
  - **5 min**: 60 seconds of income (minimum 100 Cash)
  - **10 min**: 120 seconds of income (minimum 250 Cash)
  - **15 min**: 2x income boost for 5 minutes
  - **30 min**: 300 seconds of income (minimum 1,000 Cash)
  - **60 min**: free pet spin
  - **90 min**: 2x income boost for 15 minutes
  - **120 min**: 900 seconds of income (minimum 5,000 Cash) and a 2x boost for 15 minutes
- AFK time counts (Roblox's own idle kick still applies).

Daily login streak
- One claim per UTC day, on a 7-day cycle:
  - **Day 1**: 120 seconds of income
  - **Day 2**: 2x income boost for 10 minutes
  - **Day 3**: 300 seconds of income
  - **Day 4**: free pet spin
  - **Day 5**: 600 seconds of income
  - **Day 6**: 2x income boost for 20 minutes
  - **Day 7**: 2 free pet spins and a 2x boost for 30 minutes
- Missing a day resets the streak to Day 1. After Day 7 it loops back to Day 1.
- Daily Cash rewards have minimums like the playtime ones, so new players get something: Day 1 at least 250, Day 3 at least 1,000, Day 5 at least 2,500.
- Cash rewards use the player's income without any active reward boost, so one reward isn't doubled by another.
- Show the full 7-day track on claim so players can see what's coming.

Boost rules
- Only one reward boost is active at a time. A new boost adds its duration to the current one rather than stacking multipliers, capped at 60 minutes banked.
- Boost timers run only while the player is in the game, and are saved on leave.
- Reward boosts stack multiplicatively with the 2x income game pass.
- Free pet spins from rewards are stored as tokens and used at the pet shop.

## Index (starting assumption)
- The Index lists every company and marks the ones a player has ever owned (bought, or stolen and placed). Ones not found yet show as "???".
- Prizes for collecting different companies, claimed with a button like rewards:
  - **5**: 120 seconds of income (minimum 500 Cash)
  - **10**: free pet spin
  - **15**: 300 seconds of income (minimum 2,500 Cash) and a 2x boost for 10 minutes
  - **20**: 2 free pet spins
  - **25**: 600 seconds of income (minimum 10,000 Cash) and a 2x boost for 20 minutes
  - **30 (all of them)**: 3 free pet spins and a 2x boost for 30 minutes
- Kept through rebirth.

## Rebirth (starting assumption)
- Requirement: 1,000,000 Cash and owning at least one Blue Chip company or better (placed or in storage). Not while carrying a company or with a Valuation Machine run going.
- Resets: Cash, placed and stored companies, plot and floor upgrades, upgrade station levels.
- Keeps: rebirth count, weapons, pets, rewards progress (streak, banked boost, free spins), the Index, game passes, cosmetics. Pets return to inventory and the player re-places them once floors are rebuilt.
- Reward: income multiplier = 1 + 0.5 x rebirth count, plus slightly better personal conveyor odds: every tier above Startup weighs 10% more per rebirth, up to double.
- Rebirth requirements scale up each time (x3 Cash per rebirth).

## Variants (starting assumption)
- Any company can turn up as a variant on either conveyor. A variant earns a multiple of the company's normal income, and the more it earns, the rarer it is: Shiny 1.5x (1 in 20), Pixel 2x (1 in 50), Molten 3x (1 in 120), Galaxy 5x (1 in 300), Rainbow 7x (1 in 600), Glitched 10x (1 in 1,500). Values live in `Config/Variants.luau`.
- A variant costs the same as a regular company: finding one is luck. It keeps its variant for good, through the Valuation Machine (which multiplies on top, separately) and stealing.
- Each variant has its own particles, and Molten has flames; labels show the variant's name in its colour. The Index has a Variants section showing the ones a player has owned.
- Galaxy and rarer variants on the shared conveyor are announced to the server. The Variant Chance upgrade makes variants more likely on the player's own conveyor only.

## Upgrade station (starting assumption)
- A station at one end of the street sells upgrades for Cash only, one level at a time, 10 levels each (`Config/Perks.luau`):
  - Walk Speed: +6% a level.
  - Damage: +10% a level.
  - Conveyor Luck: tiers above Startup on your own conveyor weigh +10% more a level, on top of rebirth luck.
  - Money Multiplier: +10% income a level.
  - Variant Chance: +15% a level on your own conveyor.
- Each level costs the base cost times the growth to the power of levels owned: Walk Speed 300 x1.8, Damage 500 x1.8, Conveyor Luck 1,000 x2, Money Multiplier 2,000 x2.1, Variant Chance 2,500 x2.1.
- Levels reset on rebirth (`ResetOnRebirth`), like base upgrades. Nothing at the station is sold for Robux or touches the Valuation Machine.

## Cash pads (starting assumption)
- A placed company's income doesn't go straight into Cash: it builds up on the cash pad in front of its plot, and the owner collects it by stepping on the pad. The amount waiting shows above each pad, and a "+Cash" pops up when it's collected.
- Only the base's owner can collect from its pads. The server checks where the owner is standing (`Config/Base.luau`: PadReach, PadHeight), and collects at least MinCollect (1 Cash) at a time.
- What's on the pads is saved, so leaving never loses it. It stays with the plot: picking up a company, or having it stolen, leaves its Cash on the pad for the owner. Rebirth empties the pads along with Cash.
- Offline earnings, rewards, codes and Cash packs still go straight into Cash.

## Teleports (starting assumption)
- Buttons at the top of the screen teleport to Home (your base), Upgrades (the upgrade station) and Weapons (the weapon shop, beside the pet shop).
- Not while carrying a company, which must still be carried home on foot, and at most once every 5 seconds (`Config/Travel.luau`).

## Offline earnings (starting assumption)
- Companies earn 25% of normal income while offline, capped at 4 hours.
- Shown in a "while you were away" popup on join.
- Counted from the income the player had when they left, without any 2x reward boost. Under a minute away earns nothing. Needs saving on (in Studio, API access).

## Monetisation (starting assumption, needs review)
- Game passes: 2x income, VIP (chat tag, cosmetic base trim), +1 pet slot per floor.
- Developer products: Cash packs, an extra base lock activation.
- Nothing purchasable may affect the Valuation Machine.
- No weapons, damage boosts or guard boosts for Robux at launch. Decide later how pay-to-win the game should feel.
- Built as (`Config/Monetisation.luau`, `Services/MonetisationService`, the Store button):
  - 2x Income doubles all income, offline earnings included. VIP gives a gold [VIP] tag in chat and gold trim on the owner's base. Extra Pet Slot opens each floor's second pet slot; if the pass is gone (say, refunded), a pet in that slot goes back to the player's pets.
  - Cash packs give 15 minutes, 1 hour or 4 hours of the player's income (without reward boosts), at least $5K, $25K or $100K, so they stay worth buying as income grows.
  - Lock Base Now locks the player's base from wherever they are for the usual 60 seconds, or adds 60 seconds to a lock already on. Base locks are otherwise free and renewable at the lock button, so this sells convenience, not protection players can't get.
  - Developer products are given exactly once per purchase: the purchase id is saved with what it gave before Roblox is told it's done (save version 12 keeps the last 100).
  - Prices are set on the Creator Dashboard, not in code. Each pass and product needs its id in `Config/Monetisation.luau`; until then it shows as not on sale.

## Onboarding (starting assumption)
- New player spawns at their base with enough Cash for one Startup.
- On-screen arrow guides them: buy from the personal conveyor, carry it home, place it, then collect its Cash from its pad.
- After placing the first company, prompt them to try the Valuation Machine on their second one.
- Then show them how to lock their base with its lock button.
- After 2 minutes, point them at the shared conveyor.
- Each step finishes when the save, the base or the player's position shows it's done, however they did it, and the step is saved. The machine step also finishes after 3 companies are placed without trying it, and the shared conveyor step finishes on its own after 90 seconds. Players can skip the guide. Players who joined before the guide existed don't see it.

## Server and leaderboards (starting assumption)
- 8 players per server, one base each. Set Max Players to 8 in the place's settings.
- The map (`studio/BuildMap.luau`): four bases on each side of an 80-stud street with the shared conveyor down the middle, all facing it, 44 studs apart so stealing takes a real trip. Base1 to Base4 are the middle four and fill first. The weapon and pet shops stand side by side at one end of the street and the upgrade station at the other, all facing back along it, and the leaderboards stand in the gaps beside the middle bases, facing the street. Grassy hills run all round the edge, with invisible walls so nobody can leave, and the shared conveyor runs from a tunnel in the hills at one end to a tunnel at the other.
- Each base (36 wide, 86 deep) runs back from the street: a front yard with the personal conveyor, the Valuation Machine, the lock button and the spawn, then a hall where a walkway runs down the middle of every floor with five plots either side facing it (they unlock in pairs from the front), pet slots at the back, and stairs zigzagging up behind the hall. Glass walls run down both sides and across the back from the ground to the top floor, so the way in is from the front, and nobody can steal through the glass (the server checks).
- Leaderboards: total Cash per second, rebirths, successful steals, knockouts.
- All-time, across every server, top 10 each. Cash per second is counted without any reward boost. Values are saved every 60 seconds and when a player leaves.

## Admin and debug tools (starting assumption)
- Server-checked admin commands for testing: give Cash, set rebirths, spawn a company of any tier on any conveyor, grant pets and weapons, skip playtime, reset own data.
- Debug panel (admins only) showing live economy values, active boosts and the current machine path.
- Build alongside slice 2 and extend with each slice, so every feature can be tested without grinding.

## Codes (starting assumption)
- Redeemable codes for Cash, boosts or pet spin tokens, used for social media and update announcements.
- Each code: reward, optional expiry date, one use per player. Stored in Config so a new code is a one-line change.
- The list is `src/server/Config/Codes.luau`, on the server only, so players can't read it. Expiry dates are the last day a code works, in UTC.

## Analytics (starting assumption)
- Use Roblox AnalyticsService so balance can be tuned from real data rather than guessed.
- Onboarding funnel: joined, bought first company, placed it, used the machine, first shared conveyor purchase, first steal.
- Economy events: Cash earned by source (income, rewards, codes, offline) and spent by sink (companies, upgrades, weapons, spins).
- Custom events: machine Take multiplier and how many players let it run out, steals attempted vs completed, rebirth timings.
- Built as: everything is reported by the server (`Services/AnalyticsService`, `server/Config/Analytics.luau`) and a failed report never affects play.
  - Funnel steps `Joined`, `BoughtCompany`, `PlacedCompany`, `UsedMachine`, `SharedPurchase`, `FirstSteal`, each once per player (saved). Players from before analytics count as past the funnel.
  - Cash sources `Income` (added up and sent every 5 minutes and on leaving, not every second), `Offline`, `Playtime`, `Daily`, `Index`, `Code`. Sinks `Company` (by tier), `Upgrade` (plot or floor), `Weapon` (by weapon), `PetSpin` (Cash spins only). Cash from admin commands isn't reported.
  - Custom events `MachineResult` (the multiplier; Taken, RanOut or Left; the tier), `StealStarted` (from a Plot or the Ground; the tier), `StealCompleted` (the tier) and `Rebirth` (minutes played since the last rebirth; the rebirth number).

## Map naming (to be built by hand in Studio)
- `Workspace.Map.Bases.Base1` to `Base8` (each a Model), each containing `Conveyor`, `Machine`, `LockButton`, `Spawn`, `Entrance` and `Floors`.
- Each base's `LockButton` is a part the owner uses to lock the base; the time left on a lock shows above it.
- Each base's `Machine` (the Valuation Machine) contains a part named `Pad`: companies being valued stand on it, and players use the machine there.
- Each base's `Conveyor` model holds the belt plus two parts named `Start` and `End`. Companies appear at `Start` and travel in a straight line to `End`, sitting on the bottom face of those parts, so place them on the belt surface. `Spawn` is a part the owner appears on.
- `Floors.Floor1` to `Floor4`, each containing `Plots` (Plot1 to Plot10), `CollectPads` (Pad1 to Pad10, the cash pad in front of each plot), `PetSlots` (Slot1, Slot2) and `Access` (stairs or lift pad). Locked plots are greyed out by code. Everything belonging to an upper floor is inside its folder (`Platform`, `Railings`, `Trim`, `Glass` and so on), because the game takes the whole folder out of the world until the floor is opened. Each upper floor's `TopOnly` model is only shown while it's the highest open floor.
- `Workspace.Map.SharedConveyor`: a Model with the belt plus `Start` and `End` parts, set up the same way as a base's `Conveyor`.
- `Workspace.Map.Shops.WeaponShop`, `Workspace.Map.Shops.PetShop` and `Workspace.Map.Shops.UpgradeStation`, each with a `ShopPrompt` part. Players open the shop and buy within a few studs of it. Teleports arrive in front of each one's pivot.
- Each base's `Glass` model holds the ground floor's glass walls, and each upper floor's `Glass` holds its own; stealing is refused if any glass is between the thief and the plot.
- `Workspace.Map.Leaderboards` with four parts, `IncomeBoard`, `RebirthsBoard`, `StealsBoard` and `KnockoutsBoard`. The game writes each list on the part's front face.
- Company models in `ReplicatedStorage.Assets.Companies`, named by companyId. A model named `Default` is used for any company without its own model yet.
- Weapon models in `ReplicatedStorage.Assets.Weapons`, pet models in `ReplicatedStorage.Assets.Pets`, named by id. Each weapon is a Tool with a `Handle` part; a Tool named `Default` is used for any weapon without its own yet. A pet model named `Default` is used for any pet without its own; its parts with a `RarityTint` attribute take the pet's rarity colour.

## Build order
Each slice ends when its checks pass in Studio with at least two test players (Studio's local server test).
1. **Project setup**: Rojo, Wally, ProfileStore, lint and format working. Check: an empty place syncs and runs with no errors.
2. **Data and admin tools**: Profile loads and saves Cash; basic admin commands work. Check: Cash survives leaving and rejoining, admin commands are refused for non-admins.
3. **Personal conveyor and buying**: Check: companies spawn at the right rates and odds, can be bought, Cash is deducted.
4. **Carrying and placing**: Check: carry speed applies, placing on a plot works, leaving mid-carry is handled.
5. **Income**: Check: placed companies pay out per second and the amount matches Config.
6. **Base upgrades and floors**: Check: plots unlock one at a time, next floor only unlocks when the current one is full, everything saves.
7. **Shared conveyor**: Check: exclusive tiers only appear here, and two players buying the same company at once results in exactly one owner.
8. **Valuation Machine**: Check: path matches on server and client, Take uses server time, multiplier never goes below 1.0x, never exceeds 45 seconds.
9. **Stealing and base lock**: Check: full steal works on every floor, owner tag returns the company, lock blocks entry, machine companies can't be stolen.
10. **Combat and weapon shop**: Check: damage only applies after server validation, hitting a carrier drops the company, dropped companies return correctly, no damage in own base.
11. **Pet shop and floor modifiers**: Check: spin odds match Config over 10,000 test rolls, pets modify only their floor, guard pets increase hold time, pets survive rebirth.
12. **Rebirth**: Check: correct resets and keeps, multiplier applies.
13. **Playtime and daily rewards, and the Index**: Check: milestones unlock at the right times using server time, rejoining keeps progress, daily reset happens at 00:00 UTC, streak resets after a missed day, boosts extend rather than stack, owning a new company adds it to the Index, Index prizes unlock at the right counts and can only be claimed once.
14. **Offline earnings, onboarding, leaderboards, codes**: Check: rejoining after time away pays 25% of income for that time (up to 4 hours) and shows the popup, a new player is guided from first purchase to locking their base and the shared conveyor, leaderboards fill in and update, each code works once per player and not after it expires.
15. **Analytics**: Check: funnel and economy events appear in the Creator Dashboard from a test session.
16. **Monetisation**: Check: each pass's perk turns on when it's bought in game and when an owner joins, each product is given once per purchase (also after a rejoin), and nothing for sale touches the Valuation Machine.

After the build order: variants, the upgrade station, teleports, glass walls and the stations at the street ends. Check: variants turn up at about their odds (`/testvariants`) and earn their multiple, each upgrade's effect applies and resets on rebirth, teleports refuse while carrying, and nobody can steal through the glass.

Then cash pads and floors that appear as they're opened. Check: income only reaches Cash from the pads, only the owner can collect, the pads keep their Cash through a rejoin, a new base is just the ground floor, each floor appears when it's opened (and goes on rebirth), and the guide teaches collecting.

Slices 1 to 9 are a playable core (buy, carry, place, earn, upgrade, machine, steal). Consider publishing that to a small audience for feedback before building the rest.
