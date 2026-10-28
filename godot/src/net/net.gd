## Multiplayer node (identical script + path "/root/Net" on server and clients so RPCs match).
## Server: authoritative TBGame per room; clients send commands, receive result + compact deltas.
class_name TBNet
extends Node

signal connected
signal disconnected
signal room_updated(info: Dictionary)
signal snapshot_ready(game: TBGame)
signal delta_applied(dirty: PackedInt32Array)
signal command_result(seq: int, res: Dictionary)
signal proposal_received(p: Dictionary)
signal chat_received(from: String, text: String)
signal error_received(msg: String)

const D = preload("res://src/engine/data.gd")
const MAX_ROOMS := 50
const ROOM_TTL_MS := 6 * 3600 * 1000
const MAX_PEERS := 200
const MAX_PROPOSALS_PER_NATION := 4
const IDLE_PEER_MS := 60000          # a connection that never creates or joins a room is dropped
const AFK_MS := 600000               # with the turn clock off, a player silent this long is counted ready so the others are not held for ever
const JOIN_FAILS_MAX := 8
const DEALS := ["white", "vassal", "cede"]
const ERAS := ["modern", "ancient", "roman", "medieval", "mongol", "timurid", "discovery", "gunpowder", "napoleonic", "victorian", "ww1", "ww2", "coldwar"]

var world: TBWorld
var is_server_mode := false
# ---- server state
var rooms := {}                 # code -> TBRoom
var peer_room := {}             # peer -> code
var _seen_ms := {}              # peer -> when the connection opened
var _join_fails := {}           # peer -> wrong room codes tried
# ---- client state
var game: TBGame
var room_info := {}
var my_token := ""
var my_room := ""
var my_nation := 0
var _seq := 0
var _peer: WebSocketMultiplayerPeer

# ================================================================= bootstrap
func start_server(w: TBWorld, port: int) -> bool:
	world = w; is_server_mode = true
	_peer = WebSocketMultiplayerPeer.new()
	_peer.handshake_timeout = 5.0                                              # a socket that does not finish the handshake is dropped
	_peer.inbound_buffer_size = 1 << 16                                        # clients only ever send small commands
	_peer.max_queued_packets = 1024
	var err := _peer.create_server(port)
	if err != OK:
		push_error("server listen failed: %s" % err); return false
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_disconnected.connect(_on_peer_gone)
	multiplayer.peer_connected.connect(_on_peer_in)
	print("[server] listening on :%d" % port)
	return true

func connect_to(w: TBWorld, url: String) -> bool:
	if url.length() > 200 or not (url.begins_with("wss://") or url.begins_with("ws://")): return false      # only a WebSocket address
	world = w; is_server_mode = false
	_peer = WebSocketMultiplayerPeer.new()
	var err := _peer.create_client(url)
	if err != OK: return false
	multiplayer.multiplayer_peer = _peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(func(): error_received.emit("connection failed"); disconnected.emit())
		multiplayer.server_disconnected.connect(func(): disconnected.emit())
	return true

func close() -> void:
	if _peer: _peer.close()
	multiplayer.multiplayer_peer = null

func _on_connected() -> void: connected.emit()

# ================================================================= client -> server API (call these from UI)
func create_room(player_name: String, era: String, difficulty: String, turn_secs: int) -> void:
	c_create_room.rpc_id(1, player_name, era, difficulty, turn_secs)
func join_room(code: String, player_name: String) -> void:
	c_join_room.rpc_id(1, code.to_upper(), player_name, my_token)
func pick_nation(n: int) -> void: c_pick_nation.rpc_id(1, n)
func start_game() -> void: c_start.rpc_id(1)
func send_command(cmd: Dictionary) -> int:
	_seq += 1; c_cmd.rpc_id(1, _seq, cmd); return _seq
func end_turn() -> void: c_end_turn.rpc_id(1)
func respond(pid: int, accept: bool) -> void: c_respond.rpc_id(1, pid, accept)
func chat(text: String) -> void: c_chat.rpc_id(1, text)
func leave() -> void: c_leave.rpc_id(1)

