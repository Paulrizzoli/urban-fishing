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
- **K** to launch or land a kayak or skiff
- **M** for the map, **J** for the journal (spots, Lou's Wall of Fame, the Gazette)
- **Esc** opens the pause menu (resume, controls, settings, save and quit), or closes a card
- **F11** switches full screen on and off

## What's ported so far

- [x] The whole map: town, golf course, power station, Sunsplash Jungle, Heron Lakes, the airport, downtown, the bay and offshore
- [x] New look: smooth water depth, an animated water shader, textured lawns, roofs, 3D-style skyscrapers
- [x] Day and night with real 2D lights: street lamps, lit office windows, dusk glow
- [x] Fish shadows in every body of water, all 17 spots' fish and legends
- [x] The fishing minigame: aim, cast power, twitching, nibble and bite, the reel fight
- [x] Lou's shop (sell and gear), home (rest), saving
- [x] Guards, cameras, floodlights and patrols with vision cones, the detection meter and fines
- [x] Hiding in bushes, disguises (polo, lanyard, suit), the HOA resident's car, jets over the airport
- [x] Sunsplash Jungle's admission fee and closing sweep (hide in the restroom)
- [x] The king tide flooding Low Street, with its own fish
- [x] Lou's daily orders and fish stories, the old-timer's tips and Rosa on the pier
- [x] Kayak and skiff (press K at the water), the marina shop
- [x] Story Act I (Lou's note) and Act II (Trent Marlowe), with illustrated story cards and the "Lou's note" tab
- [x] Weather: sunny, cloudy, rainy days and afternoon thunderstorms with rain, lightning, raindrop rings and cloud shadows. Rain makes fish bite more and guards see less
- [x] The Mullet Bay Slam every seventh day at the marina, Lou's Wall of Fame plaques, the Port Mullet Gazette
- [x] The Route 1 bus and its five stops
- [x] Map (M) and journal (J)
- [ ] Traffic, FINTASTIC! and the energy drink
- [ ] Manholes, the storm drain's darkness, the power station's Geiger counter, golf course gator, home aquarium
- [x] Title screen, pause menu, controls screen, settings (full screen, window size, VSync, lightning flashes), fades and a save indicator
- [ ] Music and sound (and a volume setting)
- [ ] Real art to replace the code-drawn shapes

## How it's built

Everything is drawn in tile units. The `World` node is scaled to 32 pixels per tile.

- `scripts/town.gd` builds the map: tiles, water regions, private zones and buildings
- `scripts/ground.gd` bakes the ground into one texture; `ground_chunk.gd` draws fine detail per 8×8 chunk
- `scripts/art.gd` has the drawing code for buildings, plants, people and fish
- `scripts/fishing.gd` runs the fish shadows and the fishing minigame
- `scripts/guards.gd` runs everyone who keeps you off private water
- `scripts/story.gd` has both story acts, the Wall of Fame plaques, the Mullet Bay Slam and the bus; `story_art.gd` draws the story card pictures
- `scripts/weather.gd` works out each day's weather and draws rain, lightning and cloud shadows
- `scripts/menu.gd` is the title screen, pause menu, controls, settings and screen fades
- `scripts/hud.gd` is the UI; `scripts/main.gd` wires it all together
- `data/*.json` holds the fish, gear and bait tables, exported from the browser version

## Testing from the command line

`main.gd` has test hooks, read only when passed after `--`. For example:

```
godot --path . --resolution 1280x720 -- --at=12,15.5,15 --day=5 --shot=storm.png
```

starts at tile (12, 15.5) at 3 PM on day 5 (a thunderstorm day), saves a screenshot after 90 frames and quits. Other hooks: `--open=shop|gear|order|note|marina|marina-slam|journal|fame|news|map|bus`, `--story=N` and `--act2=N` (jump to a story chapter), `--weigh` (enter and weigh in at the Slam), `--land`, `--cast`, `--busted`, `--boat=kayak|skiff`, `--rosa`, `--toast`, `--title`, `--pause`, `--controls`, `--settings`. Run `--import` twice on a fresh checkout so the fonts import before the scripts parse.
