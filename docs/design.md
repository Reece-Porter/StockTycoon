# Stock Tycoon: game design

Decisions marked "Decided" come from Reece and should not be changed without asking. Everything marked "Starting assumption" is a first guess for balance and should live in `src/shared/Config` so it can be tuned.

## Decided
- Stealing is in, Steal a Brainrot style.
- Rebirth is in.
- Each base has a Stock Spinner (a roll machine) instead of its own conveyor: it rolls 3 different companies at a time, they come out onto the base's belt and stop, and only the owner can buy them until the next roll replaces them. The shared conveyor in the middle of the map stays, with better rarity odds and two tiers that only appear there.
- The spinner's rarer tiers get more likely with every rebirth, so rebirthing is the way up to better companies.
- Stealing from bases only happens during a Hostile Takeover, an event once an hour, so players don't have to guard their base all the time.
- The Valuation Machine can never reduce a company below base income.
- Bases are upgraded to unlock more plots, then new floors with more plots.
- A weapon shop in the middle of the map sells weapons that damage other players, mainly for fighting over the shared conveyor.
- A pet shop next to the weapon shop sells pet spins. Pets are placed on a floor and give that floor a modifier.
- Playtime rewards at 5, 10, 15, 30, 60, 90 and 120 minutes, plus a daily login bonus.

## Tiers (starting assumption)
Price, base income per second, and where it spawns.
- **Startup**: 50 Cash, 2/s. Spinner and shared.
- **Scale-up**: 500 Cash, 15/s. Spinner and shared.
- **Unicorn**: 5,000 Cash, 120/s. Spinner and shared.
- **Blue Chip**: 50,000 Cash, 900/s. Spinner and shared.
- **Conglomerate**: 500,000 Cash, 7,000/s. Shared only.
- **Monopoly**: 5,000,000 Cash, 50,000/s. Shared only.

Each tier has several parody companies (aim for 4 to 6 per tier at launch). Companies within a tier can vary their price and income by up to plus or minus 20%.

## Spawn weights (starting assumption)
- **Stock Spinner**: Startup 70, Scale-up 22, Unicorn 7, Blue Chip 1.
- **Shared conveyor**: Startup 55, Scale-up 28, Unicorn 12, Blue Chip 4, Conglomerate 0.9, Monopoly 0.1.
- Spinner weights scale with rebirth count (`Config/Rebirth.luau`): the growth is 1 + 0.25 x rebirths (counted up to 20), and each tier after Startup weighs that growth to the power of its place after Startup, so the rarer the tier, the more it gains. Scale-up x1.25, Unicorn x1.56 and Blue Chip x1.95 after one rebirth; x2, x4 and x8 after four. As odds:
  - 0 rebirths: Startup 70%, Scale-up 22%, Unicorn 7%, Blue Chip 1%
  - 1: 63.4%, 24.9%, 9.9%, 1.8%
  - 2: 57.3%, 27.0%, 12.9%, 2.8%
  - 3: 51.7%, 28.5%, 15.8%, 4.0%
  - 5: 42.1%, 29.8%, 21.3%, 6.8%
  - 10: 25.4%, 27.9%, 31.1%, 15.6%
  - 20 or more: 10.4%, 19.7%, 37.6%, 32.2%
- The shared conveyor's odds are the same for everyone.

## Stock Spinner (starting assumption)
- A board over each base's belt with three reels (`Config/Spinner.luau`, `Services/SpinnerService`, `SpinnerController`). Every 20 seconds while the base has an owner it rolls 3 different companies with the owner's odds (above, plus Spinner Luck) and their Variant Chance. Rolling is free and automatic; buying a company costs its usual price.
- The reels spin for 3 seconds, slowing to a stop one after another on what was rolled. Then the roll lands: whatever the last roll brought that's still on the belt disappears, and the new companies come out of the hatch one after another (0.7 seconds apart, at 10 studs a second) and stop along the belt, each under its reel (84%, 52% and 20% of the way along). They wait there, and only the owner can buy them, until the next roll lands 20 seconds later. About 9 companies a minute, as the old conveyor gave.
- The server picks every roll (when it starts) and puts the companies on the belt; the reels only show it. Under the reels a timer says ROLLING! while they spin, then the time to the next roll with a bar running down. Gold bulbs along the board chase while it spins. The owner gets a pop over a reel that lands a Blue Chip or a variant.
- Conglomerate and Monopoly never come out of the spinner. Nothing about it is sold for Robux.

