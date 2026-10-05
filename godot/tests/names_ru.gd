extends SceneTree
func _init() -> void:
	TBI18n.load_lang("ru")
	var w := TBWorld.load_from("res://data")
	var miss := 0
	var seen := {}
	for n in w.nat_name: seen[n] = true
	for e in ["ancient", "roman", "medieval", "mongol", "timurid", "discovery", "gunpowder", "napoleonic", "victorian", "ww1", "ww2", "coldwar"]:
		for n in TBWorld.load_era("res://data", e)["nations"]: seen[n["name"]] = true
	for n in seen: if TBI18n.nation(n) == n and not (n.to_lower() in ["?"]): miss += 1; print("untranslated: ", n)
	print("names checked: ", seen.size(), " untranslated: ", miss)
	quit(1 if miss > 0 else 0)
