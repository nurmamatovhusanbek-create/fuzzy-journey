## Single source of colour and metric tokens for the interface (design/art/art-bible.md sections 3, 4 and 7).
## No raw Color(...) literals elsewhere in src/ui: use these names. `mode` switches Normal / High contrast.
class_name TBTokens
extends RefCounted

## mode: 0 NORMAL, 1 HIGH_CONTRAST (light variant), 2 HC_DARK (high-contrast dark variant). Test high contrast with is_hc(), never with == 1.
enum Mode { NORMAL, HIGH_CONTRAST, HC_DARK }
static var mode: int = Mode.NORMAL

# ---- paper ground (documents) ------------------------------------------------------------------
const NORMAL := {
	"paper_0": Color("121315"), "paper_1": Color("1E2023"), "paper_2": Color("2D3035"), "paper_hover": Color("26292D"),
	"ink_0": Color("F4F5F6"), "ink_1": Color("BCC1C7"), "ink_off": Color("80868D"),
	"oxblood": Color("FFFFFF"), "brass_ink": Color("6EC1FF"), "rule": Color("6A7078"), "hair": Color("34383D"),
	# ---- bar ground (furniture)
	"bar_0": Color("0B0C0E"), "bar_1": Color("17191C"), "bar_2": Color("24272B"), "table": Color("050608"),
	"cream": Color("FFFFFF"), "smoke": Color("B0B5BC"), "brass_lt": Color("6EC1FF"), "rule_dark": Color("7A818A"),
	# ---- semantic, paper ground
	"pos": Color("72D9C0"), "neg": Color("FF8A78"), "warn": Color("F2B84B"), "info": Color("7DB3E8"), "foreign": Color("A9B1BE"),
	# ---- semantic, bar ground
	"pos_bar": Color("72D9C0"), "neg_bar": Color("FF8A78"), "warn_bar": Color("F2B84B"), "info_bar": Color("7DB3E8"), "foreign_bar": Color("A9B1BE"),
	# ---- actions
	"brass": Color("5DB2F0"), "brass_hover": Color("7BC4F7"), "brass_press": Color("4A9BD8"),
	"wax": Color("A82A22"), "wax_hover": Color("BD3329"), "wax_press": Color("8A211B"), "wax_rim": Color("D9675C"), "on_wax": Color("FBF3E0"),
	# ---- primary action: an ink slab with brass text (the darkest object of a container, so it is found by luminance as well as hue) and text on bright fills
	"act": Color("5DB2F0"), "act_hover": Color("7BC4F7"), "act_press": Color("86CBF8"), "act_rim": Color("A9DAFA"), "on_act": Color("07131C"), "on_brass": Color("07131C"),
}
const HC := {
	"paper_0": Color("FFF9E8"), "paper_1": Color("F5E8C8"), "paper_2": Color("E6D3A3"), "paper_hover": Color("FFF2CC"),
	"ink_0": Color("0E0904"), "ink_1": Color("2B2013"), "ink_off": Color("5A4C35"),
	"oxblood": Color("5E100B"), "brass_ink": Color("4A3306"), "rule": Color("3A2C1A"), "hair": Color("7C6C4F"),
	"bar_0": Color("000000"), "bar_1": Color("1A1109"), "bar_2": Color("2B1E10"), "table": Color("000000"),
	"cream": Color("FFFFFF"), "smoke": Color("E8DFC8"), "brass_lt": Color("FFD65A"), "rule_dark": Color("C9A445"),
	"pos": Color("0B5A33"), "neg": Color("85100A"), "warn": Color("6B3F00"), "info": Color("0F4A80"), "foreign": Color("3E4550"),
	"pos_bar": Color("8DF0B4"), "neg_bar": Color("FF9D8C"), "warn_bar": Color("FFC95C"), "info_bar": Color("8CC4FF"), "foreign_bar": Color("C8D0DC"),
	"brass": Color("FFD65A"), "brass_hover": Color("FFE27F"), "brass_press": Color("E6BC2F"),
	"wax": Color("85100A"), "wax_hover": Color("A01A12"), "wax_press": Color("640C07"), "wax_rim": Color("2A0503"), "on_wax": Color("FFFFFF"),
	"act": Color("0E0904"), "act_hover": Color("2B2013"), "act_press": Color("000000"), "act_rim": Color("FFD65A"), "on_act": Color("FFD65A"), "on_brass": Color("0E0904"),
}
## High contrast, DARK variant (A11Y-CON-005): near-black paper, white ink, black bar; every semantic hue is its light "bar" value.
const HC_DARK := {
	"paper_0": Color("0A0805"), "paper_1": Color("1A1610"), "paper_2": Color("332B1D"), "paper_hover": Color("262014"),
	"ink_0": Color("FFFFFF"), "ink_1": Color("E8E0CC"), "ink_off": Color("A89C80"),
	"oxblood": Color("FFB3A6"), "brass_ink": Color("FFD65A"), "rule": Color("D9D0B8"), "hair": Color("6B6048"),
	"bar_0": Color("000000"), "bar_1": Color("1A1109"), "bar_2": Color("2B1E10"), "table": Color("000000"),
	"cream": Color("FFFFFF"), "smoke": Color("E8DFC8"), "brass_lt": Color("FFD65A"), "rule_dark": Color("C9A445"),
	"pos": Color("8DF0B4"), "neg": Color("FF9D8C"), "warn": Color("FFC95C"), "info": Color("8CC4FF"), "foreign": Color("C8D0DC"),
	"pos_bar": Color("8DF0B4"), "neg_bar": Color("FF9D8C"), "warn_bar": Color("FFC95C"), "info_bar": Color("8CC4FF"), "foreign_bar": Color("C8D0DC"),
	"brass": Color("FFD65A"), "brass_hover": Color("FFE27F"), "brass_press": Color("E6BC2F"),
	"wax": Color("85100A"), "wax_hover": Color("A01A12"), "wax_press": Color("640C07"), "wax_rim": Color("FFB3A6"), "on_wax": Color("FFFFFF"),
	"act": Color("FFD65A"), "act_hover": Color("FFE27F"), "act_press": Color("E6BC2F"), "act_rim": Color("FFFFFF"), "on_act": Color("0A0805"), "on_brass": Color("0A0805"),
}