## Shared conveyor (starting assumption)
- Spawns one company every 8.8 seconds. (Shared went from 2 to 4, then 30% fewer when its belt was made 4 times longer, then 35% fewer again for more space between companies, at the same speed.)
- Companies move at 2.4 studs per second (about 2 minutes 10 seconds along its 316 studs, which run the length of the map). They despawn at the End if unbought.
- Buying uses a ProximityPrompt on the company.
- Shared conveyor tier announcements: Conglomerate and Monopoly spawns trigger a server-wide message.

## Carrying (starting assumption)
- One company carried at a time.
- Walk speed while carrying: 75% of normal.
- If the carrier leaves the game or resets, a bought company returns to their base storage; a stolen company returns to its original owner's plot.
- A dropped company returns to its rightful place after 10 seconds.

## Base, plots and floors (starting assumption)
- Each player gets a base with a Stock Spinner over a short belt, the Valuation Machine, floors of plots and a lock button on every floor.
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
- Stealing from bases only happens during a **Hostile Takeover** (`Services/TakeoverService`, `Config/Steal.luau`): for 5 minutes at the start of every hour (UTC), in every server at once. Everyone is told 5 minutes and 1 minute before, when it starts (with a red banner) and when it's over. A chip above the Cash pill counts down to the next one (gold in the last 5 minutes) and shows the time left during one. Outside a takeover the Steal prompts don't show and the server refuses any steal.
- A thief who picked a company up during a takeover can still carry it home after it ends (the owner can still tag them).
- Knocking a company out of someone's hands with a weapon and grabbing it (see Combat) works at any time: that's the fight over the shared conveyor, not base defence.
- During a takeover, any player can walk into another player's base and pick up a placed company via ProximityPrompt (hold 1.5 seconds).
- The thief must carry it back to their own base and place it to complete the steal.
- If the owner touches the thief while they're carrying the stolen company, it returns to the owner's plot.
- Weapons can also be used to knock a carried company out of a thief's hands (see Combat).
- Base lock: the owner presses a button at their base to block entry for 60 seconds. When it ends, they must press it again. Show the remaining lock time on the base. It works at any time, but only matters during a takeover.
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
- Reward: income multiplier = 1 + 0.5 x rebirth count, plus better Stock Spinner odds (see "Spawn weights"). The Rebirth window shows the spinner's odds now and after the next rebirth.
- Rebirth requirements scale up each time (x3 Cash per rebirth).

