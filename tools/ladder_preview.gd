extends SceneTree
## Renders the hero's ladder climb (LadderPose) beside a plain wall and ladder, as frames
## into $SHOTS (default user://ladder_preview): up_000.png ... and down_000.png ..., one every
## 1/STEP s (or 1/$FPS s), from the side, (VIEW=angle) half from behind or (VIEW=back) from behind and above.
## Run with a display: godot --fixed-fps 60 --resolution 480x560 -s tools/ladder_preview.gd
const TALL := 3.2
const STEP := 12.0

var model: Node3D
var sk: Skeleton3D
var base: Dictionary
var cam: Camera3D


func _initialize() -> void:
	var dir := OS.get_environment("SHOTS")
	if dir == "":
		dir = ProjectSettings.globalize_path("user://ladder_preview")
	DirAccess.make_dir_recursive_absolute(dir)
	var world := Node3D.new()
	root.add_child(world)
	_scene(world)
	model = load("res://assets/characters/Rogue.glb").instantiate()
	world.add_child(model)
	model.rotation.y = PI * 0.5 # Faces +x, towards the wall.
	for part in Player.HIDDEN_PARTS:
		var node := model.find_child(part, true, false)
		if node:
			node.visible = false
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	player.play("Idle")
	player.seek(0.0, true)
	player.pause()
	sk = model.find_child("Skeleton3D", true, false)
	await process_frame
	base = ClimbPose.base_of(sk)
	for way in ["up", "down"]:
		var keys := LadderPose.up_keys(TALL, -0.65) if way == "up" else LadderPose.down_keys(TALL, LadderPose.TOP_FORWARD)
		var step := float(OS.get_environment("FPS")) if OS.get_environment("FPS") != "" else STEP
		var n := ceili(LadderPose.length(keys) * step) + 1
		for i in n:
			var s := LadderPose.at(keys, i / step)
			model.position = Vector3(float(s.forward), float(s.height), 0)
			_follow(model.position)
			ClimbPose.apply(sk, base, s.pose)
			await process_frame
			await process_frame
			root.get_texture().get_image().save_png(dir.path_join("%s_%03d.png" % [way, i]))
	quit()


## A wall with a flat roof whose edge is at x 0 (the house is towards +x), the ladder
## against it, the ground, a sun and a camera.
func _scene(world: Node3D) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.42, 0.38)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(sun)
	_box(world, Vector3(0, -0.05, 0), Vector3(12, 0.1, 6), Color(0.35, 0.5, 0.25))
	_box(world, Vector3(1.0, TALL * 0.5, 0), Vector3(2.0, TALL, 3.0), Color(0.62, 0.55, 0.45))
	var wood := Color(0.45, 0.3, 0.16)
	var line := -0.18
	for z in [-0.3, 0.3]:
		_box(world, Vector3(line, (TALL + 1.0) * 0.5, z), Vector3(0.07, TALL + 1.0, 0.07), wood)
	var y := 0.3
	while y < TALL + 0.75:
		_box(world, Vector3(line, y, 0), Vector3(0.05, 0.05, 0.6), wood)
		y += 0.3
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.0
	world.add_child(cam)
	cam.current = true


## Keeps the hero (feet at `feet`) in the middle of the picture.
func _follow(feet: Vector3) -> void:
	var aim := Vector3(-0.1, feet.y + 0.75, 0)
	var from := Vector3(0, 0, 8)
	match OS.get_environment("VIEW"):
		"back": from = Vector3(-5.0, 2.0, 3.6)
		"angle": from = Vector3(-4.0, 0.8, 6.5)
	cam.look_at_from_position(aim + from, aim, Vector3.UP)


func _box(parent: Node3D, at: Vector3, size: Vector3, colour: Color) -> void:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	m.material_override = mat
	m.position = at
	parent.add_child(m)
