class_name MageDuel
extends RefCounted
## A practice duel on the village square. Elder Aldo teaches and Scholar Odo is the
## pupil: now and then, by day and when the hero is near, both walk to the duel ground, the open
## stretch of the market square between the crafting benches and the apple trees round the fountain
## (see duel_ground), take a few paces' distance and throw harmless spells at each other
## (fire bolt, frost shard, arcane orb, lightning; see DuelSpells), with a word
## between the volleys. Aldo hits nearly every time and motivates; Odo mostly
## misses, and makes excuses (the sun, the wind, wet socks) and promises to do
## better. When Odo does land one, Aldo cheers and Odo cannot believe it.
##
## It is only a show: nobody is hurt. It stands on the villagers' chat machinery
## (Villager.chat_partner, so nobody else pulls either of them away, and the
## hero talking to one of them, an alarm, a storm or nightfall ends it at once).
##
## Every line is German and has an English entry in scripts/lang/mage_duel.gd.

const ALDO := "0"
const ODO := "8"
## Seconds until the first duel after the village is entered, and between duels.
const FIRST_DUEL := Vector2(35.0, 70.0)
const DUEL_EVERY := Vector2(150.0, 260.0)
## A duel that is due but cannot start is tried again this soon.
const RETRY := 5.0
## Only when the hero is this near (metres), as with the other village chatter.
const HEAR_RANGE := 24.0
## Daytime only (hours): the mages practise after breakfast and stop before dusk.
const FROM_HOUR := 8.0
const UNTIL_HOUR := 18.0
## How far apart they stand (metres), and the paces tried when the ground is crowded.
const DISTANCES := [7.0, 6.0, 5.0]
## How far apart they stand on the duel ground (metres), tried in turn.
const GROUND_APART := [6.0, 5.0, 4.0]
## The benches' station kind (see Outdoor): the duel ground lies east of them.
const BENCH_KIND := "werkbank"
## How close and how far apart they may end up standing (metres).
const MIN_APART := 3.5
const MAX_APART := 12.0
## A walk to the duel ground that takes longer than this is given up (seconds).
const WALK_LIMIT := 40.0
## How long a spell takes to leave the hand after the pose begins, and how long the
## target holds its reaction once it lands (seconds).
const WINDUP := 0.4
const REACT := 0.9
## The pause after the last line of a beat.
const GAP := 0.35
## Rounds of a duel (an Aldo spell and an Odo spell each).
const ROUNDS := Vector2i(3, 5)
## How likely Aldo's spell lands, and Odo's.
const ALDO_HITS := 0.85
const ODO_HITS := 0.3

