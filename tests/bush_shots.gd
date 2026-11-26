extends SceneTree
## Screenshots of the bushes on a small stage: a stretch of forest edge (bushes planted in a row, as the
## undergrowth does) and a lineup of every kind (BushKinds), in summer and autumn.
## Run with: SHOTS=<folder> godot -s tests/bush_shots.gd (needs a display). Without BushKinds (an older
## checkout) it grows the old bushes, for the before pictures.

const DAYS := {
	"summer": Weather.SPRING_DAYS + 2,
	"autumn": Weather.YEAR_DAYS - Weather.WINTER_DAYS - Weather.AUTUMN_DAYS + IvySeasons.TURN_DAYS - 1,
}

var shots := OS.get_environment("SHOTS")
var frames := 0
var started := false
var stage: Node3D
var cam: Camera3D


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.95, 0.85)
	stage.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	_ground()


## Meadow grass in front, a dark wall of forest behind.
func _ground() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.2, 0.34, 0.12), Color(0.34, 0.46, 0.16)])
	tex.color_ramp = gradient
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 1.0
	mat.uv1_scale = Vector3(6, 6, 1)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 60)
	plane.material = mat
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(80, 14, 6)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.04, 0.09, 0.09)
	dark.roughness = 1.0
	box.material = dark
	wall.mesh = box
	wall.position = Vector3(0, 7, -3.5)
	stage.add_child(wall)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3 and not started:
		started = true
		_run()
	return false


## A bush at `at` into `leaves`, of the old kind or of the many (see BushKinds).
func _bush(at: Vector3, rng: RandomNumberGenerator, leaves: Dictionary, recent: Array, kind := -1) -> void:
	if not ResourceLoader.exists("res://scripts/bush_kinds.gd"):
		(load("res://scripts/aged_stone.gd") as GDScript).call("grow_bush", at, rng, leaves)
	elif kind >= 0:
		(load("res://scripts/aged_stone.gd") as GDScript).call("grow_bush_kind", kind, at, rng, leaves)
	else:
		(load("res://scripts/aged_stone.gd") as GDScript).call("grow_bush", at, rng, leaves, leaves, recent)


func _build(rng_seed: int, lineup: bool) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var leaves := {"xforms": [], "colours": []}
	var recent := []
	if lineup:
		var kinds := 10
		for i in kinds:
			for j in 2:
				_bush(Vector3((i - kinds * 0.5 + 0.5) * 2.7, 0, 1.0 + j * 3.2), rng, leaves, recent, i)
	else:
		var x := -17.0
		while x < 17.0:
			_bush(Vector3(x, 0, 0.8 + rng.randf_range(-0.5, 0.5)), rng, leaves, recent)
			x += rng.randf_range(1.5, 2.1)
	var node: Node3D = AgedStone.ivy_node(leaves)
	stage.add_child(node)
	return node


func _run() -> void:
	for lineup in [false, true]:
		var node := _build(11, lineup)
		for season: String in DAYS:
			IvySeasons.apply(node, int(DAYS[season]))
			cam.global_position = Vector3(0, 9.0, 12.0) if not lineup else Vector3(0, 12.0, 17.0)
			if not lineup:
				cam.global_position = Vector3(-6, 6.0, 9.0)
			cam.look_at(Vector3(-6, 0.9, 0.5) if not lineup else Vector3(0, 0.6, 2.2))
			for i in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(shots.path_join("%s_%s.png" % ["lineup" if lineup else "edge", season]))
			if not lineup:
				cam.global_position = Vector3(6, 6.0, 9.0)
				cam.look_at(Vector3(6, 0.9, 0.5))
				for i in 6:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(shots.path_join("edge2_%s.png" % season))
		node.queue_free()
		await process_frame
	quit()
