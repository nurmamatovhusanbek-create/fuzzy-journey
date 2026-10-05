extends SceneTree
func _init() -> void:
	TBI18n.load_lang("ru")
	var w := TBWorld.load_from("res://data")
	var miss := 0
	for n in w.name: if TBI18n.place(n) == n and n != "?": miss += 1
	print("provinces: ", w.name.size(), " untranslated: ", miss)
	quit(1 if miss > 0 else 0)
