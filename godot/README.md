# Urban Fishing (Godot version)

The desktop version of Urban Fishing, being ported from the browser game (`../index.html`) to Godot 4.

## Open it on Windows

1. Download **Godot 4.4** (the standard version, not .NET) from https://godotengine.org/download/windows/ and unzip it. There's nothing to install. Just run `Godot_v4.4.x-stable_win64.exe`.
2. In the Project Manager, click **Import**, browse to this `godot` folder, pick `project.godot`, and click **Import & Edit**.
3. Press **F5** (or the ▶ button at the top right) to play.

The first time you open it, Godot takes a few seconds to import the fonts.

## Make a Windows .exe

1. In Godot: **Project → Export… → Add… → Windows Desktop**.
2. If it says export templates are missing, click **Manage Export Templates → Download and Install**.
3. Click **Export Project**, pick a folder, and you get `Urban Fishing.exe` that runs on any Windows PC.

## Controls

- **WASD / arrow keys** to walk, or **click** where you want to go
- **F / Space / E** to cast, hook, reel, and to go through doors
- **◀ ▶** to aim a cast, twitch the lure, or pull against a running fish
- **B** to switch bait
- **Esc** closes a menu

## What's ported so far

- [x] The whole map: town, golf course, power station, Sunsplash Jungle, Heron Lakes, the airport, downtown, the bay and offshore
- [x] New look: smooth water depth, an animated water shader, textured lawns, roofs, 3D-style skyscrapers
- [x] Day and night with real 2D lights: street lamps, lit office windows, dusk glow
- [x] Fish shadows in every body of water, all 17 spots' fish and legends
- [x] The fishing minigame: aim, cast power, twitching, nibble and bite, the reel fight
- [x] Lou's shop (sell and gear), home (rest), saving
- [ ] Guards, cameras and patrols
- [ ] Lou's orders and fish stories, the old-timer
- [ ] Kayak and skiff
- [ ] Story Act I and Act II
- [ ] Weather, the Mullet Bay Slam, the bus, traffic and achievements
- [ ] Map and journal, music and sound
- [ ] Real art to replace the code-drawn shapes

## How it's built

Everything is drawn in tile units. The `World` node is scaled to 32 pixels per tile.

- `scripts/town.gd` builds the map: tiles, water regions, private zones and buildings
- `scripts/ground.gd` bakes the ground into one texture; `ground_chunk.gd` draws fine detail per 8×8 chunk
- `scripts/art.gd` has the drawing code for buildings, plants, people and fish
- `scripts/fishing.gd` runs the fish shadows and the fishing minigame
- `scripts/hud.gd` is the UI; `scripts/main.gd` wires it all together
- `data/*.json` holds the fish, gear and bait tables, exported from the browser version