## token lookup honouring the active mode: TBTokens.c("ink_0")
static func c(name: String) -> Color:
	if mode == Mode.NORMAL: return NORMAL[name]
	return (HC_DARK if mode == Mode.HC_DARK else HC)[name]

## the dictionary of a mode (tests walk all three)
static func dict(m: int) -> Dictionary:
	if m == Mode.HC_DARK: return HC_DARK
	return HC if m == Mode.HIGH_CONTRAST else NORMAL

## cfg["hc"] value -> mode
static func mode_from_setting(hc: String) -> int:
	return Mode.HC_DARK if hc == "dark" else (Mode.HIGH_CONTRAST if hc == "light" else Mode.NORMAL)

## token with its own alpha: TBTokens.ca("table", 0.72)
static func ca(name: String, alpha: float) -> Color:
	var col: Color = c(name)
	return Color(col.r, col.g, col.b, alpha)

## colour with its alpha replaced (derive translucent variants without a raw Color literal)
static func with_a(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, a)

static func is_hc() -> bool:
	return mode != Mode.NORMAL

static func is_dark_hc() -> bool:
	return mode == Mode.HC_DARK

## ---- contrast (WCAG 2.x relative luminance; art bible appendix A) --------------------------------
static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

static func luminance(col: Color) -> float:
	return 0.2126 * _lin(col.r) + 0.7152 * _lin(col.g) + 0.0722 * _lin(col.b)

static func contrast(a: Color, b: Color) -> float:
	var la: float = luminance(a); var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## Registered text / boundary pairs, art bible 4.2-4.5 and 4.7: [foreground token, background token, min NORMAL, min HC, role].
