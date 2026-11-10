## The engraved-plate icon set (docs/ICONS.md): 67 emblems drawn from tools/emblems/emblems.svg, rendered once to white masks (assets/emblems/<id>.png, the engraved cuts knocked
## out) and drawn here tinted with one of five meaning colours. Every icon call of the game (TBGlyph.draw / draw_filled / draw_ic, TBBzIcons.draw) asks TBEmblem first; a name with no
## emblem (the plain markers: diamond, triangles, arrowhead; the capital ring; the unrest burst) keeps its old drawing.
## Settings > Display > Icons: "colour" (default), "brass" (all brass; also forced by every colour-vision mode and by high contrast), "classic" (the old line icons).
class_name TBEmblem
extends RefCounted

static var mode := "colour"                   # "colour" | "brass" | "classic" (set from cfg["icons"] by TBKit.apply_settings)
static var unknown: Dictionary = {}           # names that fell back to the old drawing (the tests read it)

## the five meaning colours: brass (state, money, building, land), bone (people, peace), vermilion (war, danger), Tyrian purple (diplomacy, knowledge), smoke (controls, places)
static var PAL: Dictionary = TBTokens.ICON_PAL

## emblem id -> meaning colour
static var KIND: Dictionary = {
	"treasury": "b", "coin": "b", "tax": "b", "invest": "b", "trade": "b", "decrees": "b", "council": "b", "annals": "b", "goals": "b", "market": "b", "port": "b", "workshop": "b", "build": "b", "develop": "b",
	"crown": "b", "star": "b", "settings": "b", "general": "b", "terms": "b", "hire": "b", "lamp": "b", "clock": "b", "supply": "b", "farm": "b", "settle": "b", "colonize": "b",
	"people": "g", "happy": "g", "peace": "g", "heart": "g",
	"host": "r", "wars": "r", "attack": "r", "fortress": "r", "fortify": "r", "recruit": "r", "spread": "r", "muster": "r", "watchtower": "r", "armory": "r", "supplycamp": "r", "skull": "r", "warning": "r",
	"envoys": "u", "nations": "u", "pact": "u", "spy": "u", "research": "u", "library": "u", "info": "u", "release": "u", "flag": "u",
	"move": "i", "save": "i", "load": "i", "check": "i", "close": "i", "menu": "i", "more": "i", "back": "i", "chevrons": "i", "plus": "i", "minus": "i", "lock": "i", "filter": "i", "pin": "i", "terrain": "i",
}

## every name the game's icon calls use (the old set's names, aliases, verbs) -> emblem id
static var ALIAS: Dictionary = {
	"b_farm": "farm", "b_watchtower": "watchtower", "b_workshop": "workshop", "b_supplycamp": "supplycamp", "b_library": "library", "b_armory": "armory", "b_market": "market", "b_port": "port", "b_fortress": "fortress",
	"nations": "nations", "globe": "nations", "treasury": "treasury", "coins": "treasury", "decrees": "decrees", "scroll": "decrees", "scroll2": "decrees", "council": "council", "annals": "annals", "book": "annals",
	"quill": "lamp", "goals": "goals", "trophy": "goals", "army": "host", "host": "host", "manpower": "host", "people": "people", "men": "people", "population": "people", "envoys": "envoys", "envoy": "envoys", "diplomacy": "envoys",
	"gold": "coin", "coin": "coin", "gold_coin": "coin", "move": "move", "recruit": "recruit", "build": "build", "hammer": "build", "fortify": "fortify", "shield": "fortify", "attack": "attack", "sword": "attack",
	"pact": "pact", "link": "pact", "trade": "trade", "spy": "spy", "eye": "spy", "war": "wars", "wars": "wars", "swords": "wars", "swords2": "wars", "settings": "settings", "gear": "settings", "save": "save", "load": "load",
	"close": "close", "warn": "warning", "warning": "warning", "info": "info", "check": "check", "star": "star", "general_star": "general", "general": "general", "clock": "clock", "hourglass": "clock",
	"research": "research", "flask": "research", "lamp": "lamp", "invest": "invest", "tax": "tax", "happy": "happy", "smile": "happy", "terrain": "terrain", "menu": "menu", "flag": "flag", "lock": "lock", "crown": "crown",
	"skull": "skull", "heart": "heart", "ship": "colonize", "dots": "more", "pin": "pin", "scales": "terms", "dove": "peace", "filter": "filter", "supply": "supply", "back": "back", "chevrons": "chevrons",
	"plus": "plus", "minus": "minus", "hire": "hire", "raise": "recruit", "develop": "develop", "settle": "settle", "colonize": "colonize", "spread": "spread", "muster": "muster", "release": "release", "terms": "terms", "peace": "peace",
	"fortress": "fortress", "market": "market", "port": "port", "library": "library", "farm": "farm", "watchtower": "watchtower", "workshop": "workshop", "supplycamp": "supplycamp", "armory": "armory",
}

