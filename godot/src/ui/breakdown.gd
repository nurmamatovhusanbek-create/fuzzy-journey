## The sums behind the numbers on the screen, as tooltip text: a figure that moves should always be able to say why (the engine's own terms, never a second formula).
class_name TBBreakdown
extends RefCounted

static func _t(key: String, vars: Dictionary = {}) -> String: return TBI18n.T(key, vars)
static func _sg(v: float) -> String: return ("+%.1f" % v) if v > 0.05 else (("−%.1f" % absf(v)) if v < -0.05 else "0")

## a province's stability: where it drifts and what the nation's terms add up from
static func stability(g: TBGame, p: int) -> String:
	var n: int = g.owner[p]
	if g.rules < 1 or n <= 0: return _t("stability")
	var reg: Dictionary = TBData.REGIMES[g.regime[n]]
	var pt := TBTurn.stab_parts(g, n, TBWar.weary(g, n) if g.rules >= 4 else 0.0, g.at_war(n), int(reg["stabCeil"]), g.own_count(n))
	var core_term := 0.0
	if g.rules >= 1 and g.core[p] != n and g.core[p] != 0: core_term = -TBTurn.CONQUEST_UNREST
	var total := 0.0
	for k in pt: total += float(pt[k])
	var target := clampf(total + core_term, 5.0, float(reg["stabCeil"]))
	var lines: Array = [_t("bd_stab_t", {"s": g.stab[p], "t": int(round(target))})]
	lines.append("  %s  %s" % [_t("bd_ceiling"), _sg(float(pt["ceil"]))])
	if absf(float(pt["tax"])) > 0.05: lines.append("  %s  %s" % [_t("bd_tax", {"k": g.budget[n * 4]}), _sg(float(pt["tax"]))])
	if absf(float(pt["over"])) > 0.05: lines.append("  %s  %s" % [_t("bd_over", {"k": g.own_count(n)}), _sg(float(pt["over"]))])
	if absf(float(pt["war"])) > 0.05: lines.append("  %s  %s" % [_t("bd_war"), _sg(float(pt["war"]))])
	if absf(float(pt["weary"])) > 0.05: lines.append("  %s  %s" % [_t("bd_weary"), _sg(float(pt["weary"]))])
	if absf(float(pt["ruler"])) > 0.05: lines.append("  %s  %s" % [_t("bd_ruler"), _sg(float(pt["ruler"]))])
	if core_term != 0.0: lines.append("  %s  %s" % [_t("bd_core"), _sg(core_term)])
	return "\n".join(lines)

## a province's people (rules 5): the size in real terms, what makes it grow, the ceiling, and the levy pool
static func people(g: TBGame, p: int) -> String:
	var head: String = "%s: %d" % [_t("pop"), g.pop[p]]
	if g.rules < 5 or g.owner[p] <= 0: return head
	var gp := TBTurn.growth_parts(g, p)
	var lines: Array = [_t("bd_people_t", {"p": TBKit.fmt(float(g.pop[p])), "r": TBKit.fmt(float(g.pop[p]) * float(g.scale)), "s": g.scale})]
	lines.append("  %s  %s" % [_t("bd_rate"), _t("bd_per_year", {"v": "%.2f" % (float(gp["year_rate"]) * 100.0)})])
	lines.append("  %s  ×%.2f" % [_t("bd_mood"), float(gp["mood"])])
	lines.append("  %s  ×%.2f" % [_t("bd_order"), float(gp["order"])])
	if absf(float(gp["farm"]) - 1.0) > 0.001: lines.append("  %s  ×%.2f" % [_t("bd_farms"), float(gp["farm"])])
	lines.append("  %s  ×%.2f" % [_t("bd_room", {"c": TBKit.fmt(float(gp["cap"]))}), float(gp["room"])])
	lines.append("  %s  %s%d" % [_t("bd_turn"), "+" if int(gp["growth"]) >= 0 else "−", absi(int(gp["growth"]))])
	if g.rules >= 4: lines.append(_t("bd_levy", {"a": TBKit.fmt(float(mini(g.levy[p], g.levy_cap(p)))), "b": TBKit.fmt(float(g.levy_cap(p)))}))
	return "\n".join(lines)
