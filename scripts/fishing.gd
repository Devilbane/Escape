class_name Fishing
extends RefCounted
## Fishing: stand by the water, cast the line (key G or the "Angeln" button)
## and wait. When the float jerks under and a "!" shows, press again quickly
## to strike, and the catch comes in.
##
## Or wait: when the bite is let go, the fish may bite again a moment later,
## and again (CHAIN_CHANCE each time, up to MAX_CHAIN bites in a row). The
## longer the row, the rarer the catch (CHAIN_WEED, CHAIN_RARE). When the
## fish does not bite again, the row breaks off and the fish is gone, and so
## it is when the hero strikes into the pause between two bites.
##
## Three waters hold fish: the fountain on the village square, the village
## pond and the pond in the wolf hollow. Most bites are a perch (or, in the
## fountain, a coin someone threw in for luck); each water also has a rare
## fish that bites only there, some only at certain hours. Every fish goes
## into the ingredient pouch (see Crafting), where recipes call for it.
##
## The line is drawn in again when the hero walks away from the water, is
## hit, or opens a window.
##
## The line flies well out over a pond (CAST_REACH), and now and then a
## little pond monster surfaces near the float while the hero waits (see
## MONSTER_WATERS): it peeks at the hero, says "Blubb!" and either sinks
## again or snaps up the bait and takes the float under with it.
##
## While fishing the hero holds a rod (FishingRod) in the right hand instead
## of the weapon. A cast swings it back over the shoulder and whips it
## forward; the float flies off the tip in an arc and splashes down, and the
## line runs from the reel up the rod and out to it. The rod droops at rest,
## and bends down hard when a fish pulls the float under.

## What bites in each water: [catch, weight, when]. A catch is a fish (an
## ingredient id), "muenze" for an old coin (+1 gold) or "" for weed.
## "when" limits the catch to an hour: "nacht" (see DayNight.is_night) or
## "daemmerung" (dawn and dusk, see is_dusk); "" is any time.
const WATERS := {
	"brunnen": [["", 40, ""], ["muenze", 50, ""], ["goldkarpfen", 10, ""]],
	"teich": [["", 30, ""], ["barsch", 60, ""], ["silberhecht", 12, "daemmerung"]],
	"senke": [["", 25, ""], ["barsch", 60, ""], ["mondforelle", 15, "nacht"]],
}
## How far from the water's edge the hero can stand and still cast (metres).
const RANGE := 2.4
## Seconds until a fish bites: a random time between these two.
const WAIT_MIN := 2.5
const WAIT_MAX := 6.5
## Seconds the hero has to strike once the float jerks under.
const BITE_TIME := 1.2
## Bites in a row: when a bite is let go, the fish bites again with this
## chance, after a pause of CHAIN_GAP_MIN to CHAIN_GAP_MAX seconds; never
## more than MAX_CHAIN times in a row.
const CHAIN_CHANCE := 0.6
const MAX_CHAIN := 5
const CHAIN_GAP_MIN := 0.7
const CHAIN_GAP_MAX := 1.4
## For each bite in a row after the first, weed weighs this much in the
## catch (see roll), and a rare fish this much.
const CHAIN_WEED := 0.5
const CHAIN_RARE := 2.0
## How far the line flies at most, from the hero out over a pond (metres).
## The float lands as far out as that, but always clear of the far shore.
const CAST_REACH := 6.0
## How far the float stays from any shore, and the pond monster with its
## tail (metres). The pond's ground fades from water to grass over most of
## a tile, so the water that shows starts well inside the map's pond tiles.
const SHORE_GAP := 1.2
const MONSTER_SHORE_GAP := 1.8
## The waters where the little pond monster lives (not the fountain).
const MONSTER_WATERS := ["teich", "senke"]
## The chance, for each cast into one of those waters, that it shows up.
const MONSTER_CHANCE := 0.15
## Seconds the monster takes to rise, how long it stays up, and to sink.
const MONSTER_RISE := 0.7
const MONSTER_STAY := 2.8
const MONSTER_SINK := 0.7
## The chance that the monster snaps up the bait when it shows up.
const MONSTER_STEALS := 0.4
## How big the monster is drawn, on top of the sizes in make_monster, and
## how deep it hides below the water before it rises (metres).
const MONSTER_SCALE := 1.7
const MONSTER_DEPTH := 1.4
## How far from the float the monster surfaces (metres).
const MONSTER_DISTANCE := 1.6
## Explained in the compendium the first time the monster shows up.
const MONSTER_LORE := "Das kleine Teichungeheuer: Im Dorfteich und im Tümpel der Wolfssenke lebt ein kleines grünes Ungeheuer. Manchmal taucht es beim Angeln neben dem Schwimmer auf und schaut neugierig. Es tut niemandem etwas, aber manchmal schnappt es sich den Köder."
## The cast (seconds from the key press): the rod swings back over the
## shoulder, whips forward, lets the float go and settles. The float flies
## for FLY_TIME and splashes down.
const SWING_BACK := 0.28
const SWING_WHIP := 0.14
const SETTLE := 0.35
const RELEASE := SWING_BACK + SWING_WHIP * 0.6
const FLY_TIME := 0.55
## How the rod points (radians above the ground): held up before the cast,
## swung back, whipped through, and at rest while waiting.
const HOLD_PITCH := 0.9
const BACK_PITCH := 1.95
const WHIP_PITCH := 0.2
const REST_PITCH := 0.55
## How much each joint of the rod bends: a little droop at rest, flexing
## back on the whip, and more for each metre the float is pulled under.
const REST_BEND := -0.05
const WHIP_BEND := 0.16
const PULL_BEND := -0.9
const BITE_BEND := -0.12
## Explained once in the compendium, the first time the line is cast.
const HOW_TO := "Angeln (Taste G oder der Knopf „Angeln“): stell dich ans Wasser und wirf die Leine aus. Taucht der Schwimmer unter und erscheint ein !, drück schnell noch einmal. Oder warte ab: Manchmal beißt der Fisch gleich noch einmal, und je mehr Bisse in Folge, desto seltener der Fang. Reißt die Folge ab, ist der Fisch weg. Fische kommen in den Zutatenbeutel. Seltene Fische beißen nur in einem Gewässer, manche nur zu bestimmten Stunden."

