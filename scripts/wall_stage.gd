class_name WallStage
extends Control
## The climbing wall seen and climbed: the 3D wall of a WallMap (WallBuild) in a view of its own, the
## mountaineer in his climbing set (WallClimber) on it, the rules (WallClimb) and the keys. Used by the wall
## workshop (to look at a wall and test it) and by the game (when the hero climbs a placed wall, see
## WallPlacements).
##
## Keys: arrows or WASD climb one square (a move onto the far side of a gap is a jump), Space held braces
## against the rock, the mouse wheel zooms, dragging with the right mouse button turns the view, Esc leaves.
## `finished(outcome)` says how it ended: "top" (on the summit), "gave_up" (three falls to a nail) or "left".
##
## The weather matters (see WallWeather): it changes the holds' chances, puts ice on the wall in the cold, makes
## jumps harder in wind, and in rain and storm stones fall from above: first a rattle and a trickle of dust
## in a column of the wall (the warning, WARN_SECONDS), then the stone. A climber in its column when it passes
## is knocked off the wall, unless they brace (Space held) or step aside. With `drift` the weather turns worse
## on its own while the climb lasts (every WORSEN_EVERY seconds): a change that comes while someone hangs on
## the wall is a danger.

signal finished(outcome: String)
## A line for the message strip (German, already through Lang).
signal told(text: String)
## The climber's state changed (moved, fell, set a nail): the status line and the 2D canvas look again.
signal changed
## The weather changed (a name from WallWeather).
signal weather_changed(weather: String)
## A stone grazed the climber: the hit points they lose (the game takes them off the hero).
signal hurt(amount: int)
## The climber reached a square with a goal or event (a key of WallMap.MARKERS) for the first time.
signal marker_reached(kind: String, cell: Vector2i)

const FOLLOW_DISTANCE := 10.0
const OVERVIEW_MARGIN := 1.25
const WARN_SECONDS := 1.5
const GRAVITY := 11.0
const GRAZE_DAMAGE := 3
## Meter spent per second of bracing against the rock.
const BRACE_COST := 1.5
const WORSEN_EVERY := 70.0
## The climber's height (metres) where the cloud sea begins to fill the foot of the view, and is full.
const CLOUD_FROM := 7.0
const CLOUD_FULL := 12.0
## How much of the view's height the cloud band takes.
const CLOUD_BAND := 0.42
const SEQUENCE := [WallWeather.CLEAR, WallWeather.WIND, WallWeather.RAIN, WallWeather.STORM]
## Seconds of each move's animation.
const SECONDS := {"up": 2.2, "side": 2.4, "down": 1.8, "leap": 1.1}
const HAMMER_SECONDS := 2.2
const THREAD_SECONDS := 1.4
const TOP_SECONDS := 2.0
const FALL_SECONDS := 0.8
const REST_SECONDS := 2.4
## A leap: crouch, spring and reach (poses on top of RopeClimbPose's).
const LEAP_POSES := {
	"crouch": {"hips_y": -0.14, "spine": 18.0, "head": -20.0, "arm": 150.0, "elbow": 30.0, "hip_l": 70.0, "hip_r": 70.0, "knee_l": 100.0, "knee_r": 100.0},
	# Both arms stretched out ahead to the target while the legs push off (flight), then the catch: the arms bend and
	# the knees come up for the new stand.
	"spring": {"hips_y": 0.1, "spine": -8.0, "head": -26.0, "arm_l": 0.0, "out_l": 50.0, "lift_l": 120.0, "elbow_l": 0.0, "arm_r": 0.0, "out_r": 50.0, "lift_r": 120.0, "elbow_r": 0.0, "hip_l": 8.0, "hip_r": 12.0, "knee_l": 8.0, "knee_r": 14.0, "abd_l": 20.0, "abd_r": 20.0},
	"catch": {"hips_y": -0.06, "spine": 12.0, "head": -24.0, "arm": 150.0, "elbow": 75.0, "hip_l": 72.0, "hip_r": 66.0, "knee_l": 92.0, "knee_r": 88.0, "abd_l": 30.0, "abd_r": 30.0},
}
const SKY := {
	WallWeather.CLEAR: [Color(0.43, 0.56, 0.72), 1.15, 0.7],
	WallWeather.WIND: [Color(0.5, 0.6, 0.7), 1.0, 0.65],
	WallWeather.RAIN: [Color(0.27, 0.3, 0.34), 0.5, 0.45],
	WallWeather.SNOW: [Color(0.72, 0.75, 0.8), 0.8, 0.8],
	WallWeather.STORM: [Color(0.15, 0.16, 0.19), 0.3, 0.3],
}

