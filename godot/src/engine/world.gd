## Static baked world (read-only): geometry-free metadata + ID raster.
class_name TBWorld
extends RefCounted

var W: int
var H: int
var P: int
var ids: PackedByteArray          # u16 little-endian id raster (0 = ocean, else province index + 1)
var id: PackedStringArray
var name: PackedStringArray
var lat: PackedFloat64Array
var lon: PackedFloat64Array
var area: PackedInt32Array
var nb_off: PackedInt32Array
var nb: PackedInt32Array
var nat_code: PackedStringArray
var nat_name: PackedStringArray
var prov_nat: PackedInt32Array
# adjacency incl. sea links, precomputed by the bake (empty if the data predates it)
var nbx_off: PackedInt32Array
var nbx: PackedInt32Array
var nbx_sea: PackedByteArray

static func load_from(dir: String) -> TBWorld:
	var w := TBWorld.new()
	var txt := FileAccess.get_file_as_string(dir + "/world.json")
	var d: Dictionary = JSON.parse_string(txt)
	w.W = int(d["W"]); w.H = int(d["H"]); w.P = int(d["P"])
	w.id = PackedStringArray(d["id"]); w.name = PackedStringArray(d["name"])
	w.lat = PackedFloat64Array(d["lat"]); w.lon = PackedFloat64Array(d["lon"])
	w.area = _ints(d["area"]); w.nb_off = _ints(d["nbOff"]); w.nb = _ints(d["nb"])
	w.nat_code = PackedStringArray(d["natCode"]); w.nat_name = PackedStringArray(d["natName"]); w.prov_nat = _ints(d["provNat"])
	if d.has("nbOffX"):
		w.nbx_off = _ints(d["nbOffX"]); w.nbx = _ints(d["nbX"]); w.nbx_sea = _bytes(d["nbSeaX"])
	var gz := FileAccess.get_file_as_bytes(dir + "/ids.bin.gz")
	w.ids = gz.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	return w

static func load_era(dir: String, era_id: String) -> Dictionary:
	var f := dir + "/eras/" + era_id + ".json"
	if not FileAccess.file_exists(f):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(f))

static func _bytes(a: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(a.size())
	for i in a.size():
		out[i] = int(a[i])
	return out

static func _ints(a: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = int(a[i])
	return out
