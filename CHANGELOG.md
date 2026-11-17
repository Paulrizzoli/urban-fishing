# Urban Fishing updates

Every update to Urban Fishing, newest first. This is the one file to check for what changed and when.

**How this file is kept up to date:** every change that ships gets an entry here in the same pull request, before it's merged into `main`. A new version gets its own section with the date and the build files it produced. Work that has started but isn't released yet goes under "In progress" at the top, and moves into a version section when it ships. A copy of this file is kept in the project files as `UPDATES.md`.

To make a new version, bump `config/version` in `godot/project.godot` (and the file and product version in `godot/export_presets.cfg`), add a section here, and run `tools/build_windows.sh`. It zips the game as `UrbanFishing-v<version>-windows.zip` and the Godot project as `UrbanFishing-v<version>-godot-project.zip`. The version shows on the title screen and in the pause menu. From v0.9.1 on, each update goes up by one step in the last number (v0.9.1, v0.9.2, v0.9.3 and so on).

## In progress

Nothing right now.

## Versions at a glance

| Version | Date | What it was about |
|---|---|---|
| v0.9.4 | Nov 17, 2026 | Make your own lures from parts you find around town |
| v0.9.3 | Nov 17, 2026 | Pictures of every rod, bait and upgrade in the shop, the marina and the top bar |
| v0.9.2 | Nov 17, 2026 | Round islands and beaches, and boats that stay where you leave them |
| v0.9.1 | Nov 17, 2026 | Real-looking people with walk cycles, fish that splash, and light that changes through the day |
| v0.9.0 | Nov 17, 2026 | Three save slots |
| v0.8.0 | Nov 17, 2026 | Tower sides you can see, and towers you can see through when you walk behind them |
| v0.7.0 | Nov 17, 2026 | A better-looking Port Mullet (water, buildings, streets, cars, details) |
| v0.6.0 | Nov 17, 2026 | A bigger zoomable map, and a town that opens up in four steps |
| v0.5.0 | Nov 17, 2026 | The browser version's music, and a music style setting |
| v0.4.0 | Nov 16, 2026 | Music, sound effects, ambience and volume settings |
| v0.3.0 | Nov 16, 2026 | Title screen, menus, settings and polish, Windows .exe |
| v0.2.0 | Nov 16, 2026 | Story, weather, guards, boats and more of the town |
| v0.1.0 | Nov 16, 2026 | First Godot (desktop) version |
| Browser | Nov 16, 2026 | The original game in one web page (`index.html`) |

v0.1.0 to v0.3.0 were numbered afterwards; the version label started showing in the game with v0.4.0.

## v0.9.4 · Home-made lures

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.4-windows.zip`, `UrbanFishing-v0.9.4-godot-project.zip`, screenshots in `screenshots/v0.9.4/`_

- Parts lie around town: something shiny glints on the ground by Lou's and on the banks of a dozen fishing spots. Walk up and press E (or the Pick it up button) to take it. Each spot has its own part and fills up again two days after you pick it
- Six parts: bent spoons (Back Canal, the downtown river, Marlowe Tower), bottle caps (Lou's, Maple Park Pond), beads (Bayfront Park, Sunsplash, Heron Lakes), gull feathers (Mullet Bay, the golf course lake), copper wire (Mullet Canal, the airport canal) and glow sticks (the power station outflow)
- Junk you catch can be stripped for parts at Lou's instead of sold. On the Sell tab a piece of junk has a "Strip for parts" button and says what part it gives: bikes, carts and scooters give wire, golf balls and jewelry give beads, phones and hard hats give glow sticks
- Home has a new Workbench tab next to Rest. It shows your parts with how many you have, and four lures you can make:
  - **Spoon lure** (spoon + wire): the saltwater crowd chases it, snook, redfish, jacks, trout, snapper, tarpon and more. Lasts 6 catches
  - **Bottle-cap popper** (2 caps + beads): every kind of bass, peacocks, bowfin, snakeheads and cichlids. Lasts 6 catches
  - **Feather jig** (feather + beads): no fish loves it and none minds it, so everything bites a bit better. Lasts 8 catches
  - **Glow lure** (glow stick + wire + beads): after dark every fish comes to look. In daylight it's just a lure. Lasts 5 catches
- A lure you make goes straight on your line. It switches with B like any bait, and the top bar shows how many catches it has left. Junk doesn't wear it down. When it falls apart you're back on worms, and the catch card tells you
- Every part and lure has its own picture, in the workbench, the top bar and your kit at Lou's

## v0.9.3 · Pictures in the shop

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.3-windows.zip`, `UrbanFishing-v0.9.3-godot-project.zip`, screenshots in `screenshots/v0.9.3/`_

