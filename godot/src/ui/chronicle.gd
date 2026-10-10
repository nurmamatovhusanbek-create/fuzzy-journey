## Formats engine log entries for the Chronicle screen and toasts (view helper; reads state, never mutates).
class_name TBChron
extends RefCounted

static var T: Callable = TBI18n.T

const CATS := ["mine", "all", "war", "diplo", "events"]

static func category(e: Dictionary) -> String:
	match String(e["kind"]):
		"war", "peace", "occupied", "annexed", "ceded", "eliminated", "rebels", "reconciled", "rebels_end", "independence", "ultimatum": return "war"
		"coalition", "coalition_end": return "diplo"
		"ally", "vassal", "spy", "trade", "marriage", "marriage_end", "union": return "diplo"
		"realm": return "events"
		"event", "event_choice", "era", "bankrupt", "ruler", "decision", "doctrine", "general_up", "general_fell": return "events"
	return "events"

static func involves(e: Dictionary, me: int) -> bool:
	return e.get("a", -1) == me or e.get("b", -1) == me

static func _loc(d: Variant) -> String:
	if d is Dictionary: return String(d.get(TBI18n.lang, d.get("en", "")))
	return String(d)

static func date(g: TBGame, turn: int) -> String:
	var m := g.start_month + turn * 6
	var y := g.start_year + m / 12
	return "%d BC" % -y if y < 0 else "%d AD" % y

## one-line description; empty string = not worth showing
static func text(g: TBGame, e: Dictionary) -> String:
	var a := String(g.dname(e["a"])) if int(e.get("a", 0)) > 0 else ""
	var b := String(g.dname(e["b"])) if e.has("b") and int(e["b"]) > 0 else ""
	var pn := ""
	if e.has("p") and int(e["p"]) >= 0: pn = TBI18n.place(String(g.world.name[e["p"]]))
	match String(e["kind"]):
		"war":
			var cbk := String(e.get("cb", ""))
			var base: String = T.call("e_war", {"a": a, "b": b})
			return base if cbk == "" or cbk == "rebels" else "%s (%s)" % [base, T.call("cb_" + cbk)]
		"coalition": return T.call("e_coalition", {"a": a})
		"coalition_end": return T.call("e_coalition_end", {"a": a})
		"peace": return T.call("e_peace", {"a": a, "b": b})
		"ally": return T.call("e_ally", {"a": a, "b": b})
		"offer_yes": return T.call("e_offer_yes", {"a": a, "b": b}) if involves(e, g.human_id) else ""
		"offer_no": return ""
		"realm": return T.call("e_realm", {"a": a, "r": T.call("realm_" + String(e["id"]))})
		"marriage": return T.call("e_marriage", {"a": a, "b": b})
		"marriage_end": return T.call("e_marriage_end", {"a": a, "b": b}) if involves(e, g.human_id) else ""
		"union": return T.call("e_union", {"a": a, "b": b})
		"trade": return T.call("e_trade", {"a": a, "b": b}) if involves(e, g.human_id) else ""
		"vassal": return T.call("e_vassal", {"a": a, "b": b})
		"ceded": return T.call("e_ceded", {"a": a, "b": b, "k": int(e.get("k", 0))}) if int(e.get("k", 0)) > 0 else ""
		"independence": return T.call("e_indep", {"a": a, "b": b})
		"eliminated": return T.call("e_elim", {"a": a})
		"rebels": return T.call("e_rebels", {"a": a}) if involves(e, g.human_id) else ""
		"reconciled": return T.call("e_reconciled", {"a": a, "p": pn}) if involves(e, g.human_id) else ""
		"rebels_end": return T.call("e_rebels_end", {"a": a, "p": pn}) if involves(e, g.human_id) else ""
		"occupied": return T.call("e_occupied", {"a": a, "b": b, "p": pn})
		"annexed": return T.call("e_annexed", {"a": a, "b": b, "p": pn})
		"ruler":
			if String(e["k"]) == "elected" and not involves(e, g.human_id): return ""
			return T.call("e_ruler_" + String(e["k"]), {"a": a, "old": TBRulers.name_of(e["old"], int(e["oldn"])), "new": TBRulers.name_of(e["new"], int(e["num"]))})
		"ultimatum":
			if not involves(e, g.human_id): return ""
			return T.call("e_ult_" + String(e["k"]), {"a": a, "b": b, "p": pn})
		"doctrine": return T.call("e_doctrine", {"a": a, "d": T.call("doc_" + String(e["id"]))}) if involves(e, g.human_id) else ""
		"general_up", "general_fell":
			if not involves(e, g.human_id): return ""
			return T.call("e_" + String(e["kind"]), {"a": a, "g": TBI18n.T("rn_%d" % int(e["gn"])), "sk": int(e["sk"])})
		"decision": return T.call("e_decision", {"a": a, "d": T.call("dec_" + String(e["id"]))}) if involves(e, g.human_id) else ""
		"bankrupt": return T.call("e_bankrupt", {"a": a})
		"era": return T.call("e_era", {"a": a, "e": T.call("era_name_%d" % int(e["k"]))})
		"victory": return T.call("e_victory", {"a": a})
		"defeat": return T.call("e_defeat")
		"spy":
			if not involves(e, g.human_id): return ""
			var op: String = T.call("spy_" + String(e["op"]))
			return T.call("e_spy_hit", {"a": a, "op": op}) if e["ok"] else T.call("e_spy_caught", {"a": a})
		"event":
			var t: String = T.call("ev_%s_t" % e["id"]) if TBI18n.has_key("ev_%s_t" % e["id"]) else _loc(e.get("title", {}))
			return t if a == "" or e.get("world", false) else "%s: %s" % [a, t]
		"event_choice":
			return ""
	return ""

