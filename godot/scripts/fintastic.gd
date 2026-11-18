class_name Fintastic
extends RefCounted
## FINTASTIC! Outdoor Megastore, downtown: Trent Marlowe's big-box store across from the marina.
## It doesn't sell Lou's basics. It sells flashy extras that go on top of them: a gold reel, a
## fighting harness, a cooler on wheels, scent spray and an energy drink that last the day, and
## a loyalty card. Brayden, the only team member, runs the register and reads the corporate
## script, mostly. When Act II ends, the store closes for good and the extras you bought keep working.

const DOOR := Vector2(88.5, 128.3)
const CLUB_OFF := 0.85
## Things that last the rest of the day: [id, name, description, price, save key]
const DAY_ITEMS := [
	["energy", "REEL DEAL energy drink", "You walk a lot faster for the rest of the day. Your heart has opinions.", 4, "buzz_day"],
	["magnet", "FISH MAGNET scent spray", "Sardine juice and glitter. For the rest of the day fish notice your bait from farther away and come over quicker.", 12, "scent_day"]]
const GREETINGS := ["Welcome to FINTASTIC! Have you heard about the Fin Club card?", "Are you finding everything FINTASTIC today?",
	"Trent's not here. He's never here.", "Welcome to FINTASTIC! Where every day is a REEL DEAL.", "Hi. Welcome. I'm supposed to say it louder."]
## Brayden off script. He goes through these in order, then starts again.
const ASIDES := [
	"Aisle 40 is just more camo. Nobody has ever reached Aisle 40 and come back the same.",
	"Don't tell corporate, but I buy my shrimp at Lou's. Ours come in a box from Ohio.",
	"The Signature Rod is glued to the wall. I asked. They said it's \"aspirational.\"",
	"Corporate makes me say the TurboReel \"changes lives.\" It does reel faster, though. That part's true.",
	"If a fish pulls hard enough to scare you, get the harness. That's not the script. That's me.",
	"I've been Team Member of the Month eleven months in a row. I'm the only team member.",
	"Fish Magnet is mostly sardine juice and glitter. It works, which is the upsetting part.",
	"The cardboard Trent fell on a customer once. We have a waiver now.",
	"The energy drink isn't technically a beverage. It's a \"performance liquid.\"",
	"The robot fish sings every eleven seconds. I counted for a whole summer. Please don't press the button.",
	"We don't buy fish. Corporate says fish are \"off brand.\" Lou buys anything with fins.",
	"The MegaCooler has cupholders. Four of them. I don't know who needs four cupholders on a cooler. You, I guess."]

static var talk_i := -1
static var sing_t := -100.0   # when the robot fish last sang (seconds)

static func closed() -> bool: return bool(Game.S.act2.get("finished", false))
static func buzzing() -> bool: return int(Game.S.get("buzz_day", 0)) == int(Game.S.day)
static func scented() -> bool: return int(Game.S.get("scent_day", 0)) == int(Game.S.day)
static func club() -> bool: return Game.S.gear.has("finclub")
static func price(p: int, id := "") -> int: return p if id == "finclub" or not club() else maxi(1, ceili(p * CLUB_OFF))
static func stock() -> Array: return Game.gear.filter(func(g): return g.get("where", "") == "fin")

static func sing() -> void: sing_t = Time.get_ticks_msec() / 1000.0
static func singing() -> bool: return Time.get_ticks_msec() / 1000.0 - sing_t < 4.0

## What Brayden says when you ask: something about you or the story if it fits, otherwise the next aside.
static func brayden_line() -> String:
	var S := Game.S
	var ctx := []
	if not club(): ctx.append("So, um. Fin Club. It's fifteen bucks, you save fifteen percent, and I get a dollar. Please.")
	else: ctx.append("Fin Club member! I'm supposed to do a little dance now. I'm not going to.")
	if buzzing(): ctx.append("You drank one, huh. Your eye is doing the thing.")
	if scented(): ctx.append("You smell like the Fish Magnet aisle. That's a compliment here.")
	if S.cooler.any(func(c): return c.get("legend", false)): ctx.append("Is that a legend in your cooler? Don't let corporate see. They'll want it stuffed for the window.")
	if int(S.act2.get("ch", 0)) > 0: ctx.append("Trent was on TV again saying Lou's legends are made up. Between us? I've seen Lou's tarpon photo. It's real.")
	if S.gear.has("turbo"): ctx.append("How's the TurboReel? Does it still make the vroom noise? Mine did that for a week.")
	talk_i += 1
	if talk_i % 3 == 2 and not ctx.is_empty(): return ctx.pick_random()
	return ASIDES[(talk_i - talk_i / 3) % ASIDES.size()]

static func greeting() -> String:
	return GREETINGS.pick_random()