## Aldo opens, Odo answers (German).
const OPENERS := [
	["Auf deinen Platz, Odo! Zeit für die Übung.", "Jetzt schon? Ich hatte gerade ein so gutes Buch angefangen."],
	["Die Stäbe hoch, Odo! Heute lernst du etwas.", "Ich lerne doch immer etwas, Aldo. Meistens aus Büchern."],
	["Genug gelesen. Zaubern lernt man durch Zaubern.", "Das steht in keinem meiner Bücher. Ich prüfe es nach."],
	["Schön, dass du es einrichten konntest, Odo.", "Ich hatte eigentlich Pläne. Strümpfe trocknen, zum Beispiel."],
	["Bereit für eine kleine Übungsstunde, mein Junge?", "Bereit ist ein starkes Wort, Aldo."],
	["Stell dich dorthin und sammle dich.", "Ich sammle mich schon die ganze Zeit. Meistens Krümel."],
	["Heute treffen wir, Odo. Du und ich.", "Dann bitte du mich, Aldo. Das spart uns beiden Zeit."],
	["Ein Magier, der nicht übt, ist nur ein Mann mit Hut.", "Ich mag meinen Hut, Aldo. Er gibt mir Halt."],
]
## Odo, once he has been hit: the excuse.
const EXCUSES := [
	"Die Sonne! Sie hat mich geblendet!",
	"Dieser Wind! Bei dem Wetter kann kein Mensch zaubern!",
	"Meine Socken sind nass. So kann man nicht kämpfen.",
	"Mein Hut ist verrutscht. Ich habe nichts gesehen.",
	"Du hast gewartet, bis ich wegschaue, Aldo!",
	"Der Boden ist uneben. Ich schiebe es auf den Boden.",
	"Ich habe heute Nacht schlecht geschlafen.",
	"Das war ein Probeschuss. Für dich. Zum Einfinden.",
	"Eine Wolke hat sich bewegt. Genau im falschen Moment.",
	"Der Vogel da hat mich abgelenkt!",
	"Mein Zauberbuch lag auf der falschen Seite.",
	"Das Gras kitzelt an den Knöcheln. Das stört furchtbar.",
	"Mir ist der Bart in den Weg geraten.",
	"Ich habe zu spät gefrühstückt. Das schlägt auf die Magie.",
	"Der Mond steht ungünstig. Tagsüber schwer zu sagen, aber ich spüre es.",
	"Ich habe heute einfach nicht den richtigen Ärmel an.",
	"Mir ist ein Käfer ins Auge geflogen. Ein sehr großer Käfer.",
	"Meine Stiefel drücken. Der linke ganz besonders.",
]
## Odo's excuses for the weather of the moment (added to EXCUSES).
const WEATHER_EXCUSES := {
	"clear": ["Dieses Licht! Wer soll bei so viel Sonne zielen?", "Es ist zu schön heute. Das lenkt ab."],
	"rain": ["Der Regen! Meine Zauber werden ganz nass!", "Bei Regen funkt es nicht richtig. Das ist Physik."],
	"fog": ["Dieser Nebel! Ich sehe dich ja kaum, Aldo!", "Im Nebel zielt man auf Schatten. Und ich habe den falschen erwischt."],
	"snow": ["Meine Finger sind steif vor Kälte!", "Der Schnee schluckt meine Funken. Das ist unfair."],
}
## Odo's excuses after he missed (said instead of those above half of the time).
const MISS_EXCUSES := [
	"Er wollte nicht. Der Zauber, nicht ich.",
	"Der Zauber hat sich verlaufen.",
	"Das war Absicht. Ich wollte nur die Luft prüfen.",
	"Du hast dich bewegt, Aldo. Das ist nicht erlaubt.",
	"Der Wind hat ihn abgelenkt. Ganz bestimmt.",
	"Ich habe nur gezielt. Geschossen habe ich nicht.",
	"Das war ein Warnschuss. Für die Vögel.",
	"Der Zauber ist krank. Ich pflege ihn gesund.",
]
## Aldo's word after Odo's excuse or miss: he teaches and motivates.
const TEACH := [
	"Ausreden fliegen schneller als deine Zauber, Odo.",
	"Ein Magier kämpft bei jedem Wetter!",
	"Nasse Socken halten keinen Feind auf, Odo.",
	"Der Gegner wartet nicht auf gutes Wetter.",
	"Steh fest, atme ruhig und denk an das Ziel.",
	"Du musst es wollen, Odo. Mit dem ganzen Herzen!",
	"Das war ein guter Anfang. Der nächste wird besser.",
	"Aus dem Handgelenk, Odo, nicht aus dem Ellbogen.",
	"Erst zielen, dann zaubern. Nicht andersherum!",
	"Du zielst in den Himmel. Ich stehe hier unten.",
	"Ich glaube an dich, Odo. Das tut sonst keiner.",
	"Fehler sind die besten Lehrer. Du hast schon viele Lehrer.",
	"Der Zauber folgt deinem Willen, nicht deinem Magen.",
	"Nicht denken, Odo. Zaubern!",
	"Konzentration! Stell dir vor, ich wäre ein Buch.",
]
## Odo promises to do better.
const PROMISES := [
	"Beim nächsten Mal treffe ich, versprochen!",
	"Ich zaubere gleich viel besser. Ich muss nur den Hut richten.",
	"Ich gebe mein Bestes. Mein Bestes ist halt ... bescheiden.",
	"Du wirst staunen, Aldo. Hoffentlich.",
	"Ich spüre es. Gleich hab ich es. Das ist nur der Magen.",
	"Noch eine Runde, dann zeige ich es dir!",
	"Ich werde üben. Ab morgen. Ganz bestimmt.",
	"Diesmal ziele ich mit dem ganzen Herzen. Und beiden Augen.",
]
## Aldo, when Odo lands one: praise.
const PRAISE := [
	"Ausgezeichnet, Odo! Genau so!",
	"Na also! Es geht doch!",
	"Ein Treffer, mein Junge! Ich bin stolz auf dich.",
	"Siehst du? Du kannst es, wenn du nicht nachdenkst!",
	"Das war ein Zauber, wie er im Buch steht!",
	"Bravo! Der Stab hat auf dich gehört.",
]
## Odo, hardly believing it (also when he slips past Aldo's spell).
const TRIUMPH := [
	"Habe ich das getan? Ich habe das getan!",
	"Hast du das gesehen? Sag, dass du das gesehen hast!",
	"Das war Talent. Und ein wenig Sonne im Rücken.",
	"Ich schreibe es sofort in mein Buch!",
	"Nichts anderes hatte ich geplant. Selbstverständlich.",
	"Ich wusste es! Ich habe es immer gewusst! Fast immer.",
]
## Odo's brag when he dodged: and Aldo's cheer for it.
const DODGED := [
	"Haha, vorbei! Zu langsam, Aldo!",
	"Hast du das gesehen? Ich bin ausgewichen!",
]
const DODGE_CHEER := [
	"Gut gemacht! Mit etwas Übung wirst du noch ein Magier.",
	"Beine und Magie, Odo! Beides gehört zusammen.",
]
## Aldo takes a hit (a short one).
const OUCH := [
	"Hm! Nicht schlecht.",
	"Hoppla! Das habe ich gespürt.",
	"Aha! Da steckt doch mehr in dir.",
]
## Aldo and Odo end the lesson (German).
const CLOSERS := [
	["Das reicht für heute. Morgen üben wir weiter.", "Morgen? Morgen regnet es bestimmt."],
	["Gut gekämpft, Odo. Du wirst jeden Tag besser.", "Das sagst du jeden Tag."],
	["Pause. Trink etwas und ruh dich aus.", "Endlich! Ich zähle meine blauen Flecken."],
	["Nächstes Mal triffst du mich dreimal.", "Zweimal. Und nur, wenn der Wind mitspielt."],
	["Vergiss nicht: Übung macht den Magier.", "Und Bücher machen den Weisen, Aldo."],
	["Morgen früh, gleiche Stelle.", "Wenn ich nicht verschlafe. Meine Socken trocknen noch."],
	["Das war eine feine Stunde.", "Für dich vielleicht. Meine Ohren klingeln."],
]

