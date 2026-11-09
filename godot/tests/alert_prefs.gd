extends SceneTree
## Alerts can be switched off in Settings (tips only), crises never; the choice survives a settings file and a hostile one is ignored. Usage: -s tests/alert_prefs.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var cfg := {"alert_mute": []}
	TBAlertPrefs.sync(cfg)
	var al := [{"id": "idle_gold", "sev": 0}, {"id": "bankrupt", "sev": 2}, {"id": "idle_mp", "sev": 0}, {"id": "threat", "sev": 2}]
	_check(TBAlertPrefs.filter(al).size() == 4, "nothing is hidden by default")
	TBAlertPrefs.set_muted(cfg, "idle_gold", true)
	TBAlertPrefs.set_muted(cfg, "bankrupt", true)
	TBAlertPrefs.set_muted(cfg, "bogus", true)
	var left: Array = TBAlertPrefs.filter(al)
	_check(left.size() == 3 and not left.any(func(a): return a["id"] == "idle_gold"), "a tip can be switched off")
	_check(left.any(func(a): return a["id"] == "bankrupt"), "a crisis never can")
	_check((cfg["alert_mute"] as Array) == ["idle_gold"], "only known tips are stored (%s)" % str(cfg["alert_mute"]))
	TBAlertPrefs.set_muted(cfg, "idle_gold", false)
	_check(TBAlertPrefs.filter(al).size() == 4, "and comes back")
	# the settings guard
	_check(TBCfgGuard.accept("alert_mute", ["idle_mp", "idle_dp"], []) == ["idle_mp", "idle_dp"], "a short list of names is accepted")
	_check(TBCfgGuard.accept("alert_mute", "evil", []) == [], "a string is refused")
	_check(TBCfgGuard.accept("alert_mute", [1, 2], []) == [], "numbers are refused")
	var big: Array = []
	for i in 100: big.append("x")
	_check(TBCfgGuard.accept("alert_mute", big, []) == [], "a long list is refused")
	print("ALERT_PREFS OK" if fails == 0 else "ALERT_PREFS FAIL %d" % fails)
	quit(fails)