- Every item at Lou's and the marina has its own picture next to its name: all five rods, every bait, the coolers, the camera phone, the golf polo and visor, the lanyard, the flashlight, waders, the Geiger counter, the pry bar, the kayak, the skiff, the big tank, the suit and the polarized sunglasses. They're all drawn in the game's own style, with a dark outline, on a little paper tile
- The five rods each look different: the garage-sale rod is a yellowed fiberglass stick with tape on it and a push-button reel, the bait-shop special is green with a cork grip, the graphite pro is black with blue wraps, the surf rod of legend is cream and gold with a sparkle, and the big-game rod is short and thick with gold roller guides and a big gold reel
- Items you can't buy yet (a rod that needs a better rod first) show their picture faded
- A "Your kit" strip at the top of Lou's Gear tab and the marina's Boats & gear tab shows a picture of your rod, every bait you have and everything you own. Point at one to see its name
- The fish in your cooler on the Sell tab have pictures too, tinted for their kind (green bass, orange koi, red redfish and so on), a gold fish with a star for a legend, and a soggy can for junk
- The top bar shows a picture of the bait you have on, next to its name, and it changes when you press B

## v0.9.2 · Round islands, and boats that stay put

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.2-windows.zip`, `UrbanFishing-v0.9.2-godot-project.zip`, screenshots in `screenshots/v0.9.2/`_

- Bird Key is a rounded, lumpy island instead of a stepped rectangle, and a little bigger. Its bushes grow inland, not on the water's edge, and the stray square of grass on it is gone
- Every sandy shore (Bird Key and Mullet Beach) meets the water along a smooth, gently wavy curve instead of the tile grid, with damp sand at the water line and a thin line of surf washing up and back. The big map shows the new shapes too. Walking and boating still work on the same tiles as before
- The kayak stays where you land it. It's pulled half up the bank, nose first, with the paddle across the deck, and you step off beside it. Walk back to it and press K to paddle off again
- The skiff stays tied up where you hop off, bobbing on its line
- The map (M) marks where you left each boat ("Your kayak", "Your skiff"). If you press K away from the water while your boats are parked, it tells you they're where you left them
- A boat you've never landed still comes with you to any edge, like before. If you get walked out by a guard or the park staff while you're out on the water, your boat comes with you too, so it can never be stranded out on open water

## v0.9.1 · People, splashes and light

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.1-windows.zip`, `UrbanFishing-v0.9.1-godot-project.zip`, screenshots in `screenshots/v0.9.1/`_

- People: you, the guards, staff, Lou and the anglers around town now have bodies with arms and legs, shoes, shading, hair, faces that turn the way they look, and caps or wide-brimmed hats
- You walk with a walk cycle and a little bounce, carry your rod over your shoulder, and hold it out in both hands when you fish. The rod bows under the line when a fish pulls, and its tip stays on the line. Guards and staff walk their patrols with a walk cycle too
- Your outfits show: the fishing shirt's pattern, the polo and cap at the golf club, the suit and tie downtown and the lanyard at the office park. In a kayak or skiff you sit
- The anglers around town have a line out to a bobber floating on the water
- Fish fight at the surface: churned water and spray while you reel, more of it the harder they pull, and a burst of droplets when they thrash
- Light through the day: a purple then pink dawn, white noon, a golden late afternoon, an orange and pink sunset and a purple dusk before the blue of night. Clouds wash the color out
- The water reflects the sky's color at each hour, and the sun glints pick it up
- At night lights bloom: soft halos around street lamps and the pools of light under them, house windows lit in the evening (a few stay on late), porch lights, lit shop and office windows, glowing tower windows and Lou's OPEN sign
- Headlight beams and tail lights on the security truck and the HOA resident's car after dark