var game: Node
## The duel going on, {} for none: the two (a = Aldo, b = Odo), the beats still to play
## (a queue), the beat being played, and the seconds since it began.
var _duel := {}
var _timer := 0.0
var _rng := RandomNumberGenerator.new()
## The pools being drawn from without repeats: name to the indices left.
var _decks := {}
## How many duels have been held, and the spells thrown in this one.
var duels := 0
var _spell_deck: Array = []


func _init(owner_game: Node = null) -> void:
	game = owner_game
	_rng.randomize()
	clear()


func clear() -> void:
	stop()
	duels = 0
	_decks.clear()
	_timer = _rng.randf_range(FIRST_DUEL.x, FIRST_DUEL.y)


func is_dueling() -> bool:
	return not _duel.is_empty()


# --- Starting -------------------------------------------------------------------

## Every frame in the village while the world runs (next to VillageTalk.update).
func update(delta: float, village: Outdoor) -> void:
	if village == null or game == null:
		return
	if not _duel.is_empty():
		_run(delta, village)
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = _rng.randf_range(DUEL_EVERY.x, DUEL_EVERY.y) if start(village) else RETRY


## Whether the mages may practise now: daytime, calm weather, no alarm.
static func is_time(village: Outdoor) -> bool:
	return not village.night and village.hour >= FROM_HOUR and village.hour < UNTIL_HOUR \
		and village.weather != Weather.STORM and not village.village_alarm.raised


