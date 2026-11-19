extends Node
## Every control in the game, for the keyboard and a controller, and rebinding them.
## Each action has two keyboard slots and two controller slots. The bindings live in the input map
## (so the game asks Input for "action", "bait" and so on) and are saved in settings.cfg under [controls].
## A binding is saved as a short string: "k:<physical keycode>", "b:<joypad button>", "a:<axis>:<+1|-1>", or "" for none.

signal changed

const PATH := "user://settings.cfg"
const DEADZONE := 0.3

## [id, label, group, default bindings (key, key, pad, pad)]. Actions in the same group can't share a
## binding: taking one that's in use swaps it with the other action's.
const ACTIONS := [
	["move_up", "Walk up · aim up", "play", ["k:%d" % KEY_W, "k:%d" % KEY_UP, "b:%d" % JOY_BUTTON_DPAD_UP, "a:%d:-1" % JOY_AXIS_LEFT_Y]],
	["move_down", "Walk down · aim down", "play", ["k:%d" % KEY_S, "k:%d" % KEY_DOWN, "b:%d" % JOY_BUTTON_DPAD_DOWN, "a:%d:1" % JOY_AXIS_LEFT_Y]],
	["move_left", "Walk left · aim left · twitch left", "play", ["k:%d" % KEY_A, "k:%d" % KEY_LEFT, "b:%d" % JOY_BUTTON_DPAD_LEFT, "a:%d:-1" % JOY_AXIS_LEFT_X]],
	["move_right", "Walk right · aim right · twitch right", "play", ["k:%d" % KEY_D, "k:%d" % KEY_RIGHT, "b:%d" % JOY_BUTTON_DPAD_RIGHT, "a:%d:1" % JOY_AXIS_LEFT_X]],
	["action", "Cast, hook, hold to reel · doors, talk, bus", "play", ["k:%d" % KEY_F, "k:%d" % KEY_SPACE, "b:%d" % JOY_BUTTON_A, "a:%d:1" % JOY_AXIS_TRIGGER_RIGHT]],
	["twitch_left", "Twitch the lure left", "play", ["k:%d" % KEY_Z, "", "b:%d" % JOY_BUTTON_LEFT_SHOULDER, ""]],
	["twitch_right", "Twitch the lure right", "play", ["k:%d" % KEY_X, "", "b:%d" % JOY_BUTTON_RIGHT_SHOULDER, ""]],
	["bait", "Switch bait", "play", ["k:%d" % KEY_B, "", "b:%d" % JOY_BUTTON_X, ""]],
	["boat", "Launch or land a kayak or skiff", "play", ["k:%d" % KEY_K, "", "b:%d" % JOY_BUTTON_Y, ""]],
	["map", "Map", "play", ["k:%d" % KEY_M, "", "b:%d" % JOY_BUTTON_BACK, ""]],
	["journal", "Journal", "play", ["k:%d" % KEY_J, "", "a:%d:1" % JOY_AXIS_TRIGGER_LEFT, ""]],
	["back", "Close a card · reel your line in", "play", ["k:%d" % KEY_BACKSPACE, "", "b:%d" % JOY_BUTTON_B, ""]],
	["pause", "Pause menu · close a card", "play", ["k:%d" % KEY_ESCAPE, "", "b:%d" % JOY_BUTTON_START, ""]],
	["fullscreen", "Full screen on or off", "play", ["k:%d" % KEY_F11, "", "", ""]],
	["zoom_in", "Map: zoom in", "map", ["k:%d" % KEY_EQUAL, "k:%d" % KEY_KP_ADD, "b:%d" % JOY_BUTTON_RIGHT_SHOULDER, ""]],
	["zoom_out", "Map: zoom out", "map", ["k:%d" % KEY_MINUS, "k:%d" % KEY_KP_SUBTRACT, "b:%d" % JOY_BUTTON_LEFT_SHOULDER, ""]],
]

