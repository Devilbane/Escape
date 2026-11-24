extends SceneTree
## One image with the rope-climbing poses side by side (see RopeClimbPose), on a plain rock slab. Run with:
## OUT=<file.png> xvfb-run -a godot --resolution 1800x1000 -s tests/rope_climb_sheet.gd (needs a display).

## The three key sequences, one row each: [label, phase of RopeClimbPose.KEYS, time 0..1].
const ROWS := [
	[["grab", "pull_l", 0.2], ["foot search", "pull_l", 0.55], ["pull up", "pull_l", 0.78], ["over the edge", "top", 0.35], ["knee up", "top", 0.6], ["stand", "top", 1.0]],
	[["find spot", "hammer", 0.18], ["hammer up", "hammer", 0.52], ["hammer hit", "hammer", 0.62], ["clip rope", "thread", 0.35], ["check hold", "thread", 0.78], ["rest", "rest", 0.3]],
	[["slip", "slip", 1.0], ["fall", "fall", 0.9], ["rope taut", "arrest", 0.2], ["arrest", "arrest", 0.6], ["stabilize", "arrest", 1.0], ["climb down", "desc_l", 0.5]],
]
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
	for r in ROWS.size():
		for i in ROWS[r].size():
			var entry: Array = ROWS[r][i]
			var x: float = (i - (ROWS[r].size() - 1) * 0.5) * spacing
			var y: float = -r * 3.0
			var wall := MeshInstance3D.new()
			var slab := BoxMesh.new()
			slab.size = Vector3(0.5, 3.0, 0.9)
			wall.mesh = slab
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.5, 0.48, 0.46)
			mat.roughness = 0.95
			wall.material_override = mat
			wall.position = Vector3(x - 0.75, y + 1.1, 0)
			world.add_child(wall)
			var hero := preload("res://assets/characters/Rogue.glb").instantiate() as Node3D
			hero.position = Vector3(x, y, 0)
			hero.rotation.y = -PI * 0.5
			world.add_child(hero)
			var sk := hero.find_child("Skeleton3D", true, false) as Skeleton3D
			ClimbPose.apply(sk, ClimbPose.base_of(sk), RopeClimbPose.at(entry[1], float(entry[2])))
			# The weapons are stowed while climbing (see Player._stow_hands).
			for hand_name in ["handslot_r", "handslot_l"]:
				var hand := hero.find_child(hand_name, true, false) as Node3D
				if hand != null:
					hand.visible = false
			var slot := HairLook.head_slot(hero)
			if slot != null:
				slot.add_child(ClimbHelmet.build())
			var label := Label3D.new()
			label.text = str(entry[0])
			label.position = Vector3(x, y + 2.35, 0.5)
			label.font_size = 48
			label.pixel_size = 0.004
			world.add_child(label)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.6
	cam.position = Vector3(0, -1.9, 8)
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
