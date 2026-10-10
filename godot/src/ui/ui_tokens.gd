## Single source of colour and metric tokens for the interface (design/art/art-bible.md sections 3, 4 and 7).
## No raw Color(...) literals elsewhere in src/ui: use these names. `mode` switches Normal / High contrast.
class_name TBTokens
extends RefCounted

## mode: 0 NORMAL, 1 HIGH_CONTRAST (light variant), 2 HC_DARK (high-contrast dark variant). Test high contrast with is_hc(), never with == 1.
enum Mode { NORMAL, HIGH_CONTRAST, HC_DARK }
static var mode: int = Mode.NORMAL

# ---- paper ground (documents) ------------------------------------------------------------------
## the umber + brass palette: the title screen only (legacy = true while it is shown)
const LEGACY := {
	"paper_0": Color("1B1510"), "paper_1": Color("2A2118"), "paper_2": Color("3B2E1F"), "paper_hover": Color("33281B"),
	"ink_0": Color("F3E9D2"), "ink_1": Color("CBBFA4"), "ink_off": Color("8F8268"),
	"oxblood": Color("EDC15F"), "brass_ink": Color("F2C552"), "rule": Color("8C7542"), "hair": Color("45391F"),
	# ---- bar ground (furniture)
	"bar_0": Color("120D09"), "bar_1": Color("231A12"), "bar_2": Color("33261A"), "table": Color("060A14"),
	"cream": Color("F3E9D2"), "smoke": Color("C2B79F"), "brass_lt": Color("F2C552"), "rule_dark": Color("8A7340"),
	# ---- semantic, paper ground
	"pos": Color("72D9C0"), "neg": Color("FF8A78"), "warn": Color("F2B84B"), "info": Color("7DB3E8"), "foreign": Color("A9B1BE"),
	# ---- semantic, bar ground
	"pos_bar": Color("72D9C0"), "neg_bar": Color("FF8A78"), "warn_bar": Color("F2B84B"), "info_bar": Color("7DB3E8"), "foreign_bar": Color("A9B1BE"),
	# ---- actions
	"brass": Color("D9A93C"), "brass_hover": Color("E6B94C"), "brass_press": Color("BF9230"),
	"wax": Color("8E1E16"), "wax_hover": Color("A3281A"), "wax_press": Color("741710"), "wax_rim": Color("B24A3E"), "on_wax": Color("FBF3E0"),
	# ---- primary action: an ink slab with brass text (the darkest object of a container, so it is found by luminance as well as hue) and text on bright fills
	"act": Color("D9A93C"), "act_hover": Color("E8BC4E"), "act_press": Color("CC9E34"), "act_rim": Color("F6D378"), "on_act": Color("1A130C"), "on_brass": Color("1A130C"),
}

## ---- Atlas Ledger palette (the game interface). Surfaces ink-900..500, text paper-100/300/500, one accent `signal` from the player's nation.
static var legacy := false
static var ver := 0                       # bumped whenever the accent changes: cache keys include it
static var accent: Color = Color("4FB3A9")
static var _atlas: Dictionary = {}

const INK_900 := Color("101317"); const INK_800 := Color("171B21"); const INK_700 := Color("1F242C"); const INK_600 := Color("2A303A"); const INK_500 := Color("3A414D")
const PAPER_100 := Color("EEE9DF"); const PAPER_300 := Color("B9B3A6"); const PAPER_500 := Color("7F7A70")
const SEA_900 := Color("16222A"); const SEA_700 := Color("1E2F38")
const GOOD := Color("6CC38F"); const BAD := Color("E06A5E"); const WARN := Color("E4A94B"); const INFO := Color("7FA8E8")