var binds := {}               # action id -> Array of 4 binding strings
var pad := false              # the last thing pressed was on a controller (hints name its buttons then)
var capturing := ""           # the action waiting for a new binding, or ""
var cap_slot := -1
var cap_since := 0      # the frame the capture started on
var cap_done: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# menus: A picks, B goes back, the left stick and D-pad move between buttons (Godot only does the last part itself)
	_add_ui("ui_accept", _joy_button(JOY_BUTTON_A))
	_add_ui("ui_cancel", _joy_button(JOY_BUTTON_B))
	reset(false)
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK and cf.has_section("controls"):
		for a in ACTIONS:
			var v = cf.get_value("controls", a[0], null)
			if v is Array and v.size() == 4: binds[a[0]] = v.map(func(x): return str(x))
	apply()

func _add_ui(action: String, ev: InputEvent) -> void:
	if InputMap.has_action(action) and not InputMap.action_has_event(action, ev): InputMap.action_add_event(action, ev)

## Back to the default controls.
func reset(save := true) -> void:
	for a in ACTIONS: binds[a[0]] = (a[3] as Array).duplicate()
	if save: apply(); store()

## Puts the bindings into the input map.
func apply() -> void:
	for a in ACTIONS:
		var id: String = a[0]
		if InputMap.has_action(id): InputMap.erase_action(id)
		InputMap.add_action(id, DEADZONE)
		for b in binds[id]:
			var ev := to_event(b)
			if ev: InputMap.action_add_event(id, ev)
	changed.emit()

func store() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)    # keep the other settings in the file
	for a in ACTIONS: cf.set_value("controls", a[0], binds[a[0]])
	cf.save(PATH)