enum {IDLE, WAITING, BITE}

var game: Node
var state := IDLE
## The water the line is in (see Level.fishing_waters), and the level it is on.
var water := {}
var _level: Node
## Seconds until the next bite (WAITING) or until the fish lets go (BITE).
var timer := 0.0
## How many times the fish has bitten in a row this cast (0: not yet).
var bites := 0
var _hp_at_cast := 0
var _float: Node3D
var _float_rest := Vector3.ZERO
var _bob := 0.0
## The line from the hero's hand to the float, redrawn every frame.
var _line: MeshInstance3D
## The rod in the hero's hand, what it hides there while out (the knife or
## the weapon), and seconds since the cast.
var rod: FishingRod
var _hidden_in_hand: Array[Node3D] = []
var _cast_age := 0.0
var _fly_from := Vector3.ZERO
var _splashed := false
## The pond monster, while it is up; how long it has been up; the value of
## `timer` at which it rises this cast (-1: not this cast); whether it takes
## the bait; and where it surfaced.
var monster: Node3D
var _monster_age := 0.0
var _monster_due := -1.0
var _monster_steals := false
var _monster_home := Vector3.ZERO
var rng := RandomNumberGenerator.new()


func _init(owner_game: Node = null) -> void:
	game = owner_game
	rng.randomize()


func is_fishing() -> bool:
	return state != IDLE


## The water the hero could cast into right now, or {}.
func water_near() -> Dictionary:
	if game == null or game.level == null or not game.level.has_method("nearest_water"):
		return {}
	return game.level.nearest_water(game.player.global_position, RANGE)


## Key G or the button: casts the line, strikes when a fish bites, or draws
## the line in early. Returns why nothing happened, or "".
func press() -> String:
	match state:
		WAITING:
			var row := bites
			stop()
			if row > 0:
				# Struck into the pause between two bites.
				game.show_message(Lang.t("Zu früh angeschlagen! Der Fisch ist weg."), 2.0)
			else:
				game.show_message(Lang.t("Du holst die Leine ein. Noch hat nichts angebissen."), 1.8)
			return ""
		BITE:
			land()
			return ""
	if not game.player.can_act():
		return Lang.t("Nicht jetzt.")
	var w := water_near()
	if w.is_empty():
		return Lang.t("Hier gibt es kein Wasser zum Angeln.")
	cast(w)
	return ""