## The mage with this role in the village (null if absent).
static func mage(village: Outdoor, role: String) -> Villager:
	for v in village.villagers:
		if is_instance_valid(v) and v.role == role:
			return v
	return null


## The duel ground on the market square: where Aldo and Odo stand, north and south of each other, on the
## middle line between the crafting benches in the west and the apple trees round the fountain in the
## east (the fountain's own trees: not the gardens' or the pockets'), as far apart as GROUND_APART lets the open ground be. [Aldo's place, Odo's place], or [] when
## the village has no such stretch (or it is crowded): the duel is held where Aldo stands then.
static func duel_ground(village: Outdoor) -> Array:
	var bench_x := -INF
	var bench_z := [INF, -INF]
	for s in village.stations:
		if s.kind == BENCH_KIND:
			bench_x = maxf(bench_x, s.pos.x)
			bench_z = [minf(bench_z[0], s.pos.z), maxf(bench_z[1], s.pos.z)]
	var tree_x := INF
	for t in village.square_trees:
		var tree = t.get("node")
		if tree is Node3D and not t.has("garden") and not t.has("pocket"):
			tree_x = minf(tree_x, (tree as Node3D).global_position.x)
	if bench_x == -INF or tree_x == INF or tree_x - bench_x < 8.0:
		return []
	var mid := Vector3((bench_x + tree_x) * 0.5, 0.0, (float(bench_z[0]) + float(bench_z[1])) * 0.5)
	for apart: float in GROUND_APART:
		var a := mid - Vector3(0, 0, apart * 0.5)
		var b := mid + Vector3(0, 0, apart * 0.5)
		var clear := true
		for spot: Vector3 in [a, b]:
			var cell := village.world_to_cell(spot)
			if village.astar.is_in_boundsv(cell) and village.astar.is_point_solid(cell):
				clear = false
		var eye := Vector3(0, 1.2, 0)
		if clear and village.has_line_of_sight(a + eye, b + eye) and not village.shot_blocked(a + eye, b + eye):
			return [a, b]
	return []


## A spot at a few paces from `aldo` that `odo` can walk to and from where the two see
## each other clear: Vector3.INF where the ground is too crowded.
func find_spot(village: Outdoor, aldo: Villager, odo: Villager) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	var from := aldo.global_position
	for distance: float in DISTANCES:
		for step in 8:
			var angle := TAU * step / 8.0
			var spot := from + Vector3(cos(angle), 0, sin(angle)) * distance
			spot.y = from.y
			var cell := village.world_to_cell(spot)
			if village.astar.is_in_boundsv(cell) and village.astar.is_point_solid(cell):
				continue
			if not village.has_line_of_sight(from + Vector3(0, 1.2, 0), spot + Vector3(0, 1.2, 0)):
				continue
			if village.shot_blocked(from + Vector3(0, 1.2, 0), spot + Vector3(0, 1.2, 0)):
				continue
			var path := village.grid_path(village.world_to_cell(odo.global_position), cell)
			if path.is_empty() or path.size() > WALK_LIMIT:
				continue
			var d := VillageTalk._flat(spot, odo.global_position)
			if d < best_d:
				best = spot
				best_d = d
		if best != Vector3.INF:
			return best
	return best


## Starts a duel if both mages are free and the hero is near. Returns whether it began.
func start(village: Outdoor, force := false) -> bool:
	if not _duel.is_empty() or village == null or game == null:
		return false
	if not is_time(village):
		return false
	var aldo := mage(village, ALDO)
	var odo := mage(village, ODO)
	if aldo == null or odo == null or not aldo.can_chat() or not odo.can_chat():
		return false
	if "village_talk" in game and game.village_talk.is_chatting():
		return false
	if "drinking_songs" in game and game.drinking_songs.is_singing():
		return false
	var ground := duel_ground(village)
	# The hero is near the place of the duel (or, without a duel ground, near Aldo).
	var scene: Vector3 = (ground[0] + ground[1]) * 0.5 if not ground.is_empty() else aldo.global_position
	var hero_near: bool = VillageTalk._flat(scene, game.player.global_position) <= HEAR_RANGE
	if not hero_near and not force:
		return false
	var spot := Vector3.INF
	if not ground.is_empty():
		# Both walk to the duel ground on the square.
		spot = ground[1]
		if not aldo.join_chat_at(odo, ground[0]):
			return false
		if not odo.join_chat_at(aldo, ground[1]):
			aldo.leave_chat()
			return false
	else:
		spot = find_spot(village, aldo, odo)
		if spot == Vector3.INF or not odo.join_chat_at(aldo, spot):
			return false
		aldo.join_chat(odo, false)
	duels += 1
	_duel = {"a": aldo, "b": odo, "beats": _plan(village), "beat": {}, "t": 0.0, "walk": 0.0, "spot": spot}
	return true


