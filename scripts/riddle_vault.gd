class_name RiddleVault
extends RefCounted
## Keeps the answers and codes of riddles out of reach of anyone reading the repository (it is public).
##
## An answer is never stored. A riddle keeps an ENTRY, {"salt", "rounds", "hash"}: the salt is random per riddle, the
## hash is the answer's letters (lower case, nothing else) run through `rounds` rounds of SHA-256 with the salt mixed
## in every round. The salt makes pre-computed tables useless and the rounds make every guess of a word list slow.
## A riddle's code (a list of small numbers, e.g. which flower is the light one) is stored with `scramble()`, which
## masks it with a key stream drawn from the same salt.
##
## There is no key and no secret: the game must be able to check an answer at run time, so nothing the game can read
## can be hidden from a player of the shipped game; this only keeps the answers out of the repository. Make a new
## entry with `tools/riddle_hash.gd` (the answer comes from the environment, never from a file or a command line).
##
## Use: `RiddleVault.check(said_line, ENTRY)` and `RiddleVault.unscramble(CODE, ENTRY)`.

## Rounds for a new entry: a guess costs a few milliseconds, a dictionary of millions of guesses hours.
const ROUNDS := 60000
## The longest line looked at; a longer one is never an answer.
const MAX_LETTERS := 120


## Only the letters of a line count: case, spaces and marks between the words do not.
static func plain(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		if ch >= "a" and ch <= "z":
			out += ch
			if out.length() > MAX_LETTERS:
				return ""
	return out


static func _sha(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish()


## The hash of an answer for a salt and a number of rounds.
static func digest(answer: String, salt: String, rounds: int) -> String:
	var p := plain(answer)
	if p == "":
		return ""
	var s := salt.to_utf8_buffer()
	var h := _sha(s + p.to_utf8_buffer())
	for i in rounds:
		h = _sha(h + s)
	return h.hex_encode()


## A new entry for an answer. The salt is random unless given.
static func make_entry(answer: String, salt := "", rounds := ROUNDS) -> Dictionary:
	if salt == "":
		var c := Crypto.new()
		salt = c.generate_random_bytes(12).hex_encode()
	return {"salt": salt, "rounds": rounds, "hash": digest(answer, salt, rounds)}


## Whether a said line is the answer of the entry.
static func check(said: String, entry: Dictionary) -> bool:
	var h := digest(said, str(entry.get("salt", "")), int(entry.get("rounds", ROUNDS)))
	return h != "" and h == str(entry.get("hash", ""))


## The mask of a code's n-th number.
static func _mask(salt: String, n: int) -> int:
	return (salt + ":" + str(n)).sha256_buffer()[0]


## A code (numbers 0 to 255) as scrambled text for the source.
static func scramble(code: Array, entry: Dictionary) -> String:
	var bytes := PackedByteArray()
	for n in code.size():
		bytes.append(int(code[n]) ^ _mask(str(entry.get("salt", "")), n))
	return Marshalls.raw_to_base64(bytes)


## The code back from its scrambled text.
static func unscramble(text: String, entry: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var bytes := Marshalls.base64_to_raw(text)
	for n in bytes.size():
		out.append(bytes[n] ^ _mask(str(entry.get("salt", "")), n))
	return out
