extends SceneTree
## The climbing animation sheet (docs/climbing_animation_sheet.md): the climber seen from behind, as he is in the
## game, in the key poses of a vertical move and of a sideways reach (right, left), with the next hand and foot
## hold marked. Run with: OUT=<file.png> xvfb-run -a godot --resolution 1800x1100 -s tests/wall_move_sheet.gd

## Rows: [title, phase, [[label, time 0..1], ...], sideways step in metres (0: straight up)].
const ROWS := [
	["Up (rock-over): sink, hop and stretch, grip, high step with the knee out, hips over the foot", "pull_l", [["1 sink", 0.18], ["2 hop, stretched", 0.27], ["3 grip", 0.4], ["4 high step", 0.56], ["5 rock over", 0.74], ["6 stand up", 0.88]], 0.0],
	["Sideways to the right: wide reach with one hand and one foot", "side_r", [["1 sink", 0.18], ["2 hop, reach", 0.3], ["3 grip", 0.42], ["4 foot out, planted", 0.56], ["5 weight over", 0.8], ["6 follow, hang", 1.0]], 1.0],
	["Sideways to the left (the mirror)", "side_l", [["1 sink", 0.18], ["2 hop, reach", 0.3], ["3 grip", 0.42], ["4 foot out, planted", 0.56], ["5 weight over", 0.8], ["6 follow, hang", 1.0]], -1.0],
]
var frames := 0


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.24, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	world.add_child(sun)
	var spacing := 2.6
	for r in ROWS.size():
		var row: Array = ROWS[r]
		var y := -r * 3.5
		var title := Label3D.new()
		title.text = String(row[0])
		title.position = Vector3(0.0, y + 2.75, 0.5)
		title.font_size = 44
		title.pixel_size = 0.0045
		world.add_child(title)
		for i in (row[2] as Array).size():
			var entry: Array = (row[2] as Array)[i]
			var x := (i - 2.5) * spacing
			var wall := MeshInstance3D.new()
			var slab := BoxMesh.new()
			slab.size = Vector3(spacing - 0.1, 3.2, 0.3)
			wall.mesh = slab
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.46, 0.44, 0.42)
			mat.roughness = 0.95
			wall.material_override = mat
			wall.position = Vector3(x, y + 1.0, -0.8)
			world.add_child(wall)
			var u: float = entry[1]
			var step: float = row[3]
			var lift := smoothstep(RopeClimbPose.PULL_ROLL, RopeClimbPose.PULL_LIFTED, u)
			var climber := WallClimber.make()
			climber.model.position = Vector3(x - step * 0.5 + step * lift, y + (0.0 if step != 0.0 else 0.5 * lift) - 0.35, -0.3)
			climber.model.rotation.y = PI
			climber.pose(RopeClimbPose.at(String(row[1]), u))
			world.add_child(climber.model)
			# The next holds: the hand's and the foot's (bright), and the ones he started on (dim).
			var hand_at := Vector3(x + step * 0.5 + (0.0 if step != 0.0 else 0.0), y + (1.95 if step != 0.0 else 2.35), -0.6)
			var foot_at := Vector3(x + step * 0.5 * 0.8, y + (0.2 if step != 0.0 else 0.55), -0.6)
			for hold in [hand_at, foot_at]:
				var knob := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = 0.11
				sphere.height = 0.22
				knob.mesh = sphere
				var km := StandardMaterial3D.new()
				km.albedo_color = Color(1.0, 0.85, 0.3)
				km.emission_enabled = true
				km.emission = Color(1.0, 0.7, 0.1)
				km.emission_energy_multiplier = 0.6
				knob.material_override = km
				knob.position = hold
				world.add_child(knob)
			var label := Label3D.new()
			label.text = String(entry[0])
			label.position = Vector3(x, y - 0.6, 0.4)
			label.font_size = 40
			label.pixel_size = 0.004
			world.add_child(label)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 11.2
	cam.position = Vector3(0, -3.0, 9)
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
