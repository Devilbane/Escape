class_name Rescue
extends Node3D
## A hero whose life runs out is not dead: they fall unconscious and are
## carried to their latest safe spot, the bed they last slept in (or their
## camp, see Camp), and wake up there with full life. The run goes on.
##
## Who carries them depends on where they fell: on the surface (the open air,
## a house, an inn) a giant eagle swoops down and lifts them away; below
## ground (the dungeon, the mines, the lairs) the dwarves' emergency team
## comes with lanterns and a stretcher.
##
## The rescuers carry the hero, not their loot. Everything in the bag, every
## coin in the purse and every ingredient in the pouch stays where they fell:
## the coins as piles (see CoinPile), the rest in one pack, the hero's
## "bundle" on the floor list (see Level.lay_bundle). What is worn stays
## worn, and so do the knives in the belt. Walking onto the pack gives it all
## back (as much as the bag holds). The dragon's helpers leave the pack alone,
## but at night they may carry the coin piles off to the hoard like any other
## coins lying about (see DragonHelpers).
##
## The eagle and the dwarves move per frame and are not interpolated; the
## hero they carry is moved in physics ticks (a tween), and they follow where
## the hero is drawn (SmoothMotion.drawn_at).

## Explained once in the compendium, the first time it happens.
const LORE := "Sinkt dein Leben auf null, wirst du bewusstlos, aber nicht tot. An der Oberfläche trägt dich ein Riesenadler fort, unter der Erde holt dich der Rettungstrupp der Zwerge. Du wachst in dem Bett auf, in dem du zuletzt geschlafen hast (oder an deinem Lager), mit vollem Leben. Was du anhast, behältst du. Alles in der Tasche, deine Münzen und deine Zutaten bleiben dort liegen, wo du gefallen bist: die Münzen als Haufen, der Rest in deinem Bündel. Geh hin und hol es dir zurück. Aber beeil dich: Nachts tragen die Helfer des Drachen liegende Münzen in seinen Hort."

## The pack's floor entry kind (see Level.floor_items).
const BUNDLE := "bundle"
## Seconds the hero lies there before help comes.
const LIE_STILL := 1.3
## The eagle: how long it swoops down, holds on, and climbs away with the hero.
const SWOOP := 1.7
const GRIP := 0.45
const CLIMB := 2.4
## The dwarves: how long they walk up, lift the hero onto the stretcher, and
## carry them off.
const WALK_UP := 1.9
const LIFT := 0.7
const CARRY := 2.4
## How long the screen takes to go dark while the hero is carried off.
const FADE := 1.4
## How big the giant eagle is.
const EAGLE_SIZE := 1.7
## The stretcher's height above the floor.
const STRETCHER_HIGH := 0.75

const BROWN := Color(0.33, 0.21, 0.11)
const DARK_BROWN := Color(0.22, 0.14, 0.08)
const WHITE := Color(0.95, 0.93, 0.87)
const YELLOW := Color(0.95, 0.72, 0.15)

var hero: Player
var by_eagle := true
## The whole rescue up to the dark, in seconds (see duration).
var _time := 0.0
var _from := Vector3.ZERO
var _away := Vector3.FORWARD
var _eagle: Node3D
var _wings: Array[Node3D] = []
var _dwarves: Array[Node3D] = []
var _stretcher: Node3D
var _carrying := false
var _last_beat := -1
## The tween that lifts and carries the hero (see _start).
var _lift: Tween


## Whether a level is on the surface, where the eagle comes (see the class).
static func on_surface(level: Level) -> bool:
	return level != null and (level.outdoor or level.is_home or level.inn)


## Sends help for `hero`, lying on `level`: an eagle on the surface, the
## dwarves below. The hero is lifted and carried off; `fade` is a callable
## (seconds) that darkens the screen, `done` runs once it is dark.
static func send(level: Level, who: Player, fade: Callable, done: Callable) -> Rescue:
	var r := Rescue.new()
	r.name = "Rescue"
	r.hero = who
	r.by_eagle = on_surface(level)
	level.add_child(r)
	r._start(fade, done)
	return r


## How long a rescue takes until the screen is dark.
static func duration(eagle: bool) -> float:
	return LIE_STILL + (SWOOP + GRIP + CLIMB if eagle else WALK_UP + LIFT + CARRY)


