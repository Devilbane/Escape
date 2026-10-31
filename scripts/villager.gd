class_name Villager
extends CharacterBody3D
## A villager who goes about their day: works at their spot, walks over to
## the well or the square now and then, and comes back. Run into one to hear
## what they have to say. Driven by a small script, no AI service needed.

const WALK_SPEED := 1.7
const RUN_SPEED := 3.6
## Body parts every model keeps; everything else (hats, weapons, books) is
## shown only when a role asks for it.
const BODY_PARTS := ["Body", "Head", "ArmLeft", "ArmRight", "LegLeft", "LegRight"]
const SAY_TIME := 4.0
## Waits this long for the hero to step aside before walking on.
const MAKE_WAY := 1.4

## name: shown above the head; model; show: extra parts; colors: body,
## legs, hat/cape; plan: how they spend the day (see _next_task); work: the
## animation at their spot; lines: what they say, one after another.
const ROLES := {
	"0": {"name": "Dorfvorsteher Aldo", "model": "Mage", "show": ["Mage_Hat", "2H_Staff", "Mage_Cape"],
		"colors": [Color(0.55, 0.6, 0.8), Color(0.5, 0.5, 0.55), Color(0.45, 0.42, 0.7)], "plan": "stay", "work": "Idle",
		"lines": ["Willkommen in Lindenhain, Fremder!", "Das Haus mit dem Ziegeldach gehört jetzt dir.", "Ruh dich aus. Die Gruft ist weit weg."]},
	"1": {"name": "Schmied Gorm", "model": "Barbarian", "show": ["1H_Axe"],
		"colors": [Color(0.55, 0.42, 0.32), Color(0.4, 0.36, 0.34), Color(1, 1, 1)], "plan": "work", "work": "1H_Melee_Attack_Chop", "sound": "hit",
		"lines": ["Brauchst du eine Klinge? Ich schmiede die besten im Tal.", "Heiß muss das Eisen sein, sonst bricht es.", "Aus der Gruft? Dann hast du Mut, das muss man dir lassen."]},
	"2": {"name": "Bäuerin Lene", "model": "Rogue", "show": [],
		"colors": [Color(0.9, 0.75, 0.45), Color(0.55, 0.45, 0.3), Color(0.85, 0.55, 0.3)], "plan": "work", "work": "PickUp",
		"lines": ["Die Kürbisse sind dieses Jahr riesig!", "Das Korn muss rein, bevor der Frost kommt.", "Hast du Hunger? Im Wirtshaus gibt es Suppe."]},
	"3": {"name": "Holzfäller Bruno", "model": "Barbarian", "show": ["2H_Axe", "Barbarian_Hat"],
		"colors": [Color(0.75, 0.35, 0.3), Color(0.35, 0.4, 0.3), Color(0.6, 0.45, 0.3)], "plan": "work", "work": "2H_Melee_Attack_Chop", "sound": "hit",
		"lines": ["Holla! Du kommst vom Friedhof? Da geht doch keiner hin.", "Folge dem Weg, dann kommst du ins Dorf.", "Ein Baum am Tag, so hält man den Wald gesund."]},
	"4": {"name": "Wache Ulrich", "model": "Knight", "show": ["Knight_Helmet", "1H_Sword", "Round_Shield", "Knight_Cape"],
		"colors": [Color(1, 1, 1), Color(0.8, 0.8, 0.85), Color(0.35, 0.45, 0.8)], "plan": "patrol", "work": "Idle",
		"lines": ["Halt! Ach, du bist der Neue. Willkommen.", "Seit Jahren kam keiner mehr aus der Gruft.", "Ich halte Wache. Hier bist du sicher."]},
	"5": {"name": "Zecher Fritz", "model": "Barbarian", "show": ["Mug"],
		"colors": [Color(0.4, 0.55, 0.4), Color(0.45, 0.35, 0.28), Color(1, 1, 1)], "plan": "sit", "work": "Sit_Floor_Idle",
		"lines": ["Prost! Auf die Freiheit!", "Das Bier hier ist das beste diesseits der Berge.", "Setz dich doch, erzähl von da unten!"]},
	"6": {"name": "Händlerin Mira", "model": "Rogue", "show": ["Rogue_Cape"],
		"colors": [Color(0.7, 0.35, 0.6), Color(0.35, 0.3, 0.45), Color(0.6, 0.3, 0.5)], "plan": "work", "work": "Interact",
		"lines": ["Frische Äpfel! Feines Tuch! Kommt näher!", "Morgen kommt ein Händler aus der Stadt.", "Für einen Helden mache ich einen guten Preis."]},
	"7": {"name": "Pip", "model": "Rogue", "show": [], "scale": 0.72,
		"colors": [Color(0.45, 0.6, 0.9), Color(0.6, 0.45, 0.3), Color(0.9, 0.8, 0.3)], "plan": "wander", "work": "Cheer",
		"lines": ["Fang mich doch!", "Bist du ein echter Abenteurer?", "Mama sagt, in der Gruft spukt es!"]},
	"8": {"name": "Gelehrter Odo", "model": "Mage", "show": ["Mage_Hat", "Spellbook_open"],
		"colors": [Color(0.35, 0.3, 0.45), Color(0.3, 0.3, 0.35), Color(0.3, 0.25, 0.4)], "plan": "stroll", "work": "Spellcast_Raise",
		"lines": ["Faszinierend, du lebst! Das Verlies gilt als unentrinnbar.", "In meinen Büchern steht etwas über Wächter in Rüstung...", "Ruhe, bitte. Ich lese."]},
	"9": {"name": "Wasserträgerin Hanna", "model": "Knight", "show": [],
		"colors": [Color(0.4, 0.65, 0.75), Color(0.45, 0.4, 0.35), Color(1, 1, 1)], "plan": "carry", "work": "PickUp",
		"lines": ["Frisches Wasser vom Brunnen!", "Puh, die Eimer sind schwer.", "Der Brunnen ist so alt wie das Dorf."]},
}

