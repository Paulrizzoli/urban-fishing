# Urban Fishing updates

Every update to Urban Fishing, newest first. This is the one file to check for what changed and when.

**How this file is kept up to date:** every change that ships gets an entry here in the same pull request, before it's merged into `main`. A new version gets its own section with the date and the build files it produced. Work that has started but isn't released yet goes under "In progress" at the top, and moves into a version section when it ships. A copy of this file is kept in the project files as `UPDATES.md`.

To make a new version, bump `config/version` in `godot/project.godot` (and the file and product version in `godot/export_presets.cfg`), add a section here, and run `tools/build_windows.sh`. It zips the game as `UrbanFishing-v<version>-windows.zip` and the Godot project as `UrbanFishing-v<version>-godot-project.zip`. The version shows on the title screen and in the pause menu.

## In progress

Nothing right now.

## Versions at a glance

| Version | Date | What it was about |
|---|---|---|
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