func _start(fade: Callable, done: Callable) -> void:
	_from = hero.global_position
	# They come from (and leave towards) the way the camera looks into the
	# scene, so they are seen arriving.
	_away = Vector3(randf_range(-0.6, 0.6), 0.0, -1.0).normalized()
	if by_eagle:
		_build_eagle()
	else:
		_build_dwarves()
	var total := duration(by_eagle)
	var t := create_tween()
	t.tween_interval(total - FADE)
	t.tween_callback(func(): fade.call(FADE))
	t.tween_interval(FADE)
	t.tween_callback(func():
		# Whatever of the carrying is left must not move the hero once they
		# are put down at the bed.
		if _lift and _lift.is_valid():
			_lift.kill()
		done.call())
	t.tween_callback(queue_free)
	# The hero is lifted and carried in physics ticks (see SmoothMotion).
	_lift = hero.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var lift := _lift
	if by_eagle:
		lift.tween_interval(LIE_STILL + SWOOP + GRIP)
		lift.tween_callback(func(): _carrying = true)
		lift.tween_property(hero, "global_position", _from + _away * 16.0 + Vector3(0, 15.0, 0), CLIMB) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		lift.tween_interval(LIE_STILL + WALK_UP)
		lift.tween_property(hero, "global_position", _from + Vector3(0, STRETCHER_HIGH, 0), LIFT)
		lift.tween_callback(func(): _carrying = true)
		lift.tween_property(hero, "global_position", _from + _away * 9.0 + Vector3(0, STRETCHER_HIGH, 0), CARRY)


func _process(delta: float) -> void:
	_time += delta
	if by_eagle:
		_fly_eagle()
	else:
		_walk_dwarves()


# --- The eagle ------------------------------------------------------------------

func _fly_eagle() -> void:
	var t := _time - LIE_STILL
	var hold := Vector3(0, 2.4, 0)
	var beat_speed := 9.0
	if t < 0.0:
		_eagle.visible = false
		return
	_eagle.visible = true
	if t < SWOOP:
		# Down in a long glide from high up behind the hero, wings spread.
		var k := t / SWOOP
		var high := _from + _away * 26.0 + Vector3(0, 18.0, 0)
		var low := _from + hold
		var at := high.lerp(low, 1.0 - pow(1.0 - k, 2.0))
		_face(_eagle, at, low)
		_eagle.global_position = at
		beat_speed = 3.0 if k < 0.7 else 12.0
	else:
		# Hovering above the hero, then climbing away with them in its claws.
		var at := SmoothMotion.drawn_at(hero) + hold
		_face(_eagle, _eagle.global_position, at + _away * 4.0 if _carrying else at - _away)
		_eagle.global_position = at
		beat_speed = 13.0
	var angle := sin(_time * beat_speed) * (0.25 if beat_speed < 5.0 else 0.7)
	_wings[0].rotation.z = angle
	_wings[1].rotation.z = -angle
	# A heavy wingbeat now and then, and one cry as it comes down.
	var beat := int(_time * beat_speed / TAU)
	if beat != _last_beat and beat_speed > 5.0:
		_last_beat = beat
		Sfx.play(self, "dragon_wingbeat_%d" % (beat % 3), -10.0, _eagle.global_position, 1.7)
	if t >= SWOOP * 0.35 and not has_meta("cried"):
		set_meta("cried", true)
		Sfx.play(self, "dragon_shriek", -12.0, _eagle.global_position, 2.3)


## Turns a flyer (built facing -Z) towards where it goes, upright.
static func _face(node: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	dir.y = 0.0
	if dir.length() > 0.01:
		node.rotation.y = atan2(-dir.x, -dir.z)


func _build_eagle() -> void:
	_eagle = Node3D.new()
	_eagle.name = "Eagle"
	add_child(_eagle)
	_eagle.scale = Vector3.ONE * EAGLE_SIZE
	_eagle.visible = false
	var body := _part(_eagle, _capsule(0.32, 1.3), BROWN, Vector3.ZERO)
	body.rotation.x = PI * 0.5
	_part(_eagle, _sphere(0.26), WHITE, Vector3(0, 0.12, -0.72))
	var beak := _part(_eagle, _cone(0.09, 0.28), YELLOW, Vector3(0, 0.08, -1.0))
	beak.rotation.x = -PI * 0.5
	_part(_eagle, _box(Vector3(0.55, 0.06, 0.55)), DARK_BROWN, Vector3(0, 0.02, 0.82))
	# Talons, hanging ready to grip.
	for side in [-1.0, 1.0]:
		_part(_eagle, _box(Vector3(0.09, 0.32, 0.09)), YELLOW, Vector3(0.16 * side, -0.4, -0.05))
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.26 * side, 0.08, -0.05)
		_eagle.add_child(pivot)
		_part(pivot, _box(Vector3(1.9, 0.06, 0.75)), BROWN, Vector3(0.95 * side, 0, 0))
		# Darker flight feathers at the tips.
		_part(pivot, _box(Vector3(0.7, 0.05, 0.9)), DARK_BROWN, Vector3(2.15 * side, 0, 0.05))
		_wings.append(pivot)