## icon of an event entry as a TBGlyph id (data icons are glyph ids; old emoji values are mapped so nothing renders as tofu); "" for other entries
const EMOJI_GLYPH := {"⚔": "swords", "🗡": "swords", "🪖": "men", "💥": "swords", "🏹": "swords", "☢": "warning", "⚡": "warning", "🔥": "warning", "🌊": "warning", "⛈": "warning", "❄": "warning", "🥶": "warning", "☄": "warning",
	"👑": "crown", "⚜": "crown", "🏛": "crown", "🏰": "crown", "🌹": "crown", "🕊": "dove", "🤝": "dove", "☮": "dove", "📜": "scroll", "📨": "scroll", "🗺": "scroll", "📚": "book", "🎓": "book",
	"☠": "skull", "⚰": "skull", "🦠": "skull", "🤒": "skull", "💰": "coins", "💸": "coins", "💵": "coins", "💎": "coins", "🏦": "coins", "🛡": "shield", "🧱": "shield", "⛓": "shield",
	"🚩": "flag", "🏴": "flag", "🇮🇹": "flag", "🇫🇷": "flag", "🇪🇸": "flag", "🇩🇪": "flag", "🇺🇸": "flag", "🇮🇳": "flag", "🇨🇳": "flag", "🌍": "globe", "🌏": "globe", "⚓": "globe", "🚢": "globe", "⛵": "globe"}

static func glyph(e: Dictionary) -> String:
	if String(e.get("kind", "")) != "event": return ""
	var raw := String(e.get("icon", ""))
	if raw != "" and TBGlyph.G.has(raw): return raw
	return String(EMOJI_GLYPH.get(raw, "scroll"))

## toast severity: true = bad news for `me`
static func is_bad(e: Dictionary, me: int) -> bool:
	match String(e["kind"]):
		"war", "rebels", "bankrupt", "independence": return e.get("b", -1) == me or e.get("a", -1) == me
		"occupied": return e.get("b", -1) == me
		"annexed": return e.get("b", -1) == me
		"ultimatum": return e.get("b", -1) == me
		"spy": return e.get("b", -1) == me and bool(e["ok"])
		"general_fell": return true
	return false

## which entries pop up as toasts when they happen
static func toast_worthy(g: TBGame, e: Dictionary, me: int) -> bool:
	match String(e["kind"]):
		"war", "peace", "ally", "vassal", "ceded", "independence", "occupied", "annexed", "ultimatum", "trade", "marriage", "marriage_end", "union": return involves(e, me)
		"rebels", "reconciled", "rebels_end", "bankrupt", "era", "ruler", "realm", "general_up", "general_fell": return e.get("a", -1) == me
		"coalition", "coalition_end": return true
		"eliminated": return true
		"event": return e.get("a", 0) == me or e.get("a", 0) == 0
		"spy": return e.get("b", -1) == me
	return false
