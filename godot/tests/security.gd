extends SceneTree
## Security and robustness: the command schema, the wire format, save files, settings and the server's text/rate rules. Usage: -s tests/security.gd   (headless, ~20 s)
var fails := 0
func check(c: bool, what: String) -> void:
	if c: print("  ok   ", what)
	else: fails += 1; print("  FAIL ", what)

func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 5, "rules": 2})
	var me := 1
	for n in range(1, g.N1):
		if g.alive[n] == 1: me = n; break
	g.add_human(me); g.human_id = me
	var other := me % (g.N1 - 1) + 1
	# --- command schema
	var sum0 := g.state_checksum()
	for bad in [{}, {"cmd": 5}, {"cmd": "recruit"}, {"cmd": "recruit", "n": me}, {"cmd": "recruit", "n": me, "p": -1}, {"cmd": "recruit", "n": me, "p": g.P}, {"cmd": "recruit", "n": me, "p": "3"},
			{"cmd": "recruit", "n": me, "p": NAN}, {"cmd": "recruit", "n": me, "p": INF}, {"cmd": "recruit", "n": [1], "p": 0}, {"cmd": "declareWar", "n": me, "t": me}, {"cmd": "declareWar", "n": me, "t": 0},
			{"cmd": "decide", "n": me, "id": "x".repeat(200)}, {"cmd": "budget", "n": me, "key": 7, "val": 1}, {"cmd": "move", "n": me, "from": 0}, {"cmd": "nope", "n": me}, {"cmd": "ally", "n": me, "t": me}]:
		var r := g.apply(bad)
		check(not bool(r["ok"]), "hostile command refused: %s" % str(bad).substr(0, 60))
	check(g.state_checksum() == sum0, "hostile commands changed nothing")
	var c1 := TBCommands.normalize(g, {"cmd": "recruit", "n": me, "p": 3, "amount": 99999.0, "evil": 1, "_force": true}, false)
	check(c1 == {"cmd": "recruit", "n": me, "p": 3, "amount": 65000}, "untrusted: unknown keys and flags dropped, quantity capped")
	var c2 := TBCommands.normalize(g, {"cmd": "peace", "n": me, "t": other, "_force": true, "_ult": 5}, true)
	check(c2.get("_force", false) == true and c2.get("_ult", true) == false, "trusted: flags kept, only as booleans")
	# --- text
	check(TBNet._clean_text("hi\n" + String.chr(27) + "[31mthere" + String.chr(0x202E) + String.chr(0x200B) + "!", 40) == "hi31mthere!", "chat: controls, brackets, bidi and zero-width removed")
	check(TBNet._clean("   ") == "Player" and TBNet._clean("[b]x[/b]") == "bx/b", "names: never empty, no markup")
	check(TBNet._clean_text("a".repeat(500), 200).length() == 200, "chat: bounded")
	# --- wire format
	var bomb := PackedByteArray(); bomb.resize(100 * 1024 * 1024); bomb.fill(0)
	var zbomb := bomb.compress(FileAccess.COMPRESSION_GZIP); bomb.clear()
	check(TBNetProto.unpack(zbomb) == null, "decompression bomb refused (%d KB packed)" % (zbomb.size() / 1024))
	check(TBNetProto.unpack(PackedByteArray([1, 2, 3, 4])) == null and TBNetProto.unpack(PackedByteArray()) == null, "garbage bytes decode to nothing")
	check(TBNetProto.restore_snapshot(w, TBNetProto.pack({"v": 1})) == null, "incomplete snapshot refused")
	check(TBNetProto.apply_delta(g, TBNetProto.pack({"turn": 1})) == PackedInt32Array([TBNetProto.BAD]), "incomplete delta refused")
	check(TBNetProto.apply_delta(g, PackedByteArray([9, 9])) == PackedInt32Array([TBNetProto.BAD]), "undecodable delta refused")
	var prev := {}
	var dirty := PackedInt32Array([0, 1])
	var good := TBNetProto.make_delta(g, dirty, 0, true, prev)
	check(TBNetProto.apply_delta(g, good) == dirty, "a real delta still applies")
	var d: Dictionary = TBNetProto.unpack(good)
	d["prov"] = PackedInt32Array([g.P + 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var s1 := g.state_checksum()
	check(TBNetProto.apply_delta(g, TBNetProto.pack(d)) == PackedInt32Array([TBNetProto.BAD]) and g.state_checksum() == s1, "delta with a province out of range applies nothing")
	# --- saves
	check(TBSave.slot_id("../../etc/passwd") == "etcpasswd" and TBSave.slot_id("") == "x" and TBSave.path_for("a/b") == "user://save_ab.tbs", "slot names cannot leave the save folder")
	check(TBSave.save(g, "sectest"), "save written")
	check(TBSave.save(g, "sectest") and FileAccess.file_exists(TBSave.path_for("sectest") + ".bak"), "second save keeps the previous one as .bak")
	check(TBSave.load_game(w, "sectest") != null, "save loads")
	var path := ProjectSettings.globalize_path(TBSave.path_for("sectest"))
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	var len := f.get_length(); f.seek(len / 2); var byte := f.get_8(); f.seek(len / 2); f.store_8(byte ^ 0x5A); f.close()
	var h := TBSave.load_game(w, "sectest")
	check(h != null, "a damaged save falls back to the .bak (loaded %s)" % ("yes" if h != null else "no"))
	DirAccess.remove_absolute(path + ".bak")
	check(TBSave.load_game(w, "sectest") == null, "a damaged save with no backup is refused, not half-loaded")
	TBSave.delete("sectest")
	var dd := TBSave.to_dict(g)
	var e1 := dd.duplicate(true); e1["era_id"] = "../../x"
	check(TBSave.from_dict(w, e1) == null, "save naming an era outside the data folder refused")
	var e2 := dd.duplicate(true); e2["owner"] = PackedInt32Array([1, 2, 3])
	check(TBSave.from_dict(w, e2) == null, "save with a wrongly sized array refused")
	var e3 := dd.duplicate(true); var ow: PackedInt32Array = e3["owner"]; ow[0] = 99999; e3["owner"] = ow
	check(TBSave.from_dict(w, e3) == null, "save with an owner that does not exist refused")
	var e4 := dd.duplicate(true); var gold: PackedFloat32Array = e4["gold"]; gold[me] = NAN; gold[other] = 1.0e30; e4["gold"] = gold
	var g4 := TBSave.from_dict(w, e4)
	check(g4 != null and is_finite(g4.gold[me]) and g4.gold[other] <= 1.0e9, "non-finite and absurd money repaired on load")
	var e5 := dd.duplicate(true); e5["turn"] = "five"
	check(TBSave.from_dict(w, e5) == null, "save with a wrongly typed field refused")
	var e6 := dd.duplicate(true); e6["difficulty"] = "godmode"
	check(TBSave.from_dict(w, e6) == null, "save with an unknown difficulty refused")
	# --- settings file
	check(TBCfgGuard.accept("quality", "ultra", "auto") == "auto" and TBCfgGuard.accept("quality", "high", "auto") == "high", "settings: an unknown choice falls back")
	check(TBCfgGuard.accept("vol_music", 9000, 80) == 100 and TBCfgGuard.accept("vol_music", "loud", 80) == 80 and TBCfgGuard.accept("text_scale", NAN, 1.0) == 1.0, "settings: numbers clamped, wrong types ignored")
	check(TBCfgGuard.accept("tips", "yes", true) == true and TBCfgGuard.accept("win", 5, {}) == {}, "settings: bool and dictionary keep their kind")
	# --- server rules without a socket
	var net := TBNet.new()
	var okc := 0
	for i in 60: if net._allow(7): okc += 1
	check(okc >= 30 and okc <= 33, "rate limit: burst of about 30, then throttled (%d)" % okc)
	check(not net._allow(8, 99.0), "rate limit: an action dearer than the bucket never passes")
	net.free()
	print("SECURITY OK" if fails == 0 else "SECURITY FAIL %d" % fails)
	quit(fails)
