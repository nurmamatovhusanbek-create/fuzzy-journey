## Wire format helpers: full snapshots and compact deltas. Everything is packed typed arrays + zstd.
class_name TBNetProto
extends RefCounted

const NAT_F := ["gold", "manpower", "mp", "dp", "tech_level", "research", "intel", "liberty", "infamy"]
const NAT_B := ["era", "regime", "alive", "tribute", "cap_lost", "human", "personality", "coalition", "trade_cnt"]
const NAT_I := ["capital_of", "overlord", "last_war_turn", "war_cnt", "color", "r_name", "r_num", "r_born", "r_since", "r_adm", "r_dip", "r_mil", "r_trait"]
const MATRICES := ["war_score", "war_turns", "truce", "grudge", "dec_until", "trade", "realm_done"]

static func pack(v: Variant) -> PackedByteArray:
	return var_to_bytes(v).compress(FileAccess.COMPRESSION_GZIP)

static func unpack(b: PackedByteArray) -> Variant:
	return bytes_to_var(b.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP))

static func snapshot(g: TBGame) -> PackedByteArray:
	return pack(TBSave.to_dict(g))

static func restore_snapshot(w: TBWorld, b: PackedByteArray) -> TBGame:
	var d = unpack(b)
	return TBSave.from_dict(w, d) if d is Dictionary else null

## prev: per-room Dictionary caching the last-sent matrices (updated in place when full_matrices)
static func make_delta(g: TBGame, dirty: PackedInt32Array, log_from: int, full_matrices: bool, prev: Dictionary) -> PackedByteArray:
	var d := {"turn": g.turn, "year": g.year, "mi": g.month_idx, "over": g.over, "winner": g.winner, "vk": g.victory_kind}
	var pv := PackedInt32Array()
	for p in dirty:
		pv.append(p); pv.append(g.owner[p]); pv.append(g.occupier[p]); pv.append(g.army[p]); pv.append(g.pop[p])
		pv.append(g.dev[p] | (g.econ[p] << 8)); pv.append(g.stab[p] | (g.happy[p] << 8)); pv.append(g.defense[p])
		pv.append(g.building[p] | (g.b_level[p] << 8)); pv.append(g.b_building[p] | (g.b_turns[p] << 8))
		pv.append(g.capital[p] | (g.discoverable[p] << 8)); pv.append(g.gen[p])
	d["prov"] = pv
	for f in NAT_F: d["n_" + f] = g.get(f)
	for f in NAT_B: d["n_" + f] = g.get(f)
	for f in NAT_I: d["n_" + f] = g.get(f)
	d["n_budget"] = g.budget
	d["pending"] = g.pending
	d["n_trade_bonus"] = g.trade_bonus
	d["n_combat_bonus"] = g.combat_bonus
	d["n_combat_turns"] = g.combat_turns
	var rp := PackedInt32Array()
	for k in g.rel_dirty:
		var a: int = k / g.N1
		var b: int = k % g.N1
		rp.append(a); rp.append(b); rp.append(g.rel[a * g.N1 + b])
	g.rel_dirty = PackedInt32Array()
	d["rel"] = rp
	if full_matrices:
		for m in MATRICES:
			var cur = g.get(m)
			var old = prev.get(m)
			var diff := PackedInt32Array()
			for i in cur.size():
				if old == null or old[i] != cur[i]:
					diff.append(i); diff.append(cur[i])
			d["m_" + m] = diff
			prev[m] = cur.duplicate()
	if g.log.size() > log_from: d["log"] = g.log.slice(log_from)
	return pack(d)

## returns the dirty province list (for repaint)
static func apply_delta(g: TBGame, b: PackedByteArray) -> PackedInt32Array:
	var d: Dictionary = unpack(b)
	g.turn = d["turn"]; g.year = d["year"]; g.month_idx = d["mi"]; g.over = d["over"]; g.winner = d["winner"]; g.victory_kind = d.get("vk", "")
	var dirty := PackedInt32Array()
	var pv: PackedInt32Array = d["prov"]
	var i := 0
	while i < pv.size():
		var p := pv[i]
		g.owner[p] = pv[i + 1]; g.occupier[p] = pv[i + 2]; g.army[p] = pv[i + 3]; g.pop[p] = pv[i + 4]
		g.dev[p] = pv[i + 5] & 255; g.econ[p] = pv[i + 5] >> 8
		g.stab[p] = pv[i + 6] & 255; g.happy[p] = pv[i + 6] >> 8
		g.defense[p] = pv[i + 7]
		g.building[p] = pv[i + 8] & 255; g.b_level[p] = pv[i + 8] >> 8
		g.b_building[p] = pv[i + 9] & 255; g.b_turns[p] = pv[i + 9] >> 8
		g.capital[p] = pv[i + 10] & 255; g.discoverable[p] = pv[i + 10] >> 8; g.gen[p] = pv[i + 11]
		dirty.append(p)
		i += 12
	g.own_dirty = true
	for f in NAT_F: g.set(f, d["n_" + f])
	for f in NAT_B: g.set(f, d["n_" + f])
	for f in NAT_I: g.set(f, d["n_" + f])
	g.budget = d["n_budget"]
	g.pending = d["pending"]
	g.trade_bonus = d["n_trade_bonus"]; g.combat_bonus = d["n_combat_bonus"]; g.combat_turns = d["n_combat_turns"]
	var rp: PackedInt32Array = d["rel"]
	i = 0
	while i < rp.size():
		g.rel[rp[i] * g.N1 + rp[i + 1]] = rp[i + 2]; g.rel[rp[i + 1] * g.N1 + rp[i]] = rp[i + 2]
		i += 3
	for m in MATRICES:
		if d.has("m_" + m):
			var diff: PackedInt32Array = d["m_" + m]
			var arr = g.get(m)
			var j := 0
			while j < diff.size():
				arr[diff[j]] = diff[j + 1]
				j += 2
			g.set(m, arr)
	TBStats.record(g)
	if d.has("log"):
		for e in d["log"]: g.log.append(e)
	return dirty