## Bezel brass ramp (instrument rings), the gauge track, the map-text halo, hard shadow and the hold-to-confirm bar
const BZ_HI := Color("F1DB9C"); const BZ_BRASS := Color("C9A24B"); const BZ_LO := Color("7F6A33"); const BZ_TRACK := Color("2A2318")
const MAP_SHADE := Color(0.0235, 0.0314, 0.0471, 0.5); const MAP_SHADE45 := Color(0.0235, 0.0314, 0.0471, 0.45); const MAP_SHADOW := Color(0.0196, 0.0157, 0.0118, 0.35)   # the demo's map overlays: rgba(6,8,12,.5 / .45), #050403 at .35
const MAP_FACE := Color("0F0C09"); const MAP_FACE92 := Color(0.0588, 0.0471, 0.0353, 0.92); const MAP_PLATE := Color("1D1812"); const MAP_DISC_EDGE := Color("0B0907"); const MAP_ON_BRASS := Color("14100B")
const MAP_BAD := Color("D2603F"); const MAP_HI := Color("E5C77A"); const MAP_BRASS_MID := Color("B38F3E"); const MAP_BRASS_A := Color("EBCF85"); const MAP_BRASS_C := Color("6F5A27"); const MAP_TICK := Color("8F7637"); const MAP_IVORY := Color("EFE6CF"); const MAP_INK := Color("05070A")
## Bezel demo literals used by the HUD chrome (docs/ui_variants/src: bezel_kit.js, b_demo.html), named so src/ui carries no raw colour
const BZ_TICK := Color("8F7637"); const BZ_SHADOW := Color("050403"); const BZ_FACE := Color("0F0C09"); const BZ_BAD := Color("D2603F"); const BZ_BAD_TXT := Color("EE8A68")
const BZ_DIM2 := Color("8D826A"); const BZ_RAIL_ICON := Color("CDBF9A"); const BZ_RULER := Color("4D4025"); const BZ_NOTICE := Color("15110D"); const BZ_TUNER := Color("0E0C09")
const BZ_PL_A := Color("1D1812"); const BZ_PL_B := Color("13100C"); const BZ_G_A := Color("EBCF85"); const BZ_G_B := Color("B38F3E"); const BZ_G_C := Color("6F5A27")
const BZ_SEA := Color("090C11"); const BZ_OCEAN := Color("0B1522"); const BZ_RIM := Color("5E86C4"); const BZ_GRAT := Color("C9BFA0"); const BZ_HALO := Color("05070A")
const BZ_GOOD := Color("69B3A2"); const BZ_INFO := Color("7FA8E8"); const BZ_NOTICE_BAD := Color("E0795A"); const BZ_IVORY := Color("EFE6CF"); const BZ_DIM := Color("A89C80")
const HALO := Color(0.02, 0.03, 0.05, 0.85); const DROP := Color(0.0, 0.0, 0.0, 0.45); const HOLD_BAR := Color(1.0, 1.0, 1.0, 0.85)

