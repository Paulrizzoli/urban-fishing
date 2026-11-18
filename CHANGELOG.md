# Urban Fishing updates

Every update to Urban Fishing, newest first. This is the one file to check for what changed and when.

**How this file is kept up to date:** every change that ships gets an entry here in the same pull request, before it's merged into `main`. A new version gets its own section with the date and the build files it produced. Work that has started but isn't released yet goes under "In progress" at the top, and moves into a version section when it ships. A copy of this file is kept in the project files as `UPDATES.md`.

To make a new version, bump `config/version` in `godot/project.godot` (and the file and product version in `godot/export_presets.cfg`), add a section here, and run `tools/build_windows.sh`. It zips the game as `UrbanFishing-v<version>-windows.zip` and the Godot project as `UrbanFishing-v<version>-godot-project.zip`. The version shows on the title screen and in the pause menu. From v0.9.1 on, each update goes up by one step in the last number (v0.9.1, v0.9.2, v0.9.3 and so on).

## In progress

Nothing right now.

## Versions at a glance

| Version | Date | What it was about |
|---|---|---|
| v0.9.28 | Nov 18, 2026 | Cars and boats you can't walk or paddle through, cars that honk and then knock you down, and marina boats that head out and can roll your kayak |
| v0.9.27 | Nov 18, 2026 | Bridges you paddle under: hide in the shade, and fish under big bridges, where snook wait under the lights at night |
| v0.9.26 | Nov 18, 2026 | The whole town is open from day one: places are kept from you by gear or guards, not by progress |
| v0.9.25 | Nov 18, 2026 | Lou's bait chart the first time you walk into Lou's, and place names that fade after 5 seconds |
| v0.9.24 | Nov 18, 2026 | The storm drain tells you what you still need to get in, and the grate is easier to walk through |
| v0.9.23 | Nov 18, 2026 | A detailed town map: street names, building roofs, real shorelines, fishing spot and shop icons, a legend |
| v0.9.22 | Nov 18, 2026 | A bigger, more detailed living room, and Chum reacts when you pet him |
| v0.9.21 | Nov 18, 2026 | A picture of every piece of junk, on the catch card and in Lou's Sell tab |
| v0.9.19 | Nov 17, 2026 | Runs faster, and a Graphics quality setting (Low, Medium, High) |
| v0.9.18 | Nov 17, 2026 | Screen polish: zoom in on a hooked fish, shake on big catches, a drawing of every fish on its catch card |
| v0.9.17 | Nov 17, 2026 | Weather: wet streets and puddles, morning mist, storm clouds |
| v0.9.16 | Nov 17, 2026 | Town life: people out walking, trees in the wind, flags and fountains |
| v0.9.15 | Nov 17, 2026 | The bait or lure you have on shows on the water, a thin line, and twitching left and right |
| v0.9.14 | Nov 17, 2026 | Your house on the map, and a living room that fills up as you play |
| v0.9.13 | Nov 17, 2026 | Fish that bump off the edge and swim away instead of circling into walls |
| v0.9.12 | Nov 17, 2026 | Town traffic: cars driving the streets, with headlights at night |
| v0.9.11 | Nov 17, 2026 | A desktop icon: a bobber in a Port Mullet sunset |
| v0.9.10 | Nov 17, 2026 | Life on the water: wakes, ripples, jumping fish, a bobbing float and reflections |
| v0.9.9 | Nov 17, 2026 | Build your own rod from a blank, a reel and a grip you find around town |
| v0.9.8 | Nov 17, 2026 | A starter area you can actually get out of: manholes, the golf course, easier first orders, Lou's note on day 7 |
| v0.9.7 | Nov 17, 2026 | A round, natural-looking Maple Park Pond |
| v0.9.6 | Nov 17, 2026 | Make your own lures from parts you find around town |
| v0.9.5 | Nov 17, 2026 | Driveways from every house to the street |
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

## v0.9.28 · Watch for traffic

_Nov 18, 2026 · Builds: `UrbanFishing-v0.9.28-windows.zip`, `UrbanFishing-v0.9.28-godot-project.zip`, screenshots in `screenshots/v0.9.28/`_