## Ends the duel going on: both go back to their day.
func stop() -> void:
	for side in ["a", "b"]:
		var v = _duel.get(side)
		if v != null and is_instance_valid(v):
			v.leave_chat()
	_duel = {}


# --- The script -------------------------------------------------------------------

## The beats of a whole duel in order: {"line": speaker side, "text": ...} or
## {"cast": caster side, "spell": kind, "hit": bool}.
func _plan(village: Outdoor) -> Array:
	var beats := []
	var opener: Array = OPENERS[_deal("openers", OPENERS.size())]
	beats.append(_line("a", opener[0]))
	beats.append(_line("b", opener[1]))
	var excuses := EXCUSES.duplicate()
	excuses.append_array(WEATHER_EXCUSES.get(village.weather, []))
	for round in _rng.randi_range(ROUNDS.x, ROUNDS.y):
		# Aldo throws.
		var hits := _rng.randf() < ALDO_HITS
		beats.append({"cast": "a", "spell": _next_spell(), "hit": hits})
		if hits:
			beats.append(_line("b", _pick("excuses", excuses)))
			if _rng.randf() < 0.75:
				beats.append(_line("a", _pick("teach", TEACH)))
			if _rng.randf() < 0.6:
				beats.append(_line("b", _pick("promises", PROMISES)))
		else:
			beats.append(_line("b", _pick("dodged", DODGED)))
			beats.append(_line("a", _pick("dodge_cheer", DODGE_CHEER)))
		# Odo throws.
		hits = _rng.randf() < ODO_HITS
		beats.append({"cast": "b", "spell": _next_spell(), "hit": hits})
		if hits:
			beats.append(_line("a", _pick("ouch", OUCH)))
			beats.append(_line("a", _pick("praise", PRAISE)))
			beats.append(_line("b", _pick("triumph", TRIUMPH)))
		else:
			if _rng.randf() < 0.55:
				beats.append(_line("b", _pick("miss", MISS_EXCUSES)))
			beats.append(_line("a", _pick("teach", TEACH)))
	var closer: Array = CLOSERS[_deal("closers", CLOSERS.size())]
	beats.append(_line("a", closer[0]))
	beats.append(_line("b", closer[1]))
	return beats


func _line(side: String, text: String) -> Dictionary:
	return {"line": side, "text": text}


## The next entry of `pool` without repeating one before all have been used.
func _pick(name: String, pool: Array) -> String:
	return pool[_deal(name, pool.size())]


func _deal(name: String, count: int) -> int:
	var deck: Array = _decks.get(name, [])
	if deck.is_empty():
		deck = range(count)
		deck.shuffle()
	var index: int = deck.pop_back()
	_decks[name] = deck
	return index


## The four spells in a shuffled turn, so each shows once before one repeats.
func _next_spell() -> String:
	if _spell_deck.is_empty():
		_spell_deck = DuelSpells.KINDS.duplicate()
		_spell_deck.shuffle()
	return _spell_deck.pop_back()


# --- Playing it -------------------------------------------------------------------

