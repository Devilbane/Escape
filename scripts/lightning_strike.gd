class_name LightningStrike
extends RefCounted
## What a stroke of lightning does to the living things it hits (see
## Outdoor.strike): anyone standing within HIT_RADIUS of the bolt is lit up
## in a white-blue glow for a moment, screams, and a monster or the hero takes
## a little damage. The peaceful animals and the villagers cannot be hurt
## (see Animal), so they only glow, scream and, if they can, bolt.
##
## Kept rare and fair: a strike picks a living thing out in the open only
## now and then (SEEK_CHANCE), and the hero is hit only by standing right
## under the bolt, takes just HERO_DAMAGE and is never felled by it.

## How close to the bolt a body must stand to be struck (metres).
const HIT_RADIUS := 2.5
## How much a monster loses; the hero loses HERO_DAMAGE, never the last life.
const MONSTER_DAMAGE := 2
const HERO_DAMAGE := 1
## How often a stroke aims at a creature that is about, not at a rock or the
## woods, and how far from the hero such a creature may stand (metres).
const SEEK_CHANCE := 0.2
const SEEK_RANGE := 30.0
## How long the glow takes to fade.
const GLOW_TIME := 1.4
const GLOW_COLOR := Color(0.75, 0.88, 1.0)
const CRY := "AAAH!"


## Where to aim a stroke that seeks someone: the position of a random living
## creature out in the open near the hero (never the hero), or null if there
## is none.
static func pick_target(level: Outdoor, hero: Node3D):
	var found: Array = []
	for who in _bodies(level):
		if _alive(who) and level._flat_distance(hero.global_position, who.global_position) < SEEK_RANGE:
			found.append(who)
	if found.is_empty():
		return null
	var at: Vector3 = (found.pick_random() as Node3D).global_position
	at.y = 0.0
	return at


## Strikes everyone near `at`. Returns how many were struck (the hero too).
static func hit(level: Outdoor, at: Vector3, hero: Node3D = null) -> int:
	var n := 0
	for who in _bodies(level):
		if _alive(who) and level._flat_distance(who.global_position, at) <= HIT_RADIUS:
			_strike_one(level, who, at)
			n += 1
	if hero and not hero.dead and level._flat_distance(hero.global_position, at) <= HIT_RADIUS:
		_strike_one(level, hero, at)
		n += 1
	return n


## Every creature that can be struck but the hero.
static func _bodies(level: Outdoor) -> Array:
	var all: Array = []
	for list in [level.enemies, level.animals, level.farm_animals, level.villagers]:
		all.append_array(list)
	return all.filter(func(x): return is_instance_valid(x))


static func _alive(who: Node3D) -> bool:
	return who.is_inside_tree() and who.visible and who.get("dead") != true


static func _strike_one(level: Outdoor, who: Node3D, at: Vector3) -> void:
	glow(who)
	Effects.head_text(level, who, 2.6, Lang.t(CRY), GLOW_COLOR)
	Sfx.play(who, scream_of(who), -2.0, who.global_position, 1.0 if who is Player or who is Villager else 1.5)
	if who is Player:
		var hero := who as Player
		if hero.hp > HERO_DAMAGE:
			hero.take_damage(HERO_DAMAGE, at, null, false)
	elif who is Enemy:
		(who as Enemy).take_hit(MONSTER_DAMAGE, at, "pierce", false)
	elif who is Animal:
		(who as Animal).bolt_from(at)


## The cry of a struck body: a person yelps, a ghost wails, the rest shrieks.
static func scream_of(who: Node3D) -> String:
	if who is Enemy and who.is_ghost():
		return "voice_banshee_%d" % (randi() % 2)
	if who is Player or who is Villager:
		return "voice_aua"
	return "voice_wicht_%d" % (randi() % 2)


## A white-blue glow all over the body that fades away. The meshes' own
## overlay (a slime's coat) is put back afterwards.
static func glow(who: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(GLOW_COLOR, 0.9)
	var old := {}
	for mesh in who.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		old[m] = m.material_overlay
		m.material_overlay = mat
	var light := OmniLight3D.new()
	light.light_color = GLOW_COLOR
	light.light_energy = 3.0
	light.omni_range = 5.0
	light.position = Vector3(0, 1.2, 0)
	who.add_child(light)
	var sparks := Effects.make_sparkles(GLOW_COLOR, true)
	sparks.position = Vector3(0, 1.2, 0)
	who.add_child(sparks)
	var tween := who.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, GLOW_TIME)
	tween.parallel().tween_property(light, "light_energy", 0.0, GLOW_TIME)
	tween.tween_callback(func():
		for m in old:
			if is_instance_valid(m):
				m.material_overlay = old[m]
		light.queue_free()
		sparks.queue_free())
