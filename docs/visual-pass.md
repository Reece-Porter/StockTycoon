# Stock Tycoon: professional visual pass

You are doing a full visual upgrade of Stock Tycoon, a Roblox tycoon game in the style of Steal a Brainrot. The gameplay works. The problem is that everything looks home-made: plain parts, default lighting, dark text-only UI. The goal is for it to look and feel like a polished front-page Roblox game: bright, cartoony, colourful and fun, but clean and readable rather than an eyesore. Mobile is the main platform.

Do not change gameplay logic, balancing numbers, RemoteEvents, or DataStore keys and save formats. This is a presentation pass only. If a visual change genuinely needs a logic change, stop and ask.


## How to work

- **Read first:** before changing anything, read the existing code and project structure. Work out how models, the map and UI are currently built (scripts, Studio instances, Rojo, config modules), where the company, pet and weapon definitions live, and how models are attached to them.
- **Phase 0 audit:** report back with a short audit (how things are built now, what you will reuse, what you will replace) and a plan for Phase 1. Then stop and wait for my approval.
- **Check in before structural decisions:** for example moving folders, changing how models are stored or cloned, enabling StreamingEnabled, adding a framework or library, or replacing a whole system. Ask first.
- **One phase at a time:** finish a phase, summarise what changed and what to look at in Studio, update ASSETS_NEEDED.md, then stop for review.
- **Build in code where possible:** shared builder functions and a central Theme module, not hand-placed one-offs, so the style stays consistent across 30 companies, 12 pets and 8 bases.


## Hard rules (apply to everything)

- **Parody only:** every company design is based on the pun in its parody name, never on the real company. No real logos, logo shapes, wordmarks, mascots, fonts, product silhouettes or brand colour schemes. If a design would make someone think of the real logo, change it.
- **Cartoon combat only:** knockback, stars, puffs and ragdoll. No blood, no realistic weapons.
- **Banned words:** never use bet, wager, gamble, crash, jackpot or casino anywhere: UI text, signs, tickers, names, tooltips, comments visible to players, or asset names. Grep for them at the end of every phase.
- **No invented asset IDs:** never make up an rbxassetid number. Only use built-in rbxasset:// content you can confirm exists in the Studio content folder. Where a real image, mesh, sound or skybox is needed, build the best version you can from parts, materials, UI shapes and built-in effects, mark it as a placeholder, and add an entry to ASSETS_NEEDED.md with exact specs (purpose, size, style, transparent background or not).
- **Mobile performance budget:**
  - Company models: 30 parts or fewer. Pets: 25 or fewer. Weapons: 12 or fewer.
  - All decorative parts Anchored (or welded), with CanCollide, CanTouch and CanQuery off, and CastShadow off on small pieces.
  - Particles: keep Rate low (around 10 per second or less per emitter), short Lifetime, and turn emitters off client-side beyond roughly 60 studs.
  - Lights: at most one PointLight per model, and only on Conglomerate and Monopoly tiers or Legendary and Mythic rarities.
  - Highlight instances: use sparingly, as the engine only renders a limited number at once. Do not use one per company or per variant.
  - All spinning, bobbing, belt movement and pulsing runs on the client (TweenService or RenderStepped), never in server loops.
  - SurfaceGuis: low PixelsPerStud, only where needed.
- **Readability:** everything must read clearly from above and at a distance on a small phone screen. Silhouette and colour first, detail second.


## Art direction

- **References:** Steal a Brainrot (layout, conveyor and base feel), Pet Simulator 99 and Grow a Garden (UI clarity, chunky buttons, rarity presentation), Adopt Me (friendly, rounded, soft look). Match their level of polish, not their exact look.
- **Shapes:** chunky, rounded, slightly exaggerated proportions. Use wedges, cylinders, balls and corner wedges to avoid plain boxes. Bevels and trim on everything that is currently a flat slab.
- **Colour:** bright but controlled. One strong accent per object or window, the rest neutral. No more than three saturated colours on any single model or screen.
- **Materials:** SmoothPlastic as the base, Neon only for small glowing accents, Glass for windows, Fabric for carpet, Wood and Brick only where they add something. Avoid default grey everywhere.
- **Lighting:** sunny early afternoon, warm and slightly saturated. Fixed time of day for now (a day/night cycle hurts readability; propose it separately if you think it is worth it).


