class_name Commands
extends RefCounted
## What a player may ask the world to do, as plain data.
##
## In an online game the client never changes the world itself: it sends one of
## these commands and the server decides. The same commands drive the local
## single-player game, so one code path is tested. A command is a Dictionary
## `{"kind": String, ...fields}`; `check()` says whether its shape is right
## ("" when it is). It does not say whether the act is allowed: that is the
## rules' job, with the world at hand.

## kind -> {field: expected type}. Types are Godot's TYPE_* constants; a whole
## number is accepted where a float is expected.
const KINDS := {
	"move": {"dir": TYPE_VECTOR2},
	"attack": {"target": TYPE_INT},
	"interact": {"target": TYPE_INT},
	"use_item": {"slot": TYPE_INT},
	"equip": {"slot": TYPE_INT},
	"drop_item": {"slot": TYPE_INT, "count": TYPE_INT},
	"say": {"text": TYPE_STRING},
	"where": {"level": TYPE_STRING, "pos": TYPE_VECTOR3, "facing": TYPE_FLOAT, "anim": TYPE_STRING},
	"trade": {"merchant": TYPE_INT, "slot": TYPE_INT, "count": TYPE_INT, "buying": TYPE_BOOL},
}

const MAX_TEXT := 200
const MAX_COUNT := 999


static func make(kind: String, fields := {}) -> Dictionary:
	var made := {"kind": kind}
	made.merge(fields)
	return made


## "" when the command is well formed, else the reason it is not.
static func check(cmd) -> String:
	if not cmd is Dictionary:
		return "not a command"
	var kind = cmd.get("kind")
	if not kind is String or not KINDS.has(kind):
		return "unknown kind"
	var schema: Dictionary = KINDS[kind]
	for field in schema:
		if not cmd.has(field):
			return "missing %s" % field
		var want: int = schema[field]
		var got := typeof(cmd[field])
		if got != want and not (want == TYPE_FLOAT and got == TYPE_INT):
			return "wrong type for %s" % field
	for field in cmd:
		if field != "kind" and not schema.has(field):
			return "unexpected %s" % field
	if cmd.has("dir"):
		var dir: Vector2 = cmd.dir
		if not is_finite(dir.x) or not is_finite(dir.y) or dir.length() > 1.001:
			return "bad direction"
	if cmd.has("count") and (cmd.count < 1 or cmd.count > MAX_COUNT):
		return "bad count"
	if cmd.has("slot") and cmd.slot < 0:
		return "bad slot"
	if cmd.has("level") and (cmd.level.is_empty() or cmd.level.length() > 64):
		return "bad level"
	if cmd.has("anim") and cmd.anim.length() > 32:
		return "bad animation"
	if cmd.has("text") and (cmd.text.is_empty() or cmd.text.length() > MAX_TEXT):
		return "bad text"
	return ""
