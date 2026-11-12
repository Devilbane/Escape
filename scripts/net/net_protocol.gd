class_name NetProtocol
extends RefCounted
## The messages between the game and a server, and how they are packed.
##
## Every message is a Dictionary with a "type". It is packed with
## var_to_bytes, which never packs objects, and unpacked with bytes_to_var,
## which never builds them, so a packet from the network can only ever hold
## plain data. Anything that is not a Dictionary with a known type is dropped.
##
## Client to server: hello {version, name}, command {seq, cmd}, bye {}.
## Server to client: welcome {id, shard, hero}, refused {reason}, ack {seq, ok, reason},
## seen {others: [{id, pos, facing, anim}]} several times a second, joined {id, name}, left {id}.

## Raised whenever the messages change, so an old game is told to update.
const VERSION := 1
const DEFAULT_PORT := 24570
## The largest packet a server takes from a player.
const MAX_PACKET := 4096
## The largest packet a game takes from the server (a hero's whole record).
const MAX_FROM_SERVER := 1 << 20
const TYPES := ["hello", "command", "bye", "welcome", "refused", "ack", "seen", "joined", "left"]


static func encode(msg: Dictionary) -> PackedByteArray:
	return var_to_bytes(msg)


## The message, or an empty Dictionary when the packet is not one (or is
## larger than `limit`).
static func decode(bytes: PackedByteArray, limit := MAX_PACKET) -> Dictionary:
	if bytes.size() < 4 or bytes.size() > limit:
		return {}
	var value = bytes_to_var(bytes)
	if not value is Dictionary or not value.get("type") is String or not TYPES.has(value.type):
		return {}
	return value
