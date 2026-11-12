class_name NetServer
extends RefCounted
## The server's door: it lets players in, checks what they send and hands
## the well-formed commands on to the world.
##
## It knows nothing about the rules. A player first says hello with the
## protocol version and a name; until then nothing else they send counts.
## Every command is checked with Commands.check and a rate limit; the player
## gets an ack (ok, or the reason it was refused) for each one. Call poll()
## once per frame or tick.

signal player_joined(id: int, name: String)
signal player_left(id: int, name: String)
## A well-formed command from a player who said hello. The world decides
## whether it is allowed.
signal command_received(id: int, cmd: Dictionary)

## Commands a player may send per second before the rest are refused.
const RATE_LIMIT := 30
const MAX_NAME := 24

var shard := "Lindenhain"
var players := {}  # peer id -> {"name": String, "window": float, "count": int}
var _peer: ENetMultiplayerPeer = null
var _waiting := {}  # peer id -> true, connected but no hello yet
var _closing: Array[int] = []  # refused: let go once their answer is sent
var _now := 0.0


func start(port: int, max_players := 32) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, max_players)
	if err != OK:
		_peer = null
		return err
	_peer.peer_connected.connect(func(id: int) -> void: _waiting[id] = true)
	_peer.peer_disconnected.connect(_gone)
	return OK


func is_running() -> bool:
	return _peer != null


func stop() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	players.clear()
	_waiting.clear()
	_closing.clear()


## Handles everything that arrived. `delta` is the time since the last poll.
func poll(delta := 0.0) -> void:
	if _peer == null:
		return
	_now += delta
	# Held here so the peer outlives a stop() from a signal mid-poll.
	var peer := _peer
	peer.poll()
	# The refusals went out with that poll; now the door can close.
	var leaving := _closing.duplicate()
	_closing.clear()
	for id in leaving:
		peer.disconnect_peer(id)
	while _peer != null and _peer.get_available_packet_count() > 0:
		var from := _peer.get_packet_peer()
		var msg := NetProtocol.decode(_peer.get_packet())
		_handle(from, msg)


func send(id: int, msg: Dictionary) -> void:
	if _peer == null:
		return
	_peer.set_target_peer(id)
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_peer.put_packet(NetProtocol.encode(msg))


func _handle(from: int, msg: Dictionary) -> void:
	if msg.is_empty() or _closing.has(from):
		return
	if not players.has(from):
		if msg.type == "hello":
			_hello(from, msg)
		return
	match msg.type:
		"command":
			_command(from, msg)
		"bye":
			_peer.disconnect_peer(from)


func _hello(from: int, msg: Dictionary) -> void:
	if int(msg.get("version", -1)) != NetProtocol.VERSION:
		_refuse(from, "version")
		return
	var name := str(msg.get("name", "")).strip_edges()
	if name.is_empty() or name.length() > MAX_NAME:
		_refuse(from, "name")
		return
	for id in players:
		if players[id].name == name:
			_refuse(from, "name taken")
			return
	_waiting.erase(from)
	players[from] = {"name": name, "window": _now, "count": 0}
	send(from, {"type": "welcome", "id": from, "shard": shard})
	player_joined.emit(from, name)


func _refuse(from: int, reason: String) -> void:
	send(from, {"type": "refused", "reason": reason})
	if not _closing.has(from):
		_closing.append(from)


func _command(from: int, msg: Dictionary) -> void:
	var seq := int(msg.get("seq", 0))
	var player: Dictionary = players[from]
	if _now - player.window >= 1.0:
		player.window = _now
		player.count = 0
	player.count += 1
	var reason := "too fast" if player.count > RATE_LIMIT else Commands.check(msg.get("cmd"))
	send(from, {"type": "ack", "seq": seq, "ok": reason == "", "reason": reason})
	if reason == "":
		command_received.emit(from, msg.cmd)


func _gone(id: int) -> void:
	_waiting.erase(id)
	if players.has(id):
		var name: String = players[id].name
		players.erase(id)
		player_left.emit(id, name)
