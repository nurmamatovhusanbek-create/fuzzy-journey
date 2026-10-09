## Procedural nation flags: deterministic from the nation code (stable across games/devices), cached as small textures.
class_name TBFlags
extends RefCounted

const W := 48
const H := 32
static var _cache := {}
## the era whose flags are shown (set when a game starts or loads); an era with no art for a nation falls back to the procedural flag
static var cur_era := ""
const DIR := "res://assets/flags/"

## the historical flag of `code` in `era` (res://assets/flags/<era>/<code>.png, rasterised from Wikimedia Commons: see flags/ATTRIBUTION.md), or null
static func historical(code: String, era: String) -> Texture2D:
	if era == "": return null
	var key := "h:%s:%s" % [era, code]
	if _cache.has(key): return _cache[key]
	var path := "%s%s/%s.png" % [DIR, era, code]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = t
	return t

## the square, circle-ready crop of an era flag (focused on its main element), or null when the era has no art for the nation
static func medal(code: String, era: String = "") -> Texture2D:
	var e: String = era if era != "" else cur_era
	if e == "": return null
	var key := "m:%s:%s" % [e, code]
	if _cache.has(key): return _cache[key]
	var path := "%s%s/%s_c.png" % [DIR, e, code]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = t
	return t

static func texture(code: String, base_rgb: int, era: String = "") -> Texture2D:
	var hist: Texture2D = historical(code, era if era != "" else cur_era)
	if hist != null: return hist
	var key := "%s:%d" % [code, base_rgb]
	if _cache.has(key): return _cache[key]
	var h := TBRng.hash_str(code)
	var rng := TBRng.new(h)
	var base := Color.hex((base_rgb << 8) | 0xFF)
	var c1 := base
	var c2 := Color.from_hsv(fposmod(base.h + 0.45 + rng.next() * 0.2, 1.0), 0.55 + rng.next() * 0.3, 0.75 + rng.next() * 0.2)
	var c3 := Color(1, 1, 1) if rng.next() < 0.6 else Color(0.08, 0.08, 0.1)
	var pattern := h % 7
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var u := float(x) / (W - 1); var v := float(y) / (H - 1)
			var c := c1
			match pattern:
				0: c = c1 if v < 0.34 else (c3 if v < 0.67 else c2)                       # horizontal tricolour
				1: c = c1 if u < 0.34 else (c3 if u < 0.67 else c2)                       # vertical tricolour
				2: c = c2 if (absf(u - 0.38) < 0.12 or absf(v - 0.5) < 0.14) else c1       # nordic cross
				3: c = c2 if (u + v * 0.6) > 0.95 else c1                                   # diagonal split
				4: c = c3 if (absf(u - 0.5) < 0.08 or absf(v - 0.5) < 0.1) else (c2 if (u < 0.5) == (v < 0.5) else c1)  # quartered
				5: c = c2 if Vector2(u - 0.5, (v - 0.5) * 0.66).length() < 0.2 else c1      # roundel
				6: c = c1 if int(v * 5.0) % 2 == 0 else c3                                  # stripes
			img.set_pixel(x, y, c)
	# thin border
	for x in W:
		img.set_pixel(x, 0, c1.darkened(0.5)); img.set_pixel(x, H - 1, c1.darkened(0.5))
	for y in H:
		img.set_pixel(0, y, c1.darkened(0.5)); img.set_pixel(W - 1, y, c1.darkened(0.5))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func chip(g: TBGame, n: int, scale: float = 0.6) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture(g.nat_code[n], g.color[n], g.era_id)
	t.custom_minimum_size = Vector2(W * scale, H * scale)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t