var level: Level
var role := "7"
var home := Vector2i.ZERO
var station: Dictionary = {}
var display_name := ""
var _info: Dictionary
var _model: Node3D
var _anim: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _path: Array[Vector3] = []
var _task := ""
var _task_time := 0.0
var _work_pause := 0.0
var _speed := WALK_SPEED
var _waiting := 0.0
var _bubble: Label3D
var _bubble_time := 0.0
var _line := 0
var _current_anim := ""
var _look_at := Vector3.INF
var _greeted := false


func setup(owner_level: Level, role_char: String, cell: Vector2i) -> void:
	level = owner_level
	role = role_char
	home = cell
	_info = ROLES[role]
	display_name = Lang.t(_info.name)
	_rng.seed = hash(role) + cell.x * 31 + cell.y


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5 * _info.get("scale", 1.0)
	capsule.height = 2.2 * _info.get("scale", 1.0)
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)
	_model = load("res://assets/characters/%s.glb" % _info.model).instantiate()
	_model.scale = Vector3.ONE * _info.get("scale", 1.0)
	add_child(_model)
	_dress()
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walking_A", "Walking_B", "Running_A", "Sit_Floor_Idle"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_bubble = Label3D.new()
	_bubble.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	_bubble.font_size = 44
	_bubble.pixel_size = 0.011
	_bubble.outline_size = 12
	_bubble.outline_modulate = Color(0.05, 0.03, 0.06)
	_bubble.modulate = Color(1, 0.95, 0.85, 0)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.render_priority = 20
	_bubble.outline_render_priority = 19
	_bubble.width = 520
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.position.y = 3.3 * _info.get("scale", 1.0) + 0.4
	add_child(_bubble)
	rotation.y = _rng.randf() * TAU
	_start("sit" if _info.plan == "sit" else "work", _rng.randf_range(2.0, 6.0))