- **Solid cars and boats:** you can't walk through cars any more, parked in a driveway or a lot or driving down the street, and you can't paddle or motor through the boats at the marina. Walk into one and you slide along its side instead of stopping dead, so you can get around it. Your kayak or skiff counts its whole length, not just where you sit.
- **Cars run you over:** stand in a car's lane and it honks, with sound lines in front of the bumper so you see it too. A few drivers stop and wait for you (about 3 in 10), but most slow down a little and keep coming. Still in the lane about a second after the horn and you get knocked down: you wake up on your couch at home two hours later with a bruise, and the ER bill is $25 (or whatever you have on you). Your cooler is safe. Step onto the sidewalk when you hear a horn.
- **It's always fair:** a car never hits you without honking first, and every car stops and waits while you have a line out, while a card is open and while the game is paused.
- **Boats come and go:** between about 6:30 AM and 7:30 PM, one of the three marina boats now and then backs out of its slip, turns and heads out, across Mullet Bay to the east or west or straight out offshore, with a wake behind it. A minute or two later it comes back the same way and ties up again.
- **Boats run you over too:** a boat under way blows its horn when your kayak or skiff is in its path, slows a little and keeps coming. Still in its way a moment after the horn and it rolls you over. You swim your boat to the nearest bank and drag it out, it takes about 45 minutes to dry off, and the last fish you caught slips out of the cooler (legends never do). Paddle out of its path when you hear the horn.
- Boats wait for you while they ease in and out of their slips, and while you're fishing. Sit in a boat's way long enough and it swings out around you.
- New sounds for a car horn, a boat horn and getting knocked down.

## v0.9.27 · Under the bridge

_Nov 18, 2026 · Builds: `UrbanFishing-v0.9.27-windows.zip`, `UrbanFishing-v0.9.27-godot-project.zip`, screenshots in `screenshots/v0.9.27/`_

- **Bridges you go under:** paddle your kayak or skiff through a road crossing and you slide under the bridge instead of riding across the top of the road. The deck covers you, and anything only partly under is cut off at the bridge's edge. Fish swim under bridges too, and the wake and ripples disappear under the deck.
- **You can still see yourself:** once you're under, the deck fades a little so you can see your boat, dimmed in the shade. People and cars keep crossing on top.
- **Fish under the bridge:** you can stop and cast from under a bridge, out into the open water. You can't climb out onto the bank while you're under one.
- **Shade and darker water:** the water under and beside every bridge is darker, with a shadow that fades out a couple of tiles each side. Railings with posts along the edges make the bridges look like bridges.
- **Fish like the shade:** more fish gather around bridges. A bait in the shade gets noticed from further away and bites come sooner. By day you see more mangrove snapper, sheepshead and snook there. At night the road bridges have lights, and snook and tarpon wait under them, along with the Bridge Troll.
- At night the bridge lamps throw warm light and broken glints onto the water at both ends of the shadow.
- The first time you go under a bridge, a tip pops up about fishing the shade.

## v0.9.26 · The whole town, from day one

_Nov 18, 2026 · Builds: `UrbanFishing-v0.9.26-windows.zip`, `UrbanFishing-v0.9.26-godot-project.zip`, screenshots in `screenshots/v0.9.26/`_

- **No more opening the map in steps:** every road, bus stop and body of water is open from the start. The barricades, the buoy lines, the grey "closed for now" areas on the map and the "Map: catch 5 kinds of fish" goal are gone, and so are the "Map unlocked" cards. The bus goes everywhere on day one.
- **What still keeps you out is gear or people:**
  - Gear: the storm drain needs a flashlight and waders, the manholes need a pry bar, the open ocean past the channel markers needs the skiff, and the warm outflow channel is kayak only.
  - People: every private place keeps its guards, staff, cameras and floodlights on their usual hours, so you go when they're away or bring the right disguise.
- **Each place tells you what you need:** walk into a guarded place and a line says who's watching and when it's your turn, for example "Pelican Point golf course. The groundskeeper drives his cart around 6 AM to 7 PM. Come after dark, or wear a golf polo from Lou's." The marina only says so after 9 PM, when the docks close. Paddle a kayak up to the open ocean and it tells you to get a skiff; the storm drain grate says which of the flashlight and waders you're missing.
- **Lou still teaches the small stuff:** his bait chart on your first visit, tips in the Sell tab while you've caught fewer than 5 kinds of fish (now pointing at the public water you can fish with no gear and no guards), and easy first orders until you've filled one. Lou's sneaking lesson ("Time you learned to sneak.") now shows the first time you walk onto guarded ground, with that place's hours.
- **Story:** Lou's jobs at Heron Lakes and the power station no longer wait for the map to open up.
- **Old saves:** load as they are, with the whole town open. A save that had already reached Lou's sneaking lesson doesn't see it again.

