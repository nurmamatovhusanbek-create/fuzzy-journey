## Loose ends before the turn ends (rules >= 5): what the advisor would still nudge you about and that a single order can settle: gold piling up, the army standing in one province,
## manpower overflowing, a big army without a general. Pure read. [{id, k, p}]: the advisor's alert id, its number and the province to look at. Muted tips (Settings > Alerts) are not nagged about.
class_name TBLoose
extends RefCounted

static var IDS: Array = ["spread_army", "idle_gold", "idle_men", "no_general"]

static func scan(g: TBGame, n: int) -> Array:
	var out: Array = []
	if g.rules < 5 or n <= 0 or g.alive[n] == 0: return out
	var seen := {}
	for a in TBAlertPrefs.filter(TBAdvisor.alerts(g, n)):
		var id: String = String(a["id"])
		if IDS.has(id) and not seen.has(id):
			seen[id] = true
			out.append({"id": id, "k": int(a["k"]), "p": int(a["p"])})
	return out

## where "Handle them" goes: the Host panel for army matters, the province for gold
static func target(item: Dictionary) -> String:
	return "province" if String(item["id"]) == "idle_gold" and int(item["p"]) >= 0 else "host"