## Variants (starting assumption)
- Any company can turn up as a variant, in the Stock Spinner or on the shared conveyor. A variant earns a multiple of the company's normal income, and the more it earns, the rarer it is: Shiny 1.5x (1 in 20), Pixel 2x (1 in 50), Molten 3x (1 in 120), Galaxy 5x (1 in 300), Rainbow 7x (1 in 600), Glitched 10x (1 in 1,500). Values live in `Config/Variants.luau`.
- A variant costs the same as a regular company: finding one is luck. It keeps its variant for good, through the Valuation Machine (which multiplies on top, separately) and stealing.
- Each variant has its own look, laid over any company's model by one shared function (`src/shared/VariantLayer.luau`, settings in `Config/Variants.luau`) without changing the stored model. The plinth keeps its tier colour; the pun object changes, and the floating badge gets a ring in the variant's colour:
  - Shiny: brighter, slightly reflective colours and a few slow white twinkles.
  - Pixel: a small retro palette, round pieces made blocky, small square particles.
  - Molten: dark rock with glowing orange Neon seams and a few rising embers.
  - Galaxy: deep purple with a faint pink and blue nebula tint and twinkling stars.
  - Rainbow: its small accent pieces turn smoothly round the colour wheel (on each player's device).
  - Glitched: a slight red and cyan split, and now and then a flicker with a red and cyan ghost copy for a moment (on each player's device), with small square noise particles.
- Variants add no lights, at most 10 particles a second, stay within a model's 30 parts (ghosts included), and their particles and motion stop beyond 60 studs. Labels show the variant's name in its colour; Storage cards show a variant company in its look. The Index has a Variants section showing the ones a player has owned, each on a sample company.
- Galaxy and rarer variants on the shared conveyor are announced to the server. The Variant Chance upgrade makes variants more likely in the player's own Stock Spinner only.

## Upgrade station (starting assumption)
- A station at one end of the street sells upgrades for Cash only, one level at a time, 10 levels each (`Config/Perks.luau`):
  - Walk Speed: +6% a level.
  - Damage: +10% a level.
  - Spinner Luck (saved as `ConveyorLuck` from before the spinner): tiers above Startup in your Stock Spinner weigh +10% more a level, on top of rebirth luck.
  - Money Multiplier: +10% income a level.
  - Variant Chance: +15% a level in your Stock Spinner.
- Each level costs the base cost times the growth to the power of levels owned: Walk Speed 300 x1.8, Damage 500 x1.8, Spinner Luck 1,000 x2, Money Multiplier 2,000 x2.1, Variant Chance 2,500 x2.1.
- Levels reset on rebirth (`ResetOnRebirth`), like base upgrades. Nothing at the station is sold for Robux or touches the Valuation Machine.

## Cash pads (starting assumption)
- A placed company's income doesn't go straight into Cash: it builds up on the cash pad in front of its plot, and the owner collects it by stepping on the pad. The amount waiting shows above each pad, and a "+Cash" pops up when it's collected.
- Only the base's owner can collect from its pads. The server checks where the owner is standing (`Config/Base.luau`: PadReach, PadHeight), and collects at least MinCollect (1 Cash) at a time.
- What's on the pads is saved, so leaving never loses it. It stays with the plot: picking up a company, or having it stolen, leaves its Cash on the pad for the owner. Rebirth empties the pads along with Cash.
- Offline earnings, rewards, codes and Cash packs still go straight into Cash.

## Screen layout
- Built from the UI kit in `src/client/Ui` (`docs/visual-pass.md`), every colour and font from `src/shared/Theme.luau`. Designed for a small phone first, and scaled up a little on bigger screens.
- Top middle: the teleport buttons, then the new-player guide.
- Bottom left: Cash with income per second underneath, a boost chip above it while a boost runs, and the Hostile Takeover chip above that. It only shows things, so the phone thumbstick still works under it.
- Left: the menu (Storage, Upgrades, Weapons, Pets, Index, Rebirth), two across in three rows: at the top left in landscape and below the top in portrait, so it stays clear of the thumbstick. A red dot marks something waiting (an affordable base upgrade, a reward or prize to claim, a rebirth ready).
- Right: Rewards, Store and Codes, clear of the jump button.
- Notifications slide in below the top middle, between the side menus. Only one window is open at a time.
- The Upgrades window has two tabs: Base (the next plot or floor, bought anywhere) and Station (the upgrade station's upgrades, bought at the station, with a teleport there when away).

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
- On-screen arrow guides them: buy a company their Stock Spinner rolled onto their belt, carry it home, place it, then collect its Cash from its pad.
- After placing the first company, prompt them to try the Valuation Machine on their second one.
- Then show them how to lock their base with the lock button on their ground floor.
- After 2 minutes, point them at the shared conveyor.
- Each step finishes when the save, the base or the player's position shows it's done, however they did it, and the step is saved. The machine step also finishes after 3 companies are placed without trying it, and the shared conveyor step finishes on its own after 90 seconds. Players can skip the guide. Players who joined before the guide existed don't see it.

## Server and leaderboards (starting assumption)
- 8 players per server, one base each. Set Max Players to 8 in the place's settings.
- The map (`studio/BuildMap.luau`): four bases on each side of an 80-stud street with the shared conveyor down the middle, all facing it, 44 studs apart so stealing takes a real trip. Base1 to Base4 are the middle four and fill first. The weapon and pet shops stand side by side at one end of the street and the upgrade station at the other, all facing back along it, and the leaderboards stand in the gaps beside the middle bases, facing the street. Grassy hills run all round the edge, with invisible walls so nobody can leave, and the shared conveyor runs from a tunnel in the hills at one end to a tunnel at the other.
- BuildMap stamps the map with its build (the `MapVersion` attribute on `Workspace.Map`). When it doesn't match `Config/Base.MapVersion`, the server warns in the Output and admins get a notice and a debug panel row saying to run BuildMap again. Bump both together whenever BuildMap changes what it builds.
- Each base (42 wide, 96 deep) runs back from the street: a front yard with the Stock Spinner over its belt, the Valuation Machine and the spawn, then a hall where a walkway runs down the middle of every floor with five plots either side facing it (they unlock in pairs from the front), a lock button in the middle of the walkway, pet slots at the back, and stairs zigzagging up behind the hall. Glass walls run down both sides and across the back from the ground to the top floor, so the way in is from the front, and nobody can steal through the glass (the server checks).
- Every floor has its own lock button; the owner can lock the base from any open floor's button. A floor that isn't open yet isn't in the world, so its button can't be used.
- How a base looks (visual pass Phase 5), in its own accent colour from `Theme.Base` (stored on the base as an `Accent` attribute):
  - Floors with grout lines making large tiles, and a two-tone front edge on each upper floor.
  - A carpet down the walkway with white edging and a row of diamonds.
  - Plots as display stands: a white top on a darker lip, with a soft glow in the accent colour once open; locked plots (and their cash pads) are dull stone with a padlock over them.
  - Pet slots as cushioned beds on short pedestals.
  - Stairs with pale treads, and glass rails with rounded handrails on posts; landings with trim.
  - Glass walls framed in the accent colour.
  - Accent trim round the edge, gold for a VIP with a slow shine running along it.
  - A headquarters sign over the way in with the owner's display name.
  - While the base is locked, a shimmering force field across the way in with a padlock and the time left (and a new player's protection time, without the field). It stops nobody: the server moves people out. Nothing floats over the lock buttons.
  - The Valuation Machine, facing the walkway: a round stage under a glass tube where the company stands, between two pillars with gauges and chasing lights, under an arch with the machine's name and a ticker of parody companies sliding past, topped by a big screen with a little moving line chart (made-up numbers) and a beacon. While the owner's run is going, a scanner sweeps up and down the tube, the gauges swing, the lights chase faster and the beacon flashes.
  - The base's belt: side rails, a roller at the end, chevrons running along it while the spinner's companies come out, and a hatch over the start that swings open when a company comes out.
  - The Stock Spinner over the belt: a dark board on posts either side of the belt, framed in the accent colour, with a "STOCK SPINNER" header, a reel screen over each place a company stops (readable from the yard and the street), a timer strip under them and a row of gold bulbs. Everything on it is drawn by the client.
  - The lock buttons: a round red button on a podium in the middle of each floor's walkway, labelled LOCK with a padlock on every side, which stays pressed down (and says LOCKED) while the base is locked.
  - A planter with a little tree in the front yard.
  - The spawn: a round pad with a glowing ring in the accent colour and a soft glow rising from it.
- Everything only for looks never collides, gets touched or blocks a raycast (shots, the glass check), and stays inside the base's floor and below its top railings, so where the game thinks a base is doesn't change. The game's own parts keep their names, places and sizes; the spawn, lock button, machine pad and pet slots became invisible pads with the look built round them. Everything that moves runs on each player's device, only near the camera.
- How the middle street looks (visual pass Phase 6), colours from `Theme.Street`:
  - The shared conveyor: a red carpet between gold rails, with roller ends and a row of small lights along each rail. Chevrons run along the carpet and the lights chase, near the camera.
  - A stock-exchange gateway at each tunnel: marble columns, a frieze with the game's name and a pediment with a gold medallion.
  - The street: a road lane each side of the conveyor with a dashed line, zebra crossings in front of each row of bases, kerbs, street lamps (glowing bulbs, no lights), benches and planters in the gaps between bases, ticker posts by the crossings, little chart screens on stands, and a gold bull across from the upgrade station.
  - Storefronts: a striped awning, a sign with the shop's name and an emblem (a gavel, a paw, an arrow), a counter with the till (`ShopPrompt`), goods on display (the five real weapons on a pegboard, hung by the server on invisible `WeaponHook` parts; pet eggs on shelves and two real pets on the counter, stood by the server on invisible `PlushSeat` parts; glowing arrows and a level meter), and a shopkeeper behind the counter who breathes, looks around, blinks and waves now and then.
  - Leaderboards styled as stock-exchange boards: a coloured header with the title, ranked rows on alternating stripes with the top three in gold, silver and bronze, and a frame with a ticker strip and a soft glow behind.
- The world round the bases (visual pass Phase 8, `Workspace.Map.Scenery`, colours in `Theme.Scenery`):
  - Patches of grass a little lighter and darker than the ground.
  - In each gap between bases: a winding path of stepping stones from the street to the back, round cartoon trees either side and two flower patches. More trees and flowers between the last bases and the ends of the map, and bushes along the strip behind the bases.
  - A wooden fence along the edge of the play area, in front of the hills, either side of the street at the ends.
  - Pines up the hills, stood on the hills' grass (never their rock) and clear of the tunnels.
  - Far behind the hills (`Workspace.Map.Skyline`), a low-detail city in pale blue-greys that sits back in the haze and peeks over the hills: plain towers turned to face the map, a few with an antenna, and a billboard on one tower along each side with a parody company's name (from `Config/Companies`) and a slogan. Original designs only.
  - All of it is only for looks: anchored, never collides, gets touched or blocks a raycast, nothing on the street or a base, and nothing but the trees near the bases casts a shadow. About 900 parts for the scenery and 140 for the city.
- Leaderboards: total Cash per second, rebirths, successful steals, knockouts.
- All-time, across every server, top 10 each. Cash per second is counted without any reward boost. Values are saved every 60 seconds and when a player leaves.

## Admin and debug tools (starting assumption)
- Server-checked admin commands for testing: give Cash, set rebirths, spawn a company of any tier (`/spawn <tier>` rolls your Stock Spinner with that tier first; `/spawn <tier> shared` puts one on the shared conveyor), roll your spinner now (`/roll`), start or stop a Hostile Takeover (`/takeover start [minutes]`, `/takeover stop`, `/takeover` for when the next one is), grant pets and weapons, skip playtime, reset own data.
- Debug panel (admins only) showing live economy values, active boosts and the current machine path.
- A photo booth for store and marketing screenshots (visual pass Phase 10; `docs/ART_BRIEFS.md`): `Workspace.Map.PhotoBooth`, built by BuildMap far out past the city. Admins pose companies, pets and a copy of their base there with `/booth`, `/pose`, `/backdrop` and `/boothcam` (`Lib/PhotoBooth`, `PhotoBoothController`). Posed things are still copies in its Posed folder that nothing in the game looks at.
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
- `Workspace.Map.Bases.Base1` to `Base8` (each a Model), each containing `Conveyor`, `Spinner`, `Machine`, `Spawn`, `Gate` and `Floors`.
- Each floor's `LockButton` (`Floors.Floor<n>.LockButton`) is a part the owner uses to lock the base; the time left on a lock shows on the force field at the way in (`Gate.Field`). A map built before the buttons moved onto the floors has one `LockButton` on the base itself, which still works.
- Each base's `Machine` (the Valuation Machine) contains a part named `Pad`: companies being valued stand on it, and players use the machine there.
- Each base's `Conveyor` model holds the belt plus two parts named `Start` and `End`. The Stock Spinner's companies come out at `Start` and stop along the line to `End` (at `Config/Spinner.Stops`), sitting on the bottom face of those parts, so place them on the belt surface. `Spawn` is a part the owner appears on.
- Each base's `Spinner` model holds `Reel1` to `Reel3` (a screen over each place a company stops), `Timer`, `Header`, `Board`, `Post` and `Bulb` parts, all only for looks. The game works without it (the reels just aren't shown).
- `Floors.Floor1` to `Floor4`, each containing `Plots` (Plot1 to Plot10), `CollectPads` (Pad1 to Pad10, the cash pad in front of each plot), `PetSlots` (Slot1, Slot2), `LockButton` and `Access` (stairs or lift pad). Locked plots are greyed out by code. Everything belonging to an upper floor is inside its folder (`Platform`, `Railings`, `Trim`, `Glass` and so on), because the game takes the whole folder out of the world until the floor is opened. Each upper floor's `TopOnly` model is only shown while it's the highest open floor.
- `Workspace.Map.SharedConveyor`: a Model with the belt plus `Start` and `End` parts, set up the same way as a base's `Conveyor`.
- `Workspace.Map.Shops.WeaponShop`, `Workspace.Map.Shops.PetShop` and `Workspace.Map.Shops.UpgradeStation`, each with a `ShopPrompt` part. Players open the shop and buy within a few studs of it. Teleports arrive in front of each one's pivot.
- Each base's `Glass` model holds the ground floor's glass walls, and each upper floor's `Glass` holds its own; stealing is refused if any glass is between the thief and the plot.
- `Workspace.Map.Leaderboards` with four parts, `IncomeBoard`, `RebirthsBoard`, `StealsBoard` and `KnockoutsBoard`. The game writes each list on the part's front face.
- Company models in `ReplicatedStorage.Assets.Companies`, named by companyId. The server builds one for every company when it starts, from its look in `src/shared/Config/CompanyLooks.luau` (see "Company models" below). A model built by hand in Studio and named by companyId is used instead and left alone. A model named `Default` is only used if a company somehow has neither.
- Pet models in `ReplicatedStorage.Assets.Pets` and weapon Tools in `ReplicatedStorage.Assets.Weapons`, named by id. The server builds them all when it starts (see "Pet and weapon models" below). A pet model made by hand and named by its id is used instead and left alone. A weapon Tool made by hand is only kept if it has a `HandMade` attribute set to true, because earlier map scripts left plainer Tools there that should be replaced; each weapon is a Tool with a `Handle` part. The `Default` pet and Tool are only used if something somehow has neither; the Default pet's parts with a `RarityTint` attribute take the pet's rarity colour.

## Company models
Every company model has the same structure, built by one shared builder (`src/server/Lib/CompanyBuilder.luau`) from config:
- A round plinth in the tier's colour, grander each tier up: Startup plain and smallest; Scale-up adds a light trim ring; Unicorn adds a base step; Blue Chip swaps the trim for gold edging; Conglomerate adds a gentle Neon glow ring with the model's one light; Monopoly is the biggest, with a few slow sparkles, and its object slowly spins and bobs.
- The pun object on top, made of simple shapes (blocks, balls, cylinders, wedges and stretched balls), each company's own design, colours and parts in `Config/CompanyLooks`.
- A floating logo badge above the object: the company's letters in a ringed circle in its own colours, always facing the camera. Original designs only.
- A nameplate on the plinth's front with the company's name.

Budget for phones: at most 30 parts per model; everything anchored with no collisions, touches or raycast hits; small, see-through and Neon pieces cast no shadow; at most one light, and only on Conglomerate and Monopoly; text kept low resolution and hidden beyond 40 studs, the badge beyond 60. The sparkles and Monopoly motion run on each player's device and stop beyond 60 studs from the camera. Adding a company means an entry in `Config/Companies` and one in `Config/CompanyLooks` (without a look it gets a plain box on its plinth).

## Pet and weapon models
Built when the server starts, the same way as company models, by `src/server/Lib/PetBuilder.luau` and `WeaponBuilder.luau` from `src/shared/Config/PetLooks.luau` and `WeaponLooks.luau` (simple shapes from `src/shared/Pieces.luau`).
- Pets: chunky chibi proportions and big glossy eyes, each recognisable from its name (a paperclip pup, a coffee cat in a cup, a vault tortoise with a dial on its shell). Rarity aura: none for Common, then a Neon glow disc under the pet that gets stronger each rarity up, sparkles from Rare (more each rarity), and a soft light on Legendary and Mythic only. Pets sit on floor slots, so near the camera they bob and sway gently on the spot (`PetFxController`), and their sparkles stop beyond 60 studs. The pet cards in the pet shop and Pets window show the model.
- Pet reveal after a spin (`src/client/Ui/PetReveal.luau`): the egg shakes (longer each rarity up, 0.7 seconds for Common to 2.2 for Mythic) and cracks, bursts in the rarity colour (bigger each rarity up, with confetti for Legendary and Mythic), and the pet pops out with its name, rarity badge and what it does. A tap anywhere skips to the pet. The server has already rolled the pet; the reveal only shows it.
- Weapons: a rolled-up newspaper, a briefcase with gold clasps, a blown-up stapler, a judge's gavel and a golden calculator, held at the Tool's `Handle`. Each has a swing from the default character animations (`Swing` attribute: Slash or Lunge), plus a whoosh in the weapon's colour, or a recoil and a puff at the nozzle for the Stapler Gun.
- Combat effects (`CombatFxController`), looks only, the server still decides every hit: when the server flashes a hit target, a white puff with a cartoon word (BONK!, POW!, WHAM!, BOP!, THWACK!) and bursting stars over their head, and a small screen shake for the attacker only; stars circling the head while a character is stunned or knocked out; a dust puff where a knocked-back character lands. Cartoon only, no blood.
- Budget for phones: at most 25 parts per pet and 12 per weapon (the Handle included); everything anchored (weapons welded to the Handle, massless) with no collisions, touches or raycast hits; small pieces cast no shadow; at most one light per pet, Legendary and Mythic only. Adding a pet or weapon means an entry in `Config/Pets` or `Config/Weapons` and one in `PetLooks` or `WeaponLooks` (without one, a pet is a plain round critter in its rarity colour and a weapon a plain stick). A new weapon also needs a `WeaponHook` added in BuildMap to be shown in the shop.

## Feedback effects
Short effects for the moments that matter (visual pass Phase 9), on each player's own screen, never over the HUD. Looks only: the server has already done each thing.
- Carrying a company: the carrier holds it up over their head with both arms, and it glows softly in its tier's colour (`CarryFxController`, from the `CarriedCompany` model and the carrier's `CarryingCompanyId`).
- A dropped company bounces as it lands and has a ring of glowing dots on the ground round it in its tier's colour, going out one by one as its return countdown runs down, under the label with the seconds left (`DropController`).
- Pops in the world over the player (`FeedbackFxController`, `Ui/WorldPop`):
  - "SOLD!" with cash flying out when anyone buys a company;
  - "YOINK!" when anyone starts carrying off someone else's company;
  - "TAGGED!" when a thief is caught;
  - "REBIRTH!" over anyone else who rebirths.

  The server says when someone bought or was tagged with two counters on the player, `BoughtCount` and `TaggedCount`, only for these pops.
- Income: now and then a small "+$12" over a plot near the camera as its cash pad fills. Each plot pops at most every 8 seconds and only one pop is shown at a time, so a full base never spams.
- Rebirth: on the player's own screen a burst of light, confetti and a big banner ("REBIRTH!", the rebirth number and the new income multiplier) for three seconds, under the menus and notifications and never taking a tap (`Ui/Celebration`).

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

Then the Stock Spinner in place of each base's conveyor, stronger rebirth odds, and Hostile Takeovers (map version 7). Check: each base's spinner rolls 3 different companies every 20 seconds, they come out and stop under their reels, only the owner can buy them, the next roll replaces what's left, the Rebirth window's odds match `/testodds` after a rebirth, Steal prompts only show during a takeover (`/takeover start 2`), the server refuses a steal outside one, and a thief can still finish a steal picked up just before it ended.

Slices 1 to 9 are a playable core (buy, carry, place, earn, upgrade, machine, steal). Consider publishing that to a small audience for feedback before building the rest.
