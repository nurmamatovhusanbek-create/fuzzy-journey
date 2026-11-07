## Rules 5: the real population of every province in every era (data/pop_real.json, built by tools/pop_build.py), the era's scale, and the growth curve.
## One game person stands for `scale` real people (10 in the old eras, 20 from gunpowder to Victorian, 30 from WW1 on: docs/RULES5_REALISM.md).
class_name TBPopData
extends RefCounted

static var _d: Dictionary = {}

static func _load() -> void:
	if not _d.is_empty(): return
	var f := "res://data/pop_real.json"
	if FileAccess.file_exists(f): _d = JSON.parse_string(FileAccess.get_file_as_string(f))
	if _d.is_empty(): _d = {"scale": {}, "real": {}}

## real people : game people for an era ("modern" = 30)
static func scale_for(era_id: String) -> int:
	_load()
	return int((_d["scale"] as Dictionary).get(era_id, 30))

static func has(era_id: String) -> bool:
	_load()
	return (_d["real"] as Dictionary).has(era_id)

## real people of province p in the era (before the game's scale and jitter)
static func real(era_id: String, p: int) -> float:
	_load()
	var a: Array = (_d["real"] as Dictionary).get(era_id, [])
	return float(a[p]) if p < a.size() else 2000.0

## what the province holds today: the ceiling the land can feed once technology is modern
static func modern(p: int) -> float: return real("modern", p)

## net natural growth per YEAR, by the calendar (so the world's people follow history whatever the game does with technology: famine, plague and the Mongol wars keep the old
## world nearly flat, the 19th century doubles it, the 20th quadruples it) and by the nation's technology (a backward state grows a quarter slower, a leader a third faster)
static var _R_YEAR: Array = [-500.0, 0.0, 1000.0, 1300.0, 1400.0, 1500.0, 1700.0, 1800.0, 1850.0, 1914.0, 1950.0, 2000.0, 2024.0, 2100.0]
static var _R_RATE: Array = [0.0005, 0.0007, 0.0010, 0.0005, 0.0010, 0.0025, 0.0030, 0.0045, 0.0060, 0.0080, 0.0170, 0.0120, 0.0090, 0.0020]
static func growth_per_year(year: float, tl: float) -> float:
	var r: float = float(_R_RATE[_R_RATE.size() - 1])
	if year <= float(_R_YEAR[0]): r = float(_R_RATE[0])
	else:
		for i in range(1, _R_YEAR.size()):
			if year <= float(_R_YEAR[i]):
				var t := (year - float(_R_YEAR[i - 1])) / (float(_R_YEAR[i]) - float(_R_YEAR[i - 1]))
				r = lerpf(float(_R_RATE[i - 1]), float(_R_RATE[i]), t)
				break
	return r * clampf(0.75 + 0.12 * tl, 0.75, 1.35)
