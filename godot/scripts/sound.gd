extends Node
## Autoload "Sound": music, ambience and sound effects, with Master, Music, SFX and Ambience buses.
## All the audio files are rendered from code by tools/make_audio.py.

const TRACKS := ["surf", "steel", "prowl", "reactor", "miami", "swamp", "yacht"]
const FADE := 1.6

var streams := {}
var music: Array[AudioStreamPlayer] = []
var cur := -1                # which of the two music players is live
var track := ""
var amb := {}                # "day", "night", "rain" -> AudioStreamPlayer
var reel: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var last_played := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new(); p.bus = "Music"; p.volume_db = -80; add_child(p); music.append(p)
	for k in ["day", "night", "rain"]:
		var p := AudioStreamPlayer.new(); p.bus = "Ambience"; p.volume_db = -80
		p.stream = _stream("amb_" + k, true); add_child(p); amb[k] = p
	reel = AudioStreamPlayer.new(); reel.bus = "SFX"; reel.stream = _stream("amb_reel", true); reel.volume_db = -6; add_child(reel)
	for i in 10:
		var p := AudioStreamPlayer.new(); p.bus = "SFX"; add_child(p); pool.append(p)

func _stream(name: String, loop := false) -> AudioStream:
	if not streams.has(name):
		var s: AudioStream = load("res://audio/%s.ogg" % name)
		if s is AudioStreamOggVorbis: s.loop = loop
		streams[name] = s
	return streams[name]

## Plays a one-shot effect. Small pitch changes keep repeats from sounding canned.
func play(name: String, db := 0.0, pitch_var := 0.04) -> void:
	var now := Time.get_ticks_msec()
	if now - int(last_played.get(name, -1000)) < 40: return
	last_played[name] = now
	var p: AudioStreamPlayer = null
	for q in pool:
		if not q.playing: p = q; break
	if p == null: p = pool[0]
	p.stream = _stream("sfx_" + name)
	p.volume_db = db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()

func play_later(name: String, delay: float, db := 0.0) -> void:
	get_tree().create_timer(delay).timeout.connect(func(): play(name, db, 0.08))

## Crossfades to a music track (one of TRACKS), or "" for silence.
func set_music(name: String) -> void:
	if name == track: return
	track = name
	if cur >= 0:
		var old := music[cur]
		var tw := create_tween(); tw.tween_property(old, "volume_db", -60.0, FADE); tw.tween_callback(old.stop)
	if name == "": cur = -1; return
	cur = 0 if cur != 0 else 1
	var p := music[cur]
	p.stream = _stream("music_" + name, true)
	p.volume_db = -40
	p.play(randf() * 8.0)
	create_tween().tween_property(p, "volume_db", 0.0, FADE)

## Ambience follows the clock and the weather: birds and breeze by day, crickets at night, rain.
func set_ambience(night: float, rain: float) -> void:
	_amb("day", (1.0 - night) * (1.0 - rain * 0.6))
	_amb("night", night * (1.0 - rain * 0.5))
	_amb("rain", rain)

func _amb(k: String, v: float) -> void:
	var p: AudioStreamPlayer = amb[k]
	var db := linear_to_db(maxf(v, 0.0001))
	if v < 0.02:
		if p.playing: p.volume_db = move_toward(p.volume_db, -60, 1.5)
		if p.volume_db <= -59: p.stop()
		return
	if not p.playing: p.volume_db = -50; p.play(randf() * 5)
	p.volume_db = move_toward(p.volume_db, db, 0.6)

func set_reeling(on: bool) -> void:
	if on and not reel.playing: reel.play()
	elif not on and reel.playing: reel.stop()

## Volume for a bus, 0..1.
func set_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0: return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)
