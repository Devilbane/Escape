class_name CaveLights
extends RefCounted
## The lights and decor of the cave styles (see WallThemes), one family for each:
## - bone: a wall torch made of a bone with a skull-cup for the flame, a tripod of
##   bones round a bowl for a brazier, and a candelabra of bones,
## - rock: iron fire baskets on the wall, a stone-footed iron brazier, an iron candelabra,
## - obsidian: bowls of black glass with a red-violet flame, on the wall and on a
##   pedestal, and a black candelabra with violet-white candles,
## - crystal: clusters of glowing crystal on the wall and growing out of a rock
##   foot (they glow instead of burning), and a candelabra of crystal.
## They are built from plain meshes, in the stone styles' own materials, and light
## the room the way the dungeon's torches do (same range and fall-off, see Level).

const IRON := Color(0.12, 0.11, 0.1)

## How each style's fire looks: the flame's colours (bright, middle, dying), the
## light's colour and strength (a share of Level.TORCH_ENERGY), and, for crystal,
## the glow that stands in for a fire.
const LOOKS := {
	"bone": {"flame": [Color(1.0, 0.86, 0.55, 0.75), Color(1.0, 0.55, 0.2, 0.65), Color(0.6, 0.2, 0.05, 0.0)],
			"light": Color(1.0, 0.68, 0.38), "energy": 1.0},
	"rock": {"flame": [Color(1.0, 0.78, 0.35, 0.75), Color(1.0, 0.45, 0.1, 0.65), Color(0.7, 0.15, 0.05, 0.0)],
			"light": Color(1.0, 0.56, 0.24), "energy": 1.1},
	"obsidian": {"flame": [Color(1.0, 0.7, 0.85, 0.75), Color(0.85, 0.2, 0.45, 0.65), Color(0.35, 0.05, 0.3, 0.0)],
			"light": Color(0.95, 0.35, 0.5), "energy": 1.0},
	"crystal": {"glow": Color(0.35, 0.8, 1.0), "light": Color(0.5, 0.82, 1.0), "energy": 0.8},
}

static var _cache := {}


static func energy(style: String, base: float) -> float:
	return base * LOOKS[style].energy


static func light_colour(style: String) -> Color:
	return LOOKS[style].light


## A flame in the style's colours. `size` scales it.
static func flame(style: String, size := 1.0) -> CPUParticles3D:
	var look: Dictionary = LOOKS[style]
	if look.has("glow"):
		# Crystal burns not: a few sparks drift up from it.
		var sparks := Effects.make_sparkles(look.glow)
		sparks.emission_sphere_radius = 0.25 * size
		sparks.amount = 8
		return sparks
	var f := Effects.make_flame()
	var colours: Array = look.flame
	var ramp := Gradient.new()
	ramp.set_color(0, colours[0])
	ramp.add_point(0.35, colours[1])
	ramp.set_color(ramp.get_point_count() - 1, colours[2])
	f.color_ramp = ramp
	f.scale = Vector3.ONE * size
	return f


static func _stone(style: String) -> Material:
	var key := "stone_" + style
	if not _cache.has(key):
		_cache[key] = WallThemes.material(style, WallThemes.ROUGH_FLOOR)
	return _cache[key]


static func _iron() -> Material:
	if not _cache.has("iron"):
		var m := StandardMaterial3D.new()
		m.albedo_color = IRON
		m.metallic = 0.7
		m.roughness = 0.55
		_cache["iron"] = m
	return _cache["iron"]


static func _wax() -> Material:
	if not _cache.has("wax"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.8, 0.66)
		m.roughness = 0.8
		_cache["wax"] = m
	return _cache["wax"]


## A glowing crystal material. `lit` 1 is a burning one, a cold one shows only
## a faint glimmer (see dim).
static func crystal_material(strength := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.55, 0.9)
	m.roughness = 0.15
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = LOOKS.crystal.glow
	m.emission_energy_multiplier = 1.3 * strength
	return m


