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
## The gold of the quest marks over the heads of villagers with a task.
const MARK_COLOR := Color(1.0, 0.82, 0.3)
## Waits this long for the hero to step aside before walking on.
const MAKE_WAY := 1.4

## name: shown above the head; model; show: extra parts; hair: a look for a
## Rogue (see HairLook); sex: "female" for a woman built on the Rogue (see
## BodyLook); colors: body, legs, hat/cape; plan: how they spend the day (see _next_task); work: the
## animation at their spot; lines: what they say, one after another.
const ROLES := {
	"0": {"name": "Dorfvorsteher Aldo", "model": "Mage", "show": ["Mage_Hat", "2H_Staff", "Mage_Cape"],
		"colors": [Color(0.55, 0.6, 0.8), Color(0.5, 0.5, 0.55), Color(0.45, 0.42, 0.7)], "plan": "stay", "work": "Idle",
		"lines": ["Willkommen in Lindenhain, Fremder!", "Das Haus mit dem Ziegeldach gehört jetzt dir.", "Ruh dich aus. Die Gruft ist weit weg."]},
	"1": {"name": "Schmied Gorm", "model": "Barbarian", "show": ["1H_Axe"],
		"colors": [Color(0.55, 0.42, 0.32), Color(0.4, 0.36, 0.34), Color(1, 1, 1)], "plan": "shop", "work": "1H_Melee_Attack_Chop", "sound": "hit",
		"lines": ["Brauchst du eine Klinge? Ich schmiede die besten im Tal.", "Heiß muss das Eisen sein, sonst bricht es.", "Bring mir altes Eisen, ich schmelze es ein und mache dir etwas Neues daraus.", "Verbeulte Rüstung? Leg sie auf den Amboss."]},
	"2": {"name": "Bäuerin Lene", "model": "Rogue", "show": [], "sex": "female",
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
	"6": {"name": "Krämerin Mira", "model": "Rogue", "show": ["Rogue_Cape"], "sex": "female",
		"colors": [Color(0.7, 0.35, 0.6), Color(0.35, 0.3, 0.45), Color(0.6, 0.3, 0.5)], "plan": "shop", "work": "Interact",
		"lines": ["Brot, Käse, Seile, Fackeln: alles für den Alltag!", "Ich kaufe auch, was du aus dem Verlies mitbringst.", "Für einen Helden mache ich einen guten Preis."]},
	"7": {"name": "Pip", "model": "Rogue", "show": [], "scale": 0.72,
		"colors": [Color(0.45, 0.6, 0.9), Color(0.6, 0.45, 0.3), Color(0.9, 0.8, 0.3)], "plan": "wander", "work": "Cheer",
		"lines": ["Fang mich doch!", "Bist du ein echter Abenteurer?", "Mama sagt, in der Gruft spukt es!"]},
	"8": {"name": "Gelehrter Odo", "model": "Mage", "show": ["Mage_Hat", "Spellbook_open"],
		"colors": [Color(0.35, 0.3, 0.45), Color(0.3, 0.3, 0.35), Color(0.3, 0.25, 0.4)], "plan": "stroll", "work": "Spellcast_Raise",
		"lines": ["Faszinierend, du lebst! Das Verlies gilt als unentrinnbar.", "In meinen Büchern steht etwas über Wächter in Rüstung...", "Ruhe, bitte. Ich lese."]},
	"9": {"name": "Wasserträgerin Hanna", "model": "Knight", "show": [],
		"colors": [Color(0.4, 0.65, 0.75), Color(0.45, 0.4, 0.35), Color(1, 1, 1)], "plan": "carry", "work": "PickUp",
		"lines": ["Frisches Wasser vom Brunnen!", "Puh, die Eimer sind schwer.", "Der Brunnen ist so alt wie das Dorf."]},
	"K": {"name": "Herold Konrad", "model": "Knight", "show": ["Knight_Cape", "Badge_Shield"],
		"colors": [Color(0.4, 0.5, 0.9), Color(0.85, 0.75, 0.4), Color(0.3, 0.4, 0.85)], "plan": "stay", "work": "Idle",
		"lines": ["Ich bin der Herold der Krone. Ich rufe die Neuigkeiten aus.", "Bleib in der Nähe, gleich gibt es Neues!", "Das Amt der Krone kümmert sich um Recht und Steuern."]},
	"O": {"name": "Priesterin Elsbeth", "model": "Mage", "show": ["Mage_Cape", "2H_Staff"],
		"colors": [Color(0.95, 0.93, 0.85), Color(0.9, 0.88, 0.8), Color(0.95, 0.8, 0.4)], "plan": "work", "work": "Spellcast_Raise",
		"lines": ["Die Götter haben dich aus der Tiefe geführt.", "Der Tempel steht allen offen, Tag und Nacht.", "Möge das Licht deinen Weg erhellen."]},
	"G": {"name": "Gildenmeisterin Ragna", "model": "Barbarian", "show": ["Barbarian_Round_Shield", "1H_Axe", "Barbarian_Cape"],
		"colors": [Color(0.6, 0.25, 0.2), Color(0.3, 0.28, 0.26), Color(0.7, 0.2, 0.15)], "plan": "stay", "work": "Idle",
		"lines": ["Die Gilde sucht Leute wie dich. Wer aus dem Verlies kommt, ist zäh.", "Bald gibt es Aufträge: Wölfe im Wald, Räuber am Pass.", "Zeig mir deine Narben, dann reden wir."]},
	"M": {"name": "Postmeister Anselm", "model": "Rogue", "show": [],
		"colors": [Color(0.95, 0.8, 0.3), Color(0.35, 0.35, 0.5), Color(1, 1, 1)], "plan": "carry", "work": "PickUp",
		"lines": ["Ein Brief für dich? Noch nicht, aber bald bestimmt.", "Ich bringe die Post zu jedem Haus im Dorf.", "Die Postkutsche kommt jeden dritten Tag."]},
	"Z": {"name": "Barbier Benno", "model": "Rogue", "show": [], "hair": {"style": "mohawk", "color": "fire"},
		"colors": [Color(0.95, 0.95, 0.95), Color(0.25, 0.25, 0.3), Color(1, 1, 1)], "plan": "shop", "work": "Interact",
		"lines": ["Haare schneiden, färben, tätowieren: Bei mir wirst du ein neuer Mensch!", "Ein Irokese steht dir bestimmt. Oder gleich in Flammen?", "Halt still, sonst wird die Tätowierung schief."]},
	"Y": {"name": "Bankier Goldwin", "model": "Mage", "show": ["Mage_Hat"],
		"colors": [Color(0.25, 0.45, 0.3), Color(0.25, 0.25, 0.28), Color(0.2, 0.35, 0.25)], "plan": "work", "work": "Interact",
		"lines": ["Gold ist bei uns sicherer als in jeder Truhe.", "Die Bank der Krone öffnet bald ihre Schalter für Abenteurer.", "Zinsen? Nur für treue Kunden."]},
	"S": {"name": "Steinmetz Hagen", "model": "Barbarian", "show": ["1H_Axe"],
		"colors": [Color(0.6, 0.58, 0.55), Color(0.4, 0.38, 0.36), Color(0.7, 0.68, 0.64)], "plan": "shop", "work": "1H_Melee_Attack_Chop", "sound": "hit",
		"lines": ["Steinblöcke, sauber behauen! Bau dir, was du willst.", "Eine Mauer hält länger als jeder Zaun.", "Stapel sie versetzt, dann hält die Mauer besser."]},
}

## What the herald calls out on the square, one after another.
const NEWS := [
	"Hört, hört! Ein Held ist aus der alten Gruft entkommen!",
	"Hört, hört! Die Krone sucht mutige Helden. Meldet euch in der Abenteurergilde!",
	"Hört, hört! Morgen ist Markttag. Die Krämerin hat frisches Brot!",
	"Hört, hört! Briefe aus der Hauptstadt liegen auf der Post bereit.",
	"Hört, hört! Die Bank der Krone verwahrt euer Gold sicher.",
	"Hört, hört! Heute Abend gibt es Segen im Tempel für alle!",
]
## How long the village listens to the herald (seconds).
const LISTEN_TIME := 13.0
## Who stays up at night: the guard keeps watch, the drinker stays at the
## tavern and the temple is open day and night. Everyone else goes home to
## sleep at nightfall (see Outdoor.set_hour) and comes out in the morning.
const NIGHT_OWLS := ["4", "5", "O"]

var level: Outdoor
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
## The name over the head, shown once the hero has talked to us.
var _name_tag: Label3D
## The quest mark over the head: "!" for a task to offer, "?" for one to
## hand in (see Quests.mark), hidden when there is neither.
var _quest_mark: Label3D
var _mark_base := 0.0
var _mark_time := 0.0
var _line := 0
var _current_anim := ""
var _look_at := Vector3.INF
var _greeted := false
## Who the villager listens to while gathered on the square.
var _listen_to := Vector3.INF
var _news := 0
## Night has fallen, and whether the villager is inside their house asleep
## (hidden, and nobody to talk to or trade with until morning).
var night := false
var at_home := false
var _layer := 1


func setup(owner_level: Outdoor, role_char: String, cell: Vector2i) -> void:
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
	_model.scale = Vector3.ONE * _info.get("scale", 1.0) * BodyLook.scale_of(_info.get("sex", BodyLook.DEFAULT))
	add_child(_model)
	_dress()
	# A woman built on the Rogue model gets her own body (see BodyLook); the
	# dyes stay on, they belong to the parts, not to the meshes.
	BodyLook.apply(_model, _info.get("sex", BodyLook.DEFAULT))
	if _info.has("hair"):
		HairLook.apply(_model, HairLook.checked(_info.hair))
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walking_A", "Walking_B", "Running_A", "Sit_Floor_Idle"]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_bubble = Label3D.new()
	_bubble.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	_bubble.font_size = 44
	_bubble.pixel_size = 0.011
	_bubble.outline_size = 12
	_bubble.outline_modulate = Color(0.05, 0.03, 0.06, 0)
	_bubble.modulate = Color(1, 0.95, 0.85, 0)
	_bubble.visible = false
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.no_depth_test = true
	_bubble.render_priority = 20
	_bubble.outline_render_priority = 19
	_bubble.width = 520
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.position.y = 3.3 * _info.get("scale", 1.0) + 0.4
	add_child(_bubble)
	_name_tag = Label3D.new()
	_name_tag.text = display_name
	_name_tag.font = _bubble.font
	_name_tag.font_size = 30
	_name_tag.pixel_size = 0.011
	_name_tag.outline_size = 10
	_name_tag.outline_modulate = Color(0.05, 0.03, 0.06, 0.85)
	_name_tag.modulate = Color(1, 0.95, 0.85, 1)
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.no_depth_test = true
	_name_tag.render_priority = 18
	_name_tag.outline_render_priority = 17
	_name_tag.position.y = 2.5 * _info.get("scale", 1.0) + 0.25
	_name_tag.visible = is_known()
	add_child(_name_tag)
	_quest_mark = Label3D.new()
	_quest_mark.font = _bubble.font
	_quest_mark.font_size = 140
	_quest_mark.pixel_size = 0.011
	_quest_mark.outline_size = 26
	_quest_mark.outline_modulate = Color(0.05, 0.03, 0.06, 0.9)
	_quest_mark.modulate = MARK_COLOR
	_quest_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_mark.no_depth_test = true
	_quest_mark.render_priority = 18
	_quest_mark.outline_render_priority = 17
	_mark_base = 2.5 * _info.get("scale", 1.0) + 1.1
	_quest_mark.position.y = _mark_base
	_quest_mark.visible = false
	add_child(_quest_mark)
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
	if task == "home" and not at_home:
		_hide_inside(true)


## What comes after the current task: mostly back to work, now and then a
## walk somewhere in the village.
func _next_task() -> void:
	if night and goes_to_bed():
		if _task == "home":
			_start("home", 10.0)
		else:
			_walk_to(_house_door(), WALK_SPEED * 1.15, "home")
		return
	match _info.plan:
		"stay", "shop":
			if level.world_to_cell(global_position) != home:
				_walk_to(level.cell_to_world(home), WALK_SPEED, "work")
			else:
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
	for c in level.grid_path(from, level.world_to_cell(target)).slice(1):
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
		"home":
			pass
		"walk":
			_walk(delta, hero)
		"work", "sit", "idle":
			_do(_task, delta)
		"listen":
			_turn_to(_listen_to - global_position, delta)
			play("Idle")
	_task_time -= delta
	if _task != "walk" and _task_time <= 0.0:
		if _task == "listen":
			# The news is out: back to the day's work.
			_listen_to = Vector3.INF
			_start("idle", 0.1)
		_next_task()
	if role == "0" and hero.global_position.distance_to(global_position) < 8.0:
		_turn_to(hero.global_position - global_position, delta)


func _walk(delta: float, hero: Node3D) -> void:
	if _path.is_empty():
		var then: String = get_meta("then", "idle")
		var time := _rng.randf_range(2.0, 5.0)
		if then in ["work", "sit"]:
			time = _rng.randf_range(8.0, 16.0)
		elif then == "listen":
			time = LISTEN_TIME + _rng.randf_range(-2.0, 2.0)
		_start(then, time)
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


# --- Night -------------------------------------------------------------------

## Whether this villager sleeps at night (see NIGHT_OWLS).
func goes_to_bed() -> bool:
	return not role in NIGHT_OWLS


## Night falls or the day breaks. At nightfall the villager walks to the
## nearest house and goes in; in the morning they step out of the door and
## go back to their day. `at_once` settles it on the spot (a game loaded at
## night finds the village already asleep).
func set_night(on: bool, at_once := false) -> void:
	night = on
	if not goes_to_bed():
		return
	if on:
		_listen_to = Vector3.INF
		_bubble_time = 0.0
		if at_once:
			global_position = _house_door()
			_start("home", 10.0)
		elif _task != "home":
			_walk_to(_house_door(), WALK_SPEED * 1.15, "home")
	elif at_home:
		_hide_inside(false)
		_start("idle", _rng.randf_range(0.5, 4.0))
	elif _task == "walk" and get_meta("then", "") == "home":
		_start("idle", 0.5)


## The door of the house nearest to the villager's own spot.
func _house_door() -> Vector3:
	var houses: Array = level.spots.houses
	var at := level.cell_to_world(home)
	var best := at
	var best_d := INF
	for h: Vector3 in houses:
		var d := at.distance_to(h)
		if d < best_d:
			best_d = d
			best = h
	return best


## In through the door (gone from the street) or back out of it.
func _hide_inside(inside: bool) -> void:
	at_home = inside
	visible = not inside
	if inside:
		_layer = collision_layer if collision_layer != 0 else _layer
		collision_layer = 0
	else:
		collision_layer = _layer
	if station:
		station.used = inside


# --- Gathering on the square -------------------------------------------------

## Who drops their work to hear the herald: not the shopkeeper at her
## stall, the elder or the woodcutter out in the woods.
func comes_to_listen() -> bool:
	return not night and _info.plan in ["work", "sit", "patrol", "stroll", "wander", "carry"] and role != "3" and _task != "listen"


func gather_at(spot: Vector3, speaker: Vector3) -> void:
	_listen_to = speaker
	_walk_to(spot, WALK_SPEED * 1.2, "listen")


## The herald's call: the next piece of news, arm raised.
func proclaim() -> void:
	say(Lang.t(NEWS[_news % NEWS.size()]), Vector3.INF, 7.0)
	_news += 1
	_current_anim = "Cheer"
	_anim.play("Cheer", 0.2)


# --- Talking ------------------------------------------------------------------

## The hero ran into us: say the next line.
func talk(hero: Node3D) -> void:
	var lines: Array = _info.lines
	meet()
	say(Lang.t(lines[_line % lines.size()]), hero.global_position)
	_line += 1


## Whether the hero has talked to this villager before (also in an earlier
## session: the village remembers, see Outdoor.met).
func is_known() -> bool:
	return level != null and level.met.has(role)


## The hero and this villager have spoken: from now on the name stays over
## the head, so the people of the village can be told apart.
func meet() -> void:
	if level:
		level.met[role] = true
	if _name_tag:
		_name_tag.visible = true


## The elder sees the newcomer and hands over the house.
func greet_newcomer(hero: Node3D) -> void:
	_line = 1
	meet()
	say(Lang.t("Willkommen, Fremder! Du kommst aus der alten Gruft? Das leere Haus mit dem Ziegeldach gehört jetzt dir."), hero.global_position, 6.5)


## Shows "!" (a task to offer), "?" (a task to hand in) or nothing ("").
func set_quest_mark(text: String) -> void:
	if _quest_mark == null:
		return
	_quest_mark.text = text
	_quest_mark.visible = text != ""


## The mark over the head right now ("" when none shows).
func quest_mark() -> String:
	return _quest_mark.text if _quest_mark and _quest_mark.visible else ""


func say(text: String, look_at := Vector3.INF, time := SAY_TIME) -> void:
	_bubble.text = "%s:\n%s" % [display_name, text]
	_bubble_time = time
	_look_at = look_at
	if _task == "walk":
		_start("idle", 0.5)


func _update_bubble(delta: float) -> void:
	_bubble_time = maxf(0.0, _bubble_time - delta)
	var target := 1.0 if _bubble_time > 0.0 else 0.0
	var alpha := move_toward(_bubble.modulate.a, target, delta * 4.0)
	if alpha != _bubble.modulate.a:
		# The outline has its own alpha that ignores `modulate`: fade both,
		# or the dark outline stays behind as black text over the head.
		_bubble.modulate.a = alpha
		_bubble.outline_modulate.a = alpha
	_bubble.visible = alpha > 0.0
	# The speech bubble already starts with the name: the plain name tag
	# steps aside while it shows, and comes back when the talk is over.
	if _name_tag and _name_tag.visible:
		_name_tag.modulate.a = 1.0 - alpha
		_name_tag.outline_modulate.a = 0.85 * (1.0 - alpha)
	# The quest mark steps aside too, and bobs gently while it shows.
	if _quest_mark and _quest_mark.visible:
		_quest_mark.modulate.a = 1.0 - alpha
		_quest_mark.outline_modulate.a = 0.9 * (1.0 - alpha)
		_mark_time += delta
		_quest_mark.position.y = _mark_base + 0.08 * sin(_mark_time * 3.0)
	if _bubble_time <= 0.0:
		_look_at = Vector3.INF
