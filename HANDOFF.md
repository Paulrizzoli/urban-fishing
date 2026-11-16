# Handoff: Godot port

From the original Urban Fishing session to the "Continue the Godot port" session. Paul confirmed the handoff. The original session has stopped porting.

This branch is the same as `main` at 367df67 plus this note. Everything was already pushed; nothing is half-done.

## Layout

- `index.html` at the root is the complete browser game and the source of truth for gameplay.
- `godot/` is the Godot 4.4 project (gl_compatibility renderer, autoload `Game`). The World node is scaled 32 px per tile and everything draws in tile units. `godot/README.md` has the file map and a progress checklist.

## Finished (scripts parse, the game launches, checked with screenshots under Xvfb)

- Map, Town data, baked ground texture with a water shader, ground detail chunks, houses/flat buildings/skyscrapers, palms/oaks/bushes
- Day/night: CanvasModulate, PointLight2D lamps, lit windows on a separate CanvasLayer
- Fish shadows and the full fishing minigame, catch card, Lou's shop (sell/order/gear/story), home rest, save to `user://urban_fishing_save.json`
- Guards: all 18 watchers from `data/watch.json`, vision cones with line of sight, detection meter, busting with fines and ejection, disguises, bush and HIDE hiding, HOA car gate, airport jets, Sunsplash admission and 6 PM sweep
- King tide flooding with region-7 fish; kayak and skiff (K key) with water A* grids; marina shop; old-timer and Rosa tips; daily orders

## Not ported yet

Story Acts I and II (`SAGA`/`ACT2` in index.html), weather, Mullet Bay Slam, bus, traffic, achievements, manholes, storm drain darkness, Geiger counter and glow, golf course gator, home aquarium, map/journal, music, FINTASTIC store.

## Known gaps

- Never tested with live keyboard input, only scripted positions and screenshots.
- Boats skip some web-version details: no deep-water hint message, no manatee hooking.
- The storm drain needs flashlight and waders, but its darkness overlay isn't ported.
- `main.gd` has test-only command-line hooks, active only when passed after `--`: `--at=x,y,hour --shot=path --open=shop|gear|order|marina --land --busted --boat=kind --day=N --rosa`.
- Testing: `Godot_v4.4.1-stable_linux.x86_64` from the GitHub release works headless and under `xvfb-run` with `--rendering-driver opengl3`. On a fresh checkout, run `--import` twice so the fonts import before the scripts parse.
