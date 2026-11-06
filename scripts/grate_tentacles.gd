class_name GrateTentacles
extends Node3D
## Something lives in the dark water under the floor grates (Level.grates).
## Now and then, while the hero stands on or next to a grate, a tentacle
## rises through the bars and lashes out at them.
##
## Kept simple and readable, like a trap you can see coming:
##   1. A roll: while the hero is near a grate, one roll every ROLL_EVERY
##      seconds (the first as soon as they come near), each with CHANCE.
##      So most passes go by quietly.
##   2. The tell (TELL_TIME): the water gurgles, bubbles rise through the
##      bars, "Blubb..." floats up and the tip of the tentacle shows below
##      them. Get two tiles away now and the blow misses.
##   3. The strike: the tentacle shoots up, stretching as far as it must to
##      reach the hero, and lashes down. If the hero is still within
##      HIT_REACH (two tiles), it hits for damage() and knocks them back,
##      away from the grate; one blow in POISON_CHANCE also poisons them
##      (Player.afflict("gift")). Like a blow, it can be blocked or dodged.
##   4. The retreat: it sways a moment, then sinks back into the pit, and
##      that grate rests for REST seconds.
##
## Only one tentacle stirs on a level at a time. None live under the grates
## of the first cell, of safe places, homes or the open air (see make).

## Level files without tentacles (the cell the hero wakes in: let them learn
## to walk first).
const CALM_FILES := ["01_die_zelle.txt"]
## How close (metres, flat) the hero must be to a grate's middle for a roll.
## A grate tile is Level.TILE (4 m) across.
const NEAR := 2.4
## A tentacle strikes on one roll in four, rolled every two seconds near a grate.
const CHANCE := 0.25
const ROLL_EVERY := 2.0
## The warning before the blow (seconds), and how close the hero must still
## be when it lands to be hit: two tiles from the grate's middle.
const TELL_TIME := 1.2
const HIT_REACH := 2.0 * Level.TILE
## How often a blow that lands also poisons the hero.
const POISON_CHANCE := 0.3
## Seconds a grate stays quiet after its tentacle sank back.
const REST := 12.0
## Damage: 1 + place level / DAMAGE_LEVELS, like a spike trap.
const DAMAGE_LEVELS := 4
## The parts of the strike (seconds).
const RISE_TIME := 0.3
const LASH_TIME := 0.18
const HOLD_TIME := 0.7
const SINK_TIME := 0.9
## The tentacle: SEGMENTS pieces, LENGTH metres in all, thick at the root.
## To strike a hero further away it stretches, up to MAX_STRETCH times.
const SEGMENTS := 10
const LENGTH := 3.0
const ROOT_RADIUS := 0.3
const TIP_RADIUS := 0.05
## How far the tip lands from the root, for each metre of tentacle, once it
## has lashed down (the curl of the lash, see _pose).
const LASH_REACH := 0.72
const MAX_STRETCH := HIT_REACH / (LASH_REACH * LENGTH)
## The bend of each piece at the end of the lash.
const LASH_BEND := 0.22
## Where the tentacle grows from: the floor of the pit (GratePits.PIT_BOTTOM).
## Whatever of it is not out yet hides below that floor.
const ROOT_Y := -1.0
## How far it is out during the tell: the tip just shows under the bars.
const PEEK := 0.25
const SKIN := Color(0.5, 0.3, 0.44)
const SUCKER := Color(0.78, 0.58, 0.56)
const BUBBLE := Color(0.7, 0.9, 0.6, 0.85)
## The sickly glow that wells up in the pit during the warning.
const GLOW := Color(0.45, 0.85, 0.35)
## The colour of the warning word over the grate.
const TELL_COLOR := Color(0.62, 0.86, 0.55)
## What the compendium says about them.
const LEARN := "Tentakel unter den Gittern: Unter manchen Bodengittern lauert etwas im dunklen Wasser. Gurgelt es und steigen Blasen auf, bring schnell zwei Felder Abstand zwischen dich und das Gitter, sonst schlägt ein Tentakel zu. Sein Schlag kann dich vergiften."

