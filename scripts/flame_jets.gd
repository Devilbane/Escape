class_name FlameJets
extends Node3D
## Flame jets: iron nozzles set in the walls of the deeper dungeons and the
## dragon's lair. Each one breathes a straight line of fire across the
## corridor or room in front of it, to the wall opposite.
##
## Unlike the hidden traps (see Traps) a flame jet is never hidden: the nozzle
## shows in the wall and a lane of soot on the floor shows where its fire
## reaches. It works on a steady beat, so the way past is to watch it:
##   rest  (REST seconds): cold and quiet, safe to cross.
##   warn  (WARN seconds): the nozzle glows, the sooty lane glows red, and the
##         mechanism clicks. Get out of the lane now.
##   blast (BLAST seconds): fire roars across the lane. It hurts the hero once
##         per blast (about as much as a spike trap) and sets them burning.
## Fire fills the lane at chest height, so jumping does not help; a deft hero
## may still twist aside (Player.spring_trap). Monsters do not trip them.
## Each jet keeps its own beat (an offset into the cycle), so two jets in one
## hall do not breathe together.
##
## Where the jets sit is chosen by a random generator seeded with the level's
## name, so a level has its jets in the same places on every visit.

## The level files that have flame jets, and how many.
const PLACES := {
	"06_die_katakomben.txt": 2,
	"09_die_klingenhalle.txt": 2,
	"10_das_tor.txt": 2,
	"13_die_drachenhoehle.txt": 2,
	"24_die_versengten_hallen.txt": 3,
	"28_die_schwefelgaenge.txt": 3,
}
## The German name, for the words over the hero (see Lang).
const NAME := "Flammenfalle"
## What the compendium says about flame jets.
const LEARN := "Flammenfallen: In manchen tiefen Gängen sitzen Eisendüsen in der Wand. In festem Takt speien sie eine gerade Feuerzunge quer durch den Gang bis zur Wand gegenüber; ein Streifen Ruß am Boden zeigt, wie weit sie reicht. Bevor sie feuern, glühen Düse und Streifen rot auf und es klickt. Springen hilft nicht: Warte, bis das Feuer erlischt, und geh dann zügig hindurch."

## The beat (seconds): quiet, then the warning, then the fire.
const REST := 3.0
const WARN := 1.0
const BLAST := 1.5
const CYCLE := REST + WARN + BLAST
## How fast the fire runs out to the far wall at the start of a blast
## (seconds); it only hurts as far as it has reached.
const REACH_TIME := 0.15
## How long a lane may be (tiles) and how short.
const MIN_TILES := 2
const MAX_TILES := 5
## How far either side of the lane's middle the fire catches the hero
## (metres; a tile is Level.TILE wide).
const HALF_WIDTH := 1.2
## Above this height (metres) the fire no longer reaches: higher than any jump.
const TOP := 2.6
## The nozzle's height on the wall (metres).
const NOZZLE_Y := 1.1
## Jets keep this many tiles away from the start and the exit, and their
## nozzles this many from each other.
const KEEP_AWAY := 3
## How close (metres) the hero must be to hear a jet, and to learn of jets
## for the compendium on first sight.
const HEAR_RANGE := 26.0
const SEE_RANGE := 12.0
## Spikes and fire hurt alike: 1 + place level / Traps.SPIKE_LEVELS.
const FIRE_COLOR := Color(1.0, 0.5, 0.12)
const WARN_COLOR := Color(1.0, 0.2, 0.05)
const SOOT_COLOR := Color(0.06, 0.05, 0.045)
const IRON_COLOR := Color(0.22, 0.2, 0.19)
const NOTE_COLOR := Color(1.0, 0.75, 0.5)

