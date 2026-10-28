## Settings read from user://settings.cfg come from a file anyone can edit: a value is taken only when it has the type of the default and sits in the allowed set or range.
class_name TBCfgGuard
extends RefCounted

const ENUMS := {
	"quality": ["auto", "low", "medium", "high"], "view": ["flat", "globe"], "difficulty": ["easy", "normal", "hard"], "hc": ["off", "light", "dark"], "fx": ["off", "light", "full"],
	"lang": ["en", "ru", "uz"], "phone_ui": ["desktop", "compact"], "ui": ["small", "normal", "large"],
}
const RANGES := {"text_scale": [0.8, 2.5], "vol_master": [0, 100], "vol_music": [0, 100], "vol_sfx": [0, 100], "vol_ui": [0, 100], "aggression": [0, 2], "players": [1, 8]}
const MAX_STR := 32
const MAX_DICT := 400

## the value to use for `key`: the loaded one when it is acceptable, else the default
static func accept(key: String, value: Variant, default: Variant) -> Variant:
	if default is bool: return value if value is bool else default
	if default is int or default is float:
		if not (value is int or value is float) or (value is float and (is_nan(value) or is_inf(value))): return default
		var v: float = float(value)
		if RANGES.has(key): v = clampf(v, float(RANGES[key][0]), float(RANGES[key][1]))
		return int(round(v)) if default is int else v
	if default is String:
		if not (value is String) or String(value).length() > MAX_STR: return default
		if ENUMS.has(key) and not (value in ENUMS[key]): return default
		return value
	if default is Dictionary: return value if (value is Dictionary and value.size() <= MAX_DICT) else default
	return default
