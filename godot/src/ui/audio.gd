## Tiny synthesised sound set (no asset files): bells, a gong, a growl. Generated once at startup, 22 kHz mono.
class_name TBAudio
extends Node

const RATE := 22050
## Buses (A11Y-AUD-001): Master (+ limiter, AUD-003) and the Music / SFX / UI children, each with its own 0-100 % slider (default 80).
## Cues: tap and coin are UI sounds, everything else SFX; Music is created for the score that does not exist yet.
const BUSES := ["Music", "SFX", "UI"]
const UI_CUES := ["tap", "coin"]
var enabled := true
static var inst: TBAudio                      # the game's one sound player; TBAudio.cue("name") plays a cue from anywhere (nothing when sound is off / there is no player)
var _snd := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

static func cue(name: String) -> void:
	if inst != null and is_instance_valid(inst): inst.play(name)

func _ready() -> void:
	inst = self
	setup_buses()
	for i in 4:
		var p := AudioStreamPlayer.new(); p.volume_db = -8.0; add_child(p); _players.append(p)
	_build.call_deferred()

## idempotent: creates the missing buses and the Master limiter
static func setup_buses() -> void:
	for nm in BUSES:
		if AudioServer.get_bus_index(nm) < 0:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nm); AudioServer.set_bus_send(i, "Master")
	var has_lim := false
	for e in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, e) is AudioEffectLimiter: has_lim = true
	if not has_lim: AudioServer.add_bus_effect(0, AudioEffectLimiter.new())

## percent 0-100 -> bus volume (0 = silent); name is Master / Music / SFX / UI
static func set_volume(bus_name: String, percent: float) -> void:
	var i: int = AudioServer.get_bus_index(bus_name)
	if i < 0: return
	var lin: float = clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(i, lin <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.0001)))

## apply cfg vol_master / vol_music / vol_sfx / vol_ui (default 80)
static func apply_volumes(cfg: Dictionary) -> void:
	set_volume("Master", float(cfg.get("vol_master", 80)))
	set_volume("Music", float(cfg.get("vol_music", 80)))
	set_volume("SFX", float(cfg.get("vol_sfx", 80)))
	set_volume("UI", float(cfg.get("vol_ui", 80)))

func _build() -> void:
	_snd["tap"] = _tone([[1320.0, 1.0], [1980.0, 0.3]], 0.07, 0.002, 38.0)
	_snd["coin"] = _seq([[1760.0, 0.06], [2349.0, 0.14]], 0.8)
	_snd["turn"] = _tone([[110.0, 1.0], [164.0, 0.6], [221.0, 0.45], [331.0, 0.25]], 1.1, 0.01, 4.2)
	_snd["event"] = _tone([[523.0, 1.0], [784.0, 0.5], [1046.0, 0.35]], 0.9, 0.005, 5.0)
	_snd["alert"] = _seq([[880.0, 0.1], [660.0, 0.22]], 0.9)
	_snd["war"] = _growl(0.45)
	_snd["win"] = _seq([[523.0, 0.12], [659.0, 0.12], [784.0, 0.12], [1046.0, 0.5]], 0.9)
	# B-path cues: the war stamp, a clash, a province won / lost, a defeat, a page turned, a treaty bell, a low treasury
	_snd["stamp"] = _mix([_tone([[68.0, 1.0], [136.0, 0.4]], 0.5, 0.002, 12.0, 0.9), _burst(0.12, 30.0, 0.5)])
	_snd["clash"] = _mix([_tone([[620.0, 1.0], [1480.0, 0.6], [2300.0, 0.35]], 0.4, 0.001, 13.0, 0.6), _burst(0.15, 24.0, 0.4)])
	_snd["gain"] = _seq([[587.0, 0.08], [880.0, 0.18]], 0.8)
	_snd["loss"] = _seq([[392.0, 0.12], [262.0, 0.28]], 0.8)
	_snd["defeat"] = _tone([[196.0, 1.0], [233.0, 0.6], [294.0, 0.4]], 1.5, 0.02, 2.4)
	_snd["page"] = _burst(0.2, 16.0, 0.22)
	_snd["bell"] = _tone([[1046.0, 1.0], [1568.0, 0.5], [2093.0, 0.25]], 1.0, 0.003, 4.0)
	_snd["low"] = _seq([[523.0, 0.1], [440.0, 0.1], [349.0, 0.25]], 0.7)

func play(name: String) -> void:
	if not enabled or not _snd.has(name) or _players.is_empty(): return
	var p := _players[_next]; _next = (_next + 1) % _players.size()
	p.bus = "UI" if name in UI_CUES else "SFX"
	p.stream = _snd[name]; p.play()

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var b := PackedByteArray(); b.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampi(int(samples[i] * 30000.0), -32767, 32767)
		b[i * 2] = v & 0xFF; b[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = b
	return w

## additive partials with attack + exponential decay
func _tone(partials: Array, dur: float, attack: float, decay: float, gain: float = 0.5) -> AudioStreamWAV:
	var n := int(dur * RATE); var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / attack) * exp(-decay * t)
		var v := 0.0
		for p in partials: v += sin(TAU * p[0] * t) * p[1]
		s[i] = v * env * gain / maxf(1.0, partials.size() * 0.6)
	return _wav(s)

func _seq(notes: Array, gain: float) -> AudioStreamWAV:
	var all := PackedFloat32Array()
	for nt in notes:
		var n := int(float(nt[1]) * RATE); var seg := PackedFloat32Array(); seg.resize(n)
		for i in n:
			var t := float(i) / RATE
			seg[i] = (sin(TAU * nt[0] * t) + 0.35 * sin(TAU * nt[0] * 2.0 * t)) * minf(1.0, t / 0.004) * exp(-9.0 * t) * 0.4 * gain
		all.append_array(seg)
	all.append_array(PackedFloat32Array([0.0, 0.0]))
	# let the last note ring
	var tail := int(0.25 * RATE)
	var last: float = notes[notes.size() - 1][0]
	for i in tail: all.append(sin(TAU * last * float(i) / RATE) * exp(-12.0 * float(i) / RATE) * 0.1 * gain)
	return _wav(all)

## a burst of noise (a deterministic generator), exponential decay
func _burst(dur: float, decay: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE); var s := PackedFloat32Array(); s.resize(n)
	var seed_v := 12345
	for i in n:
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var t := float(i) / RATE
		s[i] = (float(seed_v) / 1073741823.5 - 1.0) * exp(-decay * t) * gain
	return _wav(s)

## add several generated sounds into one (the longest sets the length)
func _mix(list: Array) -> AudioStreamWAV:
	var n := 0
	for w in list: n = maxi(n, (w as AudioStreamWAV).data.size() / 2)
	var out := PackedFloat32Array(); out.resize(n)
	for w in list:
		var d: PackedByteArray = (w as AudioStreamWAV).data
		for i in d.size() / 2:
			var v: int = d[i * 2] | (d[i * 2 + 1] << 8)
			if v >= 32768: v -= 65536
			out[i] += float(v) / 30000.0
	return _wav(out)

func _growl(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE); var s := PackedFloat32Array(); s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += (95.0 - 30.0 * t) / RATE
		var saw := fposmod(ph, 1.0) * 2.0 - 1.0
		s[i] = (saw * 0.55 + sin(TAU * 47.0 * t) * 0.4) * minf(1.0, t / 0.02) * exp(-4.0 * t) * 0.6
	return _wav(s)