# ================================================================= RPCs: client -> server
@rpc("any_peer", "call_remote", "reliable")
func c_create_room(player_name: String, era: String, difficulty: String, turn_secs: int) -> void:
	if not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	if not _allow(peer, 10.0): s_error.rpc_id(peer, "slow down"); return
	if _room_of(peer) != null: s_error.rpc_id(peer, "already in a room"); return
	_purge_old()
	if rooms.size() >= MAX_ROOMS: s_error.rpc_id(peer, "server full"); return
	var room := TBRoom.new()
	room.code = _new_code(); room.host_peer = peer; room.created_ms = Time.get_ticks_msec()
	room.era_id = era if era in ERAS else "modern"
	room.difficulty = difficulty if difficulty in ["easy", "normal", "hard"] else "normal"
	room.turn_secs = 0 if turn_secs <= 0 else clampi(turn_secs, 15, 900)      # 0 = Off: no clock, turns resolve when everyone is ready (A11Y-TIM-002)
	var era_pack := TBWorld.load_era("res://data", room.era_id) if room.era_id != "modern" else {}
	room.g = TBGame.new(world, era_pack, {"seed": randi() & 0x7fffffff | 1, "difficulty": room.difficulty})
	var token := _new_token()
	room.players[peer] = {"name": _clean(player_name), "nation": 0, "token": token, "connected": true, "last_ms": Time.get_ticks_msec()}
	rooms[room.code] = room; peer_room[peer] = room.code
	s_joined.rpc_id(peer, room.code, token)
	_send_snapshot(room, peer)
	_broadcast_room(room)

@rpc("any_peer", "call_remote", "reliable")
func c_join_room(code: String, player_name: String, token: String) -> void:
	if not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	if not _allow(peer, 3.0): s_error.rpc_id(peer, "slow down"); return
	if code.length() > 8 or token.length() > 64: s_error.rpc_id(peer, "room not found"); return
	var room: TBRoom = rooms.get(code)
	if room == null:
		_join_fails[peer] = int(_join_fails.get(peer, 0)) + 1
		s_error.rpc_id(peer, "room not found")
		if int(_join_fails[peer]) >= JOIN_FAILS_MAX: _peer.disconnect_peer(peer)       # guessing room codes
		return
	if _room_of(peer) != null and _room_of(peer) != room: s_error.rpc_id(peer, "already in a room"); return
	# rejoin with token
	for pid in room.players.keys():
		var p: Dictionary = room.players[pid]
		if token != "" and p["token"] == token:
			if pid != peer:
				room.players.erase(pid); peer_room.erase(pid); _bucket.erase(pid)
				if pid in multiplayer.get_peers(): _peer.disconnect_peer(pid)          # the old socket of the same player goes
			room.players[peer] = p; p["connected"] = true; p["last_ms"] = Time.get_ticks_msec()
			if room.host_peer == pid: room.host_peer = peer
			peer_room[peer] = code
			if p["nation"] != 0 and room.state == "playing": room.g.human[p["nation"]] = 1
			s_joined.rpc_id(peer, code, token)
			_send_snapshot(room, peer); _broadcast_room(room); return
	if room.state != "lobby": s_error.rpc_id(peer, "game already started"); return
	if room.players.size() >= 8: s_error.rpc_id(peer, "room full"); return
	var tk := _new_token()
	if room.players.has(peer): s_error.rpc_id(peer, "already in this room"); return
	room.players[peer] = {"name": _clean(player_name), "nation": 0, "token": tk, "connected": true, "last_ms": Time.get_ticks_msec()}
	peer_room[peer] = code
	s_joined.rpc_id(peer, code, tk)
	_send_snapshot(room, peer)
	_broadcast_room(room)

@rpc("any_peer", "call_remote", "reliable")
func c_pick_nation(n: int) -> void:
	if not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	var room := _room_of(peer)
	if room == null or room.state != "lobby" or not _allow(peer, 2.0): return
	if n < 1 or n >= room.g.N1 or room.g.alive[n] == 0 or room.nation_taken(n): s_error.rpc_id(peer, "nation unavailable"); return
	room.players[peer]["nation"] = n
	_broadcast_room(room)

@rpc("any_peer", "call_remote", "reliable")
func c_start() -> void:
	if not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	var room := _room_of(peer)
	if room == null or room.state != "lobby" or peer != room.host_peer: return
	for pid in room.players:
		if room.players[pid]["nation"] == 0: s_error.rpc_id(peer, "everyone must pick a nation"); return
	for pid in room.players:
		room.g.add_human(room.players[pid]["nation"])
	room.g.human_id = room.players[room.host_peer]["nation"]
	room.state = "playing"; room.deadline_ms = (Time.get_ticks_msec() + room.turn_secs * 1000) if room.turn_secs > 0 else 0
	room.log_sent = room.g.log.size()
	for pid in room.players: _send_snapshot(room, pid)
	_broadcast_room(room)

