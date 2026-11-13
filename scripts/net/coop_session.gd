class_name CoopSession
extends Node
## Playing together: this game hosts a server for friends, or joins a friend's.
##
## Hosting starts a NetServer inside this game and joins it like any other
## player, so the host and the guests take the same path. While connected the
## hero's place is sent ten times a second (a "where" command) and the other
## heroes near it are drawn as RemoteHero figures in this world. Each player
## keeps their own saved game; nothing of the single-player game changes when
## nobody hosts or joins.
##
## It keeps running while a window pauses the world, so friends do not time out.

signal changed()

enum Mode { OFF, HOSTING, JOINING, JOINED }

const SEND_EVERY := 0.1

var game: Node
var mode := Mode.OFF
var server: NetServer = null
var client: NetClient = null
## Who else is on the shard: peer id -> name.
var others := {}
## The figures drawn for the heroes near ours: peer id -> RemoteHero.
var figures := {}
## The last thing worth telling the player ("" when there is nothing).
var problem := ""
var address := "127.0.0.1"
var port := NetProtocol.DEFAULT_PORT
var _send_due := 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_on() -> bool:
	return mode != Mode.OFF


## Opens a server on this computer and joins it. False (and `problem` says
## why) when the port cannot be opened.
func host(on_port: int) -> bool:
	leave()
	port = on_port
	server = NetServer.new()
	server.shard = _hero_name()
	if server.start(port) != OK:
		server = null
		problem = "port"
		changed.emit()
		return false
	_connect("127.0.0.1", port)
	mode = Mode.HOSTING
	changed.emit()
	return true


## Joins a friend's game at `host_address`.
func join(host_address: String, on_port: int) -> bool:
	leave()
	address = host_address.strip_edges()
	port = on_port
	if address.is_empty() or not _connect(address, port):
		problem = "address"
		changed.emit()
		return false
	mode = Mode.JOINING
	changed.emit()
	return true


func leave() -> void:
	if client != null:
		client.leave()
	client = null
	if server != null:
		server.stop()
	server = null
	others.clear()
	_clear_figures()
	problem = ""
	mode = Mode.OFF
	changed.emit()


func _connect(to: String, on_port: int) -> bool:
	client = NetClient.new()
	if client.connect_to(to, on_port, _hero_name()) != OK:
		client = null
		return false
	client.welcomed.connect(func(_id: int, _shard: String, _hero: Dictionary) -> void:
		if mode == Mode.JOINING:
			mode = Mode.JOINED
		problem = ""
		changed.emit())
	client.refused.connect(func(reason: String) -> void: problem = reason)
	client.disconnected.connect(_lost)
	client.player_joined.connect(func(id: int, name: String) -> void:
		others[id] = name
		changed.emit())
	client.player_left.connect(func(id: int) -> void:
		others.erase(id)
		_drop_figure(id)
		changed.emit())
	client.seen.connect(_see)
	return true


func _lost() -> void:
	var why := problem if problem != "" else "lost"
	if server != null:
		server.stop()
	server = null
	client = null
	others.clear()
	_clear_figures()
	mode = Mode.OFF
	problem = why
	changed.emit()


func _process(delta: float) -> void:
	if server != null:
		server.poll(delta)
	if client == null:
		return
	client.poll()
	if client == null or not client.is_welcomed():
		return
	_send_due -= delta
	if _send_due <= 0.0:
		_send_due = SEND_EVERY
		var place := where()
		if not place.is_empty():
			client.send_command(Commands.make("where", place))


## The hero's place as a "where" command's fields, or {} when there is no hero.
func where() -> Dictionary:
	var hero = game.player if game != null else null
	if hero == null or not is_instance_valid(hero) or not hero.is_inside_tree():
		return {}
	var model: Node3D = hero.get("_model")
	var anim: AnimationPlayer = hero.get("_anim")
	return {
		"level": _level_name(),
		"pos": hero.global_position,
		"facing": model.rotation.y if model else 0.0,
		"anim": String(anim.current_animation) if anim else "Idle",
	}


func _level_name() -> String:
	if game == null or game.level_files.is_empty():
		return "?"
	return String(game.level_files[clampi(game.level_index, 0, game.level_files.size() - 1)]).get_file()


func _see(seen: Array) -> void:
	var here := {}
	var world: Node = game.level if game != null else null
	if world == null or not is_instance_valid(world):
		return
	for entry in seen:
		if not entry is Dictionary or not entry.get("pos") is Vector3:
			continue
		var id := int(entry.get("id", 0))
		here[id] = true
		var figure: RemoteHero = figures.get(id)
		if figure == null or not is_instance_valid(figure) or figure.get_parent() != world:
			figure = RemoteHero.new()
			figure.hero_name = str(others.get(id, "?"))
			world.add_child(figure)
			figure.global_position = entry.pos
			figures[id] = figure
		figure.hero_name = str(others.get(id, figure.hero_name))
		figure.target(entry.pos, float(entry.get("facing", 0.0)), str(entry.get("anim", "Idle")))
	for id in figures.keys():
		if not here.has(id):
			_drop_figure(id)


func _drop_figure(id: int) -> void:
	var figure = figures.get(id)
	if figure != null and is_instance_valid(figure):
		figure.queue_free()
	figures.erase(id)


func _clear_figures() -> void:
	for id in figures.keys():
		_drop_figure(id)


func _hero_name() -> String:
	var name := str(game.hero_name) if game != null else ""
	name = name.strip_edges().left(NetServer.MAX_NAME)
	return name if name != "" else "Held"


func _exit_tree() -> void:
	leave()
