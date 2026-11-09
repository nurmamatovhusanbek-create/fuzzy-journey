## Which advisor alerts the player has switched off (Settings > Alerts). Crises can never be switched off; the rest (tips and reminders) can, and come back with one button.
class_name TBAlertPrefs
extends RefCounted

static var MUTABLE: Array = ["idle_dp", "idle_gold", "idle_men", "idle_mp", "no_general", "no_research", "no_trade", "peacetime", "ult_chance", "war_winning", "spread_army", "nap_end", "truce_end"]
static var muted: Array = []

static func sync(cfg: Dictionary) -> void:
	muted = []
	for id in (cfg.get("alert_mute", []) as Array):
		if String(id) in MUTABLE: muted.append(String(id))

static func is_muted(id: String) -> bool: return id in muted

static func filter(alerts: Array) -> Array:
	if muted.is_empty(): return alerts
	return alerts.filter(func(a: Dictionary) -> bool: return not is_muted(String(a["id"])))

static func set_muted(cfg: Dictionary, id: String, off: bool) -> void:
	var list: Array = (cfg.get("alert_mute", []) as Array).duplicate()
	list.erase(id)
	if off and id in MUTABLE: list.append(id)
	cfg["alert_mute"] = list
	sync(cfg)
