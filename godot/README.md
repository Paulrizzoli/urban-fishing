# Urban Fishing (Godot version)

The desktop version of Urban Fishing, being ported from the browser game (`../index.html`) to Godot 4.

## Open it on Windows

1. Download **Godot 4.4** (the standard version, not .NET) from https://godotengine.org/download/windows/ and unzip it. There's nothing to install. Just run `Godot_v4.4.x-stable_win64.exe`.
2. In the Project Manager, click **Import**, browse to this `godot` folder, pick `project.godot`, and click **Import & Edit**.
3. Press **F5** (or the ▶ button at the top right) to play.

The first time you open it, Godot takes a few seconds to import the fonts.

## Versions

The current version is in `project.godot` (`config/version`) and shows on the title screen. See `../CHANGELOG.md` for what changed in each one. `../tools/build_windows.sh <godot binary> <folder>` exports the game and zips it as `UrbanFishing-v<version>-windows.zip`, plus the Godot project as `UrbanFishing-v<version>-godot-project.zip`.

## Make a Windows .exe

1. In Godot: **Project → Export… → Add… → Windows Desktop**.
2. If it says export templates are missing, click **Manage Export Templates → Download and Install**.
3. Click **Export Project**, pick a folder, and you get `Urban Fishing.exe` that runs on any Windows PC.

## Controls