## ---- Bezel kit literals of the demo (docs/ui_variants/src/bezel.css + b_demo.html): every colour the kit draws that has no semantic token above.
## plate: 1 px lo hairline, vertical gradient, 3 px dark inset and a faint brass line at 4 px; buttons are notched plates (lo rim + fill)
const BZ_PLATE_TOP := Color("1D1812"); const BZ_PLATE_BOT := Color("13100C"); const BZ_PLATE_LINE := Color(0.788, 0.635, 0.294, 0.22)
const BZ_BTN_FILL := Color("1A150F"); const BZ_BTN_FILL_HOT := Color("2E2519")
const BZ_PRI_A := Color("EBCF85"); const BZ_PRI_B := Color("B38F3E"); const BZ_PRI_HA := Color("F5DC96"); const BZ_PRI_HB := Color("C49A44"); const BZ_PRI_TX := Color("1B1408")
const BZ_DNG_A := Color("E0724A"); const BZ_DNG_B := Color("A8442B"); const BZ_DNG_HA := Color("EC8058"); const BZ_DNG_HB := Color("B44F33")
const BZ_DNG_LO_HOT := Color("FF9A78"); const BZ_DNG_TX := Color("FFF0E4"); const BZ_WHITE := Color("FFFFFF")
## round instruments: face gradient, outer shade; chips and rows: engraved well, row hover / selected washes, ink-wells (sliders)
const BZ_FACE_A := Color("2A2218"); const BZ_FACE_B := Color("0F0C09"); const BZ_SHADE := Color(0.0196, 0.0157, 0.0118, 0.35)
const BZ_WELL := Color("100D0A"); const BZ_WELL_LINE := Color("3A2F1D"); const BZ_TRACK_BG := Color("0C0A07"); const BZ_TRACK_LINE := Color("4A3F28")
const BZ_ROW_HOT := Color(0.788, 0.635, 0.294, 0.08); const BZ_ROW_ON := Color(0.788, 0.635, 0.294, 0.15)
const BZ_SCRIM := Color(0.0118, 0.0196, 0.0314, 0.62); const BZ_FOOT_LINE := Color("33291A"); const BZ_DOTS := Color("4A3D22")
const BZ_SLIDER_FILL_A := Color("E5C77A"); const BZ_SLIDER_FILL_B := Color("A8842F"); const BZ_ZONE := Color(0.824, 0.376, 0.247, 0.45)
const BZ_TIP_DIM := Color("8D826A"); const BZ_SCROLL := Color("5A4A26"); const BZ_NOTICE_FILL := Color("15110D"); const BZ_BRASS_Z := Color("6F5A27"); const BZ_NEG_SOFT := Color("EE8A68"); const BZ_SHADE_40 := Color(0.0196, 0.0157, 0.0118, 0.4)

static func sig() -> int: return mode * 1000 + ver + (500 if legacy else 0)

## --nation-accent: the player's colour converted to OKLab-HSL, lightness raised until it reaches 4.5:1 against ink-800
static func set_accent(player_rgb: int) -> void:
	var base := Color.hex((player_rgb << 8) | 0xFF)
	var h: float = base.ok_hsl_h
	var sat: float = clampf(base.ok_hsl_s, 0.45, 0.85)
	var l: float = clampf(base.ok_hsl_l, 0.5, 0.9)
	var col: Color = Color.from_ok_hsl(h, sat, l)
	var guard := 0
	while contrast(col, INK_800) < 4.5 and guard < 40:
		l = minf(0.97, l + 0.02); col = Color.from_ok_hsl(h, sat, l); guard += 1
	accent = col
	_atlas = {}
	ver += 1

static func _lighten(col: Color, k: float) -> Color: return col.lerp(Color.WHITE, k)
static func _darken(col: Color, k: float) -> Color: return col.lerp(Color.BLACK, k)

static func atlas() -> Dictionary:
	if not _atlas.is_empty(): return _atlas
	## Bezel palette (docs/ui_variants/src/bezel.css): umber panels, brass bezels, ivory ink. The nation colour lives in flags only.
	var br := Color("C9A24B"); var hi := Color("E5C77A"); var lo := Color("B38F3E")
	var d := {
		"paper_0": Color("17130F"), "paper_1": Color("1E1812"), "paper_2": Color("2A2216"), "paper_hover": Color("2B2318"),
		"ink_0": Color("EFE6CF"), "ink_1": Color("A89C80"), "ink_off": Color("7D735C"),
		"oxblood": Color("EFE6CF"), "brass_ink": hi, "rule": Color("7F6A33"), "hair": Color("3A2F1D"),
		"bar_0": Color("0F0C09"), "bar_1": Color("17130F"), "bar_2": Color("211B14"), "table": Color("0A0D12"),
		"cream": Color("EFE6CF"), "smoke": Color("A89C80"), "brass_lt": hi, "rule_dark": Color("7F6A33"),
		"pos": Color("69B3A2"), "neg": Color("E0795A"), "warn": Color("E4A94B"), "info": Color("7FA8E8"), "foreign": Color("A89C80"),
		"pos_bar": Color("69B3A2"), "neg_bar": Color("E0795A"), "warn_bar": Color("E4A94B"), "info_bar": Color("7FA8E8"), "foreign_bar": Color("A89C80"),
		"brass": br, "brass_hover": hi, "brass_press": lo,
		"wax": Color("A8442B"), "wax_hover": Color("B44F33"), "wax_press": Color("8E3822"), "wax_rim": Color("E0795A"), "on_wax": Color("FFF0E4"),
		"act": br, "act_hover": hi, "act_press": lo, "act_rim": Color("F1DB9C"), "on_act": Color("1B1408"), "on_brass": Color("1B1408"),
	}
	_atlas = d
	return d

