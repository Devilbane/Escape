class_name RiddleSeal
extends RefCounted
## Keeps the answers of the game's riddles from being read off the code: a sealed text is the answer,
## scrambled with a key and written in base64 (see tools/riddle_seal.py, which makes one). It is
## no lock, only a cover, so that the answer does not stand in the open in the repository, in the tests
## or in a diff. Tests ask the riddle's own functions for its answer and never write one down.

const KEY := "Apfeltal-Nacht"


## The plain text of a sealed one.
static func open(sealed: String) -> String:
	var raw := Marshalls.base64_to_raw(sealed)
	var key := KEY.to_utf8_buffer()
	for i in raw.size():
		raw[i] = raw[i] ^ key[i % key.size()]
	return raw.get_string_from_utf8()


## The numbers of a sealed list ("a,b,c").
static func numbers(sealed: String) -> Array[int]:
	var out: Array[int] = []
	for part in open(sealed).split(","):
		out.append(int(part))
	return out
