## Server-side room: an authoritative TBGame plus lobby/turn bookkeeping.
class_name TBRoom
extends RefCounted

var code := ""
var host_peer := 0
var g: TBGame
var era_id := "modern"
var difficulty := "normal"
var state := "lobby"            # lobby | playing | over
var turn_secs := 120
var deadline_ms := 0
var players := {}               # peer_id -> {name, nation, token, connected}
var ready := {}                 # nation -> true
var prev := {}                  # last-sent matrices (delta baseline)
var log_sent := 0
var proposals := {}             # id -> {id, kind, from, to}
var next_prop := 1
var created_ms := 0

func nation_taken(n: int) -> bool:
	for pid in players:
		if players[pid]["nation"] == n: return true
	return false

func peer_of_nation(n: int) -> int:
	for pid in players:
		if players[pid]["nation"] == n and players[pid]["connected"]: return pid
	return 0

func connected_count() -> int:
	var c := 0
	for pid in players:
		if players[pid]["connected"]: c += 1
	return c

func all_ready() -> bool:
	var any := false
	for pid in players:
		var p: Dictionary = players[pid]
		if not p["connected"] or p["nation"] == 0: continue
		any = true
		if not ready.has(p["nation"]): return false
	return any

func info() -> Dictionary:
	var pl := []
	for pid in players:
		var p: Dictionary = players[pid]
		pl.append({"peer": pid, "name": p["name"], "nation": p["nation"], "connected": p["connected"], "ready": ready.has(p["nation"]) and p["nation"] != 0, "host": pid == host_peer})
	return {"code": code, "state": state, "era": era_id, "difficulty": difficulty, "turn_secs": turn_secs, "players": pl, "host": host_peer,
		"deadline_left": maxi(0, deadline_ms - Time.get_ticks_msec()) if state == "playing" else 0}