var map: WallMap
var wall: WallMap
var climb: WallClimb
var interactive := true
var drift := false
## Set by a test: the climber braces without a key held.
var force_brace := false
var weather := WallWeather.CLEAR
var rng := RandomNumberGenerator.new()
var view: SubViewport
var camera: Camera3D
var wall_root: Node3D
var climber: WallClimber
var follow := false
var feet := Vector3.ZERO
var stones: Array[Dictionary] = []
var _env: Environment
var _sun: DirectionalLight3D
var _builder: WallBuild
var _ice: MeshInstance3D
var _nails_root: Node3D
var _rope_root: Node3D
var _queue: Array[Dictionary] = []
var _step_t := 0.0
var _left := true
## The camera looks a little from the side so that both arms and legs read from behind.
var _yaw := 0.28
var _pitch := 0.12
var _zoom := 1.0
var _drag := false
var _status: Label
var _meter: Control
var _strip: Label
var _rain: CPUParticles3D
var _clouds: ColorRect
var _cloud_mat: ShaderMaterial
var _cloud_density := 0.0
var _fall_timer := 0.0
var _worsen_timer := 0.0
var _weather_audio: AudioStreamPlayer
var _flash := 0.0
var _seen := {}
var _judged := {}
## What the climber made of each crack he looked at (key as in `_judged`), for Wolfram's own decisions.
var _reads := {}
## Wolfram climbing by himself (see WallAuto), the pause before his next move, and his bubble and voice.
var auto: WallAuto
var _auto_wait := 0.0
var _bubble: Label3D
var _bubble_time := 0.0
## How often the climber has shouted (the tests count them).
var shouts := 0
var _voice: AudioStreamPlayer
signal auto_finished(how: String)
var _flash_timer := 6.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	view = SubViewport.new()
	view.own_world_3d = true
	view.handle_input_locally = false
	holder.add_child(view)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.62, 0.66, 0.74)
	var we := WorldEnvironment.new()
	we.environment = _env
	view.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-35, 28, 0)
	_sun.shadow_enabled = true
	view.add_child(_sun)
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.far = 400.0
	view.add_child(camera)
	_rain = _make_precipitation()
	camera.add_child(_rain)
	_weather_audio = AudioStreamPlayer.new()
	_weather_audio.bus = Sfx.BUS
	_weather_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	_weather_audio.finished.connect(func() -> void:
		if _weather_audio.stream != null and is_inside_tree():
			_weather_audio.play())
	add_child(_weather_audio)
	_clouds = ColorRect.new()
	_clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clouds.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_clouds.anchor_top = 1.0 - CLOUD_BAND
	_clouds.offset_top = 0
	_clouds.offset_bottom = 0
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = preload("res://shaders/wall_cloud_band.gdshader")
	_clouds.material = _cloud_mat
	add_child(_clouds)
	_status = UiKit.label(UiKit.TEXT_FONT, UiKit.sized(18), UiKit.GOLD)
	_status.position = Vector2(14, 10)
	add_child(_status)
	_meter = Control.new()
	_meter.position = Vector2(14, 40)
	_meter.custom_minimum_size = Vector2(220, 16)
	_meter.size = Vector2(220, 16)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	add_child(_meter)
	_strip = UiKit.label(UiKit.TEXT_FONT, UiKit.sized(18), Color(0.95, 0.92, 0.85))
	_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_strip.offset_left = 14
	_strip.offset_bottom = -12
	_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_strip)
	if map != null:
		_build()


## Shows `base` with a climber of Klettern `level` in `sky` weather. Without `play` the keys do nothing and the
## camera looks over the whole wall.
func setup(base: WallMap, level: int, play := true, sky := WallWeather.CLEAR, constitution := 10) -> void:
	map = base
	interactive = play
	follow = play
	weather = sky if WallWeather.known(sky) else WallWeather.CLEAR
	wall = WallWeather.frosted(base, weather)
	climb = WallClimb.new(wall, level)
	climb.weather = weather
	climb.set_constitution(constitution)
	_queue.clear()
	_seen.clear()
	_judged.clear()
	_reads.clear()
	_bubble = null
	auto = null
	if is_inside_tree():
		_build()


func _build() -> void:
	for n in [wall_root, _rope_root]:
		if n != null:
			n.queue_free()
	for s in stones:
		if is_instance_valid(s.node):
			s.node.queue_free()
	stones.clear()
	_builder = WallBuild.new(wall)
	wall_root = WallBuild.node(wall)
	_ice = wall_root.get_node_or_null("Ice") as MeshInstance3D
	view.add_child(wall_root)
	wall_root.add_child(_ground())
	_nails_root = Node3D.new()
	wall_root.add_child(_nails_root)
	_rope_root = Node3D.new()
	wall_root.add_child(_rope_root)
	if climber != null and is_instance_valid(climber.model):
		climber.model.queue_free()
	climber = WallClimber.make()
	wall_root.add_child(climber.model)
	_build_markers()
	feet = feet_of(climb.cell)
	_put_body()
	_apply_sky(true)
	_update_status()
	_apply_camera(1.0)
	_fall_timer = _next_fall()


## The signs of the goals and events on the wall, and the dead climber hanging in his rope where there is one.
func _build_markers() -> void:
	for cell: Vector2i in wall.markers:
		var kind := String(wall.markers[cell])
		var xy := WallBuild.square_centre(wall, cell.x, cell.y)
		var z := _builder.depth_at(xy.x, xy.y)
		var label := Label3D.new()
		label.text = Lang.t(String(WallMap.MARKERS[kind].name))
		label.font_size = 56
		label.pixel_size = 0.006
		label.outline_size = 16
		label.modulate = WallMap.MARKERS[kind].colour
		label.outline_modulate = Color(0.02, 0.02, 0.03)
		label.shaded = false
		label.position = Vector3(xy.x, xy.y + 1.1, z + 0.6)
		wall_root.add_child(label)
		if kind == "body":
			var dead := WallClimber.make()
			dead.model.position = Vector3(xy.x + 0.6, xy.y - 1.9, z + 0.55)
			dead.model.rotation.y = PI
			dead.pose(ClimbPose.mix(RopeClimbPose.POSES["fall"], RopeClimbPose.POSES["rest"], 0.4))
			wall_root.add_child(dead.model)
			WallFrost.freeze(dead.model, int(cell.x * 31 + cell.y))


