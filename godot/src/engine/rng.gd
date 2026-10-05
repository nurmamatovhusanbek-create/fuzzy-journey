## Seeded deterministic RNG (mulberry32) — the ONLY randomness source in the engine.
class_name TBRng
extends RefCounted

const M := 0xFFFFFFFF
var s: int = 1

func _init(seed_value: int = 1) -> void:
	s = seed_value & M
	if s == 0:
		s = 1

static func imul(a: int, b: int) -> int:
	return (a * b) & M

func next() -> float:
	s = (s + 0x6D2B79F5) & M
	var t: int = imul(s ^ (s >> 15), s | 1)
	t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & M)) & M
	return float((t ^ (t >> 14)) & M) / 4294967296.0

func randi_n(n: int) -> int:
	return int(next() * n)

func chance(p: float) -> bool:
	return next() < p

static func hash_str(str_value: String) -> int:
	var h: int = 2166136261
	for i in str_value.length():
		h ^= str_value.unicode_at(i)
		h = imul(h, 16777619)
	return h & M
