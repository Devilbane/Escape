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
## the coins as piles (see CoinPile), the bag as a whole (with a worn
## backpack) and the ingredient pouch as a whole beside it, each a "bundle"
## on the floor list (see Level.lay_bundle). Other worn gear stays worn, and so do the knives in the
## belt. And the blow to the head costs all experience gathered towards the
## next hero level (see forget). Walking onto the pack gives it all
## back (as much as the bag holds). The dragon's helpers leave the pack alone,
## but at night they may carry the coin piles off to the hoard like any other
## coins lying about (see DragonHelpers).
##
## The eagle and the dwarves move per frame and are not interpolated; the
## hero they carry is moved in physics ticks (a tween), and they follow where
## the hero is drawn (SmoothMotion.drawn_at).

## Explained once in the compendium, the first time it happens.
const LORE := "Sinkt dein Leben auf null, wirst du bewusstlos, aber nicht tot. An der Oberfläche trägt dich ein Riesenadler fort, unter der Erde holt dich der Rettungstrupp der Zwerge. Du wachst in dem Bett auf, in dem du zuletzt geschlafen hast (oder an deinem Lager), mit vollem Leben. Aber der Schlag auf den Kopf kostet dich alle Erfahrung, die du seit deiner letzten Heldenstufe gesammelt hast; die Stufe selbst bleibt. Deine Rüstung und deine Waffen behältst du. Deine Tasche (mit dem Rucksack) und dein Zutatenbeutel fallen als Ganzes zu Boden, mit allem darin, und deine Münzen liegen als Haufen daneben. Geh hin und hol dir alles zurück. Aber beeil dich: Nachts tragen die Helfer des Drachen liegende Münzen in seinen Hort."

## The pack's floor entry kind (see Level.floor_items).
const BUNDLE := "bundle"
## Seconds the hero lies there before help comes.
const LIE_STILL := 1.6
## The eagle: how long it glides down (a long curve from far off, braking to
## hover), takes hold, and carries the hero away over the landscape: rising
## slowly with heavy wing beats, then soaring.
const SWOOP := 4.6
const GRIP := 1.5
const CLIMB := 11.0
## The carry's path: how far it goes, how high it ends, and how far it swings
## to one side in its S-curve (metres).
const CARRY_LENGTH := 70.0
const CARRY_HEIGHT := 12.0
const CARRY_SWING := 9.0
## Where the glide starts: this far off, this high.
const APPROACH_FAR := 34.0
const APPROACH_HIGH := 17.0
## The dwarves: how long they walk up, lift the hero onto the stretcher, and
## carry them off.
const WALK_UP := 1.9
const LIFT := 0.7
const CARRY := 2.4
## How long the screen takes to go dark while the hero is carried off.
const FADE := 2.0
## The stretcher's height above the floor.
const STRETCHER_HIGH := 0.75

const DARK_BROWN := Color(0.22, 0.14, 0.08)

var hero: Player
var by_eagle := true
## The whole rescue up to the dark, in seconds (see duration).
var _time := 0.0
var _from := Vector3.ZERO
var _away := Vector3.FORWARD
var _eagle: Eagle
var _shadow: MeshInstance3D
## Which way the carry's S-curve swings first (1 or -1), and the eagle's
## heading, pitch and bank, eased so it turns and banks like a bird.
var _swing := 1.0
var _yaw := 0.0
var _pitch := 0.0
var _roll := 0.0
var _turning := 0.0
var _heard_cry := 0
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
	_swing = 1.0 if randf() < 0.5 else -1.0
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
		_fly_eagle(delta)
	else:
		_walk_dwarves(delta)


# --- The eagle ------------------------------------------------------------------

## Where the carried hero is, k (0 to 1) of the way along the carry: a long
## S-curve over the landscape. They start slowly, and the speed builds as the
## eagle gets into its stride; the height comes up slowly at first (heavy
## wing beats, a hero hanging from its claws) and then eases off.
func _carry_at(k: float) -> Vector3:
	var along := pow(k, 1.45)
	var side := _away.cross(Vector3.UP).normalized() * _swing
	var p0 := _from
	var p3 := _from + _away * CARRY_LENGTH
	var c1 := _from + _away * CARRY_LENGTH * 0.3 + side * CARRY_SWING
	var c2 := _from + _away * CARRY_LENGTH * 0.7 - side * CARRY_SWING * 0.8
	var u := 1.0 - along
	var flat := p0 * (u * u * u) + c1 * (3.0 * u * u * along) + c2 * (3.0 * u * along * along) + p3 * (along * along * along)
	var rise := 1.0 - pow(1.0 - k, 1.7)
	return Vector3(flat.x, _from.y + CARRY_HEIGHT * rise, flat.z)