## The ground at the foot: the same weathered rock, drawn flat.
func _ground() -> MeshInstance3D:
	var quad := ArrayMesh.new()
	var w := float(map.width)
	var verts := PackedVector3Array([Vector3(-30, 0, -2), Vector3(w + 30, 0, -2), Vector3(w + 30, 0, 30), Vector3(-30, 0, 30)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([WallBuild.ROCK_DARK, WallBuild.ROCK_DARK, WallBuild.ROCK_DARK, WallBuild.ROCK_DARK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = quad
	mi.material_override = AgedStone.rock_material()
	return mi


## Where the climber's feet are when the hands hold square `cell` (WallClimb.NOWHERE: on the ground).
func feet_of(cell: Vector2i) -> Vector3:
	if cell == WallClimb.NOWHERE:
		return Vector3(_start_column(), 0.0, 1.0)
	var xy := WallBuild.square_centre(wall, cell.x, cell.y)
	return Vector3(xy.x, maxf(0.0, xy.y - 1.7), _builder.depth_at(xy.x, xy.y) + 0.55)


func _start_column() -> float:
	for c in wall.width:
		if wall.is_start(c, wall.height - 1):
			return c + 0.5
	return wall.width * 0.5


func _put_body() -> void:
	climber.model.position = feet
	climber.model.rotation.y = PI


func _make_precipitation() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 700
	p.lifetime = 1.2
	p.position = Vector3(0, 9, -9)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 0.2, 9)
	p.direction = Vector3(0.15, -1, 0)
	p.spread = 4.0
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 18.0
	p.gravity = Vector3(0, -12, 0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012, 0.45, 0.012)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.82, 0.95, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.mesh = mesh
	return p


# --- weather ---------------------------------------------------------------------------------------------

## Changes the weather (a WallWeather name): the sky, the rain or snow, the ice, and the climber's chances.
## `warn` tells the climber (the message strip) what it means.
func set_weather(sky: String, warn := true) -> void:
	if not WallWeather.known(sky) or sky == weather:
		return
	var worse := WallWeather.ORDER.find(sky) > WallWeather.ORDER.find(weather)
	weather = sky
	wall = WallWeather.frosted(map, weather)
	climb.weather = weather
	_builder = WallBuild.new(wall)
	_swap_ice()
	_apply_sky(false)
	if warn:
		_tell("%s %s" % [Lang.t("Das Wetter schlägt um: %s!") % Lang.t(String(WallWeather.DATA[sky].name)),
				Lang.t(_warning(sky)) if worse else Lang.t("Es wird besser.")], true)
	weather_changed.emit(weather)
	_update_status()


static func _warning(sky: String) -> String:
	match sky:
		WallWeather.RAIN:
			return "Der Fels wird nass und glatt, und von oben löst sich Gestein."
		WallWeather.SNOW:
			return "Eis legt sich auf den Fels."
		WallWeather.WIND:
			return "Sprünge über Spalten werden gefährlicher."
		WallWeather.STORM:
			return "Alles ist schwerer, und Steine fallen. Such Deckung oder gib auf."
	return "Es klart auf."


## The ice of the wall as it is in this weather (the cold adds squares, see WallWeather.frosted).
func _swap_ice() -> void:
	if _ice != null:
		_ice.queue_free()
		_ice = null
	var mesh := _builder.ice_mesh()
	if mesh == null:
		return
	_ice = MeshInstance3D.new()
	_ice.name = "Ice"
	_ice.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = WallBuild.ICE_SHADER
	_ice.material_override = mat
	wall_root.add_child(_ice)


func _apply_sky(instant: bool) -> void:
	var s: Array = SKY[weather]
	_env.background_color = s[0]
	_sun.light_energy = float(s[1])
	_env.ambient_light_energy = float(s[2])
	_env.ambient_light_color = (s[0] as Color).lerp(Color(0.7, 0.72, 0.78), 0.5)
	var wet := weather == WallWeather.RAIN or weather == WallWeather.STORM
	var snowing := weather == WallWeather.SNOW
	_rain.emitting = wet or snowing
	if snowing:
		_rain.amount = 300
		_rain.lifetime = 4.0
		_rain.initial_velocity_min = 1.0
		_rain.initial_velocity_max = 2.0
		_rain.gravity = Vector3(0, -1.2, 0)
		var flake := SphereMesh.new()
		flake.radius = 0.03
		flake.height = 0.06
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.97, 1.0)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flake.material = m
		_rain.mesh = flake
	elif wet:
		_rain.amount = 1100 if weather == WallWeather.STORM else 600
		_rain.lifetime = 1.2
		_rain.initial_velocity_min = 14.0
		_rain.initial_velocity_max = 18.0
		_rain.gravity = Vector3(0, -12, 0)
		var drop := BoxMesh.new()
		drop.size = Vector3(0.012, 0.45, 0.012)
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.75, 0.82, 0.95, 0.55)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop.material = dm
		_rain.mesh = drop
	var sound := ""
	if weather == WallWeather.STORM:
		sound = "rain_heavy"
	elif weather == WallWeather.RAIN:
		sound = "rain_light"
	elif weather == WallWeather.WIND:
		sound = "dungeon_wind_0"
	if sound == "":
		_weather_audio.stop()
		_weather_audio.stream = null
	elif is_inside_tree() and not instant or sound != "":
		_weather_audio.stream = load(Sfx.DIR + sound + ".ogg")
		_weather_audio.volume_db = -8.0
		if is_inside_tree() and not DisplayServer.get_name() == "headless":
			_weather_audio.play()
	if not instant and weather == WallWeather.STORM and is_inside_tree():
		Sfx.play(self, "thunder", -4.0)


# --- the view --------------------------------------------------------------------------------------------

func _update_status() -> void:
	if climb == null:
		return
	var up := 0 if climb.on_ground() else wall.height - climb.cell.y
	_status.text = Lang.t("Klettern %d · Höhe %d m · Stürze %d · %s · %s") % [climb.skill, up, climb.falls, Lang.t(String(WallWeather.DATA[weather].name)), climb.time_text()]
	_apply_light()
	changed.emit()


## The light of the hour: dusk dims the sky, night is dark.
func _apply_light() -> void:
	if climb == null or _sun == null or _env == null:
		return
	var f: float = [1.0, 0.65, 0.28][climb.darkness()]
	var s: Array = SKY[weather]
	_sun.light_energy = float(s[1]) * f
	_env.ambient_light_energy = float(s[2]) * (0.45 + 0.55 * f)
	_env.background_color = (s[0] as Color) * f
	if _clouds != null:
		_clouds.modulate = Color(f, f, minf(1.0, f + 0.15), 1.0)


## R: catches breath on the wall, or spends the time at a rest place (the night, by evening).
func rest_here() -> int:
	if climb == null or busy() or climb.on_ground():
		return WallClimb.Outcome.BLOCKED
	if climb.at_camp():
		var night := climb.darkness() > 0
		climb.bivouac()
		_queue_camp(feet)
		_tell("Du rastest bis zum Morgen und bist ausgeruht." if night else "Du rastest ein paar Stunden und kommst wieder zu Atem.")
		_update_status()
		return WallClimb.Outcome.CAMPED
	climb.catch_breath()
	_tell(Lang.t("Du hängst dich in den Fels und holst Luft."))
	_update_status()
	return WallClimb.Outcome.RESTED


## Starts Wolfram's own climb: he plans a route and goes up it, move by move.
func start_auto() -> void:
	if climb == null:
		return
	auto = WallAuto.new()
	auto.plan(map, climb.skill, weather, Vector2i(int(_start_column() - 0.5), wall.height - 1))
	_auto_wait = 1.0
	interactive = true


func stop_auto() -> void:
	auto = null


## The climber shouts: a speech bubble over his head for a moment, and the sound that goes with it.
func shout(kind: String) -> void:
	if climber == null:
		return
	var text := WallVoice.line(kind, rng)
	if text == "":
		return
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.font_size = 64
		_bubble.pixel_size = 0.006
		_bubble.outline_size = 18
		_bubble.shaded = false
		_bubble.no_depth_test = true
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.modulate = Color(1.0, 0.95, 0.7)
		_bubble.outline_modulate = Color(0.1, 0.05, 0.02)
		wall_root.add_child(_bubble)
	shouts += 1
	_bubble.text = Lang.t(text)
	_bubble.visible = true
	_bubble_time = 2.4
	told.emit(_bubble.text)
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		if _voice == null:
			_voice = AudioStreamPlayer.new()
			add_child(_voice)
		_voice.stream = WallVoice.sound(kind)
		_voice.volume_db = -6.0
		_voice.play()


func _tick_auto(delta: float) -> void:
	if _bubble != null and _bubble.visible:
		_bubble_time -= delta
		_bubble.position = climber.model.position + Vector3(0, 2.6, 0.5)
		if _bubble_time <= 0.0:
			_bubble.visible = false
	if auto == null or climb == null or busy():
		return
	_auto_wait -= delta
	if _auto_wait > 0.0:
		return
	_auto_wait = 0.8
	var read := {}
	if not climb.on_ground():
		for gi in wall.gaps.size():
			read = _reads.get(Vector3i(climb.cell.x, climb.cell.y, gi), read)
	var act := auto.decide(climb, read)
	match act.do:
		WallAuto.Do.STOP:
			var how := auto.ended
			if how == "turned":
				shout("turn")
			auto = null
			auto_finished.emit(how)
		WallAuto.Do.REST, WallAuto.Do.CAMP:
			rest_here()
		WallAuto.Do.LOOK, WallAuto.Do.MOVE:
			var out := step(int(act.dir))
			if out == WallClimb.Outcome.TOP:
				auto = null
				auto_finished.emit("top")
			elif out == WallClimb.Outcome.GAVE_UP:
				auto = null
				auto_finished.emit("gave_up")


func _process(delta: float) -> void:
	if wall == null or camera == null or climber == null:
		return
	_tick_auto(delta)
	_tick_animation(delta)
	_tick_stones(delta)
	_tick_weather(delta)
	_tick_clouds(delta)
	_apply_camera(minf(1.0, delta * 5.0))


func _apply_camera(weight: float) -> void:
	var target: Vector3
	var distance: float
	if follow:
		target = climber.model.position + Vector3(0, 1.4, 0)
		distance = FOLLOW_DISTANCE * _zoom
	else:
		target = Vector3(wall.width * 0.5, wall.height * 0.5, 0.0)
		distance = maxf(wall.height, wall.width * 0.6) * OVERVIEW_MARGIN * _zoom * 1.05
	var offset := Vector3(0, 0, distance).rotated(Vector3.RIGHT, -_pitch).rotated(Vector3.UP, _yaw)
	camera.position = camera.position.lerp(target + offset, weight)
	camera.look_at(target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = clampf(_zoom * 0.9, 0.3, 2.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = clampf(_zoom * 1.1, 0.3, 2.5)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed and get_global_rect().has_point(mb.global_position)
	elif event is InputEventMouseMotion and _drag:
		var mm := event as InputEventMouseMotion
		_yaw = clampf(_yaw - mm.relative.x * 0.006, -1.2, 1.2)
		_pitch = clampf(_pitch + mm.relative.y * 0.006, -0.3, 0.9)
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			finished.emit("left")
			get_viewport().set_input_as_handled()
			return
		if not interactive:
			return
		if key == KEY_R:
			rest_here()
			get_viewport().set_input_as_handled()
			return
		var dir := 0
		match key:
			KEY_UP, KEY_W:
				dir = WallMap.UP
			KEY_DOWN, KEY_S:
				dir = WallMap.DOWN
			KEY_LEFT, KEY_A:
				dir = WallMap.LEFT
			KEY_RIGHT, KEY_D:
				dir = WallMap.RIGHT
		if dir != 0:
			step(dir)
			get_viewport().set_input_as_handled()


## Whether the climber braces against the rock (Space held).
func bracing() -> bool:
	return interactive and (force_brace or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT))


## Whether the climber is in the middle of an animation (nothing new can be tried until it is over).
func busy() -> bool:
	return not _queue.is_empty()


## One move in a direction with random rolls (the keys call it). Returns the outcome (BLOCKED when busy).
func step(dir: int) -> int:
	if climb == null or busy() or bracing():
		return WallClimb.Outcome.BLOCKED
	var mv := climb.move_in(dir)
	if not mv.is_empty() and mv.kind == "jump":
		# The first push towards a gap is a look at it (a roll of Weisheit and Intuition); the second jumps.
		var key := Vector3i(climb.cell.x, climb.cell.y, int(mv.gap))
		if not _judged.has(key):
			_judged[key] = true
			var read := climb.judge(mv, rng.randf(), rng.randf())
			_reads[key] = read
			_tell(Lang.t(String(read.text)) + " " + Lang.t("Noch einmal drücken, um zu springen."), true)
			return WallClimb.Outcome.BLOCKED
	return try_move(dir, rng.randf(), rng.randf())


## One move with the given rolls (a test plays with fixed ones).
func try_move(dir: int, roll: float, fall_roll: float) -> int:
	var mv := climb.move_in(dir)
	var from := climb.cell
	var out := climb.go(dir, roll, fall_roll)
	var to := climb.cell
	match out:
		WallClimb.Outcome.BLOCKED:
			if mv.is_empty():
				_tell("Dort ist kein Halt.")
			return out
		WallClimb.Outcome.NAILED:
			_tell("Du schlägst einen Nagel in den Fels: ein Sicherungspunkt.")
		WallClimb.Outcome.SLIPPED:
			_tell("Abgerutscht! Noch ein Versuch.")
			shout("jump_miss" if mv.kind == "jump" else "slip")
		WallClimb.Outcome.RESTED:
			_tell("Du verschnaufst am Fels.")
		WallClimb.Outcome.FELL:
			shout("jump_miss" if mv.kind == "jump" else "fall")
			var why := Lang.t("Der Sprung misslingt! ") if mv.kind == "jump" else ""
			_tell(why + Lang.t("Du stürzt %d m tief.") % int(round(climb.last_fall)), true)
		WallClimb.Outcome.EXHAUSTED:
			shout("fall")
			_tell(Lang.t("Deine Arme geben nach! ") + Lang.t("Du stürzt %d m tief.") % int(round(climb.last_fall)), true)
		WallClimb.Outcome.GAVE_UP:
			_tell("Du gibst auf und seilst dich ab.")
		WallClimb.Outcome.TOP:
			_tell("Geschafft: du stehst am Gipfel!")
		WallClimb.Outcome.MOVED:
			if mv.kind == "jump":
				_tell("Du springst über die Spalte und bekommst den Griff zu fassen.")
				shout("cheer")
	if out == WallClimb.Outcome.FELL or out == WallClimb.Outcome.GAVE_UP or out == WallClimb.Outcome.EXHAUSTED:
		hurt.emit(RockClimb.fall_damage(climb.last_fall))
	_animate(out, mv, from, to, dir)
	if to != WallClimb.NOWHERE and wall.marker_at(to.x, to.y) != "" and not _seen.has(to):
		_seen[to] = true
		var kind := wall.marker_at(to.x, to.y)
		_tell(String(WallMap.MARKERS[kind].text))
		marker_reached.emit(kind, to)
	return out


## What the outcome of a move looks like: the move itself (if it was made), then the hammer, the slip, the
## fall. `from` and `to` are the squares before and after (the climber's cell after the move is `to`).
func _animate(out: int, mv: Dictionary, from: Vector2i, to: Vector2i, dir: int) -> void:
	var here := feet
	var there := feet_of(to)
	var made := out == WallClimb.Outcome.MOVED or out == WallClimb.Outcome.NAILED or out == WallClimb.Outcome.TOP
	if made:
		var kind := "leap" if mv.kind == "jump" else ("up" if dir == WallMap.UP else ("down" if dir == WallMap.DOWN else "side"))
		if from == WallClimb.NOWHERE:
			kind = "up"
		var key := ""
		_left = not _left
		match kind:
			"up":
				key = "pull_l" if _left else "pull_r"
			"down":
				key = "desc_l" if _left else "desc_r"
			"side":
				key = "side_l" if dir == WallMap.LEFT else "side_r"
			"leap":
				key = "leap"
		_queue.append({"key": key, "secs": float(SECONDS[kind]), "from": here, "to": there, "kind": kind})
		if out == WallClimb.Outcome.NAILED:
			_queue.append({"key": "hammer", "secs": HAMMER_SECONDS, "from": there, "to": there, "hammer": true, "nail": true})
			_queue.append({"key": "thread", "secs": THREAD_SECONDS, "from": there, "to": there})
		elif out == WallClimb.Outcome.TOP:
			_queue.append({"key": "top", "secs": TOP_SECONDS, "from": there, "to": there + Vector3(0, 1.3, -0.35), "kind": "top"})
	else:
		match out:
			WallClimb.Outcome.SLIPPED:
				_queue.append({"key": "slip", "secs": 0.55, "from": here, "to": here, "sound": "step_scree_1"})
			WallClimb.Outcome.RESTED:
				_queue.append({"key": "slip", "secs": 0.4, "from": here, "to": here})
				_queue.append({"key": "rest", "secs": REST_SECONDS, "from": here, "to": here})
			WallClimb.Outcome.FELL, WallClimb.Outcome.GAVE_UP, WallClimb.Outcome.EXHAUSTED:
				_queue_fall(here, there, climb.nail != WallClimb.NOWHERE)
	if out == WallClimb.Outcome.GAVE_UP:
		_queue.append({"key": "stand", "secs": 0.8, "from": there, "to": there, "end": "gave_up"})
	elif out == WallClimb.Outcome.TOP:
		_queue.append({"key": "stand", "secs": 0.8, "from": there + Vector3(0, 1.3, -0.35), "to": there + Vector3(0, 1.3, -0.35), "end": "top"})
	_step_t = 0.0
	_update_status()


## A slip, the drop to where the fall ends and the rope going taut (when a nail catches) or the ground.
func _queue_fall(here: Vector3, there: Vector3, roped: bool) -> void:
	_queue.append({"key": "slip", "secs": 0.35, "from": here, "to": here, "sound": "step_scree_2"})
	_queue.append({"key": "fall", "secs": FALL_SECONDS, "from": here, "to": there, "kind": "fall", "sound": "word_wumm" if not roped else ""})
	if roped:
		_queue.append({"key": "arrest", "secs": 1.0, "from": there, "to": there, "sound": "chain"})
	else:
		_queue.append({"key": "stand", "secs": 0.6, "from": there, "to": there, "sound": "hit"})


## The breath meter (the hero's run meter): a bar that turns red when the arms tire.
func _draw_meter() -> void:
	if climb == null:
		return
	var share := clampf(climb.stamina / maxf(0.01, climb.stamina_max), 0.0, 1.0)
	_meter.draw_rect(Rect2(Vector2.ZERO, _meter.size), Color(0.05, 0.03, 0.02, 0.8))
	var tired := share < WallClimb.TIRED_BELOW
	_meter.draw_rect(Rect2(Vector2(2, 2), Vector2((_meter.size.x - 4) * share, _meter.size.y - 4)), Color(0.85, 0.3, 0.2) if tired else Color(0.35, 0.75, 0.45))
	_meter.draw_rect(Rect2(Vector2.ZERO, _meter.size), UiKit.BRONZE, false, 2.0)


func _tick_animation(delta: float) -> void:
	if _queue.is_empty() and not bracing():
		climb.recover(delta)
	elif bracing():
		climb.stamina = maxf(0.0, climb.stamina - BRACE_COST * delta)
	_meter.queue_redraw()
	if _queue.is_empty():
		if bracing() and not climb.on_ground():
			climber.pose(RopeClimbPose.at("arrest", 0.5))
		elif not _queue.is_empty():
			pass
		else:
			climber.pose({})
			if not climb.on_ground():
				climber.pose(RopeClimbPose.at("rest", 0.0))
		_rope_update()
		return
	var st: Dictionary = _queue[0]
	if _step_t == 0.0 and st.has("sound") and String(st.sound) != "":
		Sfx.play(self, String(st.sound), -6.0)
	if _step_t == 0.0:
		climber.hammer(bool(st.get("hammer", false)))
	_step_t += delta
	var u := clampf(_step_t / float(st.secs), 0.0, 1.0)
	var key := String(st.key)
	var from: Vector3 = st.from
	var to: Vector3 = st.to
	var at := to
	match key:
		"stand":
			climber.pose({})
			at = to
		"leap":
			climber.pose(_leap_pose(u))
			var t := smoothstep(0.35, 0.8, u)
			at = from.lerp(to, t) + Vector3(0, sin(t * PI) * 0.7, 0)
		"bed":
			# Lying in the hammock on his side, breathing slowly.
			climber.pose(ClimbPose.mix(RopeClimbPose.POSES["rest"], {}, 0.6))
			var into := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.85, 1.0, u))
			climber.model.rotation.z = -into * PI * 0.5
			at = from + Vector3(WallHammock.SPAN * 0.4 * into, 0.62 * into, (0.05 - from.z + 0.9) * into * 0.0 + 0.1 * into)
		"fall":
			climber.pose(RopeClimbPose.at("fall", u))
			at = from.lerp(to, u * u)
		"top":
			climber.pose(RopeClimbPose.at("top", u))
			at = from.lerp(to, smoothstep(0.1, 0.9, u))
		_:
			climber.pose(RopeClimbPose.at(key, u))
			var lift := smoothstep(RopeClimbPose.PULL_ROLL, RopeClimbPose.PULL_LIFTED, u) if (key.begins_with("pull") or key.begins_with("side") or key.begins_with("desc")) else 1.0
			if key.begins_with("side"):
				# The body goes across once the hand and the foot have reached and gripped (no jump).
				lift = smoothstep(RopeClimbPose.PULL_ROLL, RopeClimbPose.PULL_LIFTED, u)
			at = from.lerp(to, lift)
			if key.begins_with("pull") or key.begins_with("side"):
				# The small hop before the reach: the feet leave the rock for a moment.
				at.y += 0.14 * sin(clampf((u - 0.2) / 0.14, 0.0, 1.0) * PI)
	feet = at
	climber.model.position = feet
	_slack = 0.9 * (1.0 - u * u) * sin(minf(1.0, u * 3.0) * PI * 0.5) if key == "fall" else 0.0
	if key != "bed":
		climber.model.rotation.z = 0.0
	if st.has("piton") and u >= 0.8 and not bool(st.get("placed", false)):
		st["placed"] = true
		var spike := WallHammock.piton(int(st.piton))
		spike.position = _piton_spot(from, int(st.piton))
		_camp_root().add_child(spike)
		Sfx.play(self, "gear_metal_0", -4.0)
	if bool(st.get("hang", false)) and u >= 0.5 and not bool(st.get("placed", false)):
		st["placed"] = true
		var sheet := WallHammock.cloth()
		sheet.position = (_piton_spot(from, 0) + _piton_spot(from, 1)) * 0.5 + Vector3(0, 0, 0.22)
		_camp_root().add_child(sheet)
	if bool(st.get("unhang", false)) and u >= 0.5:
		for c in _camp_root().get_children():
			c.queue_free()
	if bool(st.get("nail", false)) and u >= 0.8 and not bool(st.get("placed", false)):
		st["placed"] = true
		_add_nail(climb.nails.back() if not climb.nails.is_empty() else Vector2i.ZERO)
		Sfx.play(self, "gear_metal_0", -4.0)
	if _step_t >= float(st.secs):
		climber.hammer(false)
		_queue.pop_front()
		_step_t = 0.0
		if st.has("end"):
			finished.emit(String(st.end))
	_rope_update()


