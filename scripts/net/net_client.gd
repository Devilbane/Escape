class_name NetClient
extends RefCounted
## The game's side of the connection: says hello, sends commands and hears
## the server's answers. Call poll() once per frame.

signal welcomed(id: int, shard: String)
signal refused(reason: String)
signal acked(seq: int, ok: bool, reason: String)
signal disconnected()

var id := 0
## The protocol version this game says hello with (a test can pretend to be old).
var version := NetProtocol.VERSION
var _peer: ENetMultiplayerPeer = null
var _name := ""
var _seq := 0


func connect_to(host: String, port: int, hero: String) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host, port)
	if err != OK:
		_peer = null
		return err
	_name = hero
	_peer.peer_connected.connect(func(_server: int) -> void: _send({"type": "hello", "version": version, "name": _name}))
	_peer.peer_disconnected.connect(func(_server: int) -> void: _closed())
	return OK


func is_welcomed() -> bool:
	return id != 0


## Sends a command; returns its number, which the ack carries back (0 when
## not connected).
func send_command(cmd: Dictionary) -> int:
	if not is_welcomed():
		return 0
	_seq += 1
	_send({"type": "command", "seq": _seq, "cmd": cmd})
	return _seq


func poll() -> void:
	if _peer == null:
		return
	# Held here so the peer outlives a disconnect that clears _peer mid-poll.
	var peer := _peer
	peer.poll()
	while _peer != null and _peer.get_available_packet_count() > 0:
		var msg := NetProtocol.decode(_peer.get_packet())
		match msg.get("type", ""):
			"welcome":
				id = int(msg.get("id", 0))
				welcomed.emit(id, str(msg.get("shard", "")))
			"refused":
				refused.emit(str(msg.get("reason", "")))
			"ack":
				acked.emit(int(msg.get("seq", 0)), bool(msg.get("ok", false)), str(msg.get("reason", "")))


func leave() -> void:
	if _peer == null:
		return
	if is_welcomed():
		_send({"type": "bye"})
		_peer.poll()
	_peer.close()
	_closed()


func _send(msg: Dictionary) -> void:
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_peer.put_packet(NetProtocol.encode(msg))


func _closed() -> void:
	if _peer == null and id == 0:
		return
	_peer = null
	id = 0
	disconnected.emit()