## Casts the line into a water.
func cast(w: Dictionary) -> void:
	stop()
	water = w
	_level = game.level
	state = WAITING
	bites = 0
	timer = rng.randf_range(WAIT_MIN, WAIT_MAX)
	_hp_at_cast = game.player.hp
	var p: Vector3 = game.player.global_position
	game.player.path.clear()
	game.player.face(w.pos - p)
	game.player.play_once("Throw", 0.6)
	Sfx.play(game, "swing", -6.0)
	_float_rest = float_spot(w, p, _level.fishing_waters)
	_cast_age = 0.0
	_splashed = false
	_take_rod()
	_float = _make_float()
	_level.add_child(_float)
	_line = _make_line()
	_level.add_child(_line)
	_pose_rod()
	_fly_float()
	_draw_line()
	_monster_due = -1.0
	if w.water in MONSTER_WATERS and rng.randf() < MONSTER_CHANCE:
		# Some time while the hero waits, before a fish bites.
		_monster_due = rng.randf_range(0.0, maxf(0.0, timer - 1.5))
		_monster_steals = rng.randf() < MONSTER_STEALS
	Events.teach(HOW_TO)
	game.show_message(Lang.t("Du wirfst die Leine aus und wartest …"), 2.0)


## Where the float lands. On a pond the line flies out from the hero, past
## the nearest edge and on over the water, up to CAST_REACH metres from the
## hero but always SHORE_GAP clear of any shore; `waters` are the level's
## fishing waters, so it can fly on over a pond made of several tiles. The
## small fountain basin keeps the float near its middle.
static func float_spot(w: Dictionary, from: Vector3, waters: Array = []) -> Vector3:
	var near := edge_spot(w, from)
	if w.round:
		return near
	var start := Vector3(from.x, 0, from.z)
	var dir := Vector3(near.x, 0, near.z) - start
	if dir.length() < 0.01:
		return near
	dir = dir.normalized()
	var best := near
	var entered := false
	var t := 0.0
	while t <= CAST_REACH:
		var p := start + dir * t
		if is_deep(waters, w.water, p):
			best = Vector3(p.x, w.surface, p.z)
			entered = true
		elif entered and not on_water(waters, w.water, p):
			break
		t += 0.25
	return best


## The spot just inside the edge of a water that is closest to the hero.
static func edge_spot(w: Dictionary, from: Vector3) -> Vector3:
	var to := Vector3(from.x - w.pos.x, 0, from.z - w.pos.z)
	var spot: Vector3 = w.pos
	if w.round:
		spot += to.normalized() * minf(to.length(), w.reach * 0.6) if to.length() > 0.01 else Vector3.ZERO
	else:
		var inner: float = w.reach - 1.0
		spot += Vector3(clampf(to.x, -inner, inner), 0, clampf(to.z, -inner, inner))
	spot.y = w.surface
	return spot


## Whether a spot lies on one of the waters of a kind ("teich", ...).
static func on_water(waters: Array, kind: String, p: Vector3) -> bool:
	for w in waters:
		if w.water == kind and Level.water_distance(w, p) <= 0.0:
			return true
	return false


## Whether a spot is out on a water, at least `gap` metres from every shore
## (also across the diagonals, so not tucked into a corner).
static func is_deep(waters: Array, kind: String, p: Vector3, gap := SHORE_GAP) -> bool:
	if not on_water(waters, kind, p):
		return false
	for i in 8:
		if not on_water(waters, kind, p + Vector3(gap, 0, 0).rotated(Vector3.UP, i * TAU / 8.0)):
			return false
	return true


## Puts the rod in the hero's right hand, in place of the knife or weapon.
func _take_rod() -> void:
	var hand: Node3D = game.player.find_child("handslot_r", true, false)
	rod = FishingRod.new()
	_hidden_in_hand.clear()
	if hand == null:
		rod.position = Vector3(0.35, 1.2, 0.2)
		game.player.add_child(rod)
		return
	hand.add_child(rod)
	_clear_hand()


