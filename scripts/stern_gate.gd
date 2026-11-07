class_name SternGate
extends RefCounted
## Sternhall on the open-air map (see SternHall): the gate of the ruined
## keep in a clearing of the forest north of the wolf hollow ("|", it leads
## to "building: stern1"), and the rusty grate of the old drain on the
## hollow's western rim ("`"), where a hero who stole the tome comes out
## (the outdoor door SternHall.OUTLET). The grate does not open from outside.

## The building the gate leads into.
const BUILDING := "stern1"
## How big the graveyard's stone arch stands here, a keep's gate.
const ARCH_SCALE := 1.6


## The gate: a great stone arch in a broken wall, dark beyond, a faint
## violet glow breathing out of it, rubble and a fallen pillar in front.
static func build_gate(outdoor: Outdoor, c: Vector2i) -> void:
	var pos := outdoor.cell_to_world(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c)
	outdoor._age_graveyard(outdoor._put("arch_gate", pos, 0.0, ARCH_SCALE), false)
	var black := SternParts.material(Color(0.015, 0.01, 0.03), 0.0, 1.0, true)
	SternParts._box(outdoor, Vector3(4.6, 4.8, 0.6), black, pos + Vector3(0, 2.4, -0.9))
	# What is left of the wall on both sides: broken, mossy stone.
	var stone := SternParts.material(Color(0.44, 0.43, 0.42))
	var moss := SternParts.material(Color(0.3, 0.38, 0.26))
	for side in [-1.0, 1.0]:
		SternParts._box(outdoor, Vector3(5.0, rng.randf_range(2.6, 3.6), 1.4), stone, pos + Vector3(side * 5.4, 1.5, -0.9))
		SternParts._box(outdoor, Vector3(2.0, 0.3, 1.5), moss, pos + Vector3(side * 4.4, rng.randf_range(2.8, 3.2), -0.9))
	for i in 5:
		var at := pos + Vector3(rng.randf_range(-6.0, 6.0), 0.3, rng.randf_range(1.5, 4.5))
		if absf(at.x - pos.x) < 1.8:
			at.x += 2.4 * signf(at.x - pos.x + 0.01)
		SternParts._box(outdoor, Vector3(rng.randf_range(0.6, 1.2), 0.6, rng.randf_range(0.5, 1.0)), stone, at, Vector3(0, rng.randf() * TAU, 0))
	# A fallen pillar, half sunk into the grass.
	var drum := CylinderMesh.new()
	drum.top_radius = 0.55
	drum.bottom_radius = 0.6
	drum.height = 3.2
	SternParts._mesh(outdoor, drum, stone, pos + Vector3(-4.2, 0.4, 3.2), Vector3(0, 0.5, PI * 0.5))
	# A star of the keep, faded, over the arch.
	var star := SternParts._mesh(outdoor, SternParts.star_mesh(0.7, 0.3, 0.08), SternParts.material(SternParts.STAR_GOLD, 0.6), pos + Vector3(0, 6.2, -0.5))
	star.rotation.y = 0.0
	SternParts._light(outdoor, SternParts.VIOLET, 1.4, 6.0, pos + Vector3(0, 1.4, -0.2))
	outdoor._add_solid(pos + Vector3(0, 0, -0.9), Vector3(16.0, 4.0, 1.6))
	outdoor._add_solid(pos + Vector3(-4.2, 0, 3.2), Vector3(3.2, 1.0, 1.2))
	outdoor.doors[BUILDING] = pos + Vector3(0, 0, Level.TILE * 0.8)
	if outdoor.interiors.has(BUILDING):
		outdoor.stations.append({"kind": "eingang", "building": BUILDING, "name": Outdoor.BUILDING_NAMES["|"],
				"cell": c, "pos": pos, "used": false})


## The outlet of the drain: a round iron grate in the ground among mossy
## stones, rusted fast. The hero comes out beside it, towards the hollow.
static func build_outlet(outdoor: Outdoor, c: Vector2i) -> void:
	var pos := outdoor.cell_to_world(c)
	var rim := CylinderMesh.new()
	rim.top_radius = 1.1
	rim.bottom_radius = 1.2
	rim.height = 0.2
	SternParts._mesh(outdoor, rim, SternParts.material(Color(0.4, 0.4, 0.38)), pos + Vector3(0, 0.08, 0))
	var hole := CylinderMesh.new()
	hole.top_radius = 0.9
	hole.bottom_radius = 0.9
	hole.height = 0.02
	SternParts._mesh(outdoor, hole, SternParts.material(Color(0.02, 0.02, 0.03), 0.0, 1.0, true), pos + Vector3(0, 0.19, 0))
	var rust := SternParts.material(Color(0.42, 0.22, 0.12))
	for i in 5:
		SternParts._box(outdoor, Vector3(0.08, 0.08, 1.8), rust, pos + Vector3(-0.7 + 0.35 * i, 0.22, 0))
	SternParts._box(outdoor, Vector3(1.8, 0.08, 0.08), rust, pos + Vector3(0, 0.24, 0))
	var moss := SternParts.material(Color(0.3, 0.38, 0.26))
	for a in [0.4, 2.1, 3.6, 5.0]:
		SternParts._box(outdoor, Vector3(0.7, 0.4, 0.5), moss, pos + Vector3(cos(a), 0.2, sin(a)) * 1.5, Vector3(0, a, 0))
	outdoor._add_solid(pos, Vector3(2.4, 0.6, 2.4))
	outdoor.doors[SternHall.OUTLET] = pos + Vector3(Level.TILE * 0.8, 0, 0)