var level: Level
## Each jet: {"wall" (the nozzle's wall tile), "dir" (the way it fires, one
## of Level.DIRS), "cells" (the lane's floor tiles), "clock" (seconds into
## the cycle), "hit" (whether this blast caught the hero), "node", "glow"
## (the nozzle mouth's material), "lane" (the soot strip's material),
## "flames", "light"}.
var jets: Array = []
## The level of the place, for the damage (HeroLevel.place_level).
var place_level := 1
## Whether the compendium already heard of flame jets on this visit.
var _taught := false


## The flame jets for a level, or null when it has none. Called by Level.build
## once the grid, the path finding and the traps are set up.
static func make(owner_level: Level) -> FlameJets:
	var count: int = PLACES.get(owner_level.file.get_file(), 0)
	if count <= 0 or owner_level.outdoor or owner_level.is_home or owner_level.playtest:
		return null
	var f := FlameJets.new()
	f.level = owner_level
	f.name = "FlameJets"
	f.place_level = HeroLevel.place_level(owner_level)
	f._place(count)
	if f.jets.is_empty():
		f.free()
		return null
	return f


func _place(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level.level_name + ":flame_jets")
	var spots: Array = []
	for y in level.height:
		for x in level.width:
			for d in Level.DIRS:
				var lane := lane_from(Vector2i(x, y), d)
				if not lane.is_empty():
					spots.append({"wall": Vector2i(x, y), "dir": d, "cells": lane})
	while jets.size() < count and not spots.is_empty():
		var s: Dictionary = spots.pop_at(rng.randi() % spots.size())
		if jets.any(func(j): return Traps._apart(j.wall, s.wall) < KEEP_AWAY or _crosses(j.cells, s.cells)):
			continue
		s.clock = rng.randf() * CYCLE
		s.hit = false
		jets.append(s)


static func _crosses(a: Array, b: Array) -> bool:
	return a.any(func(c): return c in b)


## The lane a nozzle in wall tile `wall` firing towards `d` would fill: the
## floor tiles from the wall to the wall opposite, or [] when no jet fits
## there. The nozzle sits in a plain wall the camera sees (never a low wall,
## and never firing north out of one), and the lane is open floor all the way
## across, MIN_TILES to MAX_TILES long, clear of the start, the exit and the
## traps.
func lane_from(wall: Vector2i, d: Vector2i) -> Array:
	if d == Vector2i(0, -1) or level.cell_char(wall) != "#" or level._is_low_wall(wall):
		return []
	var cells: Array = []
	var c := wall + d
	while cells.size() < MAX_TILES and _open(c):
		cells.append(c)
		c += d
	# The fire must end at a wall: a lane straight across, not into a room.
	if cells.size() < MIN_TILES or level.cell_char(c) != "#":
		return []
	for cell in cells:
		if Traps._apart(cell, level.start_cell) < KEEP_AWAY + 1:
			return []
		if level.exit_cell.x >= 0 and Traps._apart(cell, level.exit_cell) < KEEP_AWAY:
			return []
		if level.traps and not level.traps.trap_at(cell).is_empty():
			return []
	return cells


func _open(c: Vector2i) -> bool:
	if not level.astar.is_in_boundsv(c) or level.astar.is_point_solid(c):
		return false
	return Traps.AROUND_OK.contains(level.cell_char(c))


func _ready() -> void:
	for j in jets:
		_build(j)
		_show_phase(j)


## What the fire deals here.
func damage() -> int:
	return maxi(1, 1 + place_level / Traps.SPIKE_LEVELS)


## The phase of a jet now: "rest", "warn" or "blast".
static func phase_of(j: Dictionary) -> String:
	if j.clock < REST:
		return "rest"
	if j.clock < REST + WARN:
		return "warn"
	return "blast"


## Where the nozzle's mouth is, on the wall face, at floor level.
func mouth(j: Dictionary) -> Vector3:
	var d := Vector3(j.dir.x, 0, j.dir.y)
	return level.cell_to_world(j.wall) + d * Level.TILE * 0.5


## How far (metres) the fire of a jet reaches from the wall when it is at
## full length.
static func length_of(j: Dictionary) -> float:
	return j.cells.size() * Level.TILE


