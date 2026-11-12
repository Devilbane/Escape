extends SceneTree
## Headless test for the server skeleton (scripts/net/): a server and two
## clients on this computer. Players say hello, wrong versions and taken names
## are refused, well-formed commands reach the world, bad ones are refused
## with a reason, and too many at once hit the rate limit.
## Run with: godot --headless -s tests/net_loopback.gd

var failures := 0
var server := NetServer.new()
var port := 24590
var frames := 0
var joined: Array = []
var received: Array = []
var acks := {}
var refusals: Array = []
var step := 0
var a := NetClient.new()
var b := NetClient.new()
var old := NetClient.new()
var twin := NetClient.new()
var a_id := 0
var heroes := {}
var sights := {}
var met := {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	# Packets: only plain dictionaries with a known type get through.
	check(NetProtocol.decode(NetProtocol.encode({"type": "hello", "name": "x"})).name == "x", "a message round-trips")
	check(NetProtocol.decode(NetProtocol.encode({"type": "steal"})).is_empty(), "an unknown type is dropped")
	check(NetProtocol.decode(var_to_bytes([1, 2])).is_empty(), "a non-dictionary is dropped")
	check(NetProtocol.decode(PackedByteArray([1, 2, 3])).is_empty(), "garbage is dropped")
	check(NetProtocol.decode(PackedByteArray()).is_empty(), "an empty packet is dropped")

	# Config: the command line wins over the defaults and stays in range.
	var cfg := ServerConfig.from_args(PackedStringArray(["--port=25000", "--max-players=9999", "--shard=Test"]))
	check(cfg.port == 25000 and cfg.shard == "Test", "the command line sets the port and shard")
	check(cfg.max_players == 4000, "max players is capped")
	check(ServerConfig.from_args(PackedStringArray(["--port=80"])).port == 1024, "a system port is not used")

	# The server keeps Brida's record; Alrik is new.
	Storage.use(Storage.Memory.new())
	HeroStore.save_hero({"version": SaveFormat.VERSION, "name": "Brida", "coins": 7})
	server.shard = "Test"
	check(server.start(port, 8) == OK, "the server opens its port")
	server.player_joined.connect(func(id: int, name: String) -> void: joined.append(name))
	server.command_received.connect(func(id: int, cmd: Dictionary) -> void: received.append([id, cmd]))
	for client in [a, b, old, twin]:
		client.acked.connect(func(seq: int, ok: bool, reason: String) -> void: acks[[client, seq]] = [ok, reason])
		client.welcomed.connect(func(_id: int, shard: String, hero: Dictionary) -> void: heroes[client] = [shard, hero])
		client.seen.connect(func(others: Array) -> void: sights[client] = others)
		client.player_joined.connect(func(id: int, name: String) -> void: met[client] = name)
		client.refused.connect(func(reason: String) -> void: refusals.append(reason))
	check(a.connect_to("127.0.0.1", port, "Alrik") == OK, "a client connects")
	check(b.connect_to("127.0.0.1", port, "Brida") == OK, "a second client connects")


func _process(delta: float) -> bool:
	frames += 1
	server.poll(delta)
	for client in [a, b, old, twin]:
		client.poll()
	match step:
		0:
			if a.is_welcomed() and b.is_welcomed():
				check(joined.size() == 2, "both players joined")
				check(server.players.size() == 2, "the server knows both")
				check(a.id != b.id, "players get their own ids")
				check(heroes[a][0] == "Test", "the welcome names the shard")
				check(heroes[a][1].is_empty(), "a new hero has no record yet")
				check(int(heroes[b][1].get("coins", 0)) == 7, "a known hero gets their record")
				a.send_command(Commands.make("where", {"level": "dorf", "pos": Vector3(0, 0, 0), "facing": 0.0, "anim": "idle"}))
				b.send_command(Commands.make("where", {"level": "dorf", "pos": Vector3(3, 0, 0), "facing": 1.0, "anim": "walk"}))
				step = 10
		10:
			if sights.get(a, []).size() == 1 and sights.get(b, []).size() == 1:
				check(sights[a][0].id == b.id and sights[a][0].anim == "walk", "Alrik sees Brida walking")
				check(sights[b][0].id == a.id, "Brida sees Alrik")
				check(met.get(a, "") == "Brida" and met.get(b, "") == "Alrik", "players are told who else is on the shard")
				# A name already in use is refused.
				twin.connect_to("127.0.0.1", port, "Alrik")
				# An old game is refused (it says hello with another version).
				old.version = NetProtocol.VERSION + 1
				old.connect_to("127.0.0.1", port, "Old")
				step = 1
		1:
			if refusals.size() >= 2:
				check(refusals.has("name taken"), "a taken name is refused")
				check(refusals.has("version"), "an old game is refused")
				check(not twin.is_welcomed(), "the twin is not let in")
				a.send_command(Commands.make("move", {"dir": Vector2(0, 1)}))
				a.send_command(Commands.make("attack", {"target": "nobody"}))
				b.send_command(Commands.make("say", {"text": "Hallo"}))
				step = 2
		2:
			if acks.has([a, 3]) and acks.has([b, 2]):
				check(acks[[a, 2]][0], "a good move is acked ok")
				check(not acks[[a, 3]][0] and acks[[a, 3]][1] != "", "a bad command is refused with a reason")
				check(not acks.has([a, 1]), "a taken place is not answered")
				check(acks[[b, 2]][0], "speech is acked ok")
				check(received.size() == 4, "only good commands reach the world")
				check(received.any(func(r): return r[0] == a.id and r[1].kind == "move"), "the world knows who moved")
				for i in NetServer.RATE_LIMIT + 5:
					b.send_command(Commands.make("say", {"text": "x"}))
				step = 3
		3:
			var last := NetServer.RATE_LIMIT + 7
			if acks.has([b, last]):
				check(acks[[b, 3]][0], "commands within the limit pass")
				check(not acks[[b, last]][0] and acks[[b, last]][1] == "too fast", "too many commands are refused")
				a_id = a.id
				a.leave()
				step = 4
		4:
			if server.players.size() == 1:
				check(not server.players.has(a_id) and a.id == 0, "a player who leaves is gone")
				return _finish()
	if frames > 600:
		check(false, "timed out at step %d" % step)
		return _finish()
	return false


func _finish() -> bool:
	b.leave()
	server.stop()
	Storage.use(null)
	if failures == 0:
		print("PASS: net loopback")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true
