## Multiplayer UI flow: connect -> create/join -> lobby (pick nation) -> in-game command routing.
## Owns the TBNet node; talks to the app root (main.gd) through a small callback surface.
class_name TBMpController
extends Node

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

var main: Control
var net: TBNet
var active := false
var in_game := false
var url := "wss://terra-bellum-server.onrender.com"
var player_name := "Player"
var _pending := {}            # seq -> cmd
var _lobby: Control
var _deadline_at := 0
var _timer_label: Label
var _chat_box: VBoxContainer
var _last_turn := 0

func setup(app: Control) -> void:
	main = app
	var f := ConfigFile.new()
	if f.load("user://settings.cfg") == OK:
		url = f.get_value("mp", "url", url); player_name = f.get_value("mp", "name", player_name)

func _save() -> void:
	var f := ConfigFile.new(); f.load("user://settings.cfg")
	f.set_value("mp", "url", url); f.set_value("mp", "name", player_name); f.save("user://settings.cfg")

# ---------------------------------------------------------------- entry dialog
func open_menu() -> void:
	var m := K.modal(main._overlay, T.call("mp_title"), 460)
	var v: VBoxContainer = m[1]
	var nm := LineEdit.new(); nm.text = player_name; nm.placeholder_text = T.call("mp_name"); nm.custom_minimum_size = Vector2(0, K.MIN_TOUCH)
	var srv := LineEdit.new(); srv.text = url; srv.placeholder_text = "wss://…"; srv.custom_minimum_size = Vector2(0, K.MIN_TOUCH)
	var code := LineEdit.new(); code.placeholder_text = T.call("mp_code"); code.custom_minimum_size = Vector2(0, K.MIN_TOUCH); code.max_length = 5
	v.add_child(K.label(T.call("mp_name"), 13, K.DIM)); v.add_child(nm)
	v.add_child(K.label(T.call("mp_server"), 13, K.DIM)); v.add_child(srv)
	var status := K.label("", 13, K.DIM)
	var create := K.button(T.call("mp_create"), func():
		player_name = nm.text; url = srv.text; _save(); m[0].queue_free()
		TBModals.era_picker(main._overlay, main.cfg["difficulty"], func(era, diff): _connect(func(): net.create_room(player_name, era, diff, 120)), func(): open_menu()), true)
	v.add_child(create)
	v.add_child(K.label(T.call("mp_code"), 13, K.DIM)); v.add_child(code)
	v.add_child(K.button(T.call("mp_join"), func():
		player_name = nm.text; url = srv.text; _save()
		status.text = T.call("mp_connecting")
		_connect(func(): net.join_room(code.text, player_name))))
	v.add_child(status)
	v.add_child(K.button(T.call("back"), func(): m[0].queue_free()))

func _connect(then: Callable) -> void:
	if net != null: net.close(); net.queue_free()
	net = TBNet.new(); net.name = "Net"; add_child(net)
	await get_tree().process_frame
	net.connected.connect(then, CONNECT_ONE_SHOT)
	net.disconnected.connect(_on_disconnected)
	net.error_received.connect(func(msg): main.hud.toast(msg, true) if main.hud.visible else _lobby_toast(msg))
	net.room_updated.connect(_on_room)
	net.snapshot_ready.connect(_on_snapshot)
	net.delta_applied.connect(_on_delta)
	net.command_result.connect(_on_result)
	net.proposal_received.connect(_on_proposal)
	net.chat_received.connect(_on_chat)
	if not net.connect_to(main.world, url): _lobby_toast(T.call("mp_failed"))

func _lobby_toast(msg: String) -> void:
	var l := K.label(msg, 15, K.RED.lightened(0.3)); l.position = Vector2(12, 60); main._overlay.add_child(l)
	get_tree().create_timer(4.0).timeout.connect(func(): if is_instance_valid(l): l.queue_free())

func _on_disconnected() -> void:
	if in_game:
		main.hud.toast(T.call("mp_lost"), true)
	active = false

# ---------------------------------------------------------------- server events
func _on_snapshot(g: TBGame) -> void:
	main.g = g
	main.map.setup(g)
	if in_game:
		main.hud.g = g; main.map.repaint_all(); main.hud.refresh()
		main._log_idx = g.log.size()

func _on_room(info: Dictionary) -> void:
	active = true
	if info["state"] == "lobby":
		main.mode = "mp_lobby"
		_show_lobby(info)
	elif info["state"] in ["playing", "over"] and not in_game:
		in_game = true
		main.enter_mp_game(net.game, net.my_nation)
		_last_turn = net.game.turn
		_make_timer()
	if in_game:
		_deadline_at = Time.get_ticks_msec() + int(info.get("deadline_left", 0))
		var me_ready := false
		for p in info["players"]:
			if p["peer"] == multiplayer.get_unique_id() and p["ready"]: me_ready = true
		main.hud.set_busy(me_ready)