- **WASD / arrow keys** to walk, or **click** where you want to go
- **F / Space / E** to cast, hook, reel, and to go through doors
- **Arrows** (or the mouse) to move the cast marker, up to as far as your rod reaches
- **◀ ▶** to twitch the lure in to the left or right, or pull against a running fish
- **B** to switch bait
- **K** to launch or land a kayak or skiff
- **M** for the map, **J** for the journal (spots, Lou's Wall of Fame, the Gazette)
- **Esc** opens the pause menu (resume, controls, settings, save and quit), or closes a card
- **F11** switches full screen on and off

## What's ported so far

- [x] The whole map: town, golf course, power station, Sunsplash Jungle, Heron Lakes, the airport, downtown, the bay and offshore
- [x] New look: smooth water depth, an animated water shader, textured lawns, roofs, 3D-style skyscrapers
- [x] v0.7.0 graphics pass: rippling water with caustics, foam and glints, lily pads and reeds, detailed houses, roofs and towers, worn streets with curbs, drains and manholes, lamp posts, parked cars, moored boats and gulls
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
- [x] Traffic, FINTASTIC! (walk in, Brayden, the flashy extras) and the energy drink
- [ ] Manholes, the storm drain's darkness, the power station's Geiger counter, golf course gator, home aquarium
- [x] Title screen, pause menu, controls screen, settings (full screen, window size, VSync, lightning flashes), fades and a save indicator
- [x] Ironwater (v0.9.34) and Gannet Harbor (v0.9.42), two more towns reached by coach
- [x] Music and sound: seven tunes that change with where you are and the time of day, sound effects, day, night and rain ambience, and volume settings
- [ ] Real art to replace the code-drawn shapes

## How it's built

Everything is drawn in tile units. The `World` node is scaled to 32 pixels per tile.

- `scripts/town.gd` builds the map: tiles, water regions, private zones and buildings. `Town.level` picks the town: 0 is Port Mullet, 1 is Ironwater, which `scripts/ironwater.gd` lays out (dam and spillway, river, the high viaduct, mill, brewery, ballpark), with its guards in `data/watch2.json`, and 2 is Gannet Harbor, which `scripts/gannet.gd` lays out (the harbor, the fish market wharf, the ferry slip, the Narrows suspension bridge, the outfall, the container port, the rooftop garden), with its guards in `data/watch3.json`. Fishing spots 1-19 are Port Mullet's, 20-29 Ironwater's and 30-37 Gannet Harbor's (`Town.spot_town`), and every spot needs a fish count in `Fishing.SHCOUNT` or no fish spawn there
- `scripts/ground.gd` bakes the ground into one texture; `ground_chunk.gd` draws fine detail per 8×8 chunk
- `scripts/art.gd` has the drawing code for buildings, plants, people and fish
- `scripts/fishing.gd` runs the fish shadows and the fishing minigame; `lure_art.gd` draws the bait or lure on the end of your line
- `scripts/guards.gd` runs everyone who keeps you off private water
- `scripts/story.gd` has both story acts, the Wall of Fame plaques, the Mullet Bay Slam and the bus; `story_art.gd` draws the story card pictures
- `scripts/bridges.gd` has the bridges you paddle under (and Gannet Harbor's suspension bridge, drawn with its towers and cables): the decks drawn over boats and fish, the shade and dark water under them, the bridge lights, and which fish gather there
- `scripts/weather.gd` works out each day's weather and draws rain, lightning and cloud shadows
- `scripts/menu.gd` is the title screen, pause menu, controls, settings and screen fades
- `scripts/sound.gd` (autoload `Sound`) plays the music, ambience and effects; `scripts/soundscape.gd` turns up the sounds around you (surf, gulls, the spillway, the mill, the ballpark, fountains, cars, boats, footsteps, the drag and the line, guards' shouts) by how close they are
- `scripts/home_art.gd` draws the living room on the home card (trophy wall, rod rack, workbench, tank, the cat)
- `scripts/map_view.gd` is the big map (M); `scripts/map_art.gd` draws its detailed picture once, into a texture
- `scripts/hud.gd` is the UI; `scripts/main.gd` wires it all together
- `data/*.json` holds the fish, gear and bait tables, exported from the browser version
- `../tools/playtest.sh <godot binary> <scenario>` plays the game headless with a bot that presses keys and buttons like a player (a new game through all three towns, every fishing spot, the skiff, every door and stop, cars and guards) and prints anything that goes wrong; `../tools/check_routes.gd` checks that guards and walkers stay on land

## Testing from the command line

`main.gd` has test hooks, read only when passed after `--`. For example:

```
godot --path . --resolution 1280x720 -- --at=12,15.5,15 --day=5 --shot=storm.png
```

starts at tile (12, 15.5) at 3 PM on day 5 (a thunderstorm day), saves a screenshot after 90 frames and quits. Other hooks: `--open=buy:<id>[:sell|menu|board|talk]` and `--open=board:<id>` (a restaurant or fish market from `data/buyers.json`), `--cooler=fresh` (a cooler of today's catch from the town you're in), `--open=shop|gear|order|note|marina|marina-slam|journal|fame|news|map|bus|home|bench|rodbench`, `--mapview=zoom,x,y` (with `--open=map`), `--legends=N` and `--slam=1,2,3` (fill the trophy wall and cup shelf at home), `--pet=kind,seconds` (hold Chum's reaction for a screenshot), `--story=N` and `--act2=N` (jump to a story chapter), `--weigh` (enter and weigh in at the Slam), `--land`, `--cast`, `--busted`, `--boat=kayak|skiff`, `--face=degrees` (which way you face, 0 is right), `--bait=<id>`, `--bob=dx,dy[,state]`, `--twitch=-1|1`, `--guards=seconds` (move every patrol that far along its route), `--rosa`, `--toast`, `--sounddebug` (print the loops and effects as they play), `--sounddemo=cast|fight|guard|bat` (a scripted bit for the sound preview, with `--sounddir=degrees` for which way to cast), `--title`, `--pause`, `--controls`, `--settings`, `--level=N` (start in town N), `--coach=N` (ride the coach to town N), `--fresh-iw` / `--fresh-gh` (see a town's welcome card again), `--open=catches=N` (every fish and bit of junk in town N, drawn as on the catch card) and `--fishcount` (print how many fish shadows each spot has when the shot is taken, to check that fish spawn everywhere). Run `--import` twice on a fresh checkout so the fonts import before the scripts parse.

## Music and sound

The music (`audio/music_*.ogg`) is the browser version's own tunes: `../tools/render_web_music.js` runs the `Music` code from `index.html` in headless Chromium with an OfflineAudioContext and saves each style as a long, seamless loop. Run `node tools/render_web_music.js` from the repo root after changing the browser music (needs Playwright and ffmpeg; it takes a few minutes). The sound effects and ambience are made by `../tools/make_audio.py`, which synthesizes them from code with oscillators, filtered noise and a small reverb; run `python3 tools/make_audio.py` (needs numpy, scipy and ffmpeg), or name the sounds to render just those, e.g. `python3 tools/make_audio.py sfx_horn`. `tools/make_sound_preview.sh <godot> <out.mp4>` records a captioned preview of the sound with Godot's movie writer. Nothing is sampled or downloaded, so all the audio is original to this game.
