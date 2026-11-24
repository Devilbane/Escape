extends SceneTree
## One image with the rope-climbing poses side by side (see RopeClimbPose), on a plain rock slab. Run with:
## OUT=<file.png> xvfb-run -a godot --resolution 2400x520 -s tests/rope_climb_sheet.gd (needs a display).

const ORDER := ["hang", "reach_l", "pull", "hammer_up", "hammer_hit", "thread", "fall", "kneel"]
var frames := 0


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.72, 0.84)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 60, 0)
	world.add_child(sun)
	var spacing := 1.7
	for i in ORDER.size():
		var x := (i - (ORDER.size() - 1) * 0.5) * spacing
		var wall := MeshInstance3D.new()
		var slab := BoxMesh.new()
		slab.size = Vector3(0.5, 3.0, 0.9)
		wall.mesh = slab
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.48, 0.46)
		mat.roughness = 0.95
		wall.material_override = mat
		wall.position = Vector3(x - 0.75, 1.1, 0)
		world.add_child(wall)
		var hero := preload("res://assets/characters/Rogue.glb").instantiate() as Node3D
		hero.position = Vector3(x, 0, 0)
		# The hero's front is +z; turn it towards the wall (-x).
		hero.rotation.y = -PI * 0.5
		world.add_child(hero)
		var sk := hero.find_child("Skeleton3D", true, false) as Skeleton3D
		var base := ClimbPose.base_of(sk)
		var pose: Dictionary = RopeClimbPose.POSES[ORDER[i]]
		ClimbPose.apply(sk, base, pose)
		var slot := HairLook.head_slot(hero)
		if slot != null:
			slot.add_child(ClimbHelmet.build())
		var label := Label3D.new()
		label.text = ORDER[i]
		label.position = Vector3(x, 2.35, 0.5)
		label.font_size = 48
		label.pixel_size = 0.004
		world.add_child(label)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.2
	cam.position = Vector3(0, 1.05, 8)
	world.add_child(cam)
	cam.make_current()


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 12:
		var out := OS.get_environment("OUT")
		if out != "":
			root.get_texture().get_image().save_png(out)
		quit(0)
	return false