signal struck(hit: bool)

var level: Level
## Each grate: {"cell", "state" ("idle", "tell", "rise", "lash", "hold",
## "sink"), "time" (in this state), "rest", "roll" (seconds to the next
## roll), "near", "node", "joints", "parts" (each joint's [body, sucker]),
## "bubbles", "glow", "out" (0..1), "bend", "stretch", "aim" (the stretch
## it grows to while it rises)}.
var grates: Array = []
## The place's level, for the damage (HeroLevel.place_level).
var place_level := 1
## Overridden by the tests to make the roll certain or impossible.
var chance := CHANCE
var poison_chance := POISON_CHANCE
## How many rolls were made (for the tests).
var rolls := 0
var _time := 0.0

static var _materials := {}


## The tentacles for a level, or null when none live there.
static func make(owner_level: Level) -> GrateTentacles:
	if owner_level.grates.is_empty() or owner_level.outdoor or owner_level.is_home or owner_level.safe:
		return null
	if owner_level.file in CALM_FILES:
		return null
	var g := GrateTentacles.new()
	g.level = owner_level
	g.name = "GrateTentacles"
	g.place_level = HeroLevel.place_level(owner_level)
	for c: Vector2i in owner_level.grates:
		g.grates.append({"cell": c, "state": "idle", "time": 0.0, "rest": 0.0, "roll": 0.0,
				"near": false, "out": 0.0, "bend": 0.0, "stretch": 1.0, "aim": 1.0})
	return g


func _ready() -> void:
	for g in grates:
		_build(g)


## What a tentacle's blow deals here.
func damage() -> int:
	return maxi(1, 1 + place_level / DAMAGE_LEVELS)


## The grate on a tile, or an empty dictionary.
func grate_at(c: Vector2i) -> Dictionary:
	for g in grates:
		if g.cell == c:
			return g
	return {}


## Whether a tentacle is stirring anywhere on the level right now.
func busy() -> bool:
	return grates.any(func(g): return g.state != "idle")


func _process(delta: float) -> void:
	_time += delta
	var hero: Player = level.player
	var calm := hero == null or level.finished or hero.dead or hero.frozen
	var stirring := busy()
	for g in grates:
		g.rest = maxf(0.0, g.rest - delta)
		if g.state != "idle":
			_advance(g, delta, hero)
			continue
		var near := not calm and _flat(hero.global_position, g) <= NEAR
		if not near:
			g.near = false
			continue
		if not g.near:
			# Just came near: the first roll right away.
			g.near = true
			g.roll = 0.0
		g.roll -= delta
		if g.roll > 0.0:
			continue
		g.roll = ROLL_EVERY
		if stirring or g.rest > 0.0:
			continue
		rolls += 1
		if randf() < chance:
			start(g)
			stirring = true


## A tentacle starts to stir under grate `g`: the warning comes first.
func start(g: Dictionary) -> void:
	var spot := level.cell_to_world(g.cell)
	g.state = "tell"
	g.time = 0.0
	g.node.visible = true
	g.node.rotation.y = randf() * TAU
	g.bubbles.emitting = true
	Sfx.play(level, "tentacle_gurgle", -3.0, spot)
	Effects.float_text(level, spot + Vector3(0, 1.2, 0), Lang.t("Blubb..."), TELL_COLOR)
	Events.teach(LEARN)


