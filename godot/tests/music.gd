extends SceneTree
## E1 / E2 / E4: the score follows the mood (peace / war crossfade), loops, ducks under loud cues, the sea bed plays in a game, Sound off silences everything.
## Usage: -s tests/music.gd  (fixed fps 30)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
func _wait(sec: float) -> void:
	for i in int(sec * 30.0): await process_frame
func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["sound"] = true
	var mu: TBMusic = main.music
	main._music_t = -1.0e9                                  # the game's own once-a-second mood tick must not fight the manual calls below (it is called by hand)
	_check(mu != null and AudioServer.get_bus_index("Music") >= 0, "the music player and its bus exist")
	# --- title: peace
	main.show_menu(); await _wait(0.5)
	main._music_tick(); await _wait(3.2)
	var cur: AudioStreamPlayer = mu._ply[mu._cur]
	_check(mu.mood == "peace" and cur.playing, "title: the peace track plays")
	_check(cur.stream is AudioStreamOggVorbis and (cur.stream as AudioStreamOggVorbis).loop, "the track loops")
	_check(absf(cur.volume_db - TBMusic.LEVEL_DB) < 1.0, "it has faded in to its level (%.1f dB)" % cur.volume_db)
	_check(not mu._sea.playing, "no sea bed on the title")
	# --- crossfade to war
	var was: AudioStreamPlayer = cur
	mu.set_mood("war"); await _wait(1.0)
	var mid: AudioStreamPlayer = mu._ply[mu._cur]
	_check(mid != was and mid.playing and was.playing, "mid-crossfade both tracks sound")
	await _wait(2.5)
	_check(mu._ply[mu._cur].stream.resource_path.ends_with("war.ogg") and not was.playing, "after the crossfade only the war track plays")
	# --- ducking
	mu.duck(0.3); await _wait(0.3)
	_check(mu._ply[mu._cur].volume_db < TBMusic.LEVEL_DB - 3.0, "a cue ducks the music (%.1f dB)" % mu._ply[mu._cur].volume_db)
	await _wait(1.6)
	_check(absf(mu._ply[mu._cur].volume_db - TBMusic.LEVEL_DB) < 0.6, "and it comes back (%.1f dB)" % mu._ply[mu._cur].volume_db)
	# --- Sound off
	mu.enabled = false
	_check(not mu._ply[0].playing and not mu._ply[1].playing and not mu._sea.playing, "Sound off: silence")
	mu.enabled = true; await _wait(3.0)
	_check(mu._ply[mu._cur].playing and mu._ply[mu._cur].stream.resource_path.ends_with("war.ogg"), "Sound back on: the mood resumes")
	# --- in a game: sea bed, peace / war by the war state, silence when over
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay()
	var g: TBGame = main.g; var me: int = g.human_id
	for o in range(1, g.nat_code.size()):
		if o != me and g.at_war(me): g.set_rel(me, o, 0)
	main._music_tick(); await _wait(0.3)
	_check(mu.mood == "peace" and mu._sea.playing, "game at peace: peace track and the sea bed (%s)" % mu.mood)
	var foe := -1
	for o in range(1, g.nat_code.size()):
		if o != me and g.owner.has(o): foe = o; break
	g.set_rel(me, foe, 1)
	_check(g.at_war(me), "the human is at war")
	main._music_tick()
	_check(mu.mood == "war", "at war: the war track (%s)" % mu.mood)
	g.over = true; main._music_tick()
	_check(mu.mood == "none", "game over: the score stops (%s)" % mu.mood)
	print("MUSIC ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