func _fly_eagle(delta: float) -> void:
	var t := _time - LIE_STILL
	if t < 0.0:
		_eagle.visible = false
		_shadow.visible = false
		return
	_eagle.visible = true
	_shadow.visible = true
	var hold := Vector3(0, 1.3 + Eagle.HANG * Eagle.SIZE, 0)
	var at: Vector3
	var heading := Vector3.ZERO
	# How the wings beat (amp 0 soars), the beats a second, braking, tucked
	# legs, closed toes and the head turned down.
	var amp := 0.0
	var freq := 0.7
	var flare := 0.0
	var tuck := 0.0
	var grip := 0.0
	var look := 0.0
	var climb := 0.0
	var old := _eagle.global_position
	if t < SWOOP:
		# A long glide down from high up and far off, curving in an S: wings
		# spread and still, a few strong beats to brake, then a hard flutter
		# as it flares to hover over the hero.
		var k := t / SWOOP
		var u := 1.0 - pow(1.0 - k, 1.7)
		var high := _from + _away * APPROACH_FAR + Vector3(0, APPROACH_HIGH, 0)
		var low := _from + hold
		var side := _away.cross(Vector3.UP).normalized() * _swing
		var c1 := high.lerp(low, 0.33) + side * 12.0
		var c2 := high.lerp(low, 0.7) - side * 6.0
		var w := 1.0 - u
		at = high * (w * w * w) + c1 * (3.0 * w * w * u) + c2 * (3.0 * w * u * u) + low * (u * u * u)
		# It sinks faster than the curve alone: a bird dips into its landing.
		at.y = lerpf(low.y, high.y, pow(1.0 - u, 1.25))
		var brake := smoothstep(0.45, 0.9, k)
		amp = lerpf(0.04, 1.0, brake)
		freq = lerpf(0.75, 2.5, brake)
		flare = smoothstep(0.62, 1.0, k)
		tuck = 1.0 - smoothstep(0.5, 0.9, k)
		look = smoothstep(0.55, 1.0, k)
		climb = -0.2 * (1.0 - flare)
		heading = old.direction_to(at) if at.distance_to(old) > 0.001 else Vector3.ZERO
		if k > 0.9:
			# Turning on the spot, to face where it will fly off.
			heading = _away
	else:
		at = SmoothMotion.drawn_at(hero) + hold
		look = 0.8
		heading = _away
		if t < SWOOP + GRIP:
			# Hovering over the hero, beating hard, the toes closing on them.
			var g := (t - SWOOP) / GRIP
			amp = 1.0
			freq = 2.4
			flare = lerpf(0.6, 0.15, g)
			grip = smoothstep(0.35, 0.8, g)
			climb = 0.3
		else:
			# Off with the hero: rising slowly on heavy beats, later a few
			# beats and then a long soar, again and again.
			var c := (t - SWOOP - GRIP) / CLIMB
			var bursts := smoothstep(0.35, 0.7, 0.5 + 0.5 * sin(c * 14.0 - 1.0))
			var work := 1.0 - smoothstep(0.25, 0.6, c)
			amp = clampf(work + (1.0 - work) * bursts * 0.85 + 0.06, 0.06, 1.0)
			freq = lerpf(0.85, 1.9, amp)
			grip = 1.0
			flare = 0.0
			var v := at - old
			heading = Vector3(v.x, 0.0, v.z) if Vector2(v.x, v.z).length() > 0.002 else _away
			climb = clampf(atan2(v.y, maxf(Vector2(v.x, v.z).length(), 0.001)), -0.3, 0.45) * 0.8
	_steer(delta, heading, climb, flare)
	_eagle.pose(amp, flare, tuck, grip, look)
	var heard := _eagle.beat(delta, freq)
	_eagle.global_transform = Transform3D(Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch) \
			* Basis(Vector3.BACK, _roll) * Basis.from_scale(Vector3.ONE * Eagle.SIZE), at)
	_lay_shadow(at)
	# A heavy wingbeat on each downstroke, and a cry as it comes down and
	# another with its catch over the landscape.
	if heard and amp > 0.3:
		Sfx.play(self, "dragon_wingbeat_%d" % (int(_eagle.phase) % 3), -10.0 + 4.0 * amp - 4.0, at, 1.7)
	if t >= SWOOP * 0.4 and _heard_cry == 0:
		_heard_cry = 1
		Sfx.play(self, "dragon_shriek", -12.0, at, 2.3)
	elif t >= SWOOP + GRIP + CLIMB * 0.45 and _heard_cry == 1:
		_heard_cry = 2
		Sfx.play(self, "dragon_shriek", -14.0, at, 2.1)