## Phase 1: Theme module, lighting and UI kit

This has the biggest effect on how professional the game feels, so it comes first.

- **Theme module:** one ModuleScript holding every colour, font, corner radius, stroke width, tween timing and the tier, rarity and variant colours. Nothing else hard-codes colours.
- **Palette (starting point, adjust if needed):**
  - Outline ink #1B1B2F, panel body #F4F6FB, card #FFFFFF, card border #D5DAE8, dark text #1B1B2F
  - Cash green #3CCB5A, gold #FFC83D, primary blue #3D8BFF, purple #A66CFF, danger red #FF4D5E
  - Tiers: Startup #7ED957, Scale-up #3D8BFF, Unicorn #A66CFF, Blue Chip #2FD3E0, Conglomerate #FFC83D, Monopoly #FF4D5E
  - Pet rarities: Common #B8C0CC, Uncommon #7ED957, Rare #3D8BFF, Epic #A66CFF, Legendary #FFB020, Mythic #FF3D6E
- **Fonts:** two only. A rounded display font (FredokaOne or LuckiestGuy) for titles, big numbers and buttons; Builder Sans Bold or GothamBold for body text.
- **Lighting:** Atmosphere (light haze, slightly blue horizon), Bloom kept subtle with a high threshold so only Neon glows, ColorCorrection with a small saturation and contrast lift, gentle SunRays, warm ambient. Interim sky until a custom skybox exists (log the skybox in ASSETS_NEEDED.md).
- **UI component kit:** reusable builders for:
  - Button: rounded corners, thick dark UIStroke, vertical UIGradient (lighter top), a darker offset shadow frame underneath, white text with a dark text stroke, optional icon left of the label. Press tween scales to about 0.92 and back; hover grows slightly on PC.
  - Window: centred panel with a coloured header bar, title, red round close button top-right, light body, optional tabs. Opens with a quick scale-and-fade tween (Back easing, around 0.2 seconds) and dims the background.
  - Card: for items in grids. White card, border in the tier, rarity or variant colour, model viewport or icon, name, key stat, and a badge.
  - Badges: small pills for tier, rarity and variant, using Theme colours and a short label.
  - Notification toast: slides in from the top, coloured left edge by type, auto-dismisses, never stacks more than three.
  - Number formatting: 1.2K, 3.4M, 5.6B, 7.8T and onwards, with a short count-up tween when Cash changes.
- **Icons:** until real icon images exist, build simple icons from UI shapes. Emoji are allowed only as labelled placeholders. List every icon needed in ASSETS_NEEDED.md.


## Phase 2: UI rebuild (mobile first)

Rebuild every existing screen with the Phase 1 kit. Keep the same functions and remotes.

- **Layout:** scale-based sizing with UIAspectRatioConstraint and UIScale, respecting the top-bar inset. Keep the bottom-left (thumbstick) and bottom-right (jump) thumb zones completely clear. Touch targets must be comfortably finger-sized. Minimum readable text size on a small phone.
- **HUD:** Cash in a pill at top-centre with a cash icon and big number, income per second underneath in smaller green text, boost timer as a small chip beside it with a ring or bar rather than plain text.
- **Left menu rail:** vertical stack of square icon buttons (Storage, Upgrades, Weapons, Pets, Index, Rebirth, Rewards), each with its own colour, icon above a short label, and a red dot badge when something new is available.
- **Right side:** Store button in gold with a slow shine sweep, and Codes below it.
- **Teleport buttons (Home, Upgrades, Weapons):** compact row near the top, out of thumb zones.
- **Windows:** Storage, Upgrades, Weapons, Pets, Pet Shop, Rewards, Index, Rebirth, Store and Codes all use the same Window template. Grids of Cards, clear primary action button per card, locked items greyed with a padlock, owned items ticked.
- **Index:** a collection grid of all 30 companies grouped by tier, with silhouettes for undiscovered ones and variant badges for those found.
- **Valuation Machine screen:** a smooth line chart that draws in, green when rising and red when falling, a very large multiplier with a slight pulse, and one huge Take button. No visible countdown. None of the banned words.
- **Tutorial:** a friendly banner card at the top with a step number, and a bouncing 3D arrow or beam guiding the player to the target.
- **Consistency check:** every screen uses Theme values only. Nothing dark-grey-with-white-text left over from the old UI.


