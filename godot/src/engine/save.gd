## Save/restore a TBGame to a compressed binary file (typed arrays stored natively).
class_name TBSave
extends RefCounted

const VERSION := 1
const FIELDS_PACKED := ["gold", "manpower", "mp", "dp", "tech_level", "research", "intel", "liberty", "era", "regime", "personality", "alive", "human", "cap_lost", "tribute", "capital_of", "overlord", "last_war_turn", "color", "budget", "rel", "truce", "war_score", "war_turns", "grudge", "war_cnt", "ev_last_any", "trade_bonus", "combat_bonus", "combat_turns", "owner", "occupier", "occ_turns", "army", "pop", "dev", "econ", "stab", "happy", "defense", "gen", "terrain", "building", "b_level", "b_lv", "b_building", "b_turns", "capital", "discoverable", "nb_off", "nb", "nb_sea", "r_name", "r_num", "r_born", "r_since", "r_adm", "r_dip", "r_mil", "r_trait", "infamy", "coalition", "core", "dec_until", "trade", "trade_cnt", "realm_done", "doctrine", "reb_age", "reb_from", "own_since", "see_until", "offer_cd", "net_ema"]
const FIELDS_SCALAR := ["turn", "year", "month_idx", "era_id", "over", "winner", "victory_kind", "human_id", "rebel", "seed_value", "rules", "difficulty", "occ_rev", "nap_expiry", "log", "stats", "pending", "asks", "marches", "ev_fired", "ev_last", "ev_uid", "start_year", "start_month", "infl", "world_y", "econ_goal", "tech_top", "tech_second", "tech_avg", "tech_start_top", "aggr_level", "vic_hold"]

## file name safety: a slot is a short id of letters, digits, "_" and "-" (anything else is dropped), never a path
static func slot_id(slot: String) -> String:
	var out := ""
	for i in mini(slot.length(), 24):
		var ch := slot[i]
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-": out += ch
	return out if out != "" else "x"

static func path_for(slot: String) -> String:
	return "user://save_%s.tbs" % slot_id(slot)

const MAX_FILE := 48 * 1024 * 1024                  # a save of the largest map is a few MB; a bigger file is not ours
const MAX_ITEMS := 200000                           # log / stats / pending lists
const MAX_COIN := 1.0e9
## floats that must stay finite and sane
const FLOAT_FIELDS := ["gold", "manpower", "mp", "dp", "tech_level", "research", "intel", "liberty", "infamy", "net_ema"]

## the checksum stored in a save: it catches a damaged or half-written file and a casual edit. It is not a secret (the game is open), so single-player saves are the player's own
## to change; anything that matters between players is decided by the server, which never loads a client's save.
static func digest(d: Dictionary) -> String:
	var c := d.duplicate()
	c.erase("sum")
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(var_to_bytes(c))
	return h.finish().hex_encode()

static func to_dict(g: TBGame) -> Dictionary:
	var d := {"v": VERSION, "rng": g.rng.s, "nat_name": g.nat_name, "nat_code": g.nat_code}
	for f in FIELDS_PACKED: d[f] = g.get(f)
	for f in FIELDS_SCALAR: d[f] = g.get(f)
	var turn_n: int = g.turn
	d["meta"] = {"turn": turn_n, "year": g.year, "nation": g.nat_name[g.human_id] if g.human_id > 0 else "", "era": g.era_id}
	var hn: int = g.human_id
	if hn > 0:                                                                  # what the title's Continue card shows: the flag and the ruler (names are composed in the player's language there)
		d["meta"]["code"] = g.nat_code[hn]; d["meta"]["color"] = g.color[hn]; d["meta"]["cap"] = g.capital_of[hn]
		if g.rules >= 1 and g.r_name[hn] != "": d["meta"]["rk"] = TBRulers.title_key(g, hn); d["meta"]["rn"] = g.r_name[hn]; d["meta"]["rnum"] = g.r_num[hn]
	return d

## a save is written beside the old one, read back and checked, and only then swapped in; the previous good file is kept as a .bak
static func save(g: TBGame, slot: String) -> bool:
	var path := path_for(slot)
	var tmp := path + ".tmp"
	var d := to_dict(g)
	d["sum"] = digest(d)
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null: return false
	f.store_var(d)
	var err := f.get_error()
	f.close()
	if err != OK or _read(tmp).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp)); return false
	var abs_main := ProjectSettings.globalize_path(path)
	var abs_bak := abs_main + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(abs_bak)
		DirAccess.rename_absolute(abs_main, abs_bak)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_main) == OK

## the payload of a save file, or {} when the file is missing, too big, not a dictionary or fails its checksum
static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var raw := FileAccess.open(path, FileAccess.READ)
	if raw == null: return {}
	var size := raw.get_length()
	raw.close()
	if size <= 0 or size > MAX_FILE: return {}
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null: return {}
	var d = f.get_var(false)                                                    # objects are never decoded
	f.close()
	if not (d is Dictionary): return {}
	if d.has("sum") and String(d["sum"]) != digest(d): return {}               # saves from before the checksum have none and still load
	return d