## Hides what else is in the rod's hand, also if the gear changes meanwhile.
func _clear_hand() -> void:
	for child in rod.get_parent().get_children():
		if child != rod and child is Node3D and child.visible:
			child.visible = false
			_hidden_in_hand.append(child)


## Puts the rod away, and the knife or weapon back in hand.
func _put_rod_away() -> void:
	if is_instance_valid(rod):
		rod.queue_free()
	rod = null
	for node in _hidden_in_hand:
		if is_instance_valid(node):
			node.visible = true
	_hidden_in_hand.clear()


## How the rod points `age` seconds after the cast (radians above ground).
static func rod_pitch(age: float) -> float:
	if age < SWING_BACK:
		return lerpf(HOLD_PITCH, BACK_PITCH, smoothstep(0.0, 1.0, age / SWING_BACK))
	age -= SWING_BACK
	if age < SWING_WHIP:
		var k := age / SWING_WHIP
		return lerpf(BACK_PITCH, WHIP_PITCH, k * k)
	age -= SWING_WHIP
	if age < SETTLE:
		return lerpf(WHIP_PITCH, REST_PITCH, smoothstep(0.0, 1.0, age / SETTLE))
	return REST_PITCH


## How much each joint of the rod bends `age` seconds after the cast, with
## the float `depth` metres under (or above, below 0) where it rests.
static func rod_bend(age: float, depth: float) -> float:
	var bend := REST_BEND + PULL_BEND * maxf(0.0, depth)
	var whip := age - SWING_BACK
	if whip > 0.0 and whip < SWING_WHIP + SETTLE:
		# The tip lags behind on the whip and springs back after.
		var k := whip / (SWING_WHIP + SETTLE)
		bend += WHIP_BEND * sin(k * TAU) * (1.0 - k)
	return bend


## How far the float has flown, 0 at the release to 1 on the water; 0
## while it still hangs at the rod's tip.
static func flight(age: float) -> float:
	return clampf((age - RELEASE) / FLY_TIME, 0.0, 1.0)


## Where the rod's tip is drawn this frame (the hand moves with the hero,
## who is drawn between physics ticks).
func _rod_tip() -> Vector3:
	var hero: Vector3 = game.player.global_position
	var drawn: Vector3 = SmoothMotion.drawn_at(game.player)
	return _level.to_local(rod.tip.global_position - hero + drawn)


## Turns the rod towards the float, swings it for the cast and bends it
## when the float is pulled under.
func _pose_rod() -> void:
	if not is_instance_valid(rod) or not is_instance_valid(_float):
		return
	var depth := _float_rest.y - _float.position.y if flight(_cast_age) >= 1.0 else 0.0
	var bend := rod_bend(_cast_age, depth)
	if state == BITE:
		# The fish tugs: the rod bends down hard and shakes.
		bend += BITE_BEND + sin(_bob * 27.0) * 0.05
	if rod.get_parent() != game.player:
		_clear_hand()
	rod.aim(_float_rest - game.player.global_position, rod_pitch(_cast_age), bend)


## The float before it lands: hanging off the tip on the backswing, then
## flying out in an arc to where it rests. Splashes down on landing.
func _fly_float() -> void:
	var k := flight(_cast_age)
	if k <= 0.0:
		_fly_from = _rod_tip() - Vector3(0, 0.25, 0)
		_float.position = _fly_from
		return
	var arc := 1.0 + 0.2 * _fly_from.distance_to(_float_rest)
	_float.position = _fly_from.lerp(_float_rest, k) + Vector3(0, arc * 4.0 * k * (1.0 - k), 0)
	if k >= 1.0 and not _splashed:
		_splashed = true
		_float.position = _float_rest
		Sfx.play(game, "drip", -4.0, _float_rest, 1.2)
		_ripple(_float_rest)


## A red and white float, a little ball on the water.
func _make_float() -> Node3D:
	var node := Node3D.new()
	for part in [[Color(0.9, 0.15, 0.12), 0.06], [Color(0.95, 0.95, 0.9), -0.06]]:
		var mesh := SphereMesh.new()
		mesh.radius = 0.13
		mesh.height = 0.2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[0]
		mat.roughness = 0.5
		var ball := MeshInstance3D.new()
		ball.mesh = mesh
		ball.material_override = mat
		ball.position.y = part[1]
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(ball)
	return node


