class_name Elementals
extends RefCounted
## The elementals and golems of the caves, each at home in one kind of rock
## (the ideas come from the classic role-playing games: a fire elemental that
## burns whatever touches it, constructs that shrug off most things, a stone
## golem that shakes the ground, a crystal one that throws back what hits it):
## - fire elemental ("feuerelementar"): touching it burns, it hurls fire bolts
##   and scorches the floor under the hero, leaving a burning patch behind it
##   (see FireField); it burns out in a last blaze when it falls,
## - obsidian golem ("obsidiangolem"): black glass with thick armour, throws
##   fans of shards that cut and slams the ground,
## - stone golem ("steingolem"): slow and very tough, flings rocks from afar
##   and its quake throws a running hero off their feet,
## - crystal golem ("kristallgolem"): a ray of light, a ring of prismatic
##   shards, a mirror ward that bounces blows back at the hero and a shatter
##   when it falls.
## Golems do not bleed and are not stunned or crippled (Enemy "big", "bloodless").
##
## Combat stays simple: every special move is announced by a coloured glow, the
## name over the head and, for a blow on the ground, a ring on the floor that
## shows where and when it lands. A move has a range band and a pause of its own
## (MOVES); between moves the monster fights like any other. The moves share
## the monster's blow timer, so it never uses two at once.

const KINDS := ["feuerelementar", "obsidiangolem", "steingolem", "kristallgolem"]
const GOLEMS := ["obsidiangolem", "steingolem", "kristallgolem"]

const FIRE := Color(1.0, 0.5, 0.12)
const GLASS := Color(0.55, 0.2, 0.45)
const STONE := Color(0.62, 0.58, 0.5)
const CRYSTAL := Color(0.45, 0.85, 1.0)

## How long the mirror ward of a crystal golem holds (seconds), how long it
## waits to raise it again, and the most a bounced blow can deal.
const WARD_TIME := 3.0
const WARD_PAUSE := 9.0
const REFLECT_MAX := 4
## How far from a falling crystal golem its shards fly (metres), and the pause
## before they land, so there is time to step away.
const SHATTER_RADIUS := 3.2
const SHATTER_WARN := 0.9
## A fire elemental's last blaze: radius and how long it burns.
const BLAZE_RADIUS := 2.0
const BLAZE_TIME := 5.0
## How often a walking fire elemental drops a burning patch (seconds).
const TRAIL_EVERY := 2.5

## Per kind, the special moves in order of preference: the first that is
## ready and whose range band (min..max metres from the hero) fits is used.
## "do" is what happens, "wind" the warning in seconds, "cool" the pause
## before the same move again, "extra" more damage than the kind's blow.
const MOVES := {
	"feuerelementar": [
		{"id": "scorch", "name": "Versengen", "do": "scorch", "min": 2.5, "max": 12.0, "cool": 8.0, "wind": 0.8, "color": FIRE},
		{"id": "fire_bolt", "name": "Feuerblitz", "do": "orb", "min": 3.5, "max": 15.0, "cool": 3.5, "wind": 0.6, "color": FIRE, "speed": 10.0},
	],
	"obsidiangolem": [
		{"id": "slam", "name": "Schmettern", "do": "slam", "min": 0.0, "max": 3.2, "cool": 6.0, "wind": 1.0, "color": GLASS, "radius": 3.4, "extra": 2},
		{"id": "shards", "name": "Splitterwurf", "do": "shards", "min": 3.5, "max": 14.0, "cool": 4.5, "wind": 0.7, "color": GLASS, "speed": 13.0},
	],
	"steingolem": [
		{"id": "quake", "name": "Beben", "do": "quake", "min": 0.0, "max": 3.6, "cool": 7.0, "wind": 1.3, "color": STONE, "radius": 3.8, "extra": 1},
		{"id": "rock", "name": "Felswurf", "do": "rock", "min": 4.5, "max": 15.0, "cool": 5.5, "wind": 1.0, "color": STONE, "speed": 7.5, "extra": 1},
	],
	"kristallgolem": [
		{"id": "ward", "name": "Spiegelschild", "do": "ward", "min": 0.0, "max": 30.0, "cool": WARD_PAUSE + WARD_TIME, "wind": 0.3, "color": CRYSTAL},
		{"id": "burst", "name": "Prismenstoß", "do": "nova", "min": 0.0, "max": 8.0, "cool": 9.0, "wind": 1.0, "color": CRYSTAL},
		{"id": "beam", "name": "Kristallstrahl", "do": "beam", "min": 4.0, "max": 16.0, "cool": 4.0, "wind": 0.8, "color": CRYSTAL, "speed": 22.0},
	],
}