## Phase 3: Companies (30 models)

Replace the shared Default box. Each company gets its own model, roughly 3 to 5 studs, built by a shared builder so the structure is consistent:

- **Structure:** a plinth or base in the tier colour, the main pun object on top, and a small floating logo badge (built from UI shapes and text on a SurfaceGui or BillboardGui, original design only) plus a nameplate.
- **Tier grandeur:** Startup plinths are simple and small; each tier up gets a bigger plinth, more trim, gold edging from Blue Chip up, a gentle glow ring from Conglomerate up, and a slow idle spin or bob with a subtle aura on Monopoly.
- **Concepts (starting points; keep the pun, never echo the real brand):**
  - Snackchat: a chatty sandwich with a speech bubble
  - Kittygram: a cat sitting on a kitchen scale reading grams
  - Duolinguini: a steaming bowl of linguine with a tiny flag on the fork
  - Pinterust: an oversized rusty drawing pin
  - Ubber: a squishy rubber car
  - Netflicks: a popcorn bucket with a film strip flicking out of it
  - Spotifly: a fly wearing big headphones on a spinning record
  - Airbnbee: a bee with a tiny house on its back
  - Discard: a playing card mid-toss into a bin
  - Zoomba: a speedy vacuum puck with racing stripes
  - SpaceY: a chunky rocket with Y-shaped fins
  - Stripey: a stripy piggy bank
  - TikTock: a dancing alarm clock
  - Robinhoodie: a hoodie wearing a feathered archer cap
  - Canvaas: a painter's canvas on an easel with paint splats
  - Pear: a glossy cartoon pear with one leaf, no bite
  - Macrohard: a giant hard hat
  - Amazin': a cardboard parcel bursting open with a ta-da sparkle
  - Goggle: a giant pair of swimming goggles
  - Choca-Cola: a chocolate drink bottle in brown and cream with a melting drip
  - Samsong: a smartphone singing with music notes
  - Disnee: a spotlit theatre stage with curtains
  - Nestled: a set of nesting dolls
  - Unileverage: a giant lever lifting a stack of soap bars
  - Berkshire Hatchaway: an egg hatching out of a top hat
  - Alphabet Soup: a bowl of letter soup
  - Meh-ta: a headset with a bored "meh" face
  - Megamart: an overflowing oversized shopping trolley
  - Tencentury: a clock tower built from stacked coins
  - Everything Inc.: a small globe with tiny objects orbiting it
- **Data-driven:** each company's model, colours and logo badge are defined in config next to its existing data, and built by the shared builder, so adding a company later means adding a config entry.


## Phase 4: Company variants

Variants are applied as a layer on top of any company model by one function, without editing the model itself.

- **Shiny:** brighter, slightly reflective colours and a few slow white sparkles
- **Pixel:** recolour to a limited retro palette, swap round parts for blocky equivalents where practical, small square particles
- **Molten:** dark rock tones with glowing orange Neon cracks and a few rising embers
- **Galaxy:** deep purple base, small twinkling star particles, a faint nebula tint
- **Rainbow:** a smooth client-side hue cycle on accent parts only, not the whole model
- **Glitched:** brief random flickers, a short offset "ghost" copy in red and cyan that appears and vanishes, small square noise particles
- **Rules:** each variant has a matching badge colour in Theme, is clearly distinguishable from the others at a glance, stays within the particle budget, and switches its particles off at distance.


## Phase 5: Player bases and front yards

