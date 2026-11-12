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
## Server to client: welcome {id, shard}, refused {reason}, ack {seq, ok, reason}.

## Raised whenever the messages change, so an old game is told to update.
const VERSION := 1
const DEFAULT_PORT := 24570
const MAX_PACKET := 4096
const TYPES := ["hello", "command", "bye", "welcome", "refused", "ack"]


static func encode(msg: Dictionary) -> PackedByteArray:
	return var_to_bytes(msg)


## The message, or an empty Dictionary when the packet is not one.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 4 or bytes.size() > MAX_PACKET:
		return {}
	var value = bytes_to_var(bytes)
	if not value is Dictionary or not value.get("type") is String or not TYPES.has(value.type):
		return {}
	return value
