## Generals: a named commander at the head of one army stack. rules >= 1 only.
## gen[p] packs  skill (bits 0-3, 1..5) | name index (bits 4-10) | victories toward the next star (bits 11-13).
## Rolls derive from a hash of (seed, nation, province, turn), so the main RNG stream is untouched.
class_name TBGenerals
extends RefCounted

const MAX_SKILL := 5
const MIN_ARMY := 12
const WINS_PER_STAR := 3
const POWER := 0.06            # +6 % combat strength per star

static func skill(g: TBGame, p: int) -> int: return g.gen[p] & 15
static func name_idx(g: TBGame, p: int) -> int: return (g.gen[p] >> 4) & 127
static func wins(g: TBGame, p: int) -> int: return (g.gen[p] >> 11) & 7
static func pack(sk: int, nm: int, w: int) -> int: return (sk & 15) | ((nm & 127) << 4) | ((w & 7) << 11)

static func display_name(g: TBGame, p: int) -> String:
	if g.gen[p] == 0: return ""
	return TBI18n.T("rn_%d" % name_idx(g, p))

## strength multiplier of the general at p (1.0 when none, or on rules 0)
static func mul(g: TBGame, p: int) -> float:
	if g.rules < 1 or g.gen.is_empty() or g.gen[p] == 0: return 1.0
	return 1.0 + POWER * skill(g, p)

static func count(g: TBGame, n: int) -> int:
	var c := 0
	for p in g.owned(n):
		if g.gen[p] != 0: c += 1
	return c

## how many commanders a nation can field: grows with the size of the realm and the ruler's martial skill
static func cap(g: TBGame, n: int) -> int:
	var mil: int = g.r_mil[n] if g.r_name[n] != "" else 3
	return clampi(1 + g.own_count(n) / 8 + (1 if mil >= 4 else 0), 1, 8)

static func cost(g: TBGame, n: int) -> int: return 50 + 15 * count(g, n)

static func _h(g: TBGame, n: int, p: int, salt: int) -> TBRng:
	var h: int = g.seed_value ^ TBRng.imul(n + 1, 0x9E3779B1) ^ TBRng.imul(p + 5, 0x85EBCA6B) ^ TBRng.imul(g.turn + 11, 0xC2B2AE35) ^ TBRng.imul(salt + 3, 0x27D4EB2F)
	var r := TBRng.new(h)
	r.next()
	return r

static func appoint(g: TBGame, n: int, p: int) -> Dictionary:
	if g.rules < 1: return {"ok": false, "err": "unknown"}
	if g.owner[p] != n or g.controller(p) != n: return {"ok": false, "err": "notyours"}
	if g.gen[p] != 0: return {"ok": false, "err": "has"}
	if g.army[p] < MIN_ARMY: return {"ok": false, "err": "army"}
	if count(g, n) >= cap(g, n): return {"ok": false, "err": "cap"}
	var c := cost(g, n)
	if g.gold[n] < c: return {"ok": false, "err": "gold"}
	g.gold[n] -= c
	var r := _h(g, n, p, 1)
	var sk := 1 + r.randi_n(3)
	if g.r_name[n] != "" and g.r_mil[n] >= 4 and sk < MAX_SKILL: sk += 1       # a martial ruler picks better men
	g.gen[p] = pack(sk, r.randi_n(TBRulers.NAME_POOL), 0)
	g.touch(p)
	return {"ok": true}

## the commander rides with the column when (nearly) the whole stack leaves
static func follows(g: TBGame, from: int, left_behind: int) -> bool:
	return g.gen[from] != 0 and left_behind <= maxi(2, g.army[from] / 4)

static func transfer(g: TBGame, from: int, to: int) -> void:
	if g.gen[to] == 0 or skill(g, from) > skill(g, to): g.gen[to] = g.gen[from]
	g.gen[from] = 0
	g.touch(from); g.touch(to)

## a victory: one step towards the next star
static func win(g: TBGame, p: int, n: int) -> void:
	if g.gen[p] == 0: return
	var w := wins(g, p) + 1
	var sk := skill(g, p)
	if w >= WINS_PER_STAR and sk < MAX_SKILL:
		sk += 1; w = 0
		if g.human[n] != 0: g.log.append({"turn": g.turn, "kind": "general_up", "a": n, "p": p, "gn": name_idx(g, p), "sk": sk})
	elif sk >= MAX_SKILL: w = 0
	g.gen[p] = pack(sk, name_idx(g, p), w)
	g.touch(p)

## a defeat: the commander may fall with his men
static func lose(g: TBGame, p: int, n: int, heavy: bool) -> void:
	if g.gen[p] == 0: return
	if _h(g, n, p, 7).next() < (0.30 if heavy else 0.12):
		if g.human[n] != 0: g.log.append({"turn": g.turn, "kind": "general_fell", "a": n, "p": p, "gn": name_idx(g, p), "sk": skill(g, p)})
		g.gen[p] = 0
		g.touch(p)

## end of turn: a commander without an army, or in a province his nation no longer holds, is gone
static func tick(g: TBGame) -> void:
	for p in g.P:
		if g.gen[p] == 0: continue
		var c := g.controller(p)
		if c == 0 or g.army[p] < 3 or g.alive[c] == 0:
			g.gen[p] = 0; g.touch(p)

static func ai_step(g: TBGame, n: int, own: PackedInt32Array) -> void:
	if g.rules < 1 or count(g, n) >= cap(g, n) or g.gold[n] < cost(g, n) + 120: return
	var best := -1; var bs := 0
	for p in own:
		if g.gen[p] == 0 and g.army[p] >= MIN_ARMY and g.army[p] > bs and g.controller(p) == n:
			bs = g.army[p]; best = p
	if best >= 0: appoint(g, n, best)