## The hanging rest: two pitons hammered in, the hammock hung between them, the climber climbs in, sleeps and climbs out.
func _queue_camp(here: Vector3) -> void:
	_queue.append({"key": "hammer", "secs": HAMMER_SECONDS, "from": here, "to": here, "hammer": true, "piton": 0})
	_queue.append({"key": "hammer", "secs": HAMMER_SECONDS, "from": here, "to": here, "hammer": true, "piton": 1})
	_queue.append({"key": "thread", "secs": THREAD_SECONDS, "from": here, "to": here, "hang": true})
	_queue.append({"key": "bed", "secs": 3.0, "from": here, "to": here})
	_queue.append({"key": "stand", "secs": 0.8, "from": here, "to": here, "unhang": true})


## Where the pitons of the hanging rest sit, for the climber at `at`.
func _piton_spot(at: Vector3, side: int) -> Vector3:
	var x := at.x + (side * 2 - 1) * WallHammock.SPAN * 0.5
	var y := at.y + 1.0
	return Vector3(x, y, maxf(_builder.depth_at(x, y) + 0.32, at.z - 0.2))


func _leap_pose(u: float) -> Dictionary:
	if u < 0.35:
		return ClimbPose.mix(RopeClimbPose.POSES["hang"], LEAP_POSES["crouch"], smoothstep(0.0, 1.0, u / 0.35))
	if u < 0.6:
		return ClimbPose.mix(LEAP_POSES["crouch"], LEAP_POSES["spring"], smoothstep(0.0, 1.0, (u - 0.35) / 0.25))
	if u < 0.78:
		return ClimbPose.mix(LEAP_POSES["spring"], LEAP_POSES["catch"], smoothstep(0.0, 1.0, (u - 0.6) / 0.18))
	return ClimbPose.mix(LEAP_POSES["catch"], RopeClimbPose.POSES["hang"], smoothstep(0.0, 1.0, (u - 0.78) / 0.22))


