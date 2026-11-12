extends SceneTree
## Runs a headless Escape! server: on a home PC today, on a rented host later.
##
##   godot --headless -s tools/server.gd -- --port=24570 --shard=Lindenhain
##
## Settings come from server.cfg and the command line (see ServerConfig). The
## server keeps its books (bank, deeds, ranking) in its own save folder. For
## now it lets players in and checks their commands; the world rules join step
## by step (see docs/mmo_plan.md).

var server := NetServer.new()
var config: ServerConfig


func _initialize() -> void:
	config = ServerConfig.from_args(OS.get_cmdline_user_args())
	Storage.use(Storage.Files.new(config.save_dir))
	server.shard = config.shard
	server.player_joined.connect(func(id: int, name: String) -> void: _log("%s joined (#%d, %s)" % [name, id, "known hero" if HeroStore.has(name) else "new hero"]))
	server.player_left.connect(func(id: int, name: String) -> void: _log("%s left (#%d)" % [name, id]))
	server.command_received.connect(func(id: int, cmd: Dictionary) -> void: _log("#%d: %s" % [id, cmd.kind]))
	var err := server.start(config.port, config.max_players)
	if err != OK:
		_log("could not open port %d (error %d)" % [config.port, err])
		quit(1)
		return
	_log("shard %s open on port %d, up to %d players, books in %s" % [config.shard, config.port, config.max_players, config.save_dir])


func _process(delta: float) -> bool:
	server.poll(delta)
	return false


func _finalize() -> void:
	server.stop()


func _log(text: String) -> void:
	print("[%s] %s" % [Time.get_time_string_from_system(), text])