## Whether a spot is in the fire of jet `j` right now.
func burns(j: Dictionary, pos: Vector3) -> bool:
	if phase_of(j) != "blast" or pos.y > TOP:
		return false
	var reached := length_of(j) * clampf((j.clock - REST - WARN) / REACH_TIME, 0.0, 1.0)
	var rel := pos - mouth(j)
	var along: float = rel.x * j.dir.x + rel.z * j.dir.y
	var across: float = absf(rel.x * j.dir.y - rel.z * j.dir.x)
	return along >= -0.3 and along <= reached and across <= HALF_WIDTH


func _process(delta: float) -> void:
	var hero: Player = level.player
	for j in jets:
		var was: String = phase_of(j)
		j.clock = fmod(j.clock + delta, CYCLE)
		var now: String = phase_of(j)
		if now != was:
			_enter_phase(j, now, hero)
		_show_phase(j)
	if hero == null or level.finished or hero.dead or hero.frozen:
		return
	for j in jets:
		if not _taught and hero.global_position.distance_to(mouth(j)) < SEE_RANGE \
				and level.has_line_of_sight(hero.global_position, mouth(j) + Vector3(j.dir.x, 0, j.dir.y)):
			_taught = true
			Events.teach(LEARN)
		if not j.hit and burns(j, hero.global_position):
			scorch(j)


## A jet moves on to the next phase: the click before the fire, the roar of it.
func _enter_phase(j: Dictionary, now: String, hero: Player) -> void:
	if now == "blast":
		j.hit = false
		j.flames.emitting = true
	elif now == "rest":
		j.flames.emitting = false
	if hero == null or hero.global_position.distance_to(mouth(j)) > HEAR_RANGE:
		return
	if now == "warn":
		Sfx.play(level, "word_klick", -8.0, mouth(j), 0.7)
	elif now == "blast":
		Sfx.play(level, "word_wusch", -3.0, mouth(j), 0.8)
		Sfx.play(level, "magic", -12.0, mouth(j), 0.5)


## The fire of jet `j` caught the hero: once per blast.
func scorch(j: Dictionary) -> void:
	var hero: Player = level.player
	j.hit = true
	var hp := hero.hp
	hero.spring_trap(damage())
	if hero.hp < hp:
		hero.afflict("brand")
	if not _taught:
		_taught = true
		Events.teach(LEARN)
	Effects.float_text(level, hero.global_position + Vector3(0, 2.2, 0), Lang.t(NAME) + "!", NOTE_COLOR)


# --- Looks ------------------------------------------------------------------

## The nozzle in the wall, the soot lane on the floor, the flames and their
## light. The jet's node sits on the wall face and looks along the lane (its
## +Z), so everything is laid out along +Z.
func _build(j: Dictionary) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = mouth(j)
	node.rotation.y = atan2(float(j.dir.x), float(j.dir.y))
	j.node = node
	var reach := length_of(j)
	# The soot the fire has left on the floor: it shows where the fire reaches.
	var lane := StandardMaterial3D.new()
	lane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lane.albedo_color = Color(SOOT_COLOR, 0.45)
	lane.roughness = 1.0
	lane.emission_enabled = true
	lane.emission = WARN_COLOR
	lane.emission_energy_multiplier = 0.0
	j.lane = lane
	var strip := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_WIDTH * 1.6, reach - 0.4)
	strip.mesh = plane
	strip.material_override = lane
	strip.position = Vector3(0, Traps.MARK_Y, reach * 0.5)
	node.add_child(strip)
	# The iron plate on the wall and the spout sticking out of it.
	var iron := Traps._material(IRON_COLOR, 0.0)
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 1.1, 0.12)
	plate.mesh = box
	plate.material_override = iron
	plate.position = Vector3(0, NOZZLE_Y, 0.06)
	node.add_child(plate)
	var spout := MeshInstance3D.new()
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.17
	pipe.bottom_radius = 0.24
	pipe.height = 0.45
	pipe.radial_segments = 10
	spout.mesh = pipe
	spout.material_override = iron
	spout.rotation.x = PI * 0.5
	spout.position = Vector3(0, NOZZLE_Y, 0.3)
	node.add_child(spout)
	# The mouth of the spout: dark when cold, glowing in the warning and the fire.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.08, 0.05, 0.04)
	glow.emission_enabled = true
	glow.emission = FIRE_COLOR
	glow.emission_energy_multiplier = 0.0
	j.glow = glow
	var hole := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.13
	disc.bottom_radius = 0.13
	disc.height = 0.02
	disc.radial_segments = 10
	hole.mesh = disc
	hole.material_override = glow
	hole.rotation.x = PI * 0.5
	hole.position = Vector3(0, NOZZLE_Y, 0.53)
	node.add_child(hole)
	j.flames = _flames(reach)
	j.flames.position = Vector3(0, NOZZLE_Y, 0.55)
	node.add_child(j.flames)
	var light := OmniLight3D.new()
	light.light_color = FIRE_COLOR
	light.omni_range = reach * 0.6 + 2.0
	light.light_energy = 0.0
	light.visible = false
	light.position = Vector3(0, NOZZLE_Y + 0.3, reach * 0.5)
	node.add_child(light)
	j.light = light


