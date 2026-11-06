class_name SlimeCoat
extends RefCounted
## Slime is hard to fight: it swallows small shots, it sticks to whoever
## strikes it, and it spits.
##
## - Shots: a slime's soft body takes in knives, bolts and arrows, so they
##   do only ABSORB of their damage (see absorb; the halves add up, so a
##   knife of 1 does 1 every second throw). Magic orbs and fire are not
##   little shots: they hurt it in full.
## - Slimed: whoever strikes a slime in close combat may get slimed (STICK,
##   more often on a Blob): coated in the slime's colour, wet and dripping,
##   they move at SLOW of their pace and take ATTACK_SLOW times as long
##   between blows, for TIME seconds. A fresh coat starts the time again.
##   The hero shows it as the ailment KIND, with an icon under the life bar;
##   a fountain, a shrine or a healing potion washes it off, like the others.
##   Ghosts have no body to coat, and slime does not stick to slime.
## - Spit: a slime spits a gob of itself at whoever it hunts, from
##   SPIT_MIN to SPIT_REACH away (an archer reaches much further) and only
##   every SPIT_COOL seconds (BLOB_SPIT_COOL for a Blob). The gob does no
##   harm, but it slimes whoever it hits.

## The hero's ailment (see Player.afflict).
const KIND := "schleimig"
const TIME := 6.0
## How fast the slimed still move, and how much longer they need between blows.
const SLOW := 0.7
const ATTACK_SLOW := 1.5
## The chance a blow on a slime leaves the striker slimed.
const STICK := 0.4
const BLOB_STICK := 0.7
## What a knife, a bolt or an arrow still does to a slime.
const ABSORB := 0.5
const SPIT_MIN := 2.5
const SPIT_REACH := 7.0
const SPIT_COOL := 8.0
const BLOB_SPIT_COOL := 5.0
## A gob flies slower than a spider's web.
const SPIT_SPEED := 9.0
## The coat's colour on the hero's icon and words.
const COLOR := Color(0.45, 0.95, 0.35)
const NODE := "SlimeCoat"
## The compendium's entry, the first time the hero meets one of these tricks.
const LEARN := "Schleim ist zäh: Kleine Geschosse wie Messer, Bolzen und Pfeile schluckt ein Schleim zur Hälfte, Magie und Feuer treffen ihn voll. Wer ihn mit der Klinge schlägt, wird leicht verschleimt und ist dann ein paar Sekunden lang langsamer, zu Fuß und beim Schlagen. Aus kurzer Entfernung spuckt ein Schleim auch Schleim, seltener und weniger weit, als ein Bogenschütze schießt."


static func is_slime(e: Enemy) -> bool:
	return e != null and is_instance_valid(e) and SlimeGrowth.grows(e.kind)


## Whether a blow on `slime` leaves its striker slimed this time.
static func sticks(slime: Enemy) -> bool:
	if not is_slime(slime):
		return false
	return randf() < (BLOB_STICK if slime.blob else STICK)


## Whether this one can be slimed at all.
static func can_coat(e: Enemy) -> bool:
	return not e.dead and not e.is_ghost() and not is_slime(e)


## What a little shot of `damage` still does to the slime `e`: ABSORB of it,
## the parts carried on to the next shot.
static func absorb(e: Enemy, damage: int) -> int:
	var total := damage * ABSORB + e.absorbed
	var out := floori(total + 0.0001)
	e.absorbed = total - out
	return out


## Coats `model` (the body under `holder`) in slime of `colour`: a wet,
## glossy skin over every part and drops running off it.
static func coat(holder: Node3D, model: Node3D, colour: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(colour, 0.42)
	mat.roughness = 0.03
	mat.metallic_specular = 1.0
	mat.rim_enabled = true
	mat.rim = 0.7
	mat.emission_enabled = true
	mat.emission = colour * 0.12
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = mat
	var old := holder.get_node_or_null(NODE)
	if old:
		old.free()
	holder.add_child(_drips(colour))


static func wipe(holder: Node3D, model: Node3D) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = null
	var old := holder.get_node_or_null(NODE)
	if old:
		old.queue_free()


## Drops of slime running off the coated body.
static func _drips(colour: Color) -> CPUParticles3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(colour, 0.85)
	mat.roughness = 0.05
	mat.metallic_specular = 0.8
	var drop := SphereMesh.new()
	drop.radius = 0.05
	drop.height = 0.16
	drop.radial_segments = 8
	drop.rings = 4
	drop.material = mat
	var drips := CPUParticles3D.new()
	drips.name = NODE
	drips.mesh = drop
	drips.amount = 14
	drips.lifetime = 0.8
	drips.position.y = 1.0
	drips.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drips.emission_box_extents = Vector3(0.35, 0.6, 0.35)
	drips.direction = Vector3.DOWN
	drips.spread = 10.0
	drips.gravity = Vector3(0, -9.0, 0)
	drips.initial_velocity_min = 0.0
	drips.initial_velocity_max = 0.3
	return drips


## A gob of spat slime in flight: a glossy ball of the slime's colour with a
## few drops trailing behind.
static func gob(colour: Color) -> Node3D:
	var ball := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(colour, 0.8)
	mat.roughness = 0.04
	mat.metallic_specular = 1.0
	mat.emission_enabled = true
	mat.emission = colour * 0.35
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.4
	sphere.radial_segments = 12
	sphere.rings = 6
	core.mesh = sphere
	core.material_override = mat
	ball.add_child(core)
	# Drops trailing back (look_at points -Z along the flight).
	for i in 3:
		var drop := MeshInstance3D.new()
		var bit := SphereMesh.new()
		bit.radius = 0.09 - i * 0.02
		bit.height = bit.radius * 2.0
		drop.mesh = bit
		drop.material_override = mat
		drop.position = Vector3(0, -0.04 * i, 0.32 + 0.2 * i)
		ball.add_child(drop)
	return ball