# --- nails and rope --------------------------------------------------------------------------------------

var _camp: Node3D
var _slack := 0.0   ## how much the rope hangs loose in a fall (it is taut again when the fall is caught)


func _camp_root() -> Node3D:
	if _camp == null or not is_instance_valid(_camp):
		_camp = Node3D.new()
		wall_root.add_child(_camp)
	return _camp


func _add_nail(cell: Vector2i) -> void:
	var xy := WallBuild.square_centre(wall, cell.x, cell.y)
	var iron := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.015
	cyl.height = 0.22
	iron.mesh = cyl
	iron.rotation_degrees = Vector3(90, 0, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.32, 0.35)
	m.metallic = 0.7
	m.roughness = 0.45
	iron.material_override = m
	iron.position = Vector3(xy.x, xy.y + 0.35, _builder.depth_at(xy.x, xy.y) + 0.14)
	_nails_root.add_child(iron)


## The rope from the foot of the wall through every nail to the climber's belt.
func _rope_update() -> void:
	if climb == null or _rope_root == null or climb.on_ground() and climb.nails.is_empty():
		for seg in _rope_root.get_children() if _rope_root != null else []:
			seg.visible = false
		return
	var points: Array[Vector3] = [Vector3(_start_column(), 0.05, _builder.depth_at(_start_column(), 0.0) + 0.3)]
	for nail in climb.nails:
		var xy := WallBuild.square_centre(wall, nail.x, nail.y)
		points.append(Vector3(xy.x, xy.y + 0.35, _builder.depth_at(xy.x, xy.y) + 0.2))
	if _slack > 0.02:
		var last := points[points.size() - 1]
		var belt := feet + Vector3(0, 0.95, 0.25)
		points.append((last + belt) * 0.5 + Vector3(_slack * 0.5, -_slack * 0.3, _slack))
	points.append(feet + Vector3(0, 0.95, 0.25))
	while _rope_root.get_child_count() < points.size() - 1:
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.022
		cyl.bottom_radius = 0.022
		cyl.height = 1.0
		cyl.radial_segments = 6
		seg.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.5, 0.3)
		mat.roughness = 0.95
		seg.material_override = mat
		_rope_root.add_child(seg)
	for i in _rope_root.get_child_count():
		var seg := _rope_root.get_child(i) as MeshInstance3D
		seg.visible = i < points.size() - 1
		if not seg.visible:
			continue
		var a := points[i]
		var b := points[i + 1]
		var length := maxf(0.01, a.distance_to(b))
		seg.position = (a + b) * 0.5
		var up := (b - a) / length
		var axis := Vector3.UP.cross(up)
		var basis := Basis(axis.normalized(), Vector3.UP.angle_to(up)) if axis.length() > 0.001 else Basis()
		seg.basis = basis.scaled_local(Vector3(1, length, 1))