## Text >= 4.5 (HC 7); non-text boundaries, focus, disabled >= 3 (HC 4.5). Where the bible itself states a lower HC figure
## (semantic text on paper-1: >= 6.84) the HC minimum is 6.8.
const PAIRS := [
	["ink_0", "paper_0", 7.0, 7.0, "primary text"], ["ink_0", "paper_1", 7.0, 7.0, "primary text on control"], ["ink_0", "paper_2", 7.0, 7.0, "primary text on pressed"],
	["ink_1", "paper_0", 4.5, 7.0, "secondary text"], ["ink_1", "paper_1", 4.5, 7.0, "secondary text on control"], ["ink_1", "paper_2", 4.5, 7.0, "secondary text on pressed"],
	["oxblood", "paper_0", 4.5, 7.0, "title"], ["oxblood", "paper_1", 4.5, 7.0, "title on control"], ["oxblood", "paper_2", 4.5, 7.0, "oxblood on pressed"],
	["brass_ink", "paper_0", 4.5, 7.0, "own text"], ["brass_ink", "paper_1", 4.5, 7.0, "own text on control"],
	["pos", "paper_0", 4.5, 7.0, "positive"], ["pos", "paper_1", 4.5, 6.8, "positive on control"],
	["neg", "paper_0", 4.5, 7.0, "negative"], ["neg", "paper_1", 4.5, 6.8, "negative on control"],
	["warn", "paper_0", 4.5, 7.0, "warning"], ["warn", "paper_1", 4.5, 6.8, "warning on control"],
	["info", "paper_0", 4.5, 7.0, "info"], ["info", "paper_1", 4.5, 6.8, "info on control"],
	["foreign", "paper_0", 4.5, 7.0, "foreign"], ["foreign", "paper_1", 4.5, 6.8, "foreign on control"],
	["cream", "bar_0", 4.5, 7.0, "bar text"], ["cream", "bar_1", 4.5, 7.0, "chip text"], ["cream", "bar_2", 4.5, 7.0, "hover chip text"],
	["smoke", "bar_0", 4.5, 7.0, "bar secondary"], ["smoke", "bar_1", 4.5, 7.0, "chip secondary"], ["smoke", "bar_2", 4.5, 7.0, "hover chip secondary"],
	["brass_lt", "bar_0", 4.5, 7.0, "accent on bar"], ["brass_lt", "bar_1", 4.5, 7.0, "accent on chip"], ["brass_lt", "bar_2", 4.5, 7.0, "accent on hover chip"],
	["pos_bar", "bar_0", 4.5, 7.0, "positive on bar"], ["pos_bar", "bar_1", 4.5, 7.0, "positive on chip"],
	["neg_bar", "bar_0", 4.5, 7.0, "negative on bar"], ["neg_bar", "bar_1", 4.5, 7.0, "negative on chip"],
	["warn_bar", "bar_0", 4.5, 7.0, "warning on bar"], ["warn_bar", "bar_1", 4.5, 7.0, "warning on chip"],
	["info_bar", "bar_0", 4.5, 7.0, "info on bar"], ["info_bar", "bar_1", 4.5, 7.0, "info on chip"],
	["foreign_bar", "bar_0", 4.5, 7.0, "foreign on bar"], ["foreign_bar", "bar_1", 4.5, 7.0, "foreign on chip"],
	["on_brass", "brass", 4.5, 7.0, "brass fill text"], ["on_brass", "brass_hover", 4.5, 7.0, "brass fill hover text"], ["on_brass", "brass_press", 4.5, 7.0, "brass fill pressed text"], ["on_brass", "warn_bar", 4.5, 7.0, "warning chip text"],
	["on_act", "act", 7.0, 7.0, "primary button"], ["on_act", "act_hover", 4.5, 7.0, "primary button hover"], ["on_act", "act_press", 7.0, 7.0, "primary button pressed"],
	["on_wax", "wax", 4.5, 7.0, "danger button"], ["on_wax", "wax_hover", 4.5, 7.0, "danger button hover"], ["on_wax", "wax_press", 4.5, 7.0, "danger button pressed"],
	["oxblood", "paper_2", 4.5, 7.0, "segmented selected underline and check"],
	["ink_0", "paper_hover", 4.5, 7.0, "hover row text"], ["ink_1", "paper_hover", 4.5, 7.0, "hover row secondary"],
	# non-text: control boundaries, disabled, focus ring, meters
	["rule", "paper_0", 3.0, 4.5, "control border on panel"], ["rule", "paper_1", 3.0, 4.5, "control border on control"],
	["brass_ink", "paper_0", 3.0, 4.5, "armed border on panel"], ["brass_ink", "paper_2", 3.0, 4.5, "own marker on pressed"],
	["act", "paper_0", 3.0, 4.5, "primary button edge on panel"], ["act", "paper_1", 3.0, 4.5, "primary button edge on control"], ["oxblood", "paper_1", 3.0, 4.5, "selected underline vs unselected cell"],
	["wax_rim", "paper_0", 1.5, 4.5, "danger button edge on panel"],
	["rule_dark", "bar_0", 3.0, 4.5, "bar border"], ["rule_dark", "bar_1", 3.0, 4.5, "chip / tooltip border"], ["rule_dark", "bar_2", 3.0, 4.5, "hover chip border"],
	["ink_off", "paper_0", 3.0, 4.5, "disabled text on panel"], ["ink_off", "paper_1", 3.0, 4.5, "disabled text on control"],
	["ink_0", "paper_0", 3.0, 4.5, "focus ring on paper"], ["cream", "bar_0", 3.0, 4.5, "focus ring on bar"], ["cream", "table", 3.0, 4.5, "focus ring on map"],
	["pos", "paper_2", 3.0, 4.5, "meter fill vs pressed"], ["neg", "paper_2", 3.0, 4.5, "meter fill vs pressed"], ["warn", "paper_2", 3.0, 4.5, "meter fill vs pressed"],
	["info", "paper_2", 3.0, 4.5, "info marker vs pressed"], ["foreign", "paper_2", 3.0, 4.5, "foreign marker vs pressed"],
]