## Hats, capes and tools for the role, and clothes in the role's colours.
func _dress() -> void:
	var show: Array = _info.show
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		var base := part.get_slice("_", part.get_slice_count("_") - 1)
		var is_body := false
		for b in BODY_PARTS:
			if part.ends_with("_" + b):
				is_body = true
				base = b
		if not is_body and not part in show:
			mi.visible = false
			continue
		var color := Color.WHITE
		if base == "Body":
			color = _info.colors[0]
		elif base.begins_with("Leg"):
			color = _info.colors[1]
		elif base.begins_with("Arm"):
			color = Color.WHITE.lerp(_info.colors[0], 0.5)
		elif part.ends_with("Hat") or part.ends_with("Cape") or part.ends_with("Helmet"):
			color = _info.colors[2]
		if color != Color.WHITE:
			var mat := mi.get_active_material(0)
			if mat is StandardMaterial3D:
				var dyed: StandardMaterial3D = mat.duplicate()
				dyed.albedo_color = color
				mi.material_override = dyed


func play(anim_name: String, blend := 0.25) -> void:
	if _current_anim == anim_name and _anim.is_playing():
		return
	_current_anim = anim_name
	_anim.play(anim_name, blend)


# --- The day's plan -----------------------------------------------------------

func _start(task: String, time: float) -> void:
	_task = task
	_task_time = time
	_work_pause = 0.0


## What comes after the current task: mostly back to work, now and then a
## walk somewhere in the village.
func _next_task() -> void:
	match _info.plan:
		"stay":
			_start("work", 6.0)
		"work", "sit":
			if _task in ["work", "sit"] and _rng.randf() < 0.35:
				_walk_to(_errand(), WALK_SPEED, "idle")
			elif level.world_to_cell(global_position) != home:
				_walk_to(level.cell_to_world(home), WALK_SPEED, "sit" if _info.plan == "sit" else "work")
			else:
				_start("sit" if _info.plan == "sit" else "work", _rng.randf_range(12.0, 25.0))
		"patrol":
			if _task == "walk":
				_start("idle", _rng.randf_range(3.0, 6.0))
			else:
				_walk_to(_nearby(9), WALK_SPEED, "idle")
		"stroll":
			if _task == "walk":
				_start("work", _rng.randf_range(4.0, 9.0))
			else:
				_walk_to(_nearby(4), WALK_SPEED * 0.7, "work")
		"wander":
			if _task == "walk" or _rng.randf() < 0.5:
				_start("work" if _rng.randf() < 0.4 else "idle", _rng.randf_range(1.5, 4.0))
			else:
				_walk_to(_nearby(5), RUN_SPEED, "idle")
		"carry":
			# Between the well and the houses, with a stop at each.
			var at_well := level.world_to_cell(global_position) == home
			if _task == "walk":
				_start("work" if at_well else "idle", _rng.randf_range(2.5, 4.5))
			elif at_well:
				var houses: Array = level.spots.houses
				_walk_to(houses[_rng.randi() % houses.size()] if not houses.is_empty() else _nearby(6), WALK_SPEED, "idle")
			else:
				_walk_to(level.cell_to_world(home), WALK_SPEED, "work")


## Somewhere in the village worth a visit: the well, the square, a house.
func _errand() -> Vector3:
	var places: Array = level.spots.well + level.spots.square
	if places.is_empty() or level.world_to_cell(places[0]).distance_to(home) > 18:
		return _nearby(5)
	return places[_rng.randi() % places.size()]


## A free tile within a few tiles of home.
func _nearby(radius: int) -> Vector3:
	for i in 20:
		var c := home + Vector2i(_rng.randi_range(-radius, radius), _rng.randi_range(-radius, radius))
		if level.is_open(c):
			return level.cell_to_world(c)
	return level.cell_to_world(home)


func _walk_to(target: Vector3, speed: float, then: String) -> void:
	_path.clear()
	var from := level.world_to_cell(global_position)
	for c in level.astar.get_id_path(from, level.world_to_cell(target), true).slice(1):
		_path.append(level.cell_to_world(c) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6)))
	if _path.is_empty():
		_start(then, 3.0)
		return
	_speed = speed
	_task = "walk"
	set_meta("then", then)