func _advance(g: Dictionary, delta: float, hero: Player) -> void:
	g.time += delta
	var spot := level.cell_to_world(g.cell)
	# The tentacle turns to face the hero while it can still see them.
	if hero and g.state in ["tell", "rise"]:
		var to := hero.global_position - spot
		if Vector2(to.x, to.z).length() > 0.1:
			g.node.rotation.y = lerp_angle(g.node.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 6.0))
	match g.state:
		"tell":
			g.out = PEEK * smoothstep(0.0, 0.6, g.time) + sin(_time * 9.0) * 0.02
			g.bend = 0.05
			_glow(g, smoothstep(0.0, 0.4, g.time) * (0.75 + 0.25 * sin(_time * 14.0)))
			if g.time >= TELL_TIME:
				_next(g, "rise")
				# Long enough to reach the hero where they stand now.
				var d := _flat(hero.global_position, g) if hero else 0.0
				g.aim = clampf(d / (LASH_REACH * LENGTH), 1.0, MAX_STRETCH)
				g.bubbles.emitting = false
				Sfx.play(level, "word_wusch", -2.0, spot)
		"rise":
			var k := clampf(g.time / RISE_TIME, 0.0, 1.0)
			g.out = lerpf(PEEK, 1.0, k * (2.0 - k))
			g.bend = lerpf(0.05, -0.06, k)
			g.stretch = lerpf(1.0, g.aim, k)
			_glow(g, 1.0 - k)
			if g.time >= RISE_TIME:
				_next(g, "lash")
		"lash":
			var k := clampf(g.time / LASH_TIME, 0.0, 1.0)
			g.bend = lerpf(-0.06, LASH_BEND, k * k)
			if g.time >= LASH_TIME:
				_next(g, "hold")
				_strike(g, hero)
		"hold":
			g.bend = LASH_BEND - 0.1 * smoothstep(0.0, HOLD_TIME, g.time)
			if g.time >= HOLD_TIME:
				_next(g, "sink")
		"sink":
			var k := clampf(g.time / SINK_TIME, 0.0, 1.0)
			g.out = 1.0 - k * k
			g.bend = lerpf(LASH_BEND - 0.1, 0.0, k)
			if g.time >= SINK_TIME:
				_next(g, "idle")
				g.out = 0.0
				g.stretch = 1.0
				g.rest = REST
				g.roll = ROLL_EVERY
				g.node.visible = false
				_glow(g, 0.0)
	_pose(g)


## How strongly the glow in the pit shows (0..1).
func _glow(g: Dictionary, strength: float) -> void:
	var m: StandardMaterial3D = g.glow.material_override
	m.albedo_color.a = 0.85 * strength


func _next(g: Dictionary, state: String) -> void:
	g.state = state
	g.time = 0.0


## The blow lands: whoever still stands close to the grate is hit.
func _strike(g: Dictionary, hero: Player) -> void:
	var spot := level.cell_to_world(g.cell)
	var hit: bool = hero != null and not hero.dead and _flat(hero.global_position, g) <= HIT_REACH
	if hit:
		var before := hero.hp
		hero.take_damage(damage(), spot, null, true)
		# Only a blow that got through (not blocked or dodged) can poison.
		if hero.hp < before and not hero.dead and randf() < poison_chance:
			hero.afflict("gift")
	else:
		# It slaps the empty floor.
		Sfx.play(level, "word_wamm", -6.0, spot)
	struck.emit(hit)


func _flat(p: Vector3, g: Dictionary) -> float:
	var spot := level.cell_to_world(g.cell)
	return Vector2(p.x - spot.x, p.z - spot.z).length()


## Sets the tentacle's shape: how far it is out (g.out) and how much each
## piece bends towards the hero (g.bend), with a slow, living sway on top.
func _pose(g: Dictionary) -> void:
	var root: Node3D = g.joints[0]
	var stretch: float = g.stretch
	root.position.y = ROOT_Y - LENGTH * stretch * (1.0 - g.out)
	var piece := LENGTH / SEGMENTS * stretch
	# A stretched tentacle thickens a little, so it does not turn to string.
	var wide := 1.0 + (stretch - 1.0) * 0.15
	for i in g.joints.size():
		var j: Node3D = g.joints[i]
		if i > 0:
			j.position.y = piece
		var body: Node3D = g.parts[i][0]
		body.scale = Vector3(wide, stretch, wide)
		body.position.y = piece * 0.5
		if g.parts[i][1]:
			g.parts[i][1].position.y = piece * 0.5
		var share := float(i) / SEGMENTS
		var sway := sin(_time * 3.1 + i * 0.7) * 0.07 * (0.4 + share)
		# The tip curls more than the root.
		j.rotation.x = g.bend * (0.4 + share * 1.6) + sway
		j.rotation.z = cos(_time * 2.3 + i * 0.5) * 0.05 * share