## v0.9.25 · Lou's bait chart up front, and place names that fade

_Nov 18, 2026 · Builds: `UrbanFishing-v0.9.25-windows.zip`, `UrbanFishing-v0.9.25-godot-project.zip`, screenshots in `screenshots/v0.9.25/`_

- **Lou's bait chart, right away:** the first time you walk into Lou's, before the shop opens, Lou tells you which bait catches what: "Worms catch a bit of everything. Bread for mullet, tilapia and koi. Hot dogs for catfish. Lures for bass. Live shrimp for snook, tarpon and redfish. Press B to switch." Before, you only heard this once the map opened up, after five kinds of fish and an order. Saves that are already going get it on their next visit to Lou's.
- The same bait chart is now at the top of Lou's **Gear** tab, so you can look it up any time.
- **Place names fade out:** the prompt that pops up when you walk up to Lou's, your house, the marina or a bus stop (like "Lou's Bait & Tackle. Press E or F to go in.") fades away after 5 seconds. Walk off and come back and it shows again. The button to go in stays.

## v0.9.24 · Getting into the storm drain

_Nov 18, 2026 · Builds: `UrbanFishing-v0.9.24-windows.zip`, `UrbanFishing-v0.9.24-godot-project.zip`_

- **Why you might not get in:** the storm drain needs a flashlight and waders, and it's also part of the last area of town to open. Until you land a fish at the golf course, the koi pond or Heron Lakes, the grate has a barricade on it, whatever gear you have and whatever the time. The time of day never mattered; night is just when the Sewer King bites.
- Walk up to the grate and the game now tells you what's stopping you: "The storm drain is barricaded for now. It opens with the last part of town", with what you still have to do, or which of the flashlight and waders you're missing. Before, it just didn't let you in, and walking into it with the keyboard said nothing at all.
- The grate is one tile wide, and walking straight at it with the keyboard used to snag on the wall beside it unless you were lined up almost exactly. Now you slide onto the opening and go through. The same help works at the other one-tile gates.

## v0.9.23 · A detailed town map

_Nov 18, 2026 · Builds: `UrbanFishing-v0.9.23-windows.zip`, `UrbanFishing-v0.9.23-godot-project.zip`, screenshots in `screenshots/v0.9.23/`_

- The map (M) is redrawn as a proper town map instead of blurry colored blocks:
  - **Streets** with curbs and center lines (yellow on US-1, Canal Rd and Plant Rd), broken at the crossings, and their **names** once you zoom in a little: US-1, Canal Rd, Plant Rd, Maple Park Dr, Pond St, Low Street, Airport Blvd, Egret Circle, Flamingo Ave, Second St, Bayshore Dr, Ocean Ave and Marina Way.
  - **Buildings** with their roof colors, hip roofs on the houses, flat roofs with rooftop units on the shops and offices, a helipad on One Mullet Place, rooftop pools, and shadows that get longer the taller the building is. Zoom in close and the named buildings show their names.
  - **Water** with the same rounded shores as the game, shallow to deep color, a dark shoreline and a ripple line just offshore.
  - Trees and bushes, golf greens with flags, sand traps, parking lots with their bays, driveways, docks with planks, bridge railings, fences and the Heron Lakes wall, the airport runway markings, footpaths and the storm drain.
  - **Private ground** is hatched in red with a dashed red border instead of a flat red tint.
