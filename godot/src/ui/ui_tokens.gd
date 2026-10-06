## Single source of colour and metric tokens for the interface (design/art/art-bible.md sections 3, 4 and 7).
## No raw Color(...) literals elsewhere in src/ui: use these names. `mode` switches Normal / High contrast.
class_name TBTokens
extends RefCounted

enum Mode { NORMAL, HIGH_CONTRAST }
static var mode: int = Mode.NORMAL

# ---- paper ground (documents) ------------------------------------------------------------------
const NORMAL := {
	"paper_0": Color("EFE3C6"), "paper_1": Color("E2D2AC"), "paper_2": Color("D3C095"), "paper_hover": Color("EADFBE"),
	"ink_0": Color("231A11"), "ink_1": Color("54442F"), "ink_off": Color("7C6C4F"),
	"oxblood": Color("7A1D17"), "brass_ink": Color("735010"), "rule": Color("7F6A46"), "hair": Color("B9A57C"),
	# ---- bar ground (furniture)
	"bar_0": Color("120D09"), "bar_1": Color("231A12"), "bar_2": Color("33261A"), "table": Color("060A14"),
	"cream": Color("F3E9D2"), "smoke": Color("C2B79F"), "brass_lt": Color("F2C552"), "rule_dark": Color("8A7340"),
	# ---- semantic, paper ground
	"pos": Color("0C6254"), "neg": Color("9A2417"), "warn": Color("7F4C00"), "info": Color("245785"), "foreign": Color("4F5662"),
	# ---- semantic, bar ground
	"pos_bar": Color("72D9C0"), "neg_bar": Color("FF8A78"), "warn_bar": Color("F2B84B"), "info_bar": Color("7DB3E8"), "foreign_bar": Color("A9B1BE"),
	# ---- actions
	"brass": Color("D9A93C"), "brass_hover": Color("E6B94C"), "brass_press": Color("BF9230"),
	"wax": Color("8E1E16"), "wax_hover": Color("A3281A"), "wax_press": Color("741710"), "wax_rim": Color("5B120D"), "on_wax": Color("FBF3E0"),
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
}

## token lookup honouring the active mode: TBTokens.c("ink_0")
static func c(name: String) -> Color:
	return (HC if mode == Mode.HIGH_CONTRAST else NORMAL)[name]

# ---- metrics (logical px at Standard density) ---------------------------------------------------
const CUT := 4                  # chamfer for plates, buttons, chips
const CUT_CHIP := 2             # chips <= 28 px high
const CUT_PANEL := 6            # panels and sheets
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

# ---- type roles (px at 100 %); sizes are multiplied by the text scale elsewhere -----------------
const FS_TITLE := 20
const FS_BODY_PHONE := 15
const FS_BODY := 14
const FS_DETAIL := 13
const FS_CAPTION := 12          # absolute floor at 100 %
const FS_FIGURE := 16
const FS_DELTA := 12