# --- Looks ------------------------------------------------------------------

func _build(g: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Tentacle_%d_%d" % [g.cell.x, g.cell.y]
	node.position = level.cell_to_world(g.cell)
	node.visible = false
	add_child(node)
	g.node = node
	var skin := _material(SKIN, 0.35)
	var sucker := _material(SUCKER, 0.5)
	var piece := LENGTH / SEGMENTS
	var joints: Array = []
	var parts: Array = []
	var parent: Node3D = node
	for i in SEGMENTS:
		var r0 := lerpf(ROOT_RADIUS, TIP_RADIUS, float(i) / SEGMENTS)
		var r1 := lerpf(ROOT_RADIUS, TIP_RADIUS, float(i + 1) / SEGMENTS)
		var j := Node3D.new()
		j.position.y = ROOT_Y if i == 0 else piece
		parent.add_child(j)
		joints.append(j)
		var body := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = r0
		cyl.top_radius = r1
		cyl.height = piece
		cyl.radial_segments = 8
		cyl.rings = 1
		body.mesh = cyl
		body.material_override = skin
		body.position.y = piece * 0.5
		j.add_child(body)
		# A ball at each joint keeps the bends closed.
		var knot := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = r0
		ball.height = r0 * 2.0
		ball.radial_segments = 8
		ball.rings = 4
		knot.mesh = ball
		knot.material_override = skin
		j.add_child(knot)
		# Suckers on the inside of the curl (towards the hero).
		parts.append([body, null])
		if i > 0:
			var s := MeshInstance3D.new()
			var cup := SphereMesh.new()
			cup.radius = r0 * 0.45
			cup.height = r0 * 0.35
			cup.radial_segments = 8
			cup.rings = 3
			s.mesh = cup
			s.material_override = sucker
			s.position = Vector3(0, piece * 0.5, r0 * 0.92)
			s.rotation.x = PI * 0.5
			j.add_child(s)
			parts[i][1] = s
		parent = j
	g.joints = joints
	g.parts = parts
	# Bubbles rising from the water through the bars.
	var bubbles := CPUParticles3D.new()
	bubbles.emitting = false
	bubbles.amount = 40
	bubbles.lifetime = 1.0
	bubbles.mesh = Effects._quad(0.22, Color(1, 1, 1))
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(1.0, 0.05, 1.0)
	bubbles.position.y = GratePits.BED_Y + 0.1
	bubbles.direction = Vector3.UP
	bubbles.spread = 15.0
	bubbles.gravity = Vector3(0, 1.5, 0)
	bubbles.initial_velocity_min = 0.6
	bubbles.initial_velocity_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(BUBBLE, 0.0))
	ramp.add_point(0.25, BUBBLE)
	ramp.set_color(ramp.get_point_count() - 1, Color(BUBBLE, 0.0))
	bubbles.color_ramp = ramp
	Effects.start_cold(bubbles)
	node.add_child(bubbles)
	g.bubbles = bubbles
	var glow := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(3.2, 3.2)
	glow.mesh = quad
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_texture = Effects._soft_dot()
	gm.albedo_color = Color(GLOW, 0.0)
	glow.material_override = gm
	glow.position.y = GratePits.BED_Y + 0.12
	node.add_child(glow)
	g.glow = glow
	_pose(g)


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var k := "%s:%s" % [color, roughness]
	if not _materials.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = roughness
		m.metallic_specular = 0.7
		_materials[k] = m
	return _materials[k]
