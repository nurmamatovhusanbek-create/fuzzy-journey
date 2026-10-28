extends SceneTree
## Alert cues: a new alert plays its cue once (the most severe new one per refresh), a game starts silent, offers get a soft knock, every cue exists and has sound.
var fails := 0
var got: Array = []
func _check(cond: bool, what: String) -> void:
	if not cond: print("FAIL: ", what); fails += 1
func _e(key: String, id: String, cls: String, sev: int) -> Dictionary:
	return {"key": key, "cls": cls, "sev": sev, "id": id, "p": -1, "n": -1, "k": 0, "uid": -1, "ps": [], "ult": false, "text": id}
func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720)); root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 10: await process_frame
	var hud = main.hud
	hud.cue.connect(func(n: String): got.append(n))
	# every cue the alerts can ask for exists and has some length
	for cn in ["war", "coalition", "capital", "low", "unrest", "loss", "alert", "offer"]:
		_check(main.sfx._snd.has(cn) and (main.sfx._snd[cn] as AudioStreamWAV).data.size() > 200, "cue '%s' exists with sound" % cn)
	_check(hud.cue_for(_e("a:coalition", "coalition", "alert", 2)) == "coalition", "coalition -> coalition")
	_check(hud.cue_for(_e("a:capital_lost", "capital_lost", "alert", 2)) == "capital", "capital lost -> capital")
	_check(hud.cue_for(_e("o:1", "ally", "offer", 1)) == "offer", "an offer -> offer")
	_check(hud.cue_for(_e("e:1", "golden_age", "event", 1)) == "", "an event has its own cue elsewhere")
	# a game starts silent: the first refresh only records
	hud._entries = [_e("a:coalition", "coalition", "alert", 2)]
	hud._announce_new()
	_check(got.is_empty(), "the alerts a game starts with are silent")
	# a new alert plays; the same one again does not; the most severe of several wins
	hud._entries = [_e("a:coalition", "coalition", "alert", 2), _e("o:7", "trade", "offer", 1)]
	hud._announce_new()
	_check(got == ["offer"], "a new offer plays once: %s" % str(got))
	hud._announce_new()
	_check(got == ["offer"], "...and not again: %s" % str(got))
	got.clear()
	hud._entries = [_e("a:coalition", "coalition", "alert", 2), _e("o:7", "trade", "offer", 1), _e("a:unrest", "unrest", "alert", 1), _e("a:capital_lost", "capital_lost", "alert", 3)]
	hud._announce_new()
	_check(got == ["capital"], "the most severe new alert wins: %s" % str(got))
	print("ALERT_CUES OK" if fails == 0 else "ALERT_CUES FAIL %d" % fails)
	quit(fails)