# --- Every frame --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if level == null or level.player == null:
		return
	station.pos = global_position
	station.cell = level.world_to_cell(global_position)
	_update_bubble(delta)
	var hero: Node3D = level.player
	if _bubble_time > 0.0 and _look_at != Vector3.INF:
		_turn_to(_look_at - global_position, delta)
		if _task != "sit":
			play("Idle")
		return
	match _task:
		"walk":
			_walk(delta, hero)
		"work", "sit", "idle":
			_do(_task, delta)
	_task_time -= delta
	if _task != "walk" and _task_time <= 0.0:
		_next_task()
	if role == "0" and hero.global_position.distance_to(global_position) < 8.0:
		_turn_to(hero.global_position - global_position, delta)


func _walk(delta: float, hero: Node3D) -> void:
	if _path.is_empty():
		_start(get_meta("then", "idle"), _rng.randf_range(8.0, 16.0) if get_meta("then", "") in ["work", "sit"] else _rng.randf_range(2.0, 5.0))
		return
	var to := _path[0] - global_position
	to.y = 0.0
	# Polite: wait when the hero stands in the way.
	var ahead := hero.global_position - global_position
	ahead.y = 0.0
	if ahead.length() < 1.6 and to.length() > 0.01 and ahead.normalized().dot(to.normalized()) > 0.3:
		_waiting += delta
		play("Idle")
		if _waiting < MAKE_WAY:
			return
		# Still blocked: go round by trying the walk again later.
		_waiting = 0.0
		_start("idle", 1.5)
		return
	_waiting = 0.0
	var step := _speed * delta
	if to.length() <= step:
		global_position = Vector3(_path[0].x, 0, _path[0].z)
		_path.pop_front()
	else:
		global_position += to.normalized() * step
	_turn_to(to, delta)
	play("Running_A" if _speed >= RUN_SPEED else ("Walking_B" if _speed < WALK_SPEED else "Walking_A"))


func _do(task: String, delta: float) -> void:
	if task == "idle":
		play("Idle")
		return
	if task == "sit":
		play(_info.work)
		return
	var work: String = _info.work
	if _anim.get_animation(work).loop_mode != Animation.LOOP_NONE:
		play(work)
		return
	# One-off moves (a hammer blow, picking something up) again and again,
	# with a breath in between.
	if _anim.is_playing() and _current_anim == work:
		return
	_work_pause -= delta
	if _current_anim == work:
		play("Idle", 0.2)
		_work_pause = _rng.randf_range(0.3, 1.2) if role in ["1", "3"] else _rng.randf_range(1.5, 3.5)
		return
	if _work_pause > 0.0:
		return
	_current_anim = work
	_anim.play(work, 0.15)
	if _info.has("sound"):
		get_tree().create_timer(0.45).timeout.connect(func():
			if is_inside_tree():
				Sfx.play(self, _info.sound, -16.0, global_position, 0.8))


func _turn_to(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	var target := atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target, minf(1.0, delta * 8.0))


# --- Talking ------------------------------------------------------------------

## The hero ran into us: say the next line.
func talk(hero: Node3D) -> void:
	var lines: Array = _info.lines
	say(Lang.t(lines[_line % lines.size()]), hero.global_position)
	_line += 1


## The elder sees the newcomer and hands over the house.
func greet_newcomer(hero: Node3D) -> void:
	_line = 1
	say(Lang.t("Willkommen, Fremder! Du kommst aus der alten Gruft? Das leere Haus mit dem Ziegeldach gehört jetzt dir."), hero.global_position, 6.5)


func say(text: String, look_at := Vector3.INF, time := SAY_TIME) -> void:
	_bubble.text = "%s:\n%s" % [display_name, text]
	_bubble_time = time
	_look_at = look_at
	if _task == "walk":
		_start("idle", 0.5)


func _update_bubble(delta: float) -> void:
	_bubble_time = maxf(0.0, _bubble_time - delta)
	var target := 1.0 if _bubble_time > 0.0 else 0.0
	_bubble.modulate.a = move_toward(_bubble.modulate.a, target, delta * 4.0)
	if _bubble_time <= 0.0:
		_look_at = Vector3.INF