# --- weather in play: falling stones, drifting weather, the cloud sea ------------------------------------

func _next_fall() -> float:
	var every := WallWeather.fall_every(weather)
	return every * rng.randf_range(0.6, 1.3) if every > 0.0 else 0.0


## The cloud sea fills the foot of the view once the climber is high enough for the ground to be out of sight
## (a look over the whole wall shows the ground, so no cloud).
func _tick_clouds(delta: float) -> void:
	var want := smoothstep(CLOUD_FROM, CLOUD_FULL, feet.y) if follow else 0.0
	_cloud_density = move_toward(_cloud_density, want, delta * 0.6)
	_cloud_mat.set_shader_parameter("density", _cloud_density)
	var tint := (SKY[weather][0] as Color).lerp(Color(0.9, 0.91, 0.95), 0.7)
	_cloud_mat.set_shader_parameter("haze", Vector3(tint.r, tint.g, tint.b))


func _tick_weather(delta: float) -> void:
	if not interactive:
		return
	if drift:
		_worsen_timer += delta
		if _worsen_timer >= WORSEN_EVERY:
			_worsen_timer = 0.0
			var i := SEQUENCE.find(weather)
			set_weather(String(SEQUENCE[mini(SEQUENCE.size() - 1, i + 1)]) if i >= 0 else WallWeather.STORM)
	if WallWeather.fall_every(weather) > 0.0 and not climb.on_ground():
		_fall_timer -= delta
		if _fall_timer <= 0.0:
			_fall_timer = _next_fall()
			start_rockfall()
	if weather == WallWeather.STORM:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_flash_timer = rng.randf_range(7.0, 14.0)
			_flash = 0.35
			Sfx.play(self, "thunder", -8.0)
		_flash = maxf(0.0, _flash - delta)
		_env.ambient_light_energy = float(SKY[weather][2]) + _flash * 4.0