func _on_delta(dirty: PackedInt32Array) -> void:
	var g := net.game
	main.map.repaint(dirty, main.map.lenses.mode != "political")
	main._flush_log()
	main.hud.refresh()
	if main.selected >= 0: main.panel.rebuild()
	if g.turn != _last_turn:
		_last_turn = g.turn
		main.hud.set_busy(false)
		if g.over:
			TBModals.game_over(main._overlay, T.call("e_victory", {"a": g.nat_name[g.winner]}) if g.winner == g.human_id else T.call("e_defeat"), main.leave_mp)

func _on_result(seq: int, res: Dictionary) -> void:
	var cmd: Dictionary = _pending.get(seq, {})
	_pending.erase(seq)
	if not res.get("ok", false):
		var key := "err_" + String(res.get("err", ""))
		main.hud.toast(T.call(key) if TBI18n.has_key(key) else String(res.get("err", "?")), true)
	elif cmd.get("cmd", "") == "move":
		var win: bool = res.get("result", "") == "win"
		main.map.labels.add_fx("atk", cmd["from"], cmd["to"], Color(0.5, 0.9, 0.55) if win else Color(1.0, 0.55, 0.5))
		if win: main.map.labels.add_fx("cap", cmd["from"], cmd["to"], Color(0.5, 0.9, 0.55))
	elif res.get("pending", false):
		main.hud.toast(T.call("mp_proposal_sent"))

func _on_proposal(p: Dictionary) -> void:
	var m := K.modal(main._overlay, T.call("mp_proposal"), 420)
	m[1].add_child(K.label("%s — %s" % [p["from_name"], T.call("mp_kind_" + String(p["kind"]))], 16))
	var row := K.hbox(8); m[1].add_child(row)
	row.add_child(K.button(T.call("mp_decline"), func(): net.respond(p["id"], false); m[0].queue_free()))
	var ok := K.button(T.call("mp_accept"), func(): net.respond(p["id"], true); m[0].queue_free(), true); ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(ok)

func _on_chat(from: String, text: String) -> void:
	main.hud.toast("%s: %s" % [from, text])

# ---------------------------------------------------------------- lobby
func _show_lobby(info: Dictionary) -> void:
	if is_instance_valid(_lobby): _lobby.queue_free()
	main.hud.visible = false; main.panel.visible = false
	_lobby = PanelContainer.new()
	_lobby.position = Vector2(12, 12)
	var v := K.vbox(6); _lobby.add_child(v)
	v.add_child(K.label("%s  %s" % [T.call("mp_room"), info["code"]], 20, K.GOLD2))
	v.add_child(K.label(T.call("era_" + String(info["era"])) + " · " + T.call(String(info["difficulty"])), 13, K.DIM))
	v.add_child(K.label(T.call("mp_pick_hint"), 13, K.DIM))
	var me := multiplayer.get_unique_id()
	var all_picked := true
	for p in info["players"]:
		var nat := "—"
		if p["nation"] != 0: nat = net.game.nat_name[p["nation"]]
		else: all_picked = false
		v.add_child(K.label("%s%s  →  %s" % ["★ " if p["host"] else "", p["name"], nat], 15, K.TEXT if p["connected"] else K.DIM))
	if info["host"] == me:
		var go := K.button(T.call("mp_start"), func(): net.start_game(), true); go.disabled = not all_picked; v.add_child(go)
	v.add_child(K.button(T.call("back"), func(): leave()))
	main._overlay.add_child(_lobby)

func pick_province(p: int) -> void:
	if p < 0 or net.game.owner[p] == 0: return
	net.pick_nation(net.game.owner[p])
	main.map.select(p)

# ---------------------------------------------------------------- in-game routing
func send_command(c: Dictionary) -> void:
	var cmd := c.duplicate()
	var seq := net.send_command(cmd)
	_pending[seq] = cmd

func end_turn() -> void:
	main.hud.set_busy(true)
	net.end_turn()

func _make_timer() -> void:
	_timer_label = K.label("", 15, K.GOLD2)
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP); _timer_label.position = Vector2(-40, 62)
	main.hud.add_child(_timer_label)
	var chat := LineEdit.new(); chat.placeholder_text = T.call("mp_chat"); chat.custom_minimum_size = Vector2(240, 36)
	chat.set_anchors_preset(Control.PRESET_BOTTOM_LEFT); chat.position = Vector2(10, -48)
	chat.text_submitted.connect(func(t: String): if t.strip_edges() != "": net.chat(t); chat.clear())
	main.hud.add_child(chat)

func _process(_d: float) -> void:
	if in_game and is_instance_valid(_timer_label):
		var left := maxi(0, _deadline_at - Time.get_ticks_msec()) / 1000
		_timer_label.text = "⏱ %d:%02d" % [left / 60, left % 60]

func leave() -> void:
	if net != null:
		net.leave(); net.close()
	active = false; in_game = false
	if is_instance_valid(_lobby): _lobby.queue_free()
	main.show_menu()
