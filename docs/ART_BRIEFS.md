# Art briefs

Briefs for the store and marketing images (visual pass Phase 10). The final images are made outside the game: an artist draws them, or you take a screenshot in the photo booth and finish it in an image editor (crop, add text, add a glow). Each brief says what the image is for, how it is laid out, what to pose and where, which game colours to use, and any text.

## The photo booth

A small studio far out past the city, out of everyone's sight, built by `studio/BuildMap.luau` (map version 6 or later). It has a curved backdrop with no corner line, three round podiums (Hero in the middle, Left and Right), a big stage for a copy of a base, studio lights and cameras set up for icons and thumbnails.

Company and pet models only exist once the game is running, so use it in a play test:

1. Rebuild the map with `studio/BuildMap.luau` if you haven't since map version 6, then press **Play** (or start a local server).
2. As an admin (`src/shared/Config/Admins.luau`), use these in chat:

| Command | What it does |
| --- | --- |
| `/booth` | Takes you to the booth, out of shot beside the podiums. `/booth back` takes you home. |
| `/pose hero <company or pet> [variant] [size]` | Stands a company or pet on the Hero podium, a bit bigger than usual. `left` and `right` work the same. Names can have spaces, for example `/pose hero dividend dragon` or `/pose left kittygram galaxy`. |
| `/pose base` | Puts a copy of your base, with the companies on its plots and the pets in its slots, on the stage. |
| `/pose clear [hero, left, right or base]` | Takes away one thing, or everything. |
| `/backdrop <colour>` | Paints the backdrop: sky, gold, green, blue, purple, teal, pink, white or night. |
| `/boothcam icon` | Looks through the square icon camera at the Hero podium, with the HUD and Roblox's menus hidden. |
| `/boothcam wide` | Looks at all three podiums, for thumbnails. |
| `/boothcam base` | Looks at the stage at three-quarters. |
| `/boothcam free` | Only hides the HUD and Roblox's menus, so you can move the camera anywhere in the map for a shot. |
| `/boothcam off` | Back to normal. |

3. Take the screenshot. For exact sizes, open Studio's **Device** emulator and add a custom device: 1024 x 1024 for icons (scale down to 512 x 512 afterwards, for sharper edges) or 1920 x 1080 for thumbnails. On a Mac, Cmd+Shift+4 then Space captures the Studio window.
4. Finish it in an image editor: crop, add the text in the brief, export as PNG.

Pets bob and companies spin a little in the booth, as they do in the game. Take a few shots and keep the best one.

## Rules for every image

These are the visual pass's hard rules, applied to marketing art:

- **Parody only:** use the game's own models as they are. No real logos, logo shapes, wordmarks, mascots, fonts, product silhouettes or brand colour schemes, and nothing added that would make someone think of a real company.
- **Keep store art about the game's own world:** cash, pets, bases, the Valuation Machine, and companies whose names aren't a play on one real brand (Everything Inc. and Megamart). Keep the other parody companies, whose names sound like real brands, out of icons and thumbnails. They're fine in the game, but store art gets looked at more closely.
- **No chance imagery:** never use any of the banned words listed in CLAUDE.md. Don't show dice, slot machines, roulette wheels, playing cards or chips. The Valuation Machine is a measuring machine with a chart, so never show it as a spin or a prize draw.
- **No Robux in the art:** don't show Robux symbols, prices or "free" claims. Never suggest pets can be bought with Robux; pet spins are Cash only.
- **Honest:** show what the pass or product really does, as its store description says (`src/shared/Config/Monetisation.luau`).
- **Cartoon and friendly:** bright, chunky and rounded, readable on a small phone. No real people, nothing scary, no realistic weapons.
- **Text:**
  - Keep it to one to four words.
  - Use FredokaOne (the game's display font, built into Roblox), white or Gold with a thick Ink (#1B1B2F) outline, large enough to read at 100 px wide.
  - Put no text on the game icon unless the brief says so.
- **Colours** come from the game's Theme (`src/shared/Theme.luau`):

| Name | Hex | Use |
| --- | --- | --- |
| Cash | #3CCB5A | Money, income, "2x" |
| Gold | #FFC83D | VIP, top prizes, highlights |
| Primary | #3D8BFF | Calm backgrounds, Storage |
| Purple | #A66CFF | Pets |
| Danger | #FF4D5E | Steals, weapons |
| Rebirth | #FFB020 | Rebirth |
| Ink | #1B1B2F | Outlines, dark text |
| Card | #FFFFFF | Highlights, light text |

  The booth's backdrops are soft versions:

| Backdrop | Hex |
| --- | --- |
| sky | #CFE6FF |
| gold | #FFE7A3 |
| green | #C4F0CE |
| blue | #BCD6FF |
| purple | #E2D3FF |
| teal | #BDEFE6 |
| pink | #FFD3E4 |
| white | #F4F6FB |
| night | #22253A |

- **Roblox's specs:**
  - Game pass and developer product icons are 512 x 512 PNGs. Pass icons are shown in a circle in some places, so keep everything important inside the middle 80%.
  - The game icon is 512 x 512 and is shown with rounded corners.
  - Thumbnails are 1920 x 1080, and there can be up to 10.

## Game passes

### 2x Income (512 x 512)

- **Purpose:** sells 2x Income: "Every company you own earns twice as much, for good."
- **Composition:**
  - Everything Inc.'s golden globe big in the middle on the Hero podium, with a green burst behind it.
  - Cash notes and coins fly up and out from behind the podium (drawn or pasted in).
  - A chunky "2x" sits bottom right, overlapping the podium.
- **Pose:** `/backdrop green`, `/pose hero everythinginc 2`, `/boothcam icon`.
- **Colours:** Cash #3CCB5A for the burst and the "2x", Gold #FFC83D coins, Ink outlines, green backdrop #C4F0CE.
- **Text:** "2x" only.

### VIP (512 x 512)

- **Purpose:** sells VIP: "A gold VIP tag in chat and gold trim on your base."
- **Composition:**
  - The front corner of a base with its gold VIP trim shining, seen from slightly below so it looks grand.
  - A gold "VIP" plaque floats in front, with a few sparkles.
- **Pose:** `/givepass vip` (so your base has the gold trim), `/pose base`, `/backdrop night`, `/boothcam base`. Crop square around the front corner.
- **Colours:** Gold #FFC83D trim and plaque, night backdrop #22253A for contrast, Card #FFFFFF sparkles.
- **Text:** "VIP".

### Extra Pet Slot (512 x 512)

- **Purpose:** sells Extra Pet Slot: "Opens a second pet slot on every floor of your base."
- **Composition:**
  - Two pets side by side on cushioned pet beds: Coffee Cat on the left and Golden Goose on the right.
  - The right one has a big "+1" badge above it in Purple with a white outline.
- **Pose:** `/backdrop purple`, `/pose left coffeecat 1.4`, `/pose right goldengoose 1.4`, `/boothcam wide`, then crop square around the two.
- **Colours:** Purple #A66CFF badge, purple backdrop #E2D3FF, the pets' own colours.
- **Text:** "+1".

## Developer products

The three Cash packs are a set: the same framing and background, and a bigger pile each step up, so the difference reads at a glance.

### Cash Pack (512 x 512)

- **Purpose:** "15 minutes of your income."
- **Composition:**
  - A neat stack of green cash with a few gold coins, centred on a white podium.
  - A small clock badge (15 minutes) top right.
- **Pose:** `/backdrop green`, `/boothcam icon` for the podium and background. Draw or paste the cash on top.
- **Colours:** Cash #3CCB5A, Gold #FFC83D, green backdrop #C4F0CE.
- **Text:** "15 MIN" on the clock badge.

### Big Cash Pack (512 x 512)

- **Purpose:** "1 hour of your income."
- **Composition:** as the Cash Pack, but three stacks and more coins spilling over the podium's edge, with a "1 HR" clock badge.
- **Pose:** as the Cash Pack.
- **Colours:** as the Cash Pack, with more Gold.
- **Text:** "1 HR".

### Huge Cash Pack (512 x 512)

- **Purpose:** "4 hours of your income."
- **Composition:**
  - A mountain of cash and coins hiding the podium, with Megamart's model peeking over the top.
  - Gold sparkles, and a "4 HRS" clock badge.
- **Pose:** `/backdrop gold`, `/pose hero megamart 1.4`, `/boothcam icon`, then add the cash mountain in front.
- **Colours:** Cash #3CCB5A, Gold #FFC83D, gold backdrop #FFE7A3.
- **Text:** "4 HRS".

### Lock Base Now (512 x 512)

- **Purpose:** "Locks your base straight away, wherever you are."
- **Composition:**
  - The way into a base, closed by its shimmering force field.
  - A big gold padlock in front, and a small lightning bolt beside it for "now".
- **Pose:** this one is shot in the real map, because the force field only shows on a real base.
  1. Lock your base (`/buyproduct locknow` works too).
  2. Stand in front of the way in and type `/boothcam free`.
  3. Frame the force field, take the shot and crop it square.
- **Colours:** the force field's own blue, Gold #FFC83D padlock and bolt, Ink outlines.
- **Text:** none.

## Game icon (512 x 512)

- **Purpose:** the first thing people see. It has to say "build a money-making company empire" in a cartoon, friendly way, at 50 px wide.
- **Composition:**
  - Everything Inc.'s golden globe big on the Hero podium, with a bright green arrow curving up behind it.
  - A small pile of cash at the front.
  - Golden Goose peeking in from the left edge, cropped by the frame.
  - One strong shape and three colours at most, plus the backdrop.
- **Pose:** `/backdrop sky`, `/pose hero everythinginc 1.8`, `/pose left goldengoose 1.3`, `/boothcam icon`. Add the arrow and cash afterwards.
- **Colours:** Gold #FFC83D globe, Cash #3CCB5A arrow, sky backdrop #CFE6FF, Ink outline round the whole group.
- **Text:** none (the game's name is shown next to the icon).

## Thumbnails (1920 x 1080)

Four thumbnails, each showing one thing the game is about. Put the text top left or top centre, clear of the main subject, at most four words.

### 1. Build your empire

- **Purpose:** the main thumbnail: the street, the bases and the shared conveyor.
- **Composition:**
  - High above the middle of the street, looking down the red carpet conveyor towards the stock-exchange gateway.
  - Bases on both sides, the nearest one gold-trimmed (VIP), its plots full.
  - Your character in the front third, carrying a Monopoly company overhead with both arms, glowing in the tier colour.
- **Pose:**
  1. In a local server, fill your base with companies from `/spawn monopoly shared` and `/spawn conglomerate shared`, buying and placing them.
  2. Pick one up to carry, type `/boothcam free` and frame the shot.
- **Colours:** the map's own, with the text in Gold #FFC83D with an Ink outline.
- **Text:** "BUILD YOUR EMPIRE".

### 2. Steal from your friends

- **Purpose:** the steal-and-chase moment.
- **Composition:**
  - A player running out of a base with someone else's company overhead, a "YOINK!" pop above them.
  - The owner chasing from behind, one weapon (the Rolled-up Newspaper) raised.
  - Low camera at the base's way in, both characters large in frame.
- **Pose:** a two-player local server. One player steals and the other chases. The stealing player types `/boothcam free` and frames the shot.
- **Colours:** Danger #FF4D5E text, with the map's own colours.
- **Text:** "STEAL THEIR COMPANIES".

### 3. Value it up

- **Purpose:** the Valuation Machine.
- **Composition:**
  - Close in on the machine in a base's yard, a company inside the glass tube, the scanner glowing.
  - The big screen above shows the rising green chart.
  - Your character watching from the side.
- **Pose:** put a company in the machine, type `/boothcam free` while the run is going, and frame the machine and screen.
- **Colours:** Cash #3CCB5A chart, Gold #FFC83D text.
- **Text:** "VALUE YOUR COMPANIES". Don't add numbers or anything that hints at chance.

### 4. Collect pets

- **Purpose:** the pets.
- **Composition:** three pets on the three podiums, the rarest in the middle and biggest: Coffee Cat left, Dividend Dragon centre, Golden Goose right.
- **Pose:** `/backdrop purple`, `/pose left coffeecat`, `/pose hero dividenddragon`, `/pose right goldengoose`, `/boothcam wide`.
- **Colours:** purple backdrop #E2D3FF, Purple #A66CFF text with a white outline.
- **Text:** "COLLECT PETS". Don't show prices, spins or Robux.