- **Floors and platforms:** replace plain grey slabs with trimmed floors, a subtle two-tone pattern, and edge bevels.
- **Walkway carpet:** accent-coloured carpet with a contrasting border and small repeating motif built from parts.
- **Plots:** become display plinths. Locked plots look dim and stone-like with a padlock; unlocked plots light up with a soft ring in the base accent colour.
- **Pet slots:** become rounded pet beds or cushions on short pedestals.
- **Stairs and railings:** proper treads, landings with trim, rounded handrails and posts.
- **Glass walls:** framed panels with a light tint and slight reflectance, frames in the base accent colour.
- **Border trim:** consistent accent trim on every base; the VIP version in gold with a slow shine.
- **Base name sign:** a sign above the entrance showing the owner's display name, styled like a company headquarters sign in the base accent colour.
- **Locked-base effect:** replace the plain highlight with a translucent force-field or laser gate across the entrance, gently animated, with a padlock icon and a countdown on a small sign if the lock is timed.
- **Valuation Machine:** a proper machine: a frame with screens showing a mini line chart, a scrolling ticker of parody company names with green and red arrows, blinking indicator lights, and a glowing pad. No banned words on any screen.
- **Personal conveyor:** side rails, visible rollers, moving belt slats or chevrons animated on the client, and a spawner hatch at the start that opens when something spawns.
- **Lock button:** a big round button on a pedestal with a padlock icon, that presses down when used.
- **Spawn pad:** a rounded pad with the base accent colour ring and a soft upward glow.


## Phase 6: The middle street

- **Shared conveyor:** a ticker-tape or red-carpet feel: gold-edged rails, rollers, moving chevrons, and small lights along the sides.
- **Tunnel arches:** become stock-exchange gateways with columns, a pediment and a sign with the game's name.
- **Street:** road markings, kerbs, street lamps, benches, planters and a few trading-floor props (ticker posts, small display screens).
- **Shops and upgrade station:** proper storefronts with an awning, an icon sign, a counter, a display of the goods (weapons on racks, pet eggs or plushies, upgrade arrows), and a simple friendly shopkeeper NPC built from parts with an idle animation.
- **Leaderboards:** styled like stock-exchange display boards, with a header strip, ranked rows, top three in gold, silver and bronze, and a soft glow.


## Phase 7: Pets, weapons and combat effects

- **Pets:** chunky chibi proportions, big glossy eyes, a gentle bob while following, and a rarity aura (Common none, then increasing glow and particles up to Mythic). Each pet should be recognisable from its name alone.
- **Pet reveal:** a short sequence: egg or box shakes, cracks, a burst in the rarity colour, the pet pops out with the name and rarity badge. Bigger and longer for higher rarities, always skippable.
- **Weapons:** proper models for the Rolled-up Newspaper, Briefcase, Stapler Gun, Gavel and Golden Calculator, a swing or use animation each, and a cartoon hit effect (stars, a "BONK"-style puff, a small screen shake on the attacker only).
- **Knockback, stun and ragdoll:** stars circling the head during stun, a dust puff on landing.


## Phase 8: World and atmosphere

- **Ground:** grass with variation, small paths, flower patches and trees between bases.
- **Hills:** trees, fences, and a distant low-detail city skyline with parody billboards (original designs only).
- **Keep it light:** distant scenery is low part count, no collisions, no shadows.


## Phase 9: Feedback and juice

- **Carrying a company:** a two-handed carry pose and a soft glow in the tier colour.
- **Dropped company:** a bouncing drop, a glow ring on the ground and a clear return countdown above it.
- **Pop effects:** distinct, quick effects for purchase, steal and "tagged".
- **Income:** a small floating "+Cash" pop over plots, not on every tick for every plot, so it does not spam.
- **Rebirth:** a celebration with a burst, confetti and a big banner.
- **Restraint:** effects are short, readable and never cover the HUD.


## Phase 10: Store and marketing art briefs

You cannot make the final images, so set them up for me.

- **Photo booth:** a separate hidden area or place with a nice backdrop and lighting where models, pets and bases can be posed for screenshots.
- **ART_BRIEFS.md:** a brief for each of these: game pass icons (512x512) for 2x Income, VIP and Extra Pet Slot; developer product icons for Cash Pack, Big Cash Pack, Huge Cash Pack and Lock Base Now; the game icon (512x512); thumbnails (1920x1080). Each brief: purpose, composition, which models to pose, colours from Theme, text if any, and must follow all the hard rules above.


## Done means

At the end of each phase, confirm:

- Tested in the Studio device emulator on a small phone and a tablet. No UI overlapping the thumbstick or jump button, nothing cut off.
- Frame rate holds with all 8 bases full.
- Grep shows none of the banned words anywhere.
- No real brand logos, colours or silhouettes.
- No invented asset IDs. Every placeholder is listed in ASSETS_NEEDED.md.
- All colours and fonts come from the Theme module.
- Gameplay, remotes and save data unchanged.
