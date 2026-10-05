extends SceneTree
func _init() -> void:
	var a := TBAudio.new(); root.add_child(a)
	await process_frame; await process_frame
	print("sounds built: ", a._snd.size())
	var ok: bool = a._snd.size() == 7
	for k in a._snd: print("  %s: %d bytes (%.2fs)" % [k, a._snd[k].data.size(), a._snd[k].data.size() / 2.0 / TBAudio.RATE]); ok = ok and a._snd[k].data.size() > 1000
	for k in a._snd: a.play(k)
	print("AUDIO ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)