# ---- metrics (logical px at Standard density) ---------------------------------------------------
const CUT := 1                  # chamfer for plates, buttons, chips
const CUT_CHIP := 1             # chips <= 28 px high
const CUT_PANEL := 1            # panels and sheets
const SP := [0, 4, 8, 12, 16, 24, 32, 48]          # spacing scale (index = step)
const TOUCH := 48               # minimum hit area
const POINTER_MIN := 32
const BTN_H := 44
const BTN_H_TOUCH := 48
const ROW_H := 48
const ROW_H_COMPACT := 40
const BAR_H := 48
const BAR_H_PHONE := 44
const DOCK_W := 56
const PANEL_W := 360
const MODAL_W_MAX := 920
const TOUCH_LARGE := 56         # "Large targets" setting
const ICON_VISUAL := 40         # visual square of an icon button (hit area stays 48)
const THUMB := 24               # slider thumb diameter
const SCRIM_ALPHA := 0.72       # modal scrim = `table` at 72 %
const SHADOW_DY := [0, 3, 6]    # hard shadow offset per elevation (art bible 3.3)
const SHADOW_A := [0.0, 0.26, 0.32]
const FOCUS_RING := 2           # focus ring: 2 px ring + 2 px gap + 1 px contrast line
const FOCUS_GAP := 2
const FOCUS_OUT := 1

# ---- type roles (px at 100 %); sizes are multiplied by the text scale elsewhere -----------------
const FS_TITLE := 20
const FS_BODY_PHONE := 15
const FS_BODY := 14
const FS_DETAIL := 13
const FS_CAPTION := 12          # absolute floor at 100 %
const FS_FIGURE := 16
const FS_DELTA := 12