## The stream of fire: soft flames shot out of the spout along +Z, swelling
## as they fly and dying at the far wall.
func _flames(reach: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var life := 0.5
	p.amount = 48
	p.lifetime = life
	p.local_coords = true
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3(0, 0, 1)
	p.spread = 5.0
	p.gravity = Vector3(0, 0.8, 0)
	p.initial_velocity_min = reach / life * 0.85
	p.initial_velocity_max = reach / life * 1.0
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.3))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.5, 0.6))
	ramp.set_color(1, Color(0.5, 0.05, 0.0, 0.0))
	ramp.add_point(0.3, Color(1.0, 0.55, 0.12, 0.5))
	ramp.add_point(0.7, Color(0.85, 0.2, 0.02, 0.3))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.3)
	quad.material = FireField._flame_material()
	p.mesh = quad
	return p


## Shows a jet's phase: cold iron at rest; in the warning a glow that swells
## and a lane that pulses red; in the fire a bright mouth and a flickering light.
func _show_phase(j: Dictionary) -> void:
	match phase_of(j):
		"rest":
			j.glow.emission_energy_multiplier = 0.0
			j.lane.emission_energy_multiplier = 0.0
			j.lane.albedo_color = Color(SOOT_COLOR, 0.45)
			j.light.visible = false
		"warn":
			var t: float = (j.clock - REST) / WARN
			var pulse := 0.5 + 0.5 * sin(t * TAU * 3.0)
			j.glow.emission_energy_multiplier = lerpf(0.4, 3.0, t)
			j.lane.emission_energy_multiplier = lerpf(0.2, 1.2, t) * (0.6 + 0.4 * pulse)
			j.lane.albedo_color = Color(SOOT_COLOR.lerp(WARN_COLOR, 0.5 * t), 0.5 + 0.25 * pulse)
			j.light.visible = true
			j.light.light_color = WARN_COLOR
			j.light.light_energy = 0.4 * t
		"blast":
			j.glow.emission_energy_multiplier = 4.0
			j.lane.emission_energy_multiplier = 0.8
			j.lane.albedo_color = Color(SOOT_COLOR.lerp(WARN_COLOR, 0.4), 0.6)
			j.light.visible = true
			j.light.light_color = FIRE_COLOR
			j.light.light_energy = 2.2 + 0.4 * sin(j.clock * 23.0)


# --- For the tests ----------------------------------------------------------

## The jet whose lane holds a tile, or an empty dictionary.
func jet_at(c: Vector2i) -> Dictionary:
	for j in jets:
		if c in j.cells:
			return j
	return {}