## The fishing line: a thin pale cord, drawn anew every frame.
func _make_line() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.92, 0.92, 0.86)
	var line := MeshInstance3D.new()
	line.mesh = ImmediateMesh.new()
	line.material_override = mat
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return line


## Poses the rod, then draws the line from the reel up to the rod's tip and
## on out to the float, sagging a little once the float is on the water.
func _draw_line() -> void:
	if not is_instance_valid(_line) or not is_instance_valid(_float):
		return
	if not is_instance_valid(rod):
		return
	_pose_rod()
	var tip := _rod_tip()
	var reel: Vector3 = tip + rod.reel.global_position - rod.tip.global_position
	var bob := _float.position + Vector3(0, 0.1, 0)
	var sag := 0.05 * Vector2(bob.x - tip.x, bob.z - tip.z).length() * flight(_cast_age)
	var mesh: ImmediateMesh = _line.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_add_vertex(reel)
	for i in 13:
		var k := i / 12.0
		mesh.surface_add_vertex(tip.lerp(bob, k) - Vector3(0, sag * 4.0 * k * (1.0 - k), 0))
	mesh.surface_end()


## Called every frame by the game.
func tick(delta: float) -> void:
	if state == IDLE:
		return
	if game.level != _level or not is_instance_valid(_float):
		stop()
		return
	if game.player.dead or game.player.hp < _hp_at_cast:
		stop()
		game.show_message(Lang.t("Der Kampf verscheucht die Fische."), 1.8)
		return
	if game.menus.is_open() or Level.water_distance(water, game.player.global_position) > RANGE + 0.8:
		stop()
		game.show_message(Lang.t("Du holst die Leine ein."), 1.4)
		return
	_hp_at_cast = maxi(_hp_at_cast, game.player.hp)
	_bob += delta
	_cast_age += delta
	if state == WAITING and _monster_due >= 0.0 and timer <= _monster_due:
		monster_rises(_monster_steals)
	if is_instance_valid(monster):
		# No fish bites while the monster is about.
		_tick_monster(delta)
		_draw_line()
		return
	timer -= delta
	if state == WAITING and not _splashed:
		_fly_float()
		if timer <= 0.0:
			bite()
	elif state == WAITING:
		_float.position = _float_rest + Vector3(0, sin(_bob * 2.2) * 0.03, 0)
		if timer <= 0.0:
			bite()
	else:
		# The float is pulled under and jerks about.
		_float.position = _float_rest + Vector3(sin(_bob * 31.0) * 0.05, -0.12, 0)
		if timer <= 0.0:
			let_go(bites < MAX_CHAIN and rng.randf() < CHAIN_CHANCE)
			if state == IDLE:
				return
	_draw_line()


## A fish takes the bait: the hero has BITE_TIME seconds to strike. Each
## bite in a row shows one more "!" and sounds a little higher.
func bite() -> void:
	state = BITE
	timer = BITE_TIME
	bites += 1
	_monster_due = -1.0
	Sfx.play(game, "drip", 0.0, _float_rest, 0.8 + 0.1 * (bites - 1))
	Effects.float_text(_level, _float_rest + Vector3(0, 1.2, 0), "!".repeat(bites), Color(1.0, 0.85, 0.3), true)
	if bites == 1:
		game.show_message(Lang.t("Es beißt! Schnell: G oder „Angeln“!"), BITE_TIME)
	else:
		game.show_message(Lang.t("%d. Biss in Folge! G: anschlagen, oder auf den nächsten warten.") % bites, BITE_TIME)