static func _joy_button(i: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new(); e.device = -1; e.button_index = i as JoyButton; return e

static func to_event(b: String) -> InputEvent:
	var p := b.split(":")
	match p[0]:
		"k":
			var e := InputEventKey.new(); e.device = -1; e.physical_keycode = int(p[1]) as Key; return e
		"b": return _joy_button(int(p[1]))
		"a":
			var e := InputEventJoypadMotion.new(); e.device = -1; e.axis = int(p[1]) as JoyAxis; e.axis_value = signf(float(p[2])); return e
	return null

## The binding an input event would be saved as, or "" if it can't be one.
static func from_event(e: InputEvent) -> String:
	if e is InputEventKey: return "k:%d" % (e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode)
	if e is InputEventJoypadButton: return "b:%d" % e.button_index
	if e is InputEventJoypadMotion and absf(e.axis_value) > 0.6: return "a:%d:%d" % [e.axis, 1 if e.axis_value > 0 else -1]
	return ""

const BUTTONS := { JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓", JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
	JOY_BUTTON_MISC1: "Share", JOY_BUTTON_PADDLE1: "Paddle 1", JOY_BUTTON_PADDLE2: "Paddle 2", JOY_BUTTON_PADDLE3: "Paddle 3", JOY_BUTTON_PADDLE4: "Paddle 4", JOY_BUTTON_TOUCHPAD: "Touchpad" }
const KEYS := { KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→", KEY_ESCAPE: "Esc", KEY_BACKSPACE: "Backspace", KEY_EQUAL: "=", KEY_MINUS: "Minus",
	KEY_KP_ADD: "Num +", KEY_KP_SUBTRACT: "Num −" }

## A binding's name as players know it: "F", "Space", "A", "RT", "Left stick ←".
static func name_of(b: String) -> String:
	var p := b.split(":")
	match p[0]:
		"k":
			var k := int(p[1])
			return KEYS[k] if KEYS.has(k) else OS.get_keycode_string(k)
		"b": return BUTTONS.get(int(p[1]), "Button %d" % int(p[1]))
		"a":
			var ax := int(p[1]); var s := int(p[2])
			match ax:
				JOY_AXIS_TRIGGER_LEFT: return "LT"
				JOY_AXIS_TRIGGER_RIGHT: return "RT"
				JOY_AXIS_LEFT_X: return "Left stick " + ("→" if s > 0 else "←")
				JOY_AXIS_LEFT_Y: return "Left stick " + ("↓" if s > 0 else "↑")
				JOY_AXIS_RIGHT_X: return "Right stick " + ("→" if s > 0 else "←")
				JOY_AXIS_RIGHT_Y: return "Right stick " + ("↓" if s > 0 else "↑")
			return "Axis %d %s" % [ax, "+" if s > 0 else "−"]
	return "—"

## The key or button for an action on the device you're using, for hints: "F", or "A" on a controller.
## Falls back to the other device's binding if this one has none.
func k(id: String) -> String:
	var b: Array = binds.get(id, ["", "", "", ""])
	for i in ([2, 3, 0, 1] if pad else [0, 1, 2, 3]):
		if b[i] != "": return name_of(b[i])
	return "?"

## Both bindings on the device you're using: "F or Space".
func k2(id: String) -> String:
	var b: Array = binds.get(id, ["", "", "", ""])
	var names := []
	for i in ([2, 3] if pad else [0, 1]):
		if b[i] != "": names.append(name_of(b[i]))
	return " or ".join(names) if not names.is_empty() else k(id)

## "WASD" / "the arrows" / "the left stick", for walking and aiming hints.
func move_text() -> String:
	if pad: return "the left stick" if binds.move_left.has("a:%d:-1" % JOY_AXIS_LEFT_X) else "%s %s %s %s" % [k("move_up"), k("move_left"), k("move_down"), k("move_right")]
	return "%s%s%s%s" % [k("move_up"), k("move_left"), k("move_down"), k("move_right")] if binds.move_up[0] == "k:%d" % KEY_W else "%s %s %s %s" % [k("move_up"), k("move_left"), k("move_down"), k("move_right")]

## Left / right as you'd say it on this device: "◀ ▶", or "LB / RB" on a controller.
func twitch_text() -> String:
	return "%s / %s" % [k("twitch_left"), k("twitch_right")] if pad else "◀ ▶"

func label_of(id: String) -> String:
	for a in ACTIONS: if a[0] == id: return a[1]
	return id

## Waits for the next key (slots 0 and 1) or controller button or stick push (slots 2 and 3) and binds it.
## Esc cancels, Delete clears the slot. done is called once it's over.
func capture(id: String, slot: int, done: Callable) -> void:
	capturing = id; cap_slot = slot; cap_since = Engine.get_process_frames(); cap_done = done

func _input(e: InputEvent) -> void:
	if e is InputEventJoypadButton and e.pressed: pad = true
	elif e is InputEventJoypadMotion and absf(e.axis_value) > 0.5: pad = true
	elif (e is InputEventKey and e.pressed) or (e is InputEventMouseButton and e.pressed): pad = false
	if capturing == "": return
	get_viewport().set_input_as_handled()
	# not the press that started it (only new presses count, so letting go of it does nothing either)
	if Engine.get_process_frames() - cap_since < 2: return
	var b := ""
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_ESCAPE and (cap_slot >= 2 or capturing != "pause"): _end_capture(); return
		if e.physical_keycode == KEY_DELETE: _bind(capturing, cap_slot, ""); _end_capture(); return
		if cap_slot >= 2: return
		b = from_event(e)
	elif e is InputEventMouseButton and e.pressed: _end_capture(); return
	elif cap_slot >= 2 and ((e is InputEventJoypadButton and e.pressed) or e is InputEventJoypadMotion):
		b = from_event(e)
	if b == "": return
	_bind(capturing, cap_slot, b)
	_end_capture()

func _end_capture() -> void:
	capturing = ""; cap_slot = -1
	apply(); store()
	if cap_done.is_valid(): cap_done.call_deferred()

func _group(id: String) -> String:
	for a in ACTIONS: if a[0] == id: return a[2]
	return ""

## Sets one slot. If another action in the same group has this binding, it gets this slot's old one.
func _bind(id: String, slot: int, b: String) -> void:
	var old: String = binds[id][slot]
	if b != "":
		for a in ACTIONS:
			if a[2] != _group(id): continue
			var other: Array = binds[a[0]]
			for i in 4:
				if other[i] == b and not (a[0] == id and i == slot):
					# the same action holding it in its other slot: just clear that one
					other[i] = "" if a[0] == id else old
	binds[id][slot] = b