static func is_elemental(kind: String) -> bool:
	return kind in KINDS


## Whether a monster takes no harm from fire.
static func fireproof(kind: String) -> bool:
	return kind == "feuerelementar"


## The move this monster would use now against a hero `dist` metres away, or
## an empty dictionary. It needs a clear line to the hero and the monster's
## blow timer to be ready.
static func pick(e: Enemy, dist: float, sees: bool) -> Dictionary:
	if not MOVES.has(e.kind) or e.dead or not sees or e._lost > 0.0 or e._cooldown > 0.0 or e.level == null:
		return {}
	var clear: bool = e.level.has_clear_shot(e.global_position, e.level.player.global_position)
	for m: Dictionary in MOVES[e.kind]:
		if float(e.move_cools.get(m.id, 0.0)) > 0.0 or dist < float(m.min) or dist > float(m.max):
			continue
		if not clear and m.do != "ward":
			continue
		if m.do == "ward" and e.ward_left > 0.0:
			continue
		return m
	return {}


## Counts the pauses down (called every physics tick).
static func tick(e: Enemy, delta: float) -> void:
	for id in e.move_cools.keys():
		e.move_cools[id] = maxf(0.0, float(e.move_cools[id]) - delta)
	if e.ward_left > 0.0:
		e.ward_left = maxf(0.0, e.ward_left - delta)
		if e.ward_left <= 0.0:
			var glow := e.get_node_or_null("WardGlow")
			if glow:
				glow.queue_free()
	# A walking fire elemental scorches the floor it crosses.
	if e.kind == "feuerelementar" and not e.dead:
		e.trail_left -= delta
		if e.trail_left <= 0.0:
			e.trail_left = TRAIL_EVERY
			if e.is_hunting() and e.level != null:
				FireField.spawn(e.level, e.global_position, 0.5, 3.0, 1.1, false)


## Uses `move` against `target` (the hero): the warning first, then the blow.
static func use(e: Enemy, move: Dictionary, target: Node3D) -> void:
	e.move_cools[move.id] = float(move.cool)
	Events.teach(LORE[e.kind])
	e._cooldown = float(e._stats.cooldown) * 0.7
	var wind := float(move.wind)
	var colour: Color = move.color
	e._play_once("1H_Melee_Attack_Chop", wind + 0.4)
	Effects.head_text(e.level, e, 3.0 * float(e._stats.size), Lang.t(str(move.name)), colour)
	_charge(e, colour, wind)
	Sfx.play(e, "magic", -4.0, e.global_position, 0.7)
	var reach := target.global_position
	var damage := int(e._stats.damage) + int(move.get("extra", 0))
	# The floor is marked at once, where the hero stands now.
	match move.do:
		"scorch":
			var side := (reach - e.global_position).cross(Vector3.UP).normalized() * 1.7
			for offset in [Vector3.ZERO, side, -side]:
				FireField.spawn(e.level, reach + offset, wind + 0.1, 5.0, 1.6, offset == Vector3.ZERO)
		"slam", "quake":
			GroundSlam.spawn(e.level, e, e.global_position, float(move.radius), wind, damage, colour, move.do == "quake")
		"nova":
			GroundSlam.spawn(e.level, e, e.global_position, 2.2, wind, damage, colour, false)
	await e.get_tree().create_timer(wind).timeout
	if not is_instance_valid(e) or e.dead or not e.is_inside_tree() or not is_instance_valid(target):
		return
	var origin := e.global_position + Vector3(0, 1.4 * float(e._stats.size), 0)
	var aim := target.global_position + Vector3(0, 1.0, 0) - origin
	var level: Level = e.level
	match move.do:
		"orb":
			var s := ElementalShot.spawn(level, e, origin, aim, "orb", colour, damage, float(move.speed))
			s.effect = "brand"
		"beam":
			ElementalShot.spawn(level, e, origin, aim, "beam", colour, damage + 1, float(move.speed))
		"rock":
			ElementalShot.spawn(level, e, origin, aim, "rock", colour, damage, float(move.speed))
		"shards":
			for turn in [-0.24, 0.0, 0.24]:
				var s := ElementalShot.spawn(level, e, origin, aim.rotated(Vector3.UP, turn), "shard", colour, damage, float(move.speed))
				s.cuts = true
		"nova":
			# Eight shards in all directions, each its own colour of the rainbow.
			for i in 8:
				var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / 8.0)
				ElementalShot.spawn(level, e, origin, dir, "shard", Color.from_hsv(float(i) / 8.0, 0.45, 1.0), maxi(1, damage - 1), 8.0)
		"ward":
			raise_ward(e)


