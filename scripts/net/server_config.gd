class_name ServerConfig
extends RefCounted
## How a server runs: read from a `server.cfg` file and from the command line,
## never from code, so the same build runs on a home PC and on a rented host.
##
## server.cfg (all optional):
##   [server]
##   port=24570
##   max_players=32
##   shard="Lindenhain"
##   save_dir="user://server/"
## Command line (after `--`): --port=24570 --max-players=32 --shard=Name
## --save-dir=path --config=path/to/server.cfg

var port := NetProtocol.DEFAULT_PORT
var max_players := 32
var shard := "Lindenhain"
var save_dir := "user://server/"


## Reads the file named by --config (or server.cfg beside the game, if there
## is one), then lets the command line override it.
static func from_args(args: PackedStringArray) -> ServerConfig:
	var made := ServerConfig.new()
	var options := _options(args)
	var file: String = options.get("config", "")
	if file == "" and FileAccess.file_exists("res://server.cfg"):
		file = "res://server.cfg"
	if file != "":
		made.read_file(file)
	made.apply(options)
	return made


func read_file(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	port = int(cfg.get_value("server", "port", port))
	max_players = int(cfg.get_value("server", "max_players", max_players))
	shard = str(cfg.get_value("server", "shard", shard))
	save_dir = str(cfg.get_value("server", "save_dir", save_dir))
	return true


func apply(options: Dictionary) -> void:
	if options.has("port"):
		port = int(options.port)
	if options.has("max-players"):
		max_players = int(options["max-players"])
	if options.has("shard"):
		shard = str(options.shard)
	if options.has("save-dir"):
		save_dir = str(options["save-dir"])
	port = clampi(port, 1024, 65535)
	max_players = clampi(max_players, 1, 4000)


static func _options(args: PackedStringArray) -> Dictionary:
	var found := {}
	for arg in args:
		if arg.begins_with("--") and arg.contains("="):
			var key := arg.substr(2, arg.find("=") - 2)
			found[key] = arg.substr(arg.find("=") + 1)
	return found