# --- The dwarves ---------------------------------------------------------------

func _walk_dwarves() -> void:
	var t := _time - LIE_STILL
	var side := _away.cross(Vector3.UP).normalized()
	var spots := [side * 1.25, -side * 1.25]
	for i in _dwarves.size():
		var d: Node3D = _dwarves[i]
		var at: Vector3
		if t < 0.0:
			d.visible = false
			continue
		d.visible = true
		if t < WALK_UP:
			var k := t / WALK_UP
			at = (_from + _away * 10.0 + spots[i]).lerp(_from + spots[i], k)
			_face(d, at, _from + spots[i])
		else:
			var drawn := SmoothMotion.drawn_at(hero)
			at = Vector3(drawn.x, _from.y, drawn.z) + spots[i]
			if _carrying:
				_face(d, at, at + _away)
			else:
				_face(d, at, _from)
		d.global_position = at
		var anim: AnimationPlayer = d.get_meta("anim")
		var walking := t < WALK_UP or _carrying
		if anim and walking and anim.current_animation != "Walking_A":
			anim.play("Walking_A", 0.2)
		elif anim and not walking and anim.current_animation != "Idle":
			anim.play("Idle", 0.2)
	_stretcher.visible = t >= WALK_UP
	if _stretcher.visible:
		var drawn := SmoothMotion.drawn_at(hero)
		_stretcher.global_position = Vector3(drawn.x, _from.y + STRETCHER_HIGH - 0.05, drawn.z)
		_face(_stretcher, _stretcher.global_position, _stretcher.global_position + _away)
	if t >= WALK_UP and not has_meta("called"):
		set_meta("called", true)
		Effects.head_text(get_parent(), _dwarves[0], 2.6, Lang.t("Bergrettung!"), Color(1.0, 0.85, 0.45))
		Sfx.play(self, "chain", -10.0, _from)
	var step := int(_time * 3.2)
	if (t < WALK_UP or _carrying) and t >= 0.0 and step != _last_beat:
		_last_beat = step
		Sfx.play(self, "step_%d" % (step % 6), -14.0, _from, 0.85)