static func _put(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = tilt
	parent.add_child(mi)
	return mi


static func _cylinder(top: float, bottom: float, height: float, sides := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


static func _ball(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s


## A bone: a shaft with a knob at each end. Upright at `pos`, `length` tall.
static func _bone(parent: Node3D, mat: Material, pos: Vector3, length: float, tilt := Vector3.ZERO, thick := 0.05) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees = tilt
	parent.add_child(holder)
	_put(holder, _cylinder(thick, thick * 1.15, length, 8), mat, Vector3.ZERO)
	for end in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			_put(holder, _ball(thick * 1.7), mat, Vector3(side * thick * 1.1, end * length * 0.5, 0))
	return holder


## A cluster of crystals standing on `parent`, pointing up and out.
static func _crystals(parent: Node3D, mat: Material, pos: Vector3, size: float, count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var h := size * (1.0 if i == 0 else rng.randf_range(0.45, 0.85))
		var lean := 0.0 if i == 0 else rng.randf_range(14.0, 34.0)
		var around := rng.randf() * TAU
		var spike := _cylinder(0.0, size * 0.17, h, 6)
		var holder := Node3D.new()
		holder.position = pos
		holder.rotation = Vector3(0, around, 0)
		parent.add_child(holder)
		var m := _put(holder, spike, mat, Vector3(0, h * 0.5, 0), Vector3(lean, 0, 0))
		m.position = Vector3(0, h * 0.5 * cos(deg_to_rad(lean)), h * 0.5 * sin(deg_to_rad(lean)))


## What a wall torch of this style is made of, placed in `holder` (its +z points
## out of the wall, the wall at z = 0). Returns {"flame": the flame (or sparks),
## "glow": the materials that dim when the torch goes out}.
static func wall_torch(style: String, holder: Node3D) -> Dictionary:
	var glow := []
	var flame_at := Vector3(0, 0.78, 0.45)
	var stone := _stone(style)
	match style:
		"bone":
			# A long bone leaning out of the wall, a skull-cup on top.
			_put(holder, BoxMesh.new(), _iron(), Vector3(0, 0.2, 0.04)).scale = Vector3(0.3, 0.3, 0.08)
			_bone(holder, stone, Vector3(0, 0.45, 0.25), 0.9, Vector3(24, 0, 0))
			_put(holder, _cylinder(0.17, 0.08, 0.16), stone, Vector3(0, 0.88, 0.46))
			_put(holder, _ball(0.1), stone, Vector3(0, 0.72, 0.4))
		"rock":
			# An iron fire basket on an arm.
			_put(holder, BoxMesh.new(), _iron(), Vector3(0, 0.45, 0.04)).scale = Vector3(0.12, 0.7, 0.08)
			_put(holder, _cylinder(0.04, 0.04, 0.5), _iron(), Vector3(0, 0.55, 0.24), Vector3(90, 0, 0))
			_put(holder, _cylinder(0.26, 0.1, 0.24), _iron(), Vector3(0, 0.6, 0.5))
			var ring := TorusMesh.new()
			ring.inner_radius = 0.24
			ring.outer_radius = 0.3
			_put(holder, ring, _iron(), Vector3(0, 0.72, 0.5))
			flame_at = Vector3(0, 0.8, 0.5)
		"obsidian":
			# A bowl of black glass in an iron claw.
			_put(holder, BoxMesh.new(), _iron(), Vector3(0, 0.45, 0.04)).scale = Vector3(0.12, 0.7, 0.08)
			_put(holder, _cylinder(0.04, 0.04, 0.45), _iron(), Vector3(0, 0.55, 0.22), Vector3(90, 0, 0))
			_put(holder, _cylinder(0.28, 0.07, 0.26, 8), stone, Vector3(0, 0.62, 0.48))
			_put(holder, _cylinder(0.3, 0.3, 0.04, 8), _iron(), Vector3(0, 0.76, 0.48))
			flame_at = Vector3(0, 0.82, 0.48)
		_:
			# A crystal cluster grown out of the wall.
			var mat := crystal_material()
			glow.append(mat)
			_put(holder, _ball(0.22), stone, Vector3(0, 0.5, 0.08)).scale = Vector3(1.0, 1.1, 0.6)
			_crystals(holder, mat, Vector3(0, 0.55, 0.18), 0.75, 4, hash(holder.position))
			flame_at = Vector3(0, 0.9, 0.4)
	var f := flame(style)
	f.position = flame_at
	holder.add_child(f)
	return {"flame": f, "glow": glow}


## Dims or brightens the crystals of a torch that goes out or burns again.
static func dim(torch: Dictionary, on: bool) -> void:
	for m: StandardMaterial3D in torch.get("glow", []):
		m.emission_energy_multiplier = 1.3 if on else 0.12


## A standing brazier of the style at `pos` (always lit). Returns the light.
static func brazier(style: String, parent: Node3D, pos: Vector3) -> OmniLight3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var stone := _stone(style)
	var top := 1.2
	match style:
		"bone":
			# Three bones leaning together, holding a skull-bowl.
			for i in 3:
				var around := i * TAU / 3.0
				var leg := _bone(holder, stone, Vector3(cos(around) * 0.32, 0.6, sin(around) * 0.32), 1.25, Vector3(sin(around) * 14.0, 0, -cos(around) * 14.0), 0.06)
				leg.rotation.y = 0.0
			_put(holder, _cylinder(0.5, 0.24, 0.3), stone, Vector3(0, 1.1, 0))
		"rock":
			_put(holder, BoxMesh.new(), stone, Vector3(0, 0.3, 0)).scale = Vector3(1.1, 0.6, 1.1)
			_put(holder, _cylinder(0.12, 0.2, 0.5), _iron(), Vector3(0, 0.85, 0))
			_put(holder, _cylinder(0.55, 0.22, 0.34), _iron(), Vector3(0, 1.2, 0))
			top = 1.45
		"obsidian":
			_put(holder, _cylinder(0.3, 0.45, 0.9, 8), stone, Vector3(0, 0.45, 0))
			_put(holder, _cylinder(0.55, 0.2, 0.36, 8), stone, Vector3(0, 1.08, 0))
			top = 1.35
		_:
			_put(holder, _ball(0.55), stone, Vector3(0, 0.25, 0)).scale = Vector3(1.1, 0.55, 1.1)
			var mat := crystal_material(1.1)
			_crystals(holder, mat, Vector3(0, 0.35, 0), 1.7, 6, hash(pos))
			top = 1.2
	var f := flame(style, 1.6)
	f.position = Vector3(0, top, 0)
	holder.add_child(f)
	var light := OmniLight3D.new()
	light.light_color = light_colour(style)
	light.light_energy = 4.5 * (0.8 if style == "crystal" else 1.0)
	light.omni_range = 11.0
	light.omni_attenuation = 1.4
	light.position = Vector3(0, top + 0.9, 0)
	holder.add_child(light)
	return light


## A standing candelabra of the style: a foot, a stem and three arms with a
## candle each, and a soft light. Returns its node.
static func candelabra(style: String, parent: Node3D, pos: Vector3, rot: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot
	parent.add_child(holder)
	var body: Material = _stone(style) if style in ["bone", "obsidian"] else (_iron() if style == "rock" else crystal_material(0.7))
	var stone := _stone(style)
	_put(holder, _cylinder(0.3, 0.38, 0.12), stone, Vector3(0, 0.06, 0))
	_put(holder, _cylinder(0.06, 0.09, 1.5), body, Vector3(0, 0.85, 0))
	for i in 3:
		var side := float(i - 1)
		var arm_top := 1.6 - absf(side) * 0.25
		_put(holder, _cylinder(0.035, 0.035, 0.5), body, Vector3(side * 0.22, arm_top - 0.12, 0), Vector3(0, 0, -side * 48.0))
		_put(holder, _cylinder(0.12, 0.07, 0.07), body, Vector3(side * 0.43, arm_top, 0))
		_put(holder, _cylinder(0.05, 0.05, 0.22, 8), _wax(), Vector3(side * 0.43, arm_top + 0.14, 0))
		var f := flame(style, 0.45)
		f.position = Vector3(side * 0.43, arm_top + 0.3, 0)
		holder.add_child(f)
	var light := OmniLight3D.new()
	light.light_color = light_colour(style)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.omni_attenuation = 1.4
	light.position = Vector3(0, 2.0, 0)
	holder.add_child(light)
	return holder