func _run(delta: float, village: Outdoor) -> void:
	var aldo = _duel.a
	var odo = _duel.b
	if not is_instance_valid(aldo) or not is_instance_valid(odo) or not is_time(village):
		stop()
		return
	# The hero spoke to one of them, or something else took them away.
	if aldo.chat_broken or odo.chat_broken or aldo.chat_partner != odo or odo.chat_partner != aldo:
		stop()
		return
	aldo.keep_task(2.0)
	odo.keep_task(2.0)
	if not (aldo.in_chat_place() and odo.in_chat_place()):
		_duel.walk += delta
		# One of them stopped short of the place (something in the way) but both are near enough
		# and in sight: the duel goes on from where they stand.
		var a_ready: bool = aldo.in_chat_place() or aldo.is_stopped_for_chat()
		var o_ready: bool = odo.in_chat_place() or odo.is_stopped_for_chat()
		if a_ready and o_ready and (aldo.chat_partner == odo and odo.chat_partner == aldo):
			var apart := VillageTalk._flat(aldo.global_position, odo.global_position)
			if apart >= MIN_APART and apart <= MAX_APART \
					and village.has_line_of_sight(aldo.global_position + Vector3(0, 1.2, 0), odo.global_position + Vector3(0, 1.2, 0)) \
					and not village.shot_blocked(aldo.global_position + Vector3(0, 1.2, 0), odo.global_position + Vector3(0, 1.2, 0)):
				if not aldo.in_chat_place():
					aldo.settle_for_chat()
				if not odo.in_chat_place():
					odo.settle_for_chat()
				return
		if not (aldo.in_chat_place() or aldo.heading_to_chat()) or not (odo.in_chat_place() or odo.heading_to_chat()) or _duel.walk > WALK_LIMIT:
			stop()
		return
	var beat: Dictionary = _duel.beat
	if beat.is_empty():
		if _duel.beats.is_empty():
			stop()
			return
		# Someone near is talking (to the hero, say): the next beat waits its turn.
		if aldo.talker_near(odo) != null or odo.talker_near(aldo) != null:
			return
		beat = _duel.beats.pop_front()
		_duel.beat = beat
		_duel.t = 0.0
		_begin_beat(beat, aldo, odo)
		return
	_duel.t += delta
	if beat.has("cast"):
		_run_cast(beat, aldo, odo)
	elif _duel.t >= beat.time:
		_duel.beat = {}


func _side(side: String, aldo: Villager, odo: Villager) -> Villager:
	return aldo if side == "a" else odo


func _begin_beat(beat: Dictionary, aldo: Villager, odo: Villager) -> void:
	if beat.has("line"):
		var speaker := _side(beat.line, aldo, odo)
		var text := Lang.t(beat.text)
		var time := VillageTalk.line_time(text)
		speaker.chat_say(text, time)
		beat["time"] = time + GAP
		return
	var caster := _side(beat.cast, aldo, odo)
	caster.strike_pose("Spellcast_Shoot", WINDUP + 0.6)
	beat["fired"] = false
	beat["landed"] = false


func _run_cast(beat: Dictionary, aldo: Villager, odo: Villager) -> void:
	var caster := _side(beat.cast, aldo, odo)
	var target := _side("b" if beat.cast == "a" else "a", aldo, odo)
	var level := caster.level
	if not beat.fired and _duel.t >= WINDUP:
		beat["fired"] = true
		var out := caster.global_position + Vector3(0, 1.4, 0) + _flat_dir(caster, target) * 0.5
		var aim := target.global_position + Vector3(0, 1.3, 0)
		beat["land_at"] = _duel.t + DuelSpells.cast(level, beat.spell, out, aim, beat.hit, -1.0 if _rng.randf() < 0.5 else 1.0)
		Effects.head_text(level, caster, 2.3, Lang.t(DuelSpells.NAMES[beat.spell]), DuelSpells.COLOURS[beat.spell].lightened(0.2))
	if beat.fired and not beat.landed and _duel.t >= beat.land_at:
		beat["landed"] = true
		if beat.hit:
			target.strike_pose("Hit_A", REACT)
		else:
			# Aldo's spell that Odo dodges: a hop to the side.
			if beat.cast == "a":
				target.strike_pose("Dodge_Backward", REACT)
	if beat.landed and _duel.t >= beat.land_at + REACT:
		_duel.beat = {}


func _flat_dir(from: Villager, to: Villager) -> Vector3:
	var d := to.global_position - from.global_position
	d.y = 0.0
	return d.normalized()