## The hero let a bite go by. With `again` the float comes up and the fish
## bites once more after a short pause; otherwise the row breaks off and
## the fish is gone.
func let_go(again: bool) -> void:
	if again:
		state = WAITING
		timer = rng.randf_range(CHAIN_GAP_MIN, CHAIN_GAP_MAX)
		game.show_message(Lang.t("Der Schwimmer taucht wieder auf … beißt er noch einmal?"), timer)
		return
	var row := bites
	var at := _float_rest
	var on := _level
	stop()
	Effects.float_text(on, at + Vector3(0, 1.2, 0), Lang.t("Weg!"), Color(0.75, 0.75, 0.8), true)
	if row <= 1:
		game.show_message(Lang.t("Zu langsam! Der Fisch beißt nicht noch einmal und ist weg."), 2.2)
	else:
		game.show_message(Lang.t("Die Bissfolge reißt nach %d Bissen ab: Der Fisch ist weg!") % row, 2.5)


## The hero strikes in time: what was on the hook comes in.
func land() -> void:
	var caught := roll(water.water, game.day_hour, rng, bites)
	var pos: Vector3 = _float_rest
	var on: Node = _level
	stop()
	take(caught, pos, on)


## What was on the hook comes in: weed (""), an old coin ("muenze") or a fish
## for the ingredient pouch. `pos` is where the float was, on level `on`.
func take(caught: String, pos: Vector3, on: Node) -> void:
	game.player.play_flourish("PickUp", 0.6)
	if caught == "":
		Sfx.play(game, "drip", -4.0)
		Events.found(Lang.t("Nur Wasserkraut am Haken."), Color(0.8, 0.8, 0.85))
	elif caught == "muenze":
		game.coins += 1
		Sfx.play(game, "coin")
		Effects.loot_text(on, pos + Vector3(0, 1.4, 0), Lang.t("+%d Kupfer") % 1, game.GOLD, DamageNumber.copper_worth(1))
		Events.found(Lang.t("Eine alte Münze, die jemand für sein Glück hineingeworfen hat. +1 Kupfer"), game.GOLD)
	else:
		game.crafting.add(caught)
		var fish := Crafting.ingredient_name(caught)
		if Crafting.INGREDIENTS[caught].get("rare", false):
			Sfx.play(game, "gift")
			var burst := Effects.make_sparkles(Color(0.6, 0.85, 1.0), true)
			burst.position = pos + Vector3(0, 0.5, 0)
			on.add_child(burst)
			Events.tell(Lang.t("Ein seltener Fang: %s!") % fish + "\n" + Lang.t("Der Fang kommt in deinen Zutatenbeutel."), Color(0.6, 0.85, 1.0))
			Events.found(Lang.t("Ein seltener Fang: %s!") % Rarity.marked(caught), Color(0.6, 0.85, 1.0))
		else:
			Sfx.play(game, "drip")
			Effects.loot_text(on, pos + Vector3(0, 1.4, 0), fish, Color(0.75, 0.9, 1.0), DamageNumber.item_worth(caught))
			Events.found(Lang.t("Gefangen: %s! Ab in den Zutatenbeutel.") % Rarity.marked(caught))
		for id in game.crafting.caught_fish(caught):
			game.show_message(Lang.t("Jetzt verstehst du eine verwischte Zeile im Rezept „%s“.") % Lang.t(Crafting.RECIPES[id].name), 3.5)
	game._update_hud()


## Draws the line in, without a catch.
func stop() -> void:
	state = IDLE
	bites = 0
	water = {}
	_level = null
	_monster_due = -1.0
	_put_rod_away()
	for node in [_float, _line, monster]:
		if is_instance_valid(node):
			node.queue_free()
	_float = null
	_line = null
	monster = null


## The little pond monster surfaces near the float. With `steals` it snaps
## up the bait at the end and takes the float under with it.
func monster_rises(steals: bool) -> void:
	_monster_due = -1.0
	if state != WAITING or is_instance_valid(monster) or not (water.water in MONSTER_WATERS):
		return
	_monster_steals = steals
	_monster_age = 0.0
	_monster_home = monster_spot(_level.fishing_waters, water, _float_rest, game.player.global_position)
	monster = make_monster()
	monster.position = _monster_home + Vector3(0, -MONSTER_DEPTH, 0)
	_level.add_child(monster)
	_face_hero()
	_ripple(_monster_home)
	Sfx.play(game, "drip", -2.0, _monster_home, 0.55)
	Events.teach(MONSTER_LORE)
	game.show_message(Lang.t("Neben dem Schwimmer taucht ein kleines Teichungeheuer auf!"), 2.5)