## v0.9.0 · Three save slots

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.0-windows.zip`, `UrbanFishing-v0.9.0-godot-project.zip`_

- Three save slots, each its own game. Playing or starting one never touches the others
- Your existing game is slot 1, exactly as it was. Slot 1 still uses the same save file as before (`urban_fishing_save.json`), so nothing is moved or converted. Slots 2 and 3 are `urban_fishing_save_2.json` and `urban_fishing_save_3.json`
- Continue on the title screen opens the slot list, with the day, time, cash and rep of each game, and plays the one you pick. Under Continue it says which slot you played last
- New game lets you pick a slot. An empty slot starts right away; a slot with a game in it asks first (Keep it is the default), and says your other slots stay as they are
- The game remembers the last slot you played and loads it when it starts. The pause menu shows which slot you're in

## v0.8.0 · Tower sides, and seeing through towers

_Nov 17, 2026 · Builds: `UrbanFishing-v0.8.0-windows.zip`, `UrbanFishing-v0.8.0-godot-project.zip`, screenshots in `screenshots/v0.8.0/`_

- Towers lean away from the middle of the screen, as if you're looking down on the city, so you see the side wall that faces you, with its floors and windows. Walls on the west are in the sun, walls on the east are in shade. Walk past a tower and it turns to show its other side
- Walk behind a tower and a soft window opens in it around you, so you can see yourself and what's around you while the rest of the tower stays solid. Before, the whole tower faded
- Lit windows at night fade in that window too, and tower name labels follow the tower's lean

## v0.7.0 · A better-looking Port Mullet

_Nov 17, 2026 · Builds: `UrbanFishing-v0.7.0-windows.zip`, `UrbanFishing-v0.7.0-godot-project.zip`, before and after screenshots in `screenshots/v0.7.0/`_

- Water: a new water shader with light rippling across the surface, caustics shimmering on the shallows, slow swells on deep water, foam lapping at the shore and sun glints that fade at dusk, under clouds and in the rain
- Ponds and lakes have lily pads (some flowering) and cattails along the banks
- Houses: shingled hip roofs with ridges and hips, solar panels, chimneys and vent stacks, framed windows with shutters, front doors in different colors with a step and porch light, AC units and flower beds, and soft shadows
- Shops, offices and other flat roofs: parapets, roof seams and gravel, rooftop AC units with fans, skylights and vent pipes, framed and lit storefront windows
- Towers: floor lines on both faces, glass curtain walls with mullions and sky reflections, lobbies with canopies, stair housings and water tanks on the roofs, and longer, softer shadows
- Streets: worn wheel tracks in each lane, gutters along the curbs, a curb lip, storm drain inlets and manhole covers, and patched, grainy asphalt
- Street lamps now stand on posts you can see by day; at night their light hangs from the lamp head, and lamps hidden behind towers no longer glow through them
- Cars have wheels, windows, lights and mirrors, and the parking lots have parked cars
- Lawns, sand, concrete, paths and dock planks have finer surface texture; sand and grass look damp right by the water, and everything darkens a little in the rain
- Boats tied up in the marina slips bob on the water, and gulls circle over the water by day

## v0.6.0 · A bigger map, and a town that opens up

_Nov 17, 2026 · Builds: `UrbanFishing-v0.6.0-windows.zip`, `UrbanFishing-v0.6.0-godot-project.zip`_

- The map (M) fills the window. Zoom with the + and − buttons, the mouse wheel or the + and − keys, drag to move around, double-click to zoom in, "Whole map" and "Find me"
- The town opens in four steps, so a new game starts small:
  1. Home waters: home, Lou's, Maple Park Pond and Mullet Canal
  2. Catch 5 kinds of fish and fill one of Lou's orders: the public water opens (Back Canal, Low Street, downtown, the river, Bayfront Park, Mullet Bay and the marina), with Lou's bait tips
  3. Catch 10 kinds of fish: Lou's sneaking lesson, and the golf course, the koi pond and Heron Lakes open
  4. Land a fish at one of those guarded spots: the whole town opens
- Closed areas have "Road closed" barricades (buoy lines on water), are greyed out on the map, and their bus stops are closed. A chip in the top left says what opens the next part, and each step gets a card from Lou and a Gazette headline
- Lou's orders only ask for fish you can reach, and his story jobs at Heron Lakes and the power station wait until those areas are open
- Saves from before v0.6.0 keep the whole town open

## v0.5.0 · The old game's music

_Nov 17, 2026 · Builds: `UrbanFishing-v0.5.0-windows.zip`, `UrbanFishing-v0.5.0-godot-project.zip`, music sampler `urban-fishing-music-v0.5.0-sampler.mp3`_

- The music is now the browser version's own tunes, rendered from its Web Audio code (`tools/render_web_music.js`) with the same instruments, reverb and mix, in stereo, and in longer loops
- A music style setting like the old game's picker: Auto, Surf, Steel drum, Night prowl, Miami nights, Swamp blues, Meltdown or Yacht rock

## v0.4.0 · Music and sound

_Nov 16, 2026 · Builds: `UrbanFishing-v0.4.0-windows.zip`, sound preview `urban-fishing-sound-preview.mp4`_

- Seven music tunes that change with where you are and the time of day, fading from one to the next
- Sound effects for fishing, Lou's shop, guards, jets, thunder, the bus and the menus
- Background sounds: birds by day, crickets at night, rain
- Volume settings for master, music, effects and ambience
- All audio is made from code by `tools/make_audio.py`, so it's original to the game
- The version number now shows on the title screen and in the pause menu

## v0.3.0 · Menus and polish

_Nov 16, 2026_

- Title screen with Continue, New game, Controls, Settings and Quit
- Esc pause menu, a controls screen and settings (full screen, window size, VSync, lightning flashes), saved between runs
- Screen fades, cards that pop in, buttons that react to hover and clicks, and a "Saved" indicator
- A Windows export preset that builds a single `Urban Fishing.exe`

## v0.2.0 · Story, weather and more of the town

_Nov 16, 2026_

- Story Act I (Lou's note) and Act II (Trent Marlowe)
- Weather: rain, thunderstorms, lightning, cloud shadows. Rain makes fish bite more and guards see less
- The Mullet Bay Slam, Lou's Wall of Fame plaques, the Port Mullet Gazette
- Journal (J), map (M) and the Route 1 bus
- Guards and sneaking, kayak and skiff, Lou's orders and fish stories, the old-timer, Rosa and the marina

## v0.1.0 · First Godot version

_Nov 16, 2026_

- The whole map with a new look: water depth and shimmer, textured lawns, 3D-style skyscrapers, real night lighting
- Click-to-walk, fish shadows for all 17 spots, the fishing minigame, Lou's shop, home and saving

## Browser version · The original game

_Nov 16, 2026_

- The complete game in one file, `index.html`, that runs in any browser and saves progress there
- Port Mullet, Florida: neighborhoods, a golf course, an office park, a power station, a theme park, a gated community, an airport, downtown, the bay and offshore
- 17 fishing spots and 20 legends to catch, with guards, cameras and patrols to sneak past
- Two story acts: saving Lou's Bait & Tackle, then taking on TV angler Trent Marlowe
- Weather, a weekly tournament, a bus line, a home aquarium and achievements
- Its own Web Audio music, with a music style picker