func _build_dwarves() -> void:
	for model in ["Barbarian", "Knight"]:
		var holder := Node3D.new()
		holder.name = "Dwarf%d" % (_dwarves.size() + 1)
		add_child(holder)
		holder.visible = false
		var body: Node3D = load("res://assets/characters/%s.glb" % model).instantiate()
		# Short and broad: a dwarf.
		body.scale = Vector3(1.0, 0.78, 1.0)
		holder.add_child(body)
		# A long beard, and a lantern that lights the way.
		var beard := _part(holder, _cone(0.24, 0.55), Color(0.55, 0.32, 0.16) if model == "Barbarian" else Color(0.75, 0.73, 0.7), Vector3(0, 1.0, -0.3))
		beard.rotation.x = PI
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.78, 0.45)
		lamp.light_energy = 1.6
		lamp.omni_range = 6.0
		lamp.position = Vector3(0, 1.6, -0.4)
		holder.add_child(lamp)
		holder.set_meta("anim", body.find_child("AnimationPlayer", true, false))
		_dwarves.append(holder)
	_stretcher = Node3D.new()
	_stretcher.name = "Stretcher"
	add_child(_stretcher)
	_stretcher.visible = false
	_part(_stretcher, _box(Vector3(0.9, 0.06, 2.1)), Color(0.62, 0.55, 0.42), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		_part(_stretcher, _box(Vector3(0.07, 0.07, 2.7)), DARK_BROWN, Vector3(0.48 * side, 0.02, 0))


# --- Meshes ---------------------------------------------------------------------

static func _part(parent: Node3D, mesh: Mesh, colour: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


static func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c


# --- What stays behind ------------------------------------------------------------

## Whether a floor entry is the hero's pack.
static func is_bundle(entry) -> bool:
	return entry is Array and entry.size() >= 5 and str(entry[0]) == BUNDLE and entry[4] is Dictionary


## Whether nothing is left in the pack.
static func is_empty(entry) -> bool:
	if not is_bundle(entry):
		return true
	var c: Dictionary = entry[4]
	return (c.get("bag", []) as Array).is_empty() and (c.get("pouch", {}) as Dictionary).is_empty()


## The pack on the floor: a tied-up leather sack with a strap, glowing a
## little so it can be found in the dark.
static func bundle_model() -> Node3D:
	var holder := Node3D.new()
	holder.name = "Bundle"
	var sack := _part(holder, _sphere(0.42), Color(0.45, 0.3, 0.17), Vector3(0, 0.36, 0))
	sack.scale = Vector3(1.0, 0.85, 0.8)
	_part(holder, _cone(0.22, 0.3), Color(0.4, 0.26, 0.14), Vector3(0, 0.82, 0))
	var strap := _part(holder, _box(Vector3(0.9, 0.05, 0.08)), DARK_BROWN, Vector3(0, 0.62, 0))
	strap.rotation.z = 0.5
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.55)
	light.light_energy = 1.2
	light.omni_range = 3.5
	light.position = Vector3(0, 1.0, 0)
	holder.add_child(light)
	holder.add_child(Effects.make_sparkles(Color(1.0, 0.88, 0.6)))
	return holder


## Takes from the hero everything they looted and lays it down where they
## lie on `game`'s level: the coins of the purse as piles, the bag and the
## ingredient pouch in one pack. Worn gear and the knives in the belt stay.
## Returns what went down: {"items", "coins", "ingredients"}.
static func drop_belongings(game: Node) -> Dictionary:
	var level: Level = game.level
	var hero: Player = game.player
	var crafting: Crafting = game.crafting
	var at := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	var lost := {"items": hero.bag.size(), "coins": 0, "ingredients": 0}
	var bag := []
	bag.assign(hero.bag)
	var contents := {"bag": bag, "pouch": {}, "pieces": {}}
	hero.bag.clear()
	var coins := {}
	if game.coins > 0:
		coins[CoinPile.MONEY] = int(game.coins)
		game.coins = 0
	for table in [crafting.pouch, crafting.purse]:
		for id in (table as Dictionary).keys():
			var n := int(table[id])
			if n <= 0:
				continue
			if Loot.COINS.has(id):
				coins[id] = n
				crafting.take(id, n)
				continue
			contents.pouch[id] = n
			lost.ingredients += n
			if Crafting.has_pieces(id):
				contents.pieces[id] = crafting.take_pieces(id, n)
			else:
				crafting.take(id, n)
	# The coins spill beside the pack, every metal its own pile. They count
	# as the hero's own (the lucky clover does not double them again).
	var spill := at + Vector3(0.9, 0, 0.5)
	for metal in coins:
		level.lay_coins(spill, coins[metal], metal, coins[metal])
		lost.coins += int(coins[metal])
	if not is_empty([BUNDLE, "", 0, 0, contents]):
		level.lay_bundle(at, contents)
	hero.refresh_stats()
	return lost


## Puts back into the hero what fits from their pack (a floor entry, changed
## in place): the ingredients always, gear while the bag has room. True when
## anything came back.
static func take_back(game: Node, entry: Array) -> bool:
	if not is_bundle(entry):
		return false
	var hero: Player = game.player
	var crafting: Crafting = game.crafting
	var c: Dictionary = entry[4]
	var any := false
	var pieces: Dictionary = c.get("pieces", {})
	var pouch: Dictionary = c.get("pouch", {})
	for id in pouch.keys():
		var n := int(pouch[id])
		if n > 0 and Crafting.INGREDIENTS.has(str(id)):
			if Crafting.has_pieces(str(id)):
				crafting.give_pieces(str(id), n, pieces.get(id, []))
			else:
				crafting.set_count(str(id), crafting.have(str(id)) + n)
			any = true
		pouch.erase(id)
	c.pouch = pouch
	c.pieces = {}
	var left := []
	for id in c.get("bag", []):
		if Items.ALL.has(str(id)) and hero.bag_fits(str(id)):
			hero.bag.append(str(id))
			any = true
		elif Items.ALL.has(str(id)):
			left.append(str(id))
	c.bag = left
	hero.refresh_stats()
	return any