static func meta(slot: String) -> Dictionary:
	var d := _read(path_for(slot))
	if d.is_empty(): d = _read(path_for(slot) + ".bak")
	var m = d.get("meta", {})
	return m if m is Dictionary else {}

static func delete(slot: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var p: String = path_for(slot) + suffix
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## returns a restored TBGame or null (a damaged main file falls back to the .bak)
static func load_game(w: TBWorld, slot: String) -> TBGame:
	for suffix in ["", ".bak"]:
		var d := _read(path_for(slot) + suffix)
		if d.is_empty(): continue
		var g := from_dict(w, d)
		if g != null: return g
	return null

## rebuild a game from a TBSave.to_dict() payload (also used for network snapshots)
static func from_dict(w: TBWorld, d: Dictionary) -> TBGame:
	if int(d.get("v", 0)) != VERSION: return null
	for k in ["era_id", "seed_value", "difficulty", "rng", "nat_name", "nat_code"]:
		if not d.has(k): return null
	if not (d["era_id"] is String) or not (d["difficulty"] is String) or not (d["seed_value"] is int) or not (d["rng"] is int): return null
	var era_id: String = d["era_id"]
	if era_id != "modern" and (era_id.length() > 24 or not _plain_id(era_id) or not FileAccess.file_exists("res://data/eras/%s.json" % era_id)): return null
	if not TBData.DIFFICULTY.has(d["difficulty"]): return null
	var rules: int = int(d.get("rules", 0))
	if rules < 0 or rules > 3: return null
	var era_pack := TBWorld.load_era("res://data", era_id) if era_id != "modern" else {}
	var g := TBGame.new(w, era_pack, {"seed": d["seed_value"], "difficulty": d["difficulty"], "rules": rules})
	for k in FIELDS_PACKED:
		if not d.has(k): continue                                                  # tolerate saves from before a field existed
		var cur = g.get(k)
		if typeof(d[k]) != typeof(cur): return null
		if k != "nb_off" and k != "nb" and k != "nb_sea" and d[k].size() != cur.size(): return null
		g.set(k, d[k])
	for k in FIELDS_SCALAR:
		if not d.has(k): continue
		var cur = g.get(k)
		var v = d[k]
		if typeof(cur) != TYPE_NIL and typeof(v) != typeof(cur) and not ((v is int or v is float) and (cur is int or cur is float)): return null
		if (v is Array or v is Dictionary) and v.size() > MAX_ITEMS: return null
		g.set(k, v)
	if not (d["nat_name"] is PackedStringArray) or not (d["nat_code"] is PackedStringArray) or d["nat_name"].size() != g.N1 or d["nat_code"].size() != g.N1: return null
	g.nat_name = d["nat_name"]; g.nat_code = d["nat_code"]
	g.rng.s = int(d["rng"])
	if not _sane(g): return null
	g.own_dirty = true
	g.dirty_list = PackedInt32Array()
	g.dirty_flag.fill(0)
	g.diff = TBData.DIFFICULTY.get(g.difficulty, TBData.DIFFICULTY["normal"])
	return g

static func _plain_id(s: String) -> bool:
	for i in s.length():
		var ch := s[i]
		if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_"): return false
	return s != ""

## a loaded state must be one the engine can run: ids in range (rejected), numbers finite and bounded (repaired in place)
static func _sane(g: TBGame) -> bool:
	if g.turn < 0 or g.turn > 1000000 or g.human_id < 0 or g.human_id >= g.N1 or g.rebel < 0 or g.rebel >= g.N1: return false
	if g.nb_off.size() != g.P + 1 or g.nb_off[0] != 0 or g.nb_off[g.P] != g.nb.size() or g.nb_sea.size() != g.nb.size(): return false
	for p in g.P:
		if g.nb_off[p + 1] < g.nb_off[p]: return false
		if g.owner[p] >= g.N1 or g.occupier[p] >= g.N1: return false
		if g.army[p] < 0 or g.army[p] > 65000: g.army[p] = clampi(g.army[p], 0, 65000)
	for q in g.nb: if q < 0 or q >= g.P: return false
	for n in range(1, g.N1):
		var cp: int = g.capital_of[n]
		if cp < -1 or cp >= g.P: return false
		if g.overlord[n] < 0 or g.overlord[n] >= g.N1: return false
		if g.regime[n] >= TBData.REGIMES.size(): return false
	for f in FLOAT_FIELDS:
		var arr = g.get(f)
		for i in arr.size():
			var v: float = arr[i]
			if not is_finite(v): arr[i] = 0.0
			elif absf(v) > MAX_COIN: arr[i] = clampf(v, -MAX_COIN, MAX_COIN)
		g.set(f, arr)
	return true
