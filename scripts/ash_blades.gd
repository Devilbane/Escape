class_name AshBlades
extends Node3D
## Blade sweepers ("z" on a dungeon map): an iron post in the middle of a tile
## with a low blade on a long arm that turns round it all day, knee high.
## The arm reaches nearly to the walls of the tile, so the only ways past are
## to time a jump over it or to run through before it comes round.
##
## A hero whose feet are below ARM_TOP while the arm is over them is cut
## (once per HIT_PAUSE seconds, a deft hero may still twist aside, see
## Player.spring_trap). A jump keeps the feet above the arm for about half a
## second. Monsters do not mind the blades.
##
## Neighbouring sweepers turn the opposite way and out of step, so a row of
## them is a gauntlet. The floor shows the circle each one sweeps.

const NAME := "Klingenfeger"
const LEARN := "Klingenfeger: Auf einem Eisenpfosten kreist eine niedrige Klinge, knapp über dem Boden. Wer ihr im Weg steht, wird geschnitten. Spring im richtigen Augenblick über den Arm hinweg, oder lauf hindurch, solange er auf der anderen Seite ist, und warte nicht in der Mitte."

## Radians per second, and the height of the arm's top (metres).
const SPEED := 1.25
const ARM_TOP := 0.75
## Half the length of the arm, and how close to its line (metres) the hero is cut.
const ARM_REACH := 1.85
const ARM_HALF_WIDTH := 0.55
## Seconds before the same blade cuts again.
const HIT_PAUSE := 1.2
const SEE_RANGE := 14.0
const IRON := Color(0.2, 0.19, 0.19)
const EDGE := Color(0.7, 0.72, 0.78)
const NOTE_COLOR := Color(0.9, 0.9, 1.0)

var level: Level
## Each sweeper: {"cell", "pos", "angle", "dir" (1 or -1), "arm" (node), "pause"}.
var blades: Array = []
var place_level := 1
var _taught := false


## The sweepers of a level, or null when it has none.
static func make(owner_level: Level) -> AshBlades:
	var s := AshBlades.new()
	s.level = owner_level
	s.name = "AshBlades"
	for y in owner_level.height:
		for x in owner_level.width:
			var c := Vector2i(x, y)
			if owner_level.cell_char(c) == "z":
				s.blades.append({"cell": c, "pos": owner_level.cell_to_world(c), "angle": (x * 0.9 + y * 1.7) * 1.3,
						"dir": 1 if (x + y) % 2 == 0 else -1, "pause": 0.0})
	if s.blades.is_empty():
		s.free()
		return null
	s.place_level = HeroLevel.place_level(owner_level)
	return s


func _ready() -> void:
	for b in blades:
		_build(b)


## What a cut deals here.
func damage() -> int:
	return maxi(2, 2 + place_level / Traps.SPIKE_LEVELS)


## Whether a spot (feet position) is under the arm of blade `b` right now.
static func cuts(b: Dictionary, pos: Vector3) -> bool:
	if pos.y >= ARM_TOP:
		return false
	var origin: Vector3 = b.pos
	var angle: float = b.angle
	var rel := pos - origin
	var dir := Vector2(cos(angle), sin(angle))
	var along: float = rel.x * dir.x + rel.z * dir.y
	var across: float = absf(rel.x * dir.y - rel.z * dir.x)
	return absf(along) <= ARM_REACH and across <= ARM_HALF_WIDTH


func _physics_process(delta: float) -> void:
	for b in blades:
		b.angle = fmod(b.angle + b.dir * SPEED * delta, TAU)
		b.pause = maxf(0.0, b.pause - delta)
		if b.has("arm"):
			b.arm.rotation.y = -b.angle
	var hero: Player = level.player
	if hero == null or level.finished or hero.dead or hero.frozen:
		return
	for b in blades:
		if not _taught and hero.global_position.distance_to(b.pos) < SEE_RANGE:
			_taught = true
			Events.teach(LEARN)
		if b.pause <= 0.0 and cuts(b, hero.global_position):
			b.pause = HIT_PAUSE
			hero.spring_trap(damage())
			Sfx.play(level, "swing", -2.0, b.pos, 0.6)
			Effects.float_text(level, hero.global_position + Vector3(0, 2.2, 0), Lang.t(NAME) + "!", NOTE_COLOR)


func _build(b: Dictionary) -> void:
	var node := Node3D.new()
	node.position = b.pos
	add_child(node)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.roughness = 0.7
	iron.metallic = 0.5
	var steel := StandardMaterial3D.new()
	steel.albedo_color = EDGE
	steel.roughness = 0.35
	steel.metallic = 0.8
	# The sweep's circle on the floor.
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = ARM_REACH
	disc.bottom_radius = ARM_REACH
	disc.height = 0.02
	disc.radial_segments = 28
	ring.mesh = disc
	var soot := StandardMaterial3D.new()
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.albedo_color = Color(0.05, 0.04, 0.04, 0.4)
	ring.material_override = soot
	ring.position.y = Traps.MARK_Y
	node.add_child(ring)
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.38
	cyl.height = 1.0
	post.mesh = cyl
	post.material_override = iron
	post.position.y = 0.5
	node.add_child(post)
	var arm := Node3D.new()
	arm.position.y = 0.4
	node.add_child(arm)
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(ARM_REACH * 2.0, ARM_TOP - 0.25, 0.14)
	bar.mesh = box
	bar.material_override = steel
	bar.position.y = (ARM_TOP - 0.25) * 0.5 - 0.15
	arm.add_child(bar)
	# The arm is drawn along +X; rotation.y = -angle turns it to (cos, sin) in x/z.
	b.arm = arm
	arm.rotation.y = -b.angle
	level._add_solid(b.pos, Vector3(0.7, 1.0, 0.7))
