## Dedicated server entry:  godot --headless --path godot res://src/net/server.tscn  [-- --port 8080]
extends Node

func _ready() -> void:
	var port := int(OS.get_environment("PORT")) if OS.get_environment("PORT") != "" else 8080
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--port" and i + 1 < args.size(): port = int(args[i + 1])
	var world := TBWorld.load_from("res://data")
	var net := TBNet.new(); net.name = "Net"
	get_tree().root.add_child.call_deferred(net)
	await get_tree().process_frame
	if not net.start_server(world, port): get_tree().quit(1)