## Where the monster surfaces: MONSTER_DISTANCE from the float, out on the
## water, a little to one side of the way from the hero (so the hero's name
## tag does not hide it); else straight beyond it, or by the float.
static func monster_spot(waters: Array, w: Dictionary, float_at: Vector3, hero: Vector3) -> Vector3:
	var away := Vector3(float_at.x - hero.x, 0, float_at.z - hero.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	for distance in [MONSTER_DISTANCE, MONSTER_DISTANCE * 0.65]:
		for turn in [0.8, -0.8, 0.0, 1.6, -1.6, 2.4, -2.4]:
			var p: Vector3 = float_at + away.rotated(Vector3.UP, turn) * distance
			if is_deep(waters, w.water, p, MONSTER_SHORE_GAP):
				return Vector3(p.x, w.surface, p.z)
	return float_at + away * 0.6


## The monster's head turns toward the hero.
func _face_hero() -> void:
	var to: Vector3 = _level.to_local(game.player.global_position) - monster.position
	to.y = 0
	if to.length() > 0.01:
		monster.rotation.y = atan2(-to.x, -to.z)


## The monster's visit, frame by frame: it rises, bobs and blinks, looks at
## the hero and says "Blubb!", then sinks again. If it takes the bait it
## glides to the float first and pulls it under as it sinks.
func _tick_monster(delta: float) -> void:
	_monster_age += delta
	var t := _monster_age
	var up := _monster_home
	var float_y := sin(_bob * 2.2) * 0.03
	if t < MONSTER_RISE:
		var k := t / MONSTER_RISE
		monster.position = up + Vector3(0, -MONSTER_DEPTH * (1.0 - k * k * (3.0 - 2.0 * k)), 0)
	elif t < MONSTER_RISE + MONSTER_STAY:
		var s := t - MONSTER_RISE
		var pos := up
		if _monster_steals:
			# Glides over to the float in the second half of its stay.
			var k := clampf((s - MONSTER_STAY * 0.5) / (MONSTER_STAY * 0.45), 0.0, 1.0)
			pos = up.lerp(Vector3(_float_rest.x, up.y, _float_rest.z), k * k * (3.0 - 2.0 * k))
		monster.position = pos + Vector3(0, sin(s * 3.0) * 0.04, 0)
		monster.rotation.z = sin(s * 2.0) * 0.08
		_face_hero()
		if _monster_steals and s > MONSTER_STAY * 0.5:
			monster.rotation.y = lerp_angle(monster.rotation.y, atan2(-(_float_rest.x - monster.position.x), -(_float_rest.z - monster.position.z)), minf(1.0, delta * 6.0))
		# A blink now and then.
		var eyes := monster.get_node_or_null("Eyes") as Node3D
		if eyes:
			eyes.scale.y = 0.15 if fmod(s, 1.6) > 1.45 else 1.0
		if s - delta < 0.5 and s >= 0.5:
			Effects.float_text(_level, up + Vector3(0, 1.3, 0), Lang.t("Blubb!"), Color(0.6, 0.95, 0.75), true)
			Sfx.play(game, "drip", -4.0, up, 0.7)
	elif t < MONSTER_RISE + MONSTER_STAY + MONSTER_SINK:
		var k := (t - MONSTER_RISE - MONSTER_STAY) / MONSTER_SINK
		var here := Vector3(monster.position.x, up.y, monster.position.z)
		monster.position = here + Vector3(0, -MONSTER_DEPTH * k * k, 0)
		if _monster_steals:
			float_y = -0.5 * k
		if t - delta < MONSTER_RISE + MONSTER_STAY:
			_ripple(here)
			Sfx.play(game, "drip", -3.0, here, 0.6)
	else:
		if _monster_steals:
			stop()
			game.show_message(Lang.t("Das kleine Teichungeheuer schnappt sich deinen Köder und taucht damit ab!"), 2.5)
			return
		monster.queue_free()
		monster = null
		# The fish need a moment to come back.
		timer = maxf(timer, 1.0)
		game.show_message(Lang.t("Das kleine Teichungeheuer taucht wieder ab. Du wartest weiter …"), 2.0)
	if is_instance_valid(_float):
		_float.position = _float_rest + Vector3(0, float_y, 0)


## A small green pond monster, about knee high above the water: a round
## head with big eyes and two stubby horns, and a hump and a tail tip
## behind it. It looks along -Z.
static func make_monster() -> Node3D:
	var root := Node3D.new()
	root.name = "PondMonster"
	var skin := _paint(Color(0.25, 0.55, 0.42))
	var belly := _paint(Color(0.55, 0.78, 0.5))
	var parts := [
		[_ball(0.3), skin, Vector3(0, 0.25, -0.05), Vector3(1.0, 1.0, 1.0)],
		[_ball(0.2), belly, Vector3(0, 0.15, -0.2), Vector3(1.1, 0.8, 0.7)],
		[_ball(0.22), skin, Vector3(0, 0.02, 0.45), Vector3(1.0, 0.8, 1.2)],
		[_ball(0.13), skin, Vector3(0, 0.0, 0.85), Vector3(1.0, 0.8, 1.3)],
	]
	for part in parts:
		var mi := _mesh_part(part[0], part[1], part[2])
		mi.scale = part[3]
		root.add_child(mi)
	for side in [-1.0, 1.0]:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.06
		horn.height = 0.18
		var h := _mesh_part(horn, belly, Vector3(side * 0.15, 0.55, 0.0))
		h.rotation.z = -side * 0.35
		root.add_child(h)
	# The eyes, in their own node so they can blink.
	var eyes := Node3D.new()
	eyes.name = "Eyes"
	eyes.position = Vector3(0, 0.36, -0.25)
	var white := _paint(Color(0.97, 0.97, 0.92), 0.3)
	var dark := _paint(Color(0.05, 0.05, 0.08), 0.2)
	for side in [-1.0, 1.0]:
		eyes.add_child(_mesh_part(_ball(0.09), white, Vector3(side * 0.11, 0, 0)))
		eyes.add_child(_mesh_part(_ball(0.045), dark, Vector3(side * 0.11, 0.0, -0.07)))
	root.add_child(eyes)
	root.scale = Vector3.ONE * MONSTER_SCALE
	return root


static func _ball(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


static func _paint(color: Color, roughness := 0.6) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


static func _mesh_part(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi


## A pale ring that spreads over the water and fades, where the monster
## rises or sinks.
func _ripple(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.5
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.95, 1.0, 0.6)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = at + Vector3(0, 0.02, 0)
	ring.scale = Vector3(1, 0.1, 1)
	_level.add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(2.6, 0.1, 2.6), 1.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.0)
	tw.chain().tween_callback(ring.queue_free)


## Whether it is dawn or dusk, when the silver pike bites.
static func is_dusk(hour: float) -> bool:
	return (hour >= 5.0 and hour < 8.0) or (hour >= 18.0 and hour < 21.0)


## Whether a catch can bite at an hour.
static func bites_at(when: String, hour: float) -> bool:
	match when:
		"nacht":
			return DayNight.is_night(hour)
		"daemmerung":
			return is_dusk(hour)
	return true


## Whether a catch is one of the rare fish.
static func is_rare(caught: String) -> bool:
	return (Crafting.INGREDIENTS.get(caught, {}) as Dictionary).get("rare", false)


## How much a row of WATERS weighs after `bites` bites in a row: each bite
## after the first makes weed rarer and a rare fish likelier.
static func weight(row: Array, bites := 1) -> float:
	var extra := maxi(0, bites - 1)
	if row[0] == "":
		return row[1] * pow(CHAIN_WEED, extra)
	if is_rare(row[0]):
		return row[1] * pow(CHAIN_RARE, extra)
	return float(row[1])


## What comes in from a water at an hour, picked by the weights in WATERS
## (see weight) after `bites` bites in a row.
static func roll(water_id: String, hour: float, random: RandomNumberGenerator, bites := 1) -> String:
	var table := (WATERS.get(water_id, []) as Array).filter(func(row): return bites_at(row[2], hour))
	var total := 0.0
	for row in table:
		total += weight(row, bites)
	if total <= 0.0:
		return ""
	var pick := random.randf() * total
	for row in table:
		pick -= weight(row, bites)
		if pick < 0.0:
			return row[0]
	return table[-1][0]
