extends SceneTree
## Headless test of the squirrel's bound: the body stretches and gathers, and every leg joins
## its paw to the body. With SHOTS=<folder> and a display it also saves a strip of one bound
## there (STATE=hop|flee|climb picks the gait).
## Run with: godot --headless -s tests/squirrel_shots.gd

var frames := 0
var shots := OS.get_environment("SHOTS")
var strip: Array[Image] = []
var s: Squirrel
var failures := 0
var stretches: Array[float] = []


## A squirrel that builds itself but skips its tree and level.
class Posed extends Squirrel:
	func _ready() -> void:
		_build()


func _initialize() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.6, 0.35)
	ground.material_override = gm
	root.add_child(ground)
	s = Posed.new()
	root.add_child(s)
	s.rotation.y = PI * 0.5  # faces +x
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.5, 3.0), Vector3(0, 0.4, 0))
	cam.fov = 30


func _process(_delta: float) -> bool:
	frames += 1
	var st := OS.get_environment("STATE") if OS.get_environment("STATE") != "" else "hop"
	s.state = st
	if frames < 4:
		return false
	if shots == "":
		_check_bound()
		return true
	var n := 6
	# Run the pose to a steady state at six points of one bound.
	var idx := (frames - 4) / 8
	if idx < n:
		var sub := (frames - 4) % 8
		if sub == 0:
			s._phase = float(idx) / float(n) * PI + 0.01
			s._hop_height = Squirrel.HOP_HEIGHT.y if st == "flee" else Squirrel.HOP_HEIGHT.x
		s._pose(0.2)
		if sub == 7:
			strip.append(root.get_viewport().get_texture().get_image())
		return false
	var w := strip[0].get_width()
	var h := strip[0].get_height()
	var out := Image.create(w * n, h, false, strip[0].get_format())
	for k in n:
		out.blit_rect(strip[k], Rect2i(0, 0, w, h), Vector2i(k * w, 0))
	out.save_png("%s/%s.png" % [shots, st])
	quit()
	return true


## Steps through one bound without drawing it.
func _check_bound() -> void:
	for step in 12:
		s._phase = float(step) / 12.0 * PI + 0.01
		s._hop_height = Squirrel.HOP_HEIGHT.x
		for i in 8:
			s._pose(0.2)
		stretches.append(s._body.scale.z)
		for i in 2:
			for pair: Array in [[s._hand_legs[i], s._hands[i]], [s._foot_legs[i], s._feet[i]]]:
				var leg: Node3D = pair[0]
				var paw: Node3D = pair[1]
				var tip := leg.position + leg.basis * Vector3(0, 0, 1)
				if tip.distance_to(paw.position + Vector3(0, 0.02, 0)) > 0.005:
					failures += 1
					print("FAIL: a leg ends away from its paw (%.3f)" % tip.distance_to(paw.position))
					return
	var lo: float = stretches.min()
	var hi: float = stretches.max()
	if hi - lo < 0.3 * Squirrel.SIZE:
		failures += 1
		print("FAIL: the body should stretch and gather over a bound (%.2f to %.2f)" % [lo, hi])
	print("PASS: squirrel bound" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
