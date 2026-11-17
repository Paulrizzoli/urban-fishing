# Changelog

Versions of the Godot (desktop) port of Urban Fishing. The version shows on the title screen and in the pause menu, and each Windows build is zipped as `UrbanFishing-v<version>-windows.zip`. To make a new version, bump `config/version` in `godot/project.godot` (and the file and product version in `godot/export_presets.cfg`), add a section here, and run `tools/build_windows.sh`, which also zips the Godot project as `UrbanFishing-v<version>-godot-project.zip`.

## v0.6.0 · A bigger map, and a town that opens up

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

- The music is now the browser version's own tunes, rendered from its Web Audio code (`tools/render_web_music.js`) with the same instruments, reverb and mix, in stereo, and in longer loops
- A music style setting like the old game's picker: Auto, Surf, Steel drum, Night prowl, Miami nights, Swamp blues, Meltdown or Yacht rock

## v0.4.0 · Music and sound

- Seven music tunes that change with where you are and the time of day, fading from one to the next
- Sound effects for fishing, Lou's shop, guards, jets, thunder, the bus and the menus
- Background sounds: birds by day, crickets at night, rain
- Volume settings for master, music, effects and ambience
- All audio is made from code by `tools/make_audio.py`, so it's original to the game
- The version number now shows on the title screen and in the pause menu

## v0.3.0 · Menus and polish

- Title screen with Continue, New game, Controls, Settings and Quit
- Esc pause menu, a controls screen and settings (full screen, window size, VSync, lightning flashes), saved between runs
- Screen fades, cards that pop in, buttons that react to hover and clicks, and a "Saved" indicator
- A Windows export preset that builds a single `Urban Fishing.exe`

## v0.2.0 · Story, weather and more of the town

- Story Act I (Lou's note) and Act II (Trent Marlowe)
- Weather: rain, thunderstorms, lightning, cloud shadows. Rain makes fish bite more and guards see less
- The Mullet Bay Slam, Lou's Wall of Fame plaques, the Port Mullet Gazette
- Journal (J), map (M) and the Route 1 bus
- Guards and sneaking, kayak and skiff, Lou's orders and fish stories, the old-timer, Rosa and the marina

## v0.1.0 · First Godot version

- The whole map with a new look: water depth and shimmer, textured lawns, 3D-style skyscrapers, real night lighting
- Click-to-walk, fish shadows for all 17 spots, the fishing minigame, Lou's shop, home and saving