## Eases the eagle's heading, pitch and bank: it turns smoothly towards where
## it goes and banks into the turn, nose up when braking.
func _steer(delta: float, heading: Vector3, climb: float, flare: float) -> void:
	heading.y = 0.0
	if heading.length() > 0.001:
		var want := atan2(-heading.x, -heading.z)
		var old := _yaw
		_yaw = lerp_angle(_yaw, want, 1.0 - exp(-2.2 * delta))
		var rate := angle_difference(old, _yaw) / maxf(delta, 0.001)
		_turning = lerpf(_turning, rate, 1.0 - exp(-3.0 * delta))
	else:
		_turning = lerpf(_turning, 0.0, 1.0 - exp(-3.0 * delta))
	_roll = lerpf(_roll, clampf(_turning * 0.9, -0.55, 0.55), 1.0 - exp(-3.0 * delta))
	_pitch = lerpf(_pitch, climb + 0.45 * flare, 1.0 - exp(-3.0 * delta))


## A soft round shadow on the ground under the eagle, so its flight over the
## land can be read: bigger and fainter the higher it is.
func _lay_shadow(at: Vector3) -> void:
	var height := maxf(at.y - _from.y, 0.0)
	_shadow.global_position = Vector3(at.x, _from.y + 0.06, at.z)
	_shadow.rotation = Vector3(-PI * 0.5, _yaw, 0.0)
	var size := Eagle.SIZE * 5.4 * (1.0 + height * 0.03)
	_shadow.scale = Vector3(size, size * 0.6, 1.0)
	(_shadow.material_override as StandardMaterial3D).albedo_color.a = clampf(0.62 - height * 0.025, 0.12, 0.62)


## Turns a walker (built facing -Z) towards where it goes, upright.
static func _face(node: Node3D, from: Vector3, to: Vector3) -> void:
	var dir := to - from
	dir.y = 0.0
	if dir.length() > 0.01:
		node.rotation.y = atan2(-dir.x, -dir.z)


func _build_eagle() -> void:
	_eagle = Eagle.new()
	add_child(_eagle)
	_eagle.visible = false
	_eagle.global_position = _from + _away * APPROACH_FAR + Vector3(0, APPROACH_HIGH, 0)
	_yaw = atan2(_away.x, _away.z)
	_shadow = MeshInstance3D.new()
	_shadow.name = "EagleShadow"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_shadow.mesh = quad
	var fade := GradientTexture2D.new()
	fade.fill = GradientTexture2D.FILL_RADIAL
	fade.fill_from = Vector2(0.5, 0.5)
	fade.fill_to = Vector2(1.0, 0.5)
	fade.gradient = Gradient.new()
	fade.gradient.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0)])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = fade
	mat.albedo_color = Color(0, 0, 0, 0.6)
	_shadow.material_override = mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.visible = false
	add_child(_shadow)


# --- The dwarves ---------------------------------------------------------------

func _walk_dwarves(delta: float) -> void:
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
		var moved := Vector2(at.x - d.global_position.x, at.z - d.global_position.z).length() / maxf(delta, 0.001)
		d.global_position = at
		var anim: AnimationPlayer = d.get_meta("anim")
		var walking := t < WALK_UP or _carrying
		if anim and walking:
			# Walk, jog or run with the pace, the feet planted (see Stride).
			var gait := Stride.gait("kaykit", Stride.GAITS.kaykit, 1.0, moved, anim.current_animation)
			if anim.current_animation != gait:
				anim.play(gait, 0.2)
			anim.speed_scale = Stride.playback("kaykit", gait, 1.0, moved)
		elif anim and not walking and anim.current_animation != "Idle":
			anim.play("Idle", 0.2)
			anim.speed_scale = 1.0
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
		var anim: AnimationPlayer = body.find_child("AnimationPlayer", true, false)
		for gait: String in Stride.GAITS.kaykit:
			anim.get_animation(gait).loop_mode = Animation.LOOP_LINEAR
		holder.set_meta("anim", anim)
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

