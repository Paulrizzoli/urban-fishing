# Changelog

Versions of the Godot (desktop) port of Urban Fishing. The version shows on the title screen and in the pause menu, and each Windows build is zipped as `UrbanFishing-v<version>-windows.zip`. To make a new version, bump `config/version` in `godot/project.godot` (and the file and product version in `godot/export_presets.cfg`), add a section here, and run `tools/build_windows.sh`.

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
