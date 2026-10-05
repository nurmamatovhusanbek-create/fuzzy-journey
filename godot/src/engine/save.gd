## Save/restore a TBGame to a compressed binary file (typed arrays stored natively).
class_name TBSave
extends RefCounted

const VERSION := 1
const FIELDS_PACKED := ["gold", "manpower", "mp", "dp", "tech_level", "research", "liberty", "era", "regime", "personality", "alive", "human", "cap_lost", "tribute", "capital_of", "overlord", "last_war_turn", "color", "budget", "rel", "truce", "war_score", "war_turns", "grudge", "war_cnt", "owner", "occupier", "army", "pop", "dev", "econ", "stab", "happy", "defense", "terrain", "building", "b_level", "b_building", "b_turns", "capital", "discoverable", "nb_off", "nb", "nb_sea"]
const FIELDS_SCALAR := ["turn", "year", "month_idx", "era_id", "over", "winner", "human_id", "rebel", "seed_value", "difficulty", "occ_rev", "nap_expiry", "log"]

static func path_for(slot: String) -> String:
	return "user://save_%s.tbs" % slot

static func to_dict(g: TBGame) -> Dictionary:
	var d := {"v": VERSION, "rng": g.rng.s, "nat_name": g.nat_name, "nat_code": g.nat_code}
	for f in FIELDS_PACKED: d[f] = g.get(f)
	for f in FIELDS_SCALAR: d[f] = g.get(f)
	var turn_n: int = g.turn
	d["meta"] = {"turn": turn_n, "year": g.year, "nation": g.nat_name[g.human_id] if g.human_id > 0 else "", "era": g.era_id}
	return d

static func save(g: TBGame, slot: String) -> bool:
	var f := FileAccess.open_compressed(path_for(slot), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null: return false
	f.store_var(to_dict(g))
	f.close()
	return true

static func meta(slot: String) -> Dictionary:
	var p := path_for(slot)
	if not FileAccess.file_exists(p): return {}
	var f := FileAccess.open_compressed(p, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null: return {}
	var d = f.get_var()
	f.close()
	return d.get("meta", {}) if d is Dictionary else {}

static func delete(slot: String) -> void:
	if FileAccess.file_exists(path_for(slot)): DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(slot)))

## returns a restored TBGame or null
static func load_game(w: TBWorld, slot: String) -> TBGame:
	var p := path_for(slot)
	if not FileAccess.file_exists(p): return null
	var f := FileAccess.open_compressed(p, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null: return null
	var d = f.get_var()
	f.close()
	if not (d is Dictionary) or int(d.get("v", 0)) != VERSION: return null
	var era_pack := TBWorld.load_era("res://data", String(d["era_id"])) if String(d["era_id"]) != "modern" else {}
	var g := TBGame.new(w, era_pack, {"seed": int(d["seed_value"]), "difficulty": String(d["difficulty"])})
	for k in FIELDS_PACKED: g.set(k, d[k])
	for k in FIELDS_SCALAR: g.set(k, d[k])
	g.nat_name = d["nat_name"]; g.nat_code = d["nat_code"]
	g.rng.s = int(d["rng"])
	g.own_dirty = true
	g.dirty_list = PackedInt32Array()
	g.dirty_flag.fill(0)
	g.diff = TBData.DIFFICULTY.get(g.difficulty, TBData.DIFFICULTY["normal"])
	return g