## The blow to the head: the hero forgets all they learnt towards their next
## hero level (the level itself stays). Returns the experience lost.
static func forget(hero: Player) -> int:
	var start := HeroLevel.total_for(hero.hero_level())
	var lost := maxi(0, hero.hero_xp - start)
	hero.hero_xp = start
	return lost


## Whether a pack on the floor is the ingredient pouch (nothing but
## ingredients in it), not the bag.
static func is_pouch(entry) -> bool:
	if not is_bundle(entry):
		return false
	var c: Dictionary = entry[4]
	return str(c.get("backpack", "")) == "" and (c.get("bag", []) as Array).is_empty()


## Whether a floor entry is the hero's pack.
static func is_bundle(entry) -> bool:
	return entry is Array and entry.size() >= 5 and str(entry[0]) == BUNDLE and entry[4] is Dictionary


## Whether nothing is left in the pack.
static func is_empty(entry) -> bool:
	if not is_bundle(entry):
		return true
	var c: Dictionary = entry[4]
	return str(c.get("backpack", "")) == "" and (c.get("bag", []) as Array).is_empty() and (c.get("pouch", {}) as Dictionary).is_empty()


## The pack on the floor: a tied-up leather sack with a strap, glowing a
## little so it can be found in the dark.
## `pouch`: the ingredient pouch, smaller, green-brown and tied with a cord,
## instead of the bag.
static func bundle_model(pouch := false) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Pouch" if pouch else "Bundle"
	var size := 0.6 if pouch else 1.0
	var leather := Color(0.36, 0.38, 0.2) if pouch else Color(0.45, 0.3, 0.17)
	var sack := _part(holder, _sphere(0.42 * size), leather, Vector3(0, 0.36 * size, 0))
	sack.scale = Vector3(1.0, 0.85, 0.8)
	_part(holder, _cone(0.22 * size, 0.3 * size), leather.darkened(0.12), Vector3(0, 0.82 * size, 0))
	var strap := _part(holder, _box(Vector3(0.9 * size, 0.05, 0.08)), Color(0.75, 0.62, 0.35) if pouch else DARK_BROWN, Vector3(0, 0.62 * size, 0))
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
## lie on `game`'s level: the coins of the purse as piles, the bag (with a
## worn backpack) and the ingredient pouch each as a whole. Other worn gear
## and the knives in the belt stay.
## Returns what went down: {"items", "coins", "ingredients"}.
static func drop_belongings(game: Node) -> Dictionary:
	var level: Level = game.level
	var hero: Player = game.player
	var crafting: Crafting = game.crafting
	var at := Vector3(hero.global_position.x, 0.0, hero.global_position.z)
	var lost := {"items": hero.bag.size(), "coins": 0, "ingredients": 0}
	var bag := []
	bag.assign(hero.bag)
	var contents := {"bag": bag, "pouch": {}, "pieces": {}, "backpack": ""}
	hero.bag.clear()
	# The bag goes down as a whole: a worn backpack with it.
	var backpack := str(hero.equipped.get("rucksack", ""))
	if backpack != "":
		contents.backpack = backpack
		hero.equipped.erase("rucksack")
		lost.items += 1
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
	# The bag and the ingredient pouch go down side by side, each whole.
	var pouch := {"bag": [], "pouch": contents.pouch, "pieces": contents.pieces, "backpack": ""}
	contents.pouch = {}
	contents.pieces = {}
	if not is_empty([BUNDLE, "", 0, 0, contents]):
		level.lay_bundle(at, contents)
	if not is_empty([BUNDLE, "", 0, 0, pouch]):
		level.lay_bundle(at + Vector3(-0.9, 0, 0.4), pouch)
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
	# The backpack first, so the bag has its room again.
	var backpack := str(c.get("backpack", ""))
	if backpack != "" and Items.ALL.has(backpack):
		if not hero.equipped.has("rucksack"):
			hero.equipped["rucksack"] = backpack
			c.backpack = ""
			any = true
		elif hero.bag_fits(backpack):
			hero.bag.append(backpack)
			c.backpack = ""
			any = true
	elif backpack != "":
		c.backpack = ""
	hero.refresh_stats()
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