## A glow that grows around the monster during the warning, in the move's colour.
static func _charge(e: Enemy, colour: Color, secs: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 0.5
	light.omni_range = 4.5
	light.position = Vector3(0, 1.5 * float(e._stats.size), 0)
	e.add_child(light)
	var grow := light.create_tween()
	grow.tween_property(light, "light_energy", 4.0, secs)
	grow.tween_callback(light.queue_free)


## A glow around a crystal golem, as long as its ward holds. A blow struck
## in this time is thrown back (see reflect).
static func raise_ward(e: Enemy) -> void:
	e.ward_left = WARD_TIME
	if e.get_node_or_null("WardGlow") != null:
		return
	var glow := OmniLight3D.new()
	glow.name = "WardGlow"
	glow.light_color = Color(1.0, 1.0, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = 4.0
	glow.position = Vector3(0, 1.4 * float(e._stats.size), 0)
	e.add_child(glow)


## The hero struck a monster of this kind for `damage`: what comes back at
## them. A warded crystal golem bounces a third of it (at most REFLECT_MAX).
static func reflect(e: Enemy, damage: int, blow: String) -> void:
	if e.kind != "kristallgolem" or e.ward_left <= 0.0 or e.level == null or e.level.player == null:
		return
	if not blow in ["hit", "knife", "shot"]:
		return
	var back := clampi(damage / 3, 1, REFLECT_MAX)
	Effects.head_text(e.level, e.level.player, 2.8, Lang.t("Zurückgeworfen!"), CRYSTAL)
	e.level.player.take_damage(back, e.global_position, null, false)


## A fallen one leaves its last act: a fire elemental a blaze, a crystal
## golem a ring of shards that bursts after a short warning.
static func on_death(e: Enemy) -> void:
	if e.level == null:
		return
	if e.kind == "feuerelementar":
		FireField.spawn(e.level, e.global_position, 0.6, BLAZE_TIME, BLAZE_RADIUS, true)
	elif e.kind == "kristallgolem":
		GroundSlam.spawn(e.level, e, e.global_position, SHATTER_RADIUS, SHATTER_WARN, maxi(1, int(e._stats.damage) - 1), CRYSTAL, false)


## What the compendium learns the first time one of them uses its special move.
const LORE := {
	"feuerelementar": "Feuerelementar: Wer es berührt, verbrennt. Es speit Feuerblitze und versengt den Boden unter dir: Tritt aus dem roten Ring, bevor er zündet. Feuer schadet ihm nicht, und wo es fällt, brennt der Boden noch eine Weile.",
	"obsidiangolem": "Obsidiangolem: Schwarzes Glas, dick gepanzert. Seine Splitter schneiden und können bluten lassen: Weiche seitlich aus. Vor seinem Schmettern warnt ein Ring am Boden: Springe darüber oder tritt hinaus.",
	"steingolem": "Steingolem: Langsam, sehr zäh und ohne Blut. Seine Felsbrocken fliegen gemächlich, sein Beben wirft einen rennenden Helden um: Tritt aus dem Ring oder springe darüber.",
	"kristallgolem": "Kristallgolem: Wenn er hell aufleuchtet, wirft sein Spiegelschild jeden Schlag zurück: Warte, bis das Leuchten erlischt. Sein Prismenstoß schickt acht Splitter in alle Richtungen: Laufe durch eine Lücke. Beim Fallen zerspringt er: Tritt zurück.",
}
## The touch of a fire elemental: how likely a blow of it sets the hero alight.
const TOUCH_BURN := 0.6


# --- Looks ---------------------------------------------------------------------

## Dresses a golem or an elemental in the stuff it is made of: rock lumps on a
## stone golem, black glass spikes on an obsidian one, glowing prisms on a
## crystal one and flames on a fire elemental. Pieces sit on the model's
## pivot (a unit is a metre at size 1).
static func dress(e: Enemy) -> void:
	if not is_elemental(e.kind) or e._model == null:
		return
	match e.kind:
		"steingolem":
			var rock := _paint(Color(0.5, 0.48, 0.44), 1.0, 0.0)
			for spot in [Vector3(-0.62, 1.55, 0.0), Vector3(0.62, 1.6, 0.05), Vector3(0.0, 1.4, 0.4), Vector3(0.0, 0.5, -0.4)]:
				var lump := SphereMesh.new()
				lump.radius = 0.32
				lump.height = 0.56
				lump.radial_segments = 6
				lump.rings = 3
				_piece(e, lump, rock, spot, Vector3(randf() * 2.0, randf() * 3.0, 0.0))
		"obsidiangolem":
			var glass := _paint(Color(0.05, 0.04, 0.07), 0.12, 0.7)
			glass.emission_enabled = true
			glass.emission = Color(0.55, 0.1, 0.3)
			glass.emission_energy_multiplier = 0.5
			for spot in [Vector3(-0.6, 1.55, 0.0), Vector3(0.6, 1.6, 0.0), Vector3(0.0, 1.8, 0.3), Vector3(-0.25, 1.35, 0.45), Vector3(0.25, 1.35, 0.45)]:
				_spike(e, glass, spot, 0.9, 4)
		"kristallgolem":
			var prism := _paint(Color(0.6, 0.9, 1.0), 0.1, 0.0)
			prism.emission_enabled = true
			prism.emission = CRYSTAL
			prism.emission_energy_multiplier = 1.6
			for spot in [Vector3(-0.6, 1.6, 0.0), Vector3(0.6, 1.65, 0.0), Vector3(0.0, 1.85, 0.2), Vector3(-0.3, 1.2, 0.45), Vector3(0.3, 1.2, 0.45)]:
				_spike(e, prism, spot, 0.8, 5)
		"feuerelementar":
			var core := SphereMesh.new()
			core.radius = 0.25
			core.height = 0.5
			var ember := _paint(Color(1.0, 0.75, 0.25), 0.5, 0.0)
			ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_piece(e, core, ember, Vector3(0, 1.1, 0.3), Vector3.ZERO)
			var flames := Ignition.make_flames(float(e._stats.size))
			flames.name = "ElementalFlames"
			e.add_child(flames)


static func _paint(colour: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	m.metallic = metal
	return m


static func _piece(e: Enemy, mesh: Mesh, mat: Material, at: Vector3, turn: Vector3) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.mesh = mesh
	p.material_override = mat
	p.position = at
	p.rotation = turn
	e._model.add_child(p)
	return p


## A spike (a four- or five-sided cone) leaning outward from the body.
static func _spike(e: Enemy, mat: Material, at: Vector3, length: float, sides: int) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.13
	cone.height = length
	cone.radial_segments = sides
	cone.rings = 0
	var lean := Vector3(0.0, 0.0, -clampf(at.x, -1.0, 1.0) * 0.8)
	_piece(e, cone, mat, at + Vector3(0, length * 0.4, 0), lean)