@rpc("any_peer", "call_remote", "reliable")
func c_cmd(seq: int, cmd: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	var room := _room_of(peer)
	if room == null or room.state != "playing": return
	var n: int = room.players[peer]["nation"]
	room.players[peer]["last_ms"] = Time.get_ticks_msec()
	if n == 0 or room.ready.has(n): s_result.rpc_id(peer, seq, {"ok": false, "err": "notready"}); return
	if not _allow(peer):
		s_result.rpc_id(peer, seq, {"ok": false, "err": "ratelimit"}); return
	cmd = _sanitize(cmd, room.g)
	if cmd.is_empty():
		s_result.rpc_id(peer, seq, {"ok": false, "err": "invalid"}); return
	var kind: String = String(cmd.get("cmd", ""))
	if kind in ["peace", "ally", "nap", "marry", "trade"] and int(cmd.get("t", 0)) > 0 and int(cmd.get("t", 0)) < room.g.N1 and room.g.human[int(cmd["t"])] != 0:
		_make_proposal(room, peer, n, kind, int(cmd["t"]), String(cmd.get("kind", "white")), seq); return
	var c := cmd.duplicate(); c["n"] = n                       # the nation is the sender's own; the schema already removed every internal flag
	var res := room.g.apply(c)
	s_result.rpc_id(peer, seq, res)
	_broadcast_delta(room, false)

@rpc("any_peer", "call_remote", "reliable")
func c_end_turn() -> void:
	if not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	var room := _room_of(peer)
	if room == null or room.state != "playing": return
	var n: int = room.players[peer]["nation"]
	if n == 0 or not _allow(peer): return
	room.players[peer]["last_ms"] = Time.get_ticks_msec()
	room.ready[n] = true
	_broadcast_room(room)
	if room.all_ready(): _resolve_turn(room)

@rpc("any_peer", "call_remote", "reliable")
func c_respond(pid: int, accept: bool) -> void:
	if not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	var room := _room_of(peer)
	if room == null or not room.proposals.has(pid) or not _allow(peer): return
	var pr: Dictionary = room.proposals[pid]
	if room.players[peer]["nation"] != pr["to"]: return
	room.proposals.erase(pid)
	var from_peer := room.peer_of_nation(pr["from"])
	if not accept:
		if from_peer != 0: s_error.rpc_id(from_peer, "proposal declined")
		return
	var res := {}
	match pr["kind"]:
		"ally": res = room.g.apply({"cmd": "ally", "n": pr["from"], "t": pr["to"]})
		"nap": res = room.g.apply({"cmd": "nap", "n": pr["from"], "t": pr["to"]})
		"marry": res = room.g.apply({"cmd": "marry", "n": pr["from"], "t": pr["to"]})
		"trade": res = room.g.apply({"cmd": "trade", "n": pr["from"], "t": pr["to"]})
		"peace": res = room.g.apply({"cmd": "peace", "n": pr["from"], "t": pr["to"], "kind": pr["deal"], "_force": true})
	if from_peer != 0 and not res.get("ok", false): s_error.rpc_id(from_peer, "proposal failed: %s" % res.get("err", "?"))
	_broadcast_delta(room, false)

@rpc("any_peer", "call_remote", "reliable")
func c_chat(text: String) -> void:
	if not multiplayer.is_server(): return
	var peer := multiplayer.get_remote_sender_id()
	var room := _room_of(peer)
	if room == null or not _allow(peer, 4.0): return
	var line := _clean_text(text, 200)
	if line == "": return
	var nm: String = room.players[peer]["name"]
	for pid in room.players:
		if room.players[pid]["connected"]: s_chat.rpc_id(pid, nm, line)

@rpc("any_peer", "call_remote", "reliable")
func c_leave() -> void:
	if not multiplayer.is_server(): return
	_on_peer_gone(multiplayer.get_remote_sender_id(), true)

# ================================================================= RPCs: server -> client
@rpc("authority", "call_remote", "reliable")
func s_joined(code: String, token: String) -> void:
	my_room = code; my_token = token

@rpc("authority", "call_remote", "reliable")
func s_room(info: Dictionary) -> void:
	if not (info.get("players") is Array): return                          # a malformed room report is ignored
	room_info = info
	for p in info["players"]:
		if p is Dictionary and p.get("peer", 0) == multiplayer.get_unique_id(): my_nation = int(p.get("nation", 0))
	if game != null and my_nation != 0: game.human_id = my_nation
	room_updated.emit(info)

@rpc("authority", "call_remote", "reliable")
func s_snapshot(bytes: PackedByteArray) -> void:
	var fresh := TBNetProto.restore_snapshot(world, bytes)
	if fresh == null: error_received.emit("bad snapshot"); return
	game = fresh
	if game != null:
		if my_nation != 0: game.human_id = my_nation
		snapshot_ready.emit(game)

@rpc("authority", "call_remote", "reliable")
func s_delta(bytes: PackedByteArray) -> void:
	if game == null: return
	var dirty := TBNetProto.apply_delta(game, bytes)
	if dirty.size() == 1 and dirty[0] == TBNetProto.BAD: error_received.emit("bad update"); return      # nothing was applied
	delta_applied.emit(dirty)

@rpc("authority", "call_remote", "reliable")
func s_result(seq: int, res: Dictionary) -> void: command_result.emit(seq, res)

@rpc("authority", "call_remote", "reliable")
func s_proposal(p: Dictionary) -> void: proposal_received.emit(p)

@rpc("authority", "call_remote", "reliable")
func s_chat(from: String, text: String) -> void: chat_received.emit(_clean(from), _clean_text(text, 200))

@rpc("authority", "call_remote", "reliable")
func s_error(msg: String) -> void: error_received.emit(_clean_text(msg, 80))

# ================================================================= server internals
# --- input validation: a public server must never trust client dictionaries
## a client command through the engine's own schema (TBCommands.normalize): only listed fields, typed and in range, no internal flags. `n` is never taken from the client.
func _sanitize(cmd: Dictionary, g: TBGame) -> Dictionary:
	var c := cmd.duplicate()
	c["n"] = 1                                                           # a stand-in: the server sets the real nation after this
	var out := TBCommands.normalize(g, c, false)
	out.erase("n")
	return out

var _bucket := {}            # peer -> [tokens, last_ms]
const BUCKET_MAX := 30.0
const BUCKET_RATE := 15.0
## 15 actions/s sustained, bursts of 30; chat, lobby changes and room creation cost more
func _allow(peer: int, cost: float = 1.0) -> bool:
	var now := Time.get_ticks_msec()
	var b: Array = _bucket.get(peer, [BUCKET_MAX, now])
	b[0] = minf(BUCKET_MAX, b[0] + (now - b[1]) / 1000.0 * BUCKET_RATE)
	b[1] = now
	var ok: bool = b[0] >= cost
	if ok: b[0] -= cost
	_bucket[peer] = b
	return ok

func _process(_d: float) -> void:
	if not is_server_mode or not multiplayer.has_multiplayer_peer(): return
	var now := Time.get_ticks_msec()
	for code in rooms.keys():
		var room: TBRoom = rooms[code]
		if room.state == "playing" and room.turn_secs > 0 and now >= room.deadline_ms: _resolve_turn(room)
		elif room.state == "playing" and room.turn_secs == 0: _count_afk_ready(room, now)
	for peer in _seen_ms.keys():
		if not peer_room.has(peer) and now - int(_seen_ms[peer]) > IDLE_PEER_MS: _seen_ms.erase(peer); _peer.disconnect_peer(peer)       # never joined anything

func _on_peer_in(peer: int) -> void:
	if multiplayer.get_peers().size() > MAX_PEERS: _peer.disconnect_peer(peer); return
	_seen_ms[peer] = Time.get_ticks_msec()

## the turn clock is off: a player who has been silent for AFK_MS counts as ready (the others are never held for ever)
func _count_afk_ready(room: TBRoom, now: int) -> void:
	var changed := false
	for pid in room.players:
		var p: Dictionary = room.players[pid]
		if p["connected"] and p["nation"] != 0 and not room.ready.has(p["nation"]) and now - int(p.get("last_ms", now)) > AFK_MS:
			room.ready[p["nation"]] = true; changed = true
	if changed:
		_broadcast_room(room)
		if room.all_ready(): _resolve_turn(room)

func _resolve_turn(room: TBRoom) -> void:
	room.g.end_turn()
	room.ready.clear()
	for pid in room.players: room.players[pid]["last_ms"] = Time.get_ticks_msec()
	room.proposals.clear()
	room.deadline_ms = (Time.get_ticks_msec() + room.turn_secs * 1000) if room.turn_secs > 0 else 0
	if room.g.over: room.state = "over"
	_broadcast_delta(room, true)
	_broadcast_room(room)

func _broadcast_delta(room: TBRoom, full: bool) -> void:
	var dirty := room.g.take_dirty()
	var bytes := TBNetProto.make_delta(room.g, dirty, room.log_sent, full, room.prev)
	room.log_sent = room.g.log.size()
	for pid in room.players:
		if room.players[pid]["connected"]: s_delta.rpc_id(pid, bytes)

func _send_snapshot(room: TBRoom, peer: int) -> void:
	# matrices baseline for future deltas
	for m in TBNetProto.MATRICES: room.prev[m] = room.g.get(m).duplicate()
	s_snapshot.rpc_id(peer, TBNetProto.snapshot(room.g))
	s_room.rpc_id(peer, room.info())

func _broadcast_room(room: TBRoom) -> void:
	var inf := room.info()
	for pid in room.players:
		if room.players[pid]["connected"]: s_room.rpc_id(pid, inf)

func _make_proposal(room: TBRoom, peer: int, from: int, kind: String, to: int, deal: String, seq: int) -> void:
	var tp := room.peer_of_nation(to)
	if tp == 0: s_result.rpc_id(peer, seq, {"ok": false, "err": "refused"}); return
	if not deal in DEALS: deal = "white"
	var mine := 0
	for id in room.proposals:
		var q: Dictionary = room.proposals[id]
		if q["from"] == from and q["to"] == to and q["kind"] == kind: s_result.rpc_id(peer, seq, {"ok": false, "err": "asked"}); return     # one open offer of a kind per pair
		if q["from"] == from: mine += 1
	if mine >= MAX_PROPOSALS_PER_NATION: s_result.rpc_id(peer, seq, {"ok": false, "err": "asked"}); return
	var id := room.next_prop; room.next_prop += 1
	room.proposals[id] = {"id": id, "kind": kind, "from": from, "to": to, "deal": deal}
	s_proposal.rpc_id(tp, {"id": id, "kind": kind, "from": from, "from_name": room.g.nat_name[from], "deal": deal})
	s_result.rpc_id(peer, seq, {"ok": true, "pending": true})

func _on_peer_gone(peer: int, explicit: bool = false) -> void:
	var room := _room_of(peer)
	peer_room.erase(peer)
	_bucket.erase(peer); _seen_ms.erase(peer); _join_fails.erase(peer)
	if room == null or not room.players.has(peer): return
	var p: Dictionary = room.players[peer]
	p["connected"] = false
	if p["nation"] != 0 and room.state == "playing": room.g.human[p["nation"]] = 0     # AI takes over while away
	if room.state == "lobby" and explicit:
		room.players.erase(peer)
		if room.host_peer == peer and not room.players.is_empty(): room.host_peer = room.players.keys()[0]
	if room.connected_count() == 0 and room.state == "lobby": rooms.erase(room.code); return
	if room.host_peer == peer:
		for pid in room.players:
			if room.players[pid]["connected"]: room.host_peer = pid; break
	_broadcast_room(room)
	if room.state == "playing" and room.all_ready(): _resolve_turn(room)

func _room_of(peer: int) -> TBRoom:
	var code: String = peer_room.get(peer, "")
	var room: TBRoom = rooms.get(code) if code != "" else null
	return room if room != null and room.players.has(peer) else null            # a peer replaced by a rejoin or removed with its room is nobody

func _purge_old() -> void:
	var now := Time.get_ticks_msec()
	for code in rooms.keys():
		var r: TBRoom = rooms[code]
		if r.connected_count() == 0 and now - r.created_ms > 300000: rooms.erase(code)
		elif now - r.created_ms > ROOM_TTL_MS: rooms.erase(code)

func _new_code() -> String:
	const A := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	while true:
		var s := ""
		for i in 5: s += A[randi() % A.length()]
		if not rooms.has(s): return s
	return ""

func _new_token() -> String:
	var c := Crypto.new()
	return c.generate_random_bytes(12).hex_encode()

static func _clean(s: String) -> String:
	var t := _clean_text(s, 24)
	return t if t != "" else "Player"

## printable text only: no control characters (newlines, escapes), no BBCode brackets, bounded
static func _clean_text(s: String, max_len: int) -> String:
	var out := ""
	for i in mini(s.length(), max_len * 2):
		var u := s.unicode_at(i)
		if u < 32 or u == 127 or (u >= 0x80 and u < 0xA0) or u == 0x200B or (u >= 0x202A and u <= 0x202E) or (u >= 0x2066 and u <= 0x2069): continue      # controls, zero-width, bidi overrides
		var ch := s[i]
		if ch == "[" or ch == "]": continue
		out += ch
		if out.length() >= max_len: break
	return out.strip_edges()
