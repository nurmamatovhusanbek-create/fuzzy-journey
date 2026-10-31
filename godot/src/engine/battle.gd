## Rules 4 battles (docs/WAR_DESIGN.md section 5): three rounds, each side losing a share of its men that grows with the enemy's strength relative to its own
## (a linear law in the spirit of Lanchester's: the side with more strength loses less and hurts more, but a larger army does not erase a smaller one in one blow). Deterministic: the same inputs
## always give the same result, so the preview can show the real outcome and a range around it instead of a dice roll.
class_name TBBattle
extends RefCounted

const ROUNDS := 3
const K := 0.16                  # share lost per round at equal strength
const MIN_LOSS := 0.04           # even a hopeless enemy hurts a little
const MAX_LOSS := 0.35           # and even a crushing one cannot kill more than a third of an army in a round
const RETREAT := 0.8             # share of a beaten army's survivors that gets away (the rest is scattered or captured)
const SPREAD := 0.10             # best and worst case: the army's strength is 10 % more or less

## men_a attack with strength multiplier mul_a against men_d with mul_d (terrain, era, general and fortifications already inside the multipliers)
static func fight(men_a: int, mul_a: float, men_d: int, mul_d: float) -> Dictionary:
	var a := float(maxi(1, men_a)); var d := float(maxi(0, men_d))
	if d < 1.0: return {"win": true, "a_left": men_a, "d_left": 0, "a_lost": 0, "d_lost": maxi(0, men_d)}
	for r in ROUNDS:
		var sa: float = a * mul_a; var sd: float = d * mul_d
		if sa <= 0.0 or sd <= 0.0 or a < 1.0 or d < 1.0: break
		var la: float = clampf(K * sd / sa, MIN_LOSS, MAX_LOSS)
		var ld: float = clampf(K * sa / sd, MIN_LOSS, MAX_LOSS)
		a -= a * la; d -= d * ld
	var a_left := clampi(int(round(a)), 0, men_a); var d_left := clampi(int(round(d)), 0, men_d)
	return {"win": a * mul_a > d * mul_d, "a_left": a_left, "d_left": d_left, "a_lost": men_a - a_left, "d_lost": men_d - d_left}

## the same battle with the attacker's strength raised (best case) or lowered (worst case) by SPREAD, and the defender's the other way round
static func ranged(men_a: int, mul_a: float, men_d: int, mul_d: float) -> Dictionary:
	return {"best": fight(men_a, mul_a * (1.0 + SPREAD), men_d, mul_d * (1.0 - SPREAD)), "expected": fight(men_a, mul_a, men_d, mul_d), "worst": fight(men_a, mul_a * (1.0 - SPREAD), men_d, mul_d * (1.0 + SPREAD))}