## Starts a stone from the top of the wall: mostly in the climber's own column or beside it. A rattle and a
## trickle of dust in that column warn for WARN_SECONDS before the stone comes down.
func start_rockfall(column := -1.0) -> void:
	var x := column
	if x < 0.0:
		x = feet.x + rng.randf_range(-1.2, 1.2) if rng.randf() < 0.7 else rng.randf_range(0.5, wall.width - 0.5)
	x = clampf(x, 0.5, wall.width - 0.5)
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = NaturalRock.mesh("rock_single_E")
	mi.material_override = AgedStone.rock_material()
	mi.scale = Vector3.ONE * 3.4
	node.add_child(mi)
	node.visible = false
	wall_root.add_child(node)
	var dust := CPUParticles3D.new()
	dust.amount = 40
	dust.lifetime = 1.4
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.5, 0.2, 0.1)
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 25.0
	dust.initial_velocity_min = 0.5
	dust.initial_velocity_max = 1.5
	dust.gravity = Vector3(0, -2.5, 0)
	var puff := SphereMesh.new()
	puff.radius = 0.09
	puff.height = 0.18
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.62, 0.56, 0.48, 0.6)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = dm
	dust.mesh = puff
	dust.position = Vector3(x, wall.height - 0.5, _builder.depth_at(x, wall.height - 0.5) + 0.4)
	wall_root.add_child(dust)
	stones.append({"node": node, "dust": dust, "x": x, "y": float(wall.height) + 1.0, "vy": 0.0, "wait": WARN_SECONDS, "hit": false})
	Sfx.play(self, "rumble", -10.0)
	Sfx.play(self, "step_scree_3", -4.0)
	_tell("Es rieselt von oben! Ein Stein löst sich: ausweichen oder an den Fels pressen (Leertaste halten).")


