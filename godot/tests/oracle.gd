extends SceneTree
# prints per-turn checksums for comparison with reference/engine-js/checksum.mjs
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 7
	var turns := int(args[1]) if args.size() > 1 else 30
	var era_id := args[2] if args.size() > 2 else ""
	var w := TBWorld.load_from("res://data")
	var era := TBWorld.load_era("res://data", era_id) if era_id != "" else {}
	var g := TBGame.new(w, era, {"seed": seed_v, "rules": 0})
	var out: Array = []
	for t in range(0, turns + 1):
		if t > 0: g.end_turn()
		if t == 0 or t % 5 == 0 or t == turns: out.append("%d:%d" % [t, g.state_checksum() & 0xFFFFFFFF])
	print(" ".join(out))
	quit()
