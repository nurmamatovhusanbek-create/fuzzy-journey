## The score (Path E1 / E2 / E4): two looped tracks (peace = plucked strings, war = drone + hand drums + brass swells; both synthesised by tools/music_score.py) that crossfade
## by mood, a very quiet sea bed while a game is on, and ducking: loud cues (war stamp, clash, victory, defeat ...) pull the music down for a moment.
## All of it plays on the "Music" bus (its slider in Settings) and stops when Sound is off. Effects Off / Reduce motion do not touch it: music is not an effect.
class_name TBMusic
extends Node

const TRACKS := {"peace": "res://assets/music/peace.ogg", "war": "res://assets/music/war.ogg"}
const SEA := "res://assets/music/sea.ogg"
const FADE := 2.5                       # seconds of a crossfade
const LEVEL_DB := -9.0                  # the score sits under the cues
const SEA_DB := -26.0
const DUCK_DB := -7.0

static var inst: TBMusic
var enabled := true : set = _set_enabled
var mood := "none"                      # none | peace | war
var _ply: Array[AudioStreamPlayer] = []     # two players: the one fading in and the one fading out
var _cur := 0
var _sea: AudioStreamPlayer
var _duck := 0.0                        # 0..1, how far the music is ducked right now
var _duck_tw: Tween
var _sea_on := false

static func set_mood_of(m: String) -> void:
	if inst != null and is_instance_valid(inst): inst.set_mood(m)

static func duck_for(seconds: float) -> void:
	if inst != null and is_instance_valid(inst): inst.duck(seconds)

func _ready() -> void:
	inst = self
	TBAudio.setup_buses()
	for i in 2:
		var p := AudioStreamPlayer.new(); p.bus = "Music"; p.volume_db = -80.0; add_child(p); _ply.append(p)
	_sea = AudioStreamPlayer.new(); _sea.bus = "Music"; _sea.volume_db = -80.0; add_child(_sea)

static func _stream(path: String) -> AudioStream:
	var s: AudioStream = load(path) as AudioStream
	if s is AudioStreamOggVorbis: (s as AudioStreamOggVorbis).loop = true
	return s

func _set_enabled(v: bool) -> void:
	enabled = v
	if not is_inside_tree(): return
	if v: _apply_mood(true)
	else: _silence()

func _silence() -> void:
	for p in _ply: p.stop(); p.volume_db = -80.0
	_sea.stop(); _sea.volume_db = -80.0

func set_mood(m: String) -> void:
	if m == mood: return
	mood = m
	if enabled: _apply_mood(false)

## the sea bed belongs to a running game (not the title, not the pick screen)
func set_sea(on: bool) -> void:
	if on == _sea_on: return
	_sea_on = on
	if not enabled or not is_inside_tree(): return
	if on:
		if _sea.stream == null: _sea.stream = _stream(SEA)
		if not _sea.playing: _sea.play()
		create_tween().tween_property(_sea, "volume_db", SEA_DB, FADE)
	else:
		var tw := create_tween(); tw.tween_property(_sea, "volume_db", -60.0, FADE); tw.tween_callback(_sea.stop)

func _apply_mood(instant: bool) -> void:
	if not is_inside_tree() or _ply.size() < 2: return
	var old: AudioStreamPlayer = _ply[_cur]
	if mood == "none" or not TRACKS.has(mood):
		_fade_out(old, instant); return
	var path: String = TRACKS[mood]
	if old.playing and old.stream != null and old.stream.resource_path == path and not instant: return
	_cur = 1 - _cur
	var nw: AudioStreamPlayer = _ply[_cur]
	nw.stream = _stream(path)
	nw.volume_db = -80.0
	nw.play(0.0 if not old.playing else fmod(old.get_playback_position(), maxf(0.1, nw.stream.get_length())))
	if instant: nw.volume_db = LEVEL_DB + _duck * DUCK_DB
	else: create_tween().tween_property(nw, "volume_db", LEVEL_DB + _duck * DUCK_DB, FADE)
	_fade_out(old, instant)
	if _sea_on and not _sea.playing: set_sea_force()

func set_sea_force() -> void:
	var on := _sea_on; _sea_on = false; set_sea(on)

func _fade_out(p: AudioStreamPlayer, instant: bool) -> void:
	if not p.playing: return
	if instant: p.stop(); return
	var tw := create_tween(); tw.tween_property(p, "volume_db", -80.0, FADE); tw.tween_callback(p.stop)

## pull the music down by DUCK_DB for a moment (a loud cue is playing) and let it back up
func duck(seconds: float) -> void:
	if not enabled: return
	if _duck_tw != null and _duck_tw.is_valid(): _duck_tw.kill()
	_duck_tw = create_tween()
	_duck_tw.tween_method(_set_duck, _duck, 1.0, 0.12)
	_duck_tw.tween_interval(maxf(0.0, seconds))
	_duck_tw.tween_method(_set_duck, 1.0, 0.0, 0.9)

func _set_duck(v: float) -> void:
	_duck = v
	var p: AudioStreamPlayer = _ply[_cur]
	if p.playing and p.volume_db > -70.0: p.volume_db = LEVEL_DB + v * DUCK_DB