func _tick_stones(delta: float) -> void:
	for s in stones.duplicate():
		if s.wait > 0.0:
			s.wait -= delta
			if s.wait <= 0.0:
				s.node.visible = true
				s.dust.emitting = false
				Sfx.play(self, "step_scree_0", -2.0)
			continue
		s.vy += GRAVITY * delta
		var was: float = s.y
		s.y -= s.vy * delta
		var z := _builder.depth_at(s.x, maxf(0.0, s.y)) + 0.4
		s.node.position = Vector3(s.x, s.y, z)
		s.node.rotation.x -= delta * 5.0
		if not s.hit and not climb.on_ground() and absf(s.x - feet.x) < 0.6 and s.y < feet.y + 1.9 and was > feet.y + 0.1:
			s.hit = true
			_stone_hits()
		if s.y < -1.5:
			s.node.queue_free()
			s.dust.queue_free()
			stones.erase(s)
			if s.y < -1.5 and absf(s.x - feet.x) < 3.0:
				Sfx.play(self, "word_krach", -8.0)


## A stone reaches the climber: braced against the rock they take nothing, otherwise it may knock them off.
func _stone_hits() -> void:
	var braced := bracing()
	var from := climb.cell
	var out := climb.struck(braced, rng.randf())
	match out:
		WallClimb.Outcome.BRACED:
			_tell("Du presst dich an den Fels: der Stein springt über dich hinweg.")
			Sfx.play(self, "word_klack", -4.0)
		WallClimb.Outcome.GRAZED:
			_tell("Ein Stein streift dich!")
			Sfx.play(self, "hurt", -4.0)
			hurt.emit(GRAZE_DAMAGE)
			_queue.append({"key": "slip", "secs": 0.55, "from": feet, "to": feet})
		_:
			Sfx.play(self, "hurt", -2.0)
			hurt.emit(GRAZE_DAMAGE * 2)
			_tell(Lang.t("Ein Stein trifft dich und wirft dich von der Wand! ") + Lang.t("Du stürzt %d m tief.") % int(round(climb.last_fall)), true)
			_queue.clear()
			_queue_fall(feet, feet_of(climb.cell), climb.nail != WallClimb.NOWHERE)
			if out == WallClimb.Outcome.GAVE_UP:
				_queue.append({"key": "stand", "secs": 0.8, "from": feet_of(climb.cell), "to": feet_of(climb.cell), "end": "gave_up"})
	_update_status()
	_step_t = 0.0
	if from == WallClimb.NOWHERE:
		return


func _tell(text: String, already := false) -> void:
	var shown := text if already else Lang.t(text)
	_strip.text = shown
	told.emit(shown)
