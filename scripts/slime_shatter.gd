class_name SlimeShatter
extends RefCounted
## In winter the slimes of the open air freeze through. A slime that is slain then
## does not run out into a puddle: it shatters like glass, and what is left of it is
## a slime crystal (CRYSTAL), an alchemy ingredient that never melts.
##
## Nothing here draws a random number: the shards fly on a fixed fan of directions and
## the crystals are counted from the slime's level, so a fight plays out the same with
## or without the frost (the tests replay fights on the shared random stream). The
## shards are a few small meshes of one shared mesh and material, and the glassy
## sound comes from Sfx.play_3d, which has no random pitch.

const CRYSTAL := "schleimkristall"
## The glassy blue of the shards and the crystal on the floor.
const COLOUR := Color(0.62, 0.88, 1.0)
const MIN_SHARDS := 7
const MAX_SHARDS := 16
## Seconds the shards fly before they have gone.
const FLIGHT := 0.9
const GRAVITY := 14.0
const LEARN := "Im Winter gefrieren die Schleime im Freien durch. Ein erschlagener Schleim zerspringt dann wie Glas und lässt Schleimkristalle zurück, die nie schmelzen. Am Alchemistentisch braust du daraus einen Frosttrank."

static var _mesh: PrismMesh
static var _mat: StandardMaterial3D


## Whether a slime that is slain now shatters: a slime of the open air in winter that
## no bigger slime swallowed.
static func applies(e: Enemy) -> bool:
	return e.level is Outdoor and Weather.is_winter((e.level as Outdoor).day) \
			and SlimeGrowth.grows(e.kind) and e.swallowed_by == null


## How many crystals a slime of this level leaves: one, two from level 10 and three from level 20.
static func crystals(level: int) -> int:
	return 1 + mini(2, level / 10)


## How many shards fly off a slime of this size.
static func shard_count(size: float) -> int:
	return clampi(roundi(MIN_SHARDS + 3.0 * size), MIN_SHARDS, MAX_SHARDS)


## The slime bursts into shards (from Enemy._die) and is gone.
static func shatter(e: Enemy) -> void:
	var level: Node3D = e.level
	SlimeGrowth.release_folk(e)
	e.remove_from_group("combatant")
	var at := e.global_position
	var size := float(e._stats.size)
	if _mesh == null:
		_mesh = PrismMesh.new()
		_mesh.size = Vector3(0.22, 0.34, 0.1)
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(COLOUR, 0.72)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.05
		_mat.metallic_specular = 1.0
		_mat.emission_enabled = true
		_mat.emission = COLOUR * 0.35
	var n := shard_count(size)
	for i in n:
		# A fixed fan: the golden angle round, and a speed that cycles with the index.
		var angle := float(i) * 2.399963
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var reach := (0.9 + 0.5 * float(i % 3)) * (0.6 + 0.4 * size)
		var shard := MeshInstance3D.new()
		shard.mesh = _mesh
		shard.material_override = _mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shard.scale = Vector3.ONE * (0.7 + 0.3 * size) * (0.8 + 0.2 * float(i % 3))
		shard.rotation = Vector3(float(i) * 0.9, angle, float(i) * 0.6)
		level.add_child(shard)
		shard.global_position = at + Vector3(0.0, 0.5 * size, 0.0) + dir * 0.2
		var from := shard.global_position
		var lift := 2.2 + 0.8 * float(i % 2)
		var tween := shard.create_tween()
		tween.tween_method(func(t: float) -> void:
			var rise := lift * t * FLIGHT - 0.5 * GRAVITY * t * t * FLIGHT * FLIGHT
			shard.global_position = from + dir * reach * t + Vector3(0.0, maxf(0.05 - from.y, rise), 0.0),
				0.0, 1.0, FLIGHT)
		tween.parallel().tween_property(shard, "scale", Vector3.ZERO, 0.25).set_delay(FLIGHT - 0.25)
		tween.tween_callback(shard.queue_free)
	Sfx.play_3d(level, "gear_trinket", -4.0, at, 2.2)
	Sfx.play_3d(level, "word_zing", -9.0, at, 1.6)
	if e.level.player != null and e._flat_distance(e.level.player) < Enemy.SIGHT:
		Events.teach(LEARN)
	if e._model != null:
		e._model.visible = false
	e.queue_free()
