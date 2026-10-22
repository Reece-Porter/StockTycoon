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

The menu icons are also drawn from shapes for now (Box, Weapon, Paw, Book, Rebirth, Gift, Ticket and Bolt in `Icons.luau`):

| Icon | Purpose | Suggested design |
| --- | --- | --- |
| Storage | Storage menu button and window | A cardboard box with the lid open |
| Weapons | Weapons menu button and teleport | A rolled-up newspaper |
| Pets | Pets menu button, pet shop and pet cards | A round paw print |
| Index | Index menu button | A closed book with a star on the cover |
| Rebirth | Rebirth menu button | Two curved arrows in a circle |
| Rewards | Rewards menu button and reward rows | A wrapped gift with a bow |
| Codes | Codes menu button | A ticket stub |
| Boost | 2x income boost chip | A lightning bolt (Gold) |
| Upgrades | Upgrades menu button and teleport | A chunky up arrow |
| Collect | Cash pads (not used yet) | A coin with an arrow into it (Cash green) |

## Company logo badges

Each company's model has a floating badge (stand-in: the company's letters in a ringed circle, drawn from UI shapes, colours in `src/shared/Config/CompanyLooks.luau`). A real badge image per company would replace the letters. Each is a 256 x 256 PNG, transparent background, a round badge filling the image with a thick Ink (#1B1B2F) outline, readable at 48 x 48. Original designs only: never the real company's logo, logo shape, wordmark, mascot, font or colours. Keep each badge's background colour from the table so it matches its model.

| Company | Badge colour | Suggested design |
| --- | --- | --- |
| Snackchat | Tomato #E8473B | A sandwich with a speech bubble |
| Kittygram | Cream #FFF1D6 | A cat face on a kitchen scale dial |
| Duolinguini | Navy #3D5A80 | A fork twirling linguine |
| Pinterust | Rust #B4532A | A rusty drawing pin |
| Ubber | Pink #FF7EB6 | A squishy round car |
| Netflicks | Popcorn #FFF3C4 | A popcorn kernel with a film strip |
| Spotifly | Pink #FF5FB0 | A fly wearing headphones |
| Airbnbee | Bee yellow #FFD23F | A bee with a tiny house |
| Discard | Teal #2A9D8F | A playing card dropping into a bin |
| Zoomba | Red #E63946 | A vacuum puck with speed lines |
| SpaceY | Red #E63946 | A rocket with three fins in a Y |
| Stripey | Teal #2EC4B6 | A striped piggy bank |
| TikTock | Orange #FF8C1A | An alarm clock with dancing legs |
| Robinhoodie | Brown #8B5A2B | A hood with a feathered cap |
| Canvaas | Gold #FFC83D | An easel with paint splats |
| Pear | Pear green #9BCB3C | A whole pear with a leaf, no bite |
| Macrohard | Gold #FFC83D | A hard hat with a lamp |
| Amazin' | Cardboard #C69C6D | An open box with a sparkle |
| Goggle | Purple #7B4AE2 | Swimming goggles |
| Choca-Cola | Cream #F3E5C8 | A chocolate drip |
| Samsong | Dark #2B2D42 | A phone singing a music note |
| Disnee | Curtain red #C0263A | Theatre curtains |
| Nestled | Red #D7263D | Three nesting dolls |
| Unileverage | Mint #B5EAD7 | A lever lifting a soap bar |
| Berkshire Hatchaway | Ink #1B1B2F | An egg hatching from a top hat |
| Alphabet Soup | Orange #F28C28 | A bowl with letters |
| Meh-ta | Light grey #E8ECF2 | A headset with a bored face |
| Megamart | White #FFFFFF | An overflowing trolley |
| Tencentury | Purple #7B4AE2 | A coin-stack clock tower |
| Everything Inc. | Gold #FFC83D | A globe with a ring |

Company models themselves need no assets: they're built from parts in code. A hand-made model (mesh or parts) for any company can be dropped into `ReplicatedStorage.Assets.Companies` with the company's id as its name, and it will be used instead; keep it within the same budget (30 parts, one light only on Conglomerate and Monopoly).

## Bases

Nothing is required: every base is built from parts and built-in materials (the lock's force field uses Roblox's ForceField material). These would make them better:

| Asset | Replaces | Spec |
| --- | --- | --- |
| Belt texture | The chevron parts on each base's belt | 256 x 256 PNG, tiles along its length: a dark rubber belt (#3A3A4A) with two faint lighter chevrons pointing one way. Opaque. |
| Carpet pattern | The carpet's diamond parts | 256 x 256 PNG, tiles both ways: a soft fabric look, white so the accent colour tints it, with a small diamond every half tile. Opaque. |
| Machine screen frame | The plain screen and ticker panels | 512 x 256 PNG: a rounded monitor bezel with a small antenna, dark grey (#2B2D42), transparent in the middle and outside. |
| Gauge face | The plain white gauge discs on the machine's pillars | 128 x 128 PNG: a round dial, white with a thin dark rim, tick marks round the top two thirds and a green-to-red arc. Transparent outside the circle. The needle stays a part. |

## Street

Nothing is required: the street, shops, gateways and boards are built from parts, built-in materials and text. These would make them better:

| Asset | Replaces | Spec |
| --- | --- | --- |
| Carpet texture | The plain red Fabric on the shared conveyor | 256 x 256 PNG, tiles along its length: a deep red carpet (#A3203A) with a thin gold border stripe 16 px in from each long edge. Opaque. |
| Road markings | The dash and zebra crossing parts | 512 x 512 PNG decals: a white dashed line on transparent, and a five-stripe zebra crossing on transparent. Slightly worn edges. |
| Game logo | The gateway frieze text "STOCK TYCOON" and the gold medallion | 1024 x 256 PNG: the game's name in a chunky rounded style with a small rising arrow, gold (#E1B93C) with a dark navy outline, on transparent. Plus a 256 x 256 round version for the medallion. Original artwork only. |
| Shop sign emblems | The part-built gavel, paw and arrow on each sign | Three 256 x 256 PNGs on transparent, white with a dark outline so they read on any colour: a gavel, a paw print, an up arrow. |
| Shopkeeper faces | The eye and smile parts | Three 256 x 256 PNG face decals on transparent: big friendly cartoon eyes and a smile, one each for the weapon, pet and upgrade shopkeepers. |
| Board header icons | The plain header strip on each leaderboard | Four 128 x 128 PNG icons on transparent, white: a coin stack (Cash per second), a circular arrow (rebirths), a sneaking hand grabbing a box (steals), a cartoon star burst (knockouts). |


## Scenery

Nothing is required: the trees, flowers, fence and city are built from parts and built-in materials. These would make them better:

| Asset | Replaces | Spec |
| --- | --- | --- |
| Leaf clump texture | The plain Grass material on the round trees' leaf balls | 256 x 256 PNG, tiles: soft cartoon leaf clusters in light and mid greens (#6BBE5E, #58AA52) with darker gaps. Opaque. |
| Flower decal | The ball flowers in the flower patches | 128 x 128 PNG on transparent: a simple five-petal cartoon flower, white with a yellow centre, so the game can tint the petals. |
| Stepping stone | The plain slate discs on the paths | 256 x 256 PNG on transparent: a rounded flat stone, pale warm grey (#CFC9BC), a few small cracks. |
| Skyline billboards | The plain coloured boards with the company name and slogan | Four 512 x 216 PNGs: an advert for a parody company from `Config/Companies` (its own logo badge from `Config/CompanyLooks`, its name and a silly slogan) on a bright background. Original artwork only, no real brands. |
| Distant towers | The plain pale tower blocks | 256 x 512 PNG, tiles up: rows of faint windows in pale blue-grey (#B9C5D8), very low contrast so the city stays in the background. |

## Pets

Nothing is required: every pet is built from parts. These would make them better:

| Asset | Replaces | Spec |
| --- | --- | --- |
| Eye highlight decal | The small white ball on each glossy eye | 128 x 128 PNG on transparent: a round black eye with two white glints (a big one top right, a small one bottom left). |
| Aura sparkle | Roblox's default particle on the Rare to Mythic aura | 64 x 64 PNG on transparent, white so the rarity colour tints it: a soft four-pointed star with a bright centre. |
| Egg art for the reveal | The plain drawn egg, spots and cracks | 256 x 320 PNG on transparent: a cream cartoon egg with pastel spots and a thick dark outline, plus three overlay PNGs of the same size with one, two and three zigzag cracks. |

## Weapons and combat effects

Nothing is required: weapons are built from parts and the effects are drawn from frames. These would make them better:

| Asset | Replaces | Spec |
| --- | --- | --- |
| Newspaper print | The plain paper colour and stripes on the Rolled-up Newspaper | 256 x 256 PNG, tiles round the roll: grey columns of squiggly fake text and a small made-up masthead "THE DAILY DIVIDEND". Opaque. No real newspaper names or logos. |
| Calculator keys | The key parts on the Golden Calculator | 256 x 256 PNG on transparent: a 3 x 4 grid of rounded cream keys with dark digits, one orange key. |
| Hit puff | The white circles behind the hit word | 256 x 256 PNG on transparent: a white cartoon cloud burst with a dark outline and a few speed lines. |
| Hit star | The drawn star bursting from a hit and circling a stunned head | 64 x 64 PNG on transparent: a chunky five-pointed cartoon star, white so the game can tint it gold, with a dark outline. |
| Dust puff | The grey ball parts where a knocked-back player lands | 64 x 64 PNG on transparent: a soft grey cloud puff for a ParticleEmitter, light in the middle and fading at the edges. |
| Whoosh trail | The thin Neon streaks of a swing | 128 x 32 PNG on transparent: a white curved swoosh fading towards one end, for a Trail. |

## Variant particles

Small textures for company variant particles (`src/shared/Config/Variants.luau`). Each is a 64 x 64 PNG on a transparent background, white or light grey so the particle colours tint it, soft edges unless noted. Until each exists, the stand-in is Roblox's built-in sparkle, or a plain square for Pixel and Glitched.

| Texture | Used by | Design |
| --- | --- | --- |
| Pixel square | Pixel | A crisp square with a one-pixel lighter top-left edge, like a retro sprite pixel. Hard edges. |
| Noise block | Glitched | Two or three small offset rectangles, like a broken screen. Hard edges. |
| Twinkle | Shiny, Galaxy | A soft four-pointed star with a bright centre. |
| Ember | Molten | A soft round glow, brightest in the middle. |

## Fonts

None needed: the two fonts (FredokaOne and BuilderSans Bold) are built into Roblox.

## Store and marketing art

The game pass, developer product and game icons and the thumbnails have their own briefs in `docs/ART_BRIEFS.md`, with the photo booth to pose the shots.

## Sounds

None are required: the game plays without them. Phase 7 would use these (short, cartoon, no realistic weapon sounds):

| Sound | Plays when | Spec |
| --- | --- | --- |
| Whoosh | A melee weapon swings | 0.2 s soft air swish. |
| Staple shot | The Stapler Gun fires | 0.2 s springy "ka-chunk". |
| Bonk | A hit lands | 0.3 s cartoon bonk with a squeaky tail. |
| Dizzy | A player is stunned | 1 s looping tweety birds or twinkles, quiet. |
| Egg shake | The egg shakes in the reveal | 0.5 s looping wobble rattle. |
| Egg crack | The egg bursts | 0.4 s crack and pop. |
| Pet reveal | The pet pops out | 1 s rising chime; a longer, brighter fanfare variant for Legendary and Mythic. |

Phase 9 would use these (short and cartoon, quiet enough to hear often):

| Sound | Plays when | Spec |
| --- | --- | --- |
| Ka-ching | Someone buys a company ("SOLD!") | 0.4 s cash register ding. |
| Yoink | Someone starts stealing ("YOINK!") | 0.3 s cartoon slide whistle up. |
| Tagged | A thief is caught ("TAGGED!") | 0.4 s cartoon buzzer and boing. |
| Coin tick | The small "+$" over a plot | 0.15 s soft coin tick, very quiet. |
| Drop thud | A company bounces as it lands | 0.3 s soft cartoon thud with a small bounce. |
| Rebirth fanfare | The rebirth celebration | 2 s bright fanfare with a confetti pop. |

The Stock Spinner and Hostile Takeovers would use these:

| Sound | Plays when | Spec |
| --- | --- | --- |
| Reel ticks | The spinner's reels roll | Soft mechanical ticks that slow down with the reels, about 3 s, quiet (it plays every 20 seconds). Like a stock ticker board flipping, not an arcade machine. |
| Reel stop | Each reel lands | 0.2 s soft clunk; a short sparkle on top for a Blue Chip or a variant. |
| Takeover siren | A Hostile Takeover starts | 1.5 s cartoon alarm or trading-floor bell, played once for everyone. |
| Takeover over | It ends | 1 s calm closing bell. |

Button clicks are still to come.