- **Fishing spot icons** on all 16 waters you can fish (manholes are everywhere, so they don't get one). Zoom in and each shows its name and how many of its fish you've caught, like "Maple Park Pond 2/6". A gold ring means you've caught every fish there. Spots that aren't open yet are grey.
- **Shop icons** for Lou's Bait & Tackle, Mullet Bay Marina and FINTASTIC! Outdoors, and clearer bus stop icons.
- A **legend** in the corner (the new Legend button hides it) and a north arrow.
- Labels no longer pile on top of each other: when two would overlap, the less important one waits until you zoom in.
- It doesn't cost frame rate: the detailed map is drawn once, the first time you open it, into one picture. After that only the labels and your blinking dot redraw, instead of the whole map 20 times a second as before.

## v0.9.22 · A more detailed living room, and a cat who reacts

_Nov 18, 2026 · Builds: `UrbanFishing-v0.9.22-windows.zip`, `UrbanFishing-v0.9.22-godot-project.zip`_

- The living room on the home card is bigger (the card gets wider for it) and has a lot more in it:
  - A ceiling with crown molding and a **ceiling fan** that turns, with a light that comes on in the evening
  - The **front door**, with a little window, a brass knob and a GONE FISHIN' doormat
  - A **wall clock** over the door that shows the real time in the game
  - A hook by the door with a bucket hat and a landing net. Your lanyard hangs there once you have one, and your **waders** stand by the door once you buy them (before that it's a pair of flip-flops)
  - A **snake plant** between the tank and the couch, and a little cactus on the window sill
  - A **coffee table** with a mug (it steams in the morning), the remote and a fishing magazine. The rug has fringe
  - A castle and a treasure chest in the big tank
  - **Sunlight** falls through the window across the floor by day, with dust floating in it. Clouds and rain dim it
  - Wallpaper with a little dot pattern
- **Pet Chum** now does something you can see. Chum wakes up for a few seconds and does one of three things: a big stretch with his paws out front, his tail up and a yawn; a roll onto his back with all four paws wiggling in the air; or a purr with his head up, eyes squeezed happy and his tail swishing. Hearts float up each time, then he curls back up and goes back to sleep
- The tail is a smooth curve now instead of a stiff zigzag

## v0.9.21 · Pictures of the junk

_Nov 18, 2026 · Builds: `UrbanFishing-v0.9.21-windows.zip`, `UrbanFishing-v0.9.21-godot-project.zip`, screenshots in `screenshots/v0.9.21/`_

- Every one of the 31 junk catches has its own drawing now, instead of the same rusty can: the flip-flop, the shopping cart, the bike, the golf balls, the cracked phone, the rubber duck, the car keys, the Florida Man VHS, the message in a bottle, the gold tooth, the wedding ring, the HOA violation notice, the Cleveland luggage tag, the Rolex, the stock certificate and the rest.
- The drawing shows on the catch card when you reel one in, still dripping, and as the small picture next to it in Lou's Sell tab.
- (v0.9.20 is the map update, shipped separately.)

## v0.9.19 · Faster, with a graphics setting

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.19-windows.zip`, `UrbanFishing-v0.9.19-godot-project.zip`, screenshots in `screenshots/v0.9.19/`_

- The game draws a lot less each frame. Bridges, driveways, parked cars and fences used to be drawn all at once for the whole map. They're now split into blocks, and only the blocks on screen get drawn, which cuts the number of draw calls per frame from about 2,500 to about 750.
- Trees, towers, boats, flags, fountains, cars and people that are off screen no longer redraw every frame.
- New **Graphics quality** setting at the top of Settings:
  - **High:** everything on, as before.
  - **Medium:** slightly simpler water (one layer of light on the bottom instead of two), 24 cars and 28 people.
  - **Low:** much simpler water, no reflections, puddles, mist, storm cloud or lit-window glow, trees stand still, 12 cars and 14 people.
- The setting is saved with your other settings.

## v0.9.18 · Screen polish

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.18-windows.zip`, `UrbanFishing-v0.9.18-godot-project.zip`, screenshots in `screenshots/v0.9.18/`_

- When a fish bites and you're reeling it in, the camera eases in closer and leans toward the bobber. Once the fight is over, it eases back out.
- Landing a big one (12 lb or more, a new record, or a legend) gives the screen a short shake. A legend shakes it harder.
- Every catch card now shows a drawing of what you caught, all 70 kinds, each with its own shape, fins, colors and markings. Catfish have whiskers, gar have long snouts, the sailfish has its sail and the Three-Eyed Tilapia has three eyes. The crab, stingray, python, gator, rat and glowing shrimp have their own drawings, and junk shows its picture. Legends get a gold frame with sparkles.

## v0.9.17 · Weather you can see on the ground

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.17-windows.zip`, `UrbanFishing-v0.9.17-godot-project.zip`, screenshots in `screenshots/v0.9.17/`_

- Rain soaks the streets. Roads, sidewalks, the plaza and the docks go darker, puddles form and reflect the sky, and raindrops ring in the puddles while it's still raining.
- After the rain stops, the streets dry out over about four hours, and the puddles shrink as they go.
- Mist drifts over the ponds, the canal and the bay around dawn (about 5 to 8:30 AM), and spills onto the banks. It's thicker the morning after a wet day.
- On storm and rainy days the cloud shadows are bigger, darker and move faster. Low, ragged storm cloud blows across the screen, and lightning lights it up.
- Cloud shadows have soft edges now, with no rings.

## v0.9.16 · Town life

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.16-windows.zip`, `UrbanFishing-v0.9.16-godot-project.zip`, screenshots in `screenshots/v0.9.16/`_

- People walk the sidewalks and park paths. They keep to the right, stop to look around now and then, and step back if you're in their way. Some walk a dog.
- When it rains, they put up umbrellas and walk a bit slower.
- At night fewer people are out, and very late only a few.
- The leafy trees now sway and rustle, and the palms move more. On cloudy, rainy and stormy days the wind is stronger, so everything moves more.
- Flags fly outside City Hall (the Port Mullet flag with its little mullet), the marina, the golf club and Lou's. They ripple in the breeze and whip about in a storm.
- A fountain sprays in the middle of the plaza pool in front of Marlowe Tower, with a smaller one in the Bayfront Park pond. The wind blows the spray sideways.

## v0.9.15 · See what's on your hook

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.15-windows.zip`, `UrbanFishing-v0.9.15-godot-project.zip`_

- The red-and-white bobber is gone. Whatever you have on the line now sits on the water at the end of it, pointing up the line toward you, and changes when you switch bait with B:
  - **Worms**: a pink nightcrawler on the hook, both ends wriggling
  - **Live shrimp**: curled on the hook, kicking its tail, antennae out front
  - **Spinner lure**: the gold body with a silver blade that spins and flashes, and a red tuft
  - **Hot dogs**: a chunk of hot dog with a streak of mustard
  - **White bread**: a doughy ball going soft and shedding crumbs
  - **Frozen squid**: a pink strip with its tentacles trailing
  - The home-made lures look like they do at the workbench: the **spoon** wobbles and a glint slides across it, the **bottle-cap popper** pushes a little bulge of water ahead of its cup, the **feather jig**'s feathers open and close, and the **glow lure** lights up the water around it after dark
- A nibble jiggles the bait, and on a bite it gets pulled under (it fades and goes blue-green) with the "!" over it
- Your line is thin now, like the other anglers' lines, instead of a thick white cord. It's a little brighter while you're reeling, and still turns red when it's about to snap
- Twitching works like the browser game again: while you wait, **◀** (or A) twitches the lure to the left and **▶** (or D) twitches it to the right, with a little tug toward you. The lure darts across instead of jumping, tilts as it goes, and leaves a ripple. A sideways twitch draws fish in just like a forward one. Before, both arrows just pulled the lure toward you
- Tapping F / Space still twitches it toward you, and holding still reels it in
- The hint while you wait says so: "Tap to twitch the lure toward you, ◀ ▶ to twitch it left or right"
- Test hooks for checking this from the command line: `--bait=<id>`, `--bob=dx,dy[,state]` (a line already out) and `--twitch=-1|1`

## v0.9.14 · Home on the map, and a living room worth coming back to

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.14-windows.zip`, `UrbanFishing-v0.9.14-godot-project.zip`_

- Your house is on the map (M): a little yellow house with a red roof and "Home" next to it, at every zoom. A new **Home** button next to Find me jumps the map straight to it
- Going home now shows your living room, drawn in the same style as Lou's shop, and it fills up as you play:
  - **My Legends**: every legend you land gets mounted on a wooden shield above the couch, heaviest first, with an empty one waiting for the next. The card lists who's up there and how much they weighed
  - **Slam cups**: gold, silver and bronze cups on the shelf for every top-three finish at the Mullet Bay Slam
  - **The rod rack** holds every rod you own, plus the one you built yourself (with a star). The surf rod of legend glints
  - **The workbench**: the parts you've found hang on the pegboard, a lure you made sits on the bench, and a cash jar fills up with what you're carrying. Your cooler is by the door
  - **The big tank** sits under the window once you buy it, with fish like the ones you've caught swimming in it. Before that it's a goldfish bowl
  - **The window** shows the real time of day and weather: sun, dusk, the moon and stars, rain running down the glass, and a palm swaying outside. At night the room dims and the floor lamp comes on
  - **A calendar** with today's day (Slam days circled), and Lou's note taped to the window once he's called
  - **Chum**, a ginger cat asleep on the couch, breathing, flicking a tail and snoring little z's. There's a **Pet Chum** button
- The big line at the top of the home card talks about the room as it is: the legend staring at you from the wall, the tank bubbling, rain on the window, the lamp on at night

## v0.9.13 · Fish that bounce off the edges

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.13-windows.zip`, `UrbanFishing-v0.9.13-godot-project.zip`_

- Fish shadows no longer get stuck swimming into a wall or a corner over and over in a circle. When one reaches the edge it bumps off, like a ball off a wall, turns away and swims back out into open water before picking somewhere new to go
- Fish only set off for places they can reach in a straight line, so they don't aim across an island, a point or a bend in the bank
- A fish spooked by a splash now darts away along open water instead of straight into the bank behind it
- On the curved shores (the beaches, Bird Key and the round Maple Park Pond) fish keep to the water you can see, so their nose no longer pokes into the sand or grass
- A fish heading for your bait that keeps hitting the bank gives up instead of pushing into it

## v0.9.12 · Town traffic

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.12-windows.zip`, `UrbanFishing-v0.9.12-godot-project.zip`, screenshots in `screenshots/v0.9.12/`_

- Cars now drive around Port Mullet. They keep to the right-hand lane, pick a way at each crossing (straight on, left or right), slow down behind other cars and show brake lights.
- Cars stop for you when you step out in front of them, and drive off once you're out of the way.
- At night they have headlight beams and red tail lights.
- Cars that drive off the edge of the map are replaced by new ones pulling in somewhere off screen, so there are always about 30 on the roads.
- A few streets had a strip of sidewalk across them right where they met another street, so they didn't join up. Those are now proper crossings.

## v0.9.11 · A desktop icon

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.11-windows.zip`, `UrbanFishing-v0.9.11-godot-project.zip`, preview in `screenshots/v0.9.11/`_

- **Urban Fishing has its own icon.** A red-and-white bobber sits in the bay at sunset, with the Port Mullet skyline, a palm tree, and a mullet jumping beside it. It replaces the default Godot icon on the .exe, on the desktop, in the taskbar, in the window's title bar, and in the Godot project list
- At small sizes (16 to 32 pixels, like the title bar or a small taskbar) it switches to a bold, simple bobber so it still reads clearly
- The .exe's file details (right-click, Properties, Details) now say Urban Fishing and the game's version instead of Godot Engine
- The icon is drawn in `tools/icon/icon.svg` and `tools/icon/icon_small.svg`. `tools/icon/make_icon.sh` turns them into `godot/icon.png` and `godot/icon.ico`, and `tools/build_windows.sh` now puts the icon into the .exe itself (it needs Node for that)

## v0.9.10 · Life on the water

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.10-windows.zip`, `UrbanFishing-v0.9.10-godot-project.zip`, screenshots in `screenshots/v0.9.10/`_

- Your kayak and skiff leave a V-shaped wake of foam that spreads out and fades behind you. The skiff also churns the water behind the motor and pushes a bow wave.
- Rings of ripples spread out where your lure lands (smaller for a quiet cast) and where a fish goes back in.
- Every few seconds a fish jumps somewhere on screen: one of the fish shadows you can see, or out in open water. It arcs out, drips, and lands with a soft plop.
- The bobber rocks on the waves and sends out slow rings while you wait for a bite.
- Towers, flats and the marina are reflected in the water in front of them. At night their lit windows shimmer in the reflection; by day there are light streaks. Moored boats and street lamps reflect in the water too.

## v0.9.9 · Build your own rod

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.9-windows.zip`, `UrbanFishing-v0.9.9-godot-project.zip`, screenshots in `screenshots/v0.9.9/`_

- Six new parts glint around town, two places each, and come back two days after you take them:
  - fiberglass blanks (Mullet Canal, Back Canal)
  - graphite shafts (the golf course lake, the downtown river)
  - rusty spinning reels (Mullet Bay, the airport canal)
  - old baitcaster reels (Marlowe Tower's pool, the power station outflow)
  - wine corks (Bayfront Park, the downtown river)
  - pool noodles (Sunsplash, Heron Lakes)
- Junk gives rod parts too: a lost kayak paddle strips down to a fiberglass blank, and a message in a bottle gives a cork
- The workbench at home has three tabs now: Rest, Make lures and Build a rod
- Build a rod by picking a blank, a reel and a grip, then pressing Build it:
  - **Blank:** fiberglass (tension builds 18% slower) or graphite (32% slower)
  - **Reel:** spinning (reels 22% faster) or baitcaster (42% faster, and you get longer to set the hook)
  - **Grip:** duct tape (free), cork (three corks, reels a little faster) or foam (from a pool noodle, a little less tension)
- Before you build, the card shows what the rod will do and a picture of it. The best home-built rod (graphite, baitcaster, cork or foam) fishes about as well as Lou's Surf rod of legend
- A home-built rod goes straight into your hands. Switch between it and your best shop rod at the workbench. Building a new one replaces the old one
- A home-built rod is never the garage-sale rod, so legends bite on it as well as on a bought rod
- The rod in "Your kit" at Lou's and the marina shows whichever rod you're using. A home-built rod has its own picture, with the blank, reel and grip you picked and coral thread wraps

## v0.9.8 · Getting out of the starter area

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.8-windows.zip`, `UrbanFishing-v0.9.8-godot-project.zip`, screenshots in `screenshots/v0.9.8/`_

- **Manholes work.** With Lou's pry bar, walk up to any manhole cover in the street and press F to drop a line into the sewer. You jig the line instead of casting, and each manhole gives up three things a day before you have to try another one. Down there: American eels, sewer rats at night, and junk Lou pays for (car keys, a gold tooth, a wedding ring, and the Key to the City if you're lucky). The pry bar was on sale before, but manhole fishing had never been built into this version, so it did nothing
- Manholes are open from the start, and there are seven of them in the home streets
- **The golf course is open from the start.** The old-timer by the pond tells you about the gap in the golf course fence on day one, and now it's there to walk through instead of behind a road-closed barricade. Pelican Point Lake has bass, bowfin, peacock bass and golf balls Lou buys. The groundskeeper still patrols it until 7 PM. A golf course catch counts toward opening the whole town once the koi pond and Heron Lakes are open
- **Lou's first orders are ones you can fill.** Until the first part of town opens, Lou only asks for mullet, bluegill, largemouth bass, or (once you own the pry bar) eels and manhole finds, never a snook that needs live shrimp at dusk. A game saved with an order you can't fill yet gets a new one when you load it
- **Lou tells you how to catch things.** While you're still in the home waters, the Sell tab lists the fish you haven't caught yet, where they are, what they bite on and when. The order tab says where to find what Lou wants
- Largemouth bass show up more often in Maple Park Pond, and they bite on worms
- **Lou's note comes up on day 7** instead of day 3, so you have a week to find your feet before Chad Brickell shows up

## v0.9.7 · A natural Maple Park Pond

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.7-windows.zip`, `UrbanFishing-v0.9.7-godot-project.zip`, screenshots in `screenshots/v0.9.7/`_

- Maple Park Pond is a soft, uneven, rounded shape instead of a stepped rectangle, and its grassy banks meet the water along a smooth curve. The grass runs down to a muddy edge, with a little shade on the water under the bank
- The reeds and cattails grow right at the curved water line, the lily pads stay out on the water, and the grass blades stop at the bank
- The two anglers at the pond stand on the bank instead of in the water
- Heron Lakes and the golf course pond keep their straight, built edges, since they're man-made

## v0.9.6 · Home-made lures

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.6-windows.zip`, `UrbanFishing-v0.9.6-godot-project.zip`, screenshots in `screenshots/v0.9.6/`_

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
## v0.9.5 · Driveways

_Nov 17, 2026 · Builds: `UrbanFishing-v0.9.5-windows.zip`, `UrbanFishing-v0.9.5-godot-project.zip`, screenshots in `screenshots/v0.9.5/`_

- Every house has a concrete driveway out to the nearest street, with a flared apron at the curb, expansion joints, tire wear and an oil spot. Houses with no street close by, or with something in the way, go without
- About half the driveways have a car parked in them

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