## the pixel sizes the masters are scaled to (the nearest one above the size drawn: crisp, never a big mask squeezed small)
static var BINS: Array = [24, 32, 40, 56, 72, 96, 128, 192, 256]
static var _master: Dictionary = {}           # id -> Image (256 px)
static var _tex: Dictionary = {}              # "id@bin" -> ImageTexture

static func active() -> bool: return mode != "classic"
static func exists(id: String) -> bool: return KIND.has(id)

## the emblem id for an icon name, or "" (old drawing)
static func id_of(name: String) -> String:
	var id: String = String(ALIAS.get(name, ""))
	return id if KIND.has(id) else ""

static func _texture(id: String, px: float) -> Texture2D:
	var want := int(ceilf(px))
	var bin: int = BINS[BINS.size() - 1]
	for b in BINS:
		if int(b) >= want: bin = int(b); break
	var key := "%s@%d" % [id, bin]
	if _tex.has(key): return _tex[key]
	var img: Image = _master.get(id)
	if img == null:
		var path := "res://assets/emblems/%s.png" % id
		var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if t == null: return null
		img = t.get_image()
		if img == null: return null
		if img.is_compressed(): img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_master[id] = img
	var out: Image = img
	if bin != img.get_width():
		out = img.duplicate(); out.resize(bin, bin, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(out)
	_tex[key] = tex
	return tex

## the colour an emblem is drawn in: the colour passed by the call keeps its alpha and its dimness (a disabled icon stays dim), and the game's own status colours (teal, coral, blue) pass through
static func tint(id: String, col: Color) -> Color:
	if mode != "colour" or TBKit.cvd != "off" or TBTokens.is_hc(): return col
	var lum: float = col.get_luminance()
	if lum < 0.28: return col                                                  # dark ink on a brass plate (the primary verb of the ring): stays dark
	if col.s > 0.35 and ((col.h > 0.40 and col.h < 0.70) or col.h < 0.06 or col.h > 0.96): return col
	var m: Color = PAL[String(KIND.get(id, "b"))]
	var k: float = clampf((lum - 0.2) / 0.5, 0.3, 1.0)                         # a disabled icon (dim ink) stays dim
	return Color(m.r * k, m.g * k, m.b * k, col.a)

## draw the emblem for `name` centred at c, size px square; false = no emblem (draw the old one). mono: in the colour the caller passes, no meaning colour (the province ring is one brass instrument)
static func draw(ci: CanvasItem, name: String, c: Vector2, size: float, col: Color, mono: bool = false) -> bool:
	if mode == "classic": return false
	var id := id_of(name)
	if id == "":
		unknown[name] = true
		return false
	var xf: Transform2D = ci.get_global_transform_with_canvas()
	var sc: float = maxf(absf(xf.get_scale().x), 0.01)
	var rect := Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size))
	var dpx: float = maxf(roundf(size * sc), 2.0)
	if absf(xf.x.y) < 0.001 and absf(xf.y.x) < 0.001:                         # no rotation: put the emblem on whole device pixels, so it is crisp and its middle is the plate's middle
		var tl: Vector2 = ((xf * c) - Vector2(dpx, dpx) * 0.5).round()
		rect = Rect2(xf.affine_inverse() * tl, Vector2(dpx, dpx) / sc)
	var tex := _texture(id, dpx)
	if tex == null: return false
	ci.draw_texture_rect(tex, rect, false, col if mono else tint(id, col))
	return true