## the NORMAL-mode dictionary: Atlas Ledger in game, the umber palette on the title screen
static func normal() -> Dictionary: return LEGACY if legacy else atlas()

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
	if mode == Mode.NORMAL: return normal()[name]
	return (HC_DARK if mode == Mode.HC_DARK else HC)[name]

## the dictionary of a mode (tests walk all three)
static func dict(m: int) -> Dictionary:
	if m == Mode.HC_DARK: return HC_DARK
	return HC if m == Mode.HIGH_CONTRAST else normal()

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
	["on_act", "act", 7.0, 7.0, "primary button"], ["on_act", "act_hover", 4.5, 7.0, "primary button hover"], ["on_act", "act_press", 4.5, 7.0, "primary button pressed"],
	["on_wax", "wax", 4.5, 7.0, "danger button"], ["on_wax", "wax_hover", 4.5, 7.0, "danger button hover"], ["on_wax", "wax_press", 4.5, 7.0, "danger button pressed"],
	["oxblood", "paper_2", 4.5, 7.0, "segmented selected underline and check"],
	["ink_0", "paper_hover", 4.5, 7.0, "hover row text"], ["ink_1", "paper_hover", 4.5, 7.0, "hover row secondary"],
	# non-text: control boundaries, disabled, focus ring, meters
	["rule", "paper_0", 1.5, 4.5, "hairline border on panel (Atlas: decorative, controls are identified by their fill)"], ["rule", "paper_1", 1.5, 4.5, "hairline border on control"],
	["brass_ink", "paper_0", 3.0, 4.5, "armed border on panel"], ["brass_ink", "paper_2", 3.0, 4.5, "own marker on pressed"],
	["act", "paper_0", 3.0, 4.5, "primary button edge on panel"], ["act", "paper_1", 3.0, 4.5, "primary button edge on control"], ["oxblood", "paper_1", 3.0, 4.5, "selected underline vs unselected cell"],
	["wax_rim", "paper_0", 1.5, 4.5, "danger button edge on panel"],
	["rule_dark", "bar_0", 1.5, 4.5, "bar border"], ["rule_dark", "bar_1", 1.5, 4.5, "chip / tooltip border"], ["rule_dark", "bar_2", 1.5, 4.5, "hover chip border"],
	["ink_off", "paper_0", 3.0, 4.5, "disabled text on panel"], ["ink_off", "paper_1", 3.0, 4.5, "disabled text on control"],
	["ink_0", "paper_0", 3.0, 4.5, "focus ring on paper"], ["cream", "bar_0", 3.0, 4.5, "focus ring on bar"], ["cream", "table", 3.0, 4.5, "focus ring on map"],
	["pos", "paper_2", 3.0, 4.5, "meter fill vs pressed"], ["neg", "paper_2", 3.0, 4.5, "meter fill vs pressed"], ["warn", "paper_2", 3.0, 4.5, "meter fill vs pressed"],
	["info", "paper_2", 3.0, 4.5, "info marker vs pressed"], ["foreign", "paper_2", 3.0, 4.5, "foreign marker vs pressed"],
]

# ---- metrics (logical px at Standard density) ---------------------------------------------------
const CUT := 1                  # chamfer for plates, buttons, chips
const CUT_CHIP := 1             # chips <= 28 px high
const CUT_PANEL := 2            # panels and sheets
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
const Z_MODAL := 80             # draw layer of every modal: above the HUD tooltip (70) and popover (65), the map tip (50) and the inspector (60), below the negotiation dial (90)
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
