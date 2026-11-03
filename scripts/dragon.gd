class_name Dragon
extends Enemy
## Embermaw, the hoard dragon: the boss of the dragon's lair. Its health bar
## shows at the top of the screen (see BossBar), and it wakes with a roar.
## The fight in three phases:
##   1. It spits fireballs from afar and bites whoever comes close. Every few
##      seconds it draws breath: red rings glow on the floor in a line
##      towards the hero, and a moment later its fire breath sets them
##      ablaze (see FireField). The flames burn for a while, hurt the hero
##      (not while jumping over them) and set them burning; dragons fly
##      through them unharmed. After each breath it sinks down, winded, and
##      takes double damage: the moment to strike.
##   2. Below 60 % of its life it is furious: three lines of fire at once,
##      and it breathes more often.
##   3. Below 30 % it rages: quicker, and it rains fire around the hero
##      every few seconds, besides the breath.
## A stab in the back only hits three times as hard. It guards its hoard and
## does not follow the hero far; off the hunt for a while, it licks its
## wounds and is whole again.

signal awakened
signal phase_changed(phase: int)

const TITLE := "Glutschlund, der Hortdrache"
## Share of its life at which phase 2 and phase 3 begin.
const PHASE_AT := [0.6, 0.3]
const BACKSTAB_FACTOR := 3
## Off the hunt this long, it is whole again.
const RECOVER_AFTER := 15.0
## How far from its hoard it follows the hero (metres).
const HOARD_LEASH := 24.0
## The fire breath: how often, from how far, how long it draws breath, the
## gap between the fields of a line, how many fields a line has per phase,
## the angle between the lines from phase 2 on, and how long it is winded.
const BREATH_EVERY := 7.0
const BREATH_RANGE := 12.0
const BREATH_WINDUP := 1.1
const BREATH_FIRST := 2.2
const BREATH_STEP := 2.6
const BREATH_LENGTH := [4, 5, 6]
const BREATH_FAN := deg_to_rad(28.0)
const WINDED_TIME := 1.8
## The bite up close.
const BITE_RANGE := 2.8
const BITE_DAMAGE := 2
const BITE_EVERY := 1.6
## The fire rain of phase 3.
const RAIN_EVERY := 6.0
const RAIN_WARN := 1.3
const RAIN_COUNT := 3
## How much quicker it gets once raging.
const RAGE_SPEED := 1.2
const RAGE_COOLDOWN := 0.7

var phase := 1
var _breath_timer := BREATH_EVERY * 0.5
var _windup := 0.0
var _aim := Vector3.FORWARD
var _winded := 0.0
var _bite_timer := 0.0
var _rain_timer := RAIN_EVERY
var _calm := 0.0
var _introduced := false
## The fields of the breath it is drawing, still only warning rings.
var _pending: Array[FireField] = []
var _mouth_light: OmniLight3D
var _rage_light: OmniLight3D


func _init() -> void:
	kind = "drache"


## Its name and the shares of its life where its phases begin (see BossBar).
func boss_title() -> String:
	# One made in the map workshop goes by the name it was given there.
	return str(custom.get("title", TITLE))


func phase_marks() -> Array:
	return PHASE_AT


func max_hp() -> int:
	return int(_stats.hp)


## Winded after a breath: it hovers low and takes double damage.
func is_dazed() -> bool:
	return _winded > 0.0


func is_breathing() -> bool:
	return _windup > 0.0


func take_hit(damage: int, from: Vector3, hit_kind := "hit", wakes := true) -> void:
	if dead:
		return
	if hit_kind == "backstab":
		# No single stab ends a dragon, but it hurts.
		damage *= BACKSTAB_FACTOR
		hit_kind = "hit"
		Comic.pop(global_position, "backstab")
	if _winded > 0.0:
		damage *= 2
	super.take_hit(damage, from, hit_kind, wakes)
	if dead:
		return
	var share := float(hp) / float(max_hp())
	while phase < 3 and share <= PHASE_AT[phase - 1]:
		_enter_phase(phase + 1)


func _die() -> void:
	_windup = 0.0
	_winded = 0.0
	_quench()
	super._die()


## Its fire dies with it: the ground cools so the hoard can be gathered.
func _quench() -> void:
	_pending.clear()
	if is_instance_valid(_mouth_light):
		_mouth_light.queue_free()
	if not is_inside_tree():
		return
	for f in get_tree().get_nodes_in_group("fire_field"):
		f.queue_free()


func _enter_phase(next: int) -> void:
	phase = next
	var head := global_position + Vector3(0, 3.6 * _stats.size, 0)
	_breath_timer = minf(_breath_timer, 1.5)
	if phase == 2:
		Effects.float_text(level, head, Lang.t("Der Drache brüllt vor Wut!"), Color(1.0, 0.6, 0.25))
	elif phase == 3:
		Effects.float_text(level, head, Lang.t("Der Drache rast!"), Color(1.0, 0.3, 0.15))
		_stats.speed *= RAGE_SPEED
		_stats.cooldown *= RAGE_COOLDOWN
		_rain_timer = 2.0
		# A red glow about it, so the rage shows.
		_rage_light = OmniLight3D.new()
		_rage_light.light_color = Color(1.0, 0.25, 0.08)
		_rage_light.light_energy = 2.0
		_rage_light.omni_range = 6.0
		_rage_light.position = Vector3(0, 2.0, 0)
		add_child(_rage_light)
	_roar(4.0)
	Comic.pop(global_position, "big")
	phase_changed.emit(phase)


## Whole again, calm, no rage: the fight starts over.
func _recover() -> void:
	if phase >= 3:
		_stats.speed /= RAGE_SPEED
		_stats.cooldown /= RAGE_COOLDOWN
	if _rage_light:
		_rage_light.queue_free()
		_rage_light = null
	hp = max_hp()
	phase = 1
	phase_changed.emit(phase)


func _roar(db := 0.0) -> void:
	Sfx.play(level, "voice_koloss_%d" % (randi() % 2), db, global_position, 0.55)
	Effects.float_text(level, global_position + Vector3(0, 2.8 * _stats.size, 0), Lang.t("BRÜLL") + "!", Color(1.0, 0.55, 0.3))


## The first time it spots the hero on this visit: a roar the whole lair hears.
func _introduce() -> void:
	_introduced = true
	_breath_timer = 3.0
	_roar(6.0)
	Comic.pop(global_position, "rumble")
	awakened.emit()


func _physics_process(delta: float) -> void:
	if dead or level == null or level.player == null:
		return
	var player: Player = level.player
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if is_hunting() and not _introduced:
		_introduce()
	if _winded > 0.0:
		_winded -= delta
		_halt()
		if _winded <= 0.0:
			_rise()
		return
	if _windup > 0.0:
		_windup -= delta
		_face(_aim, delta)
		_halt()
		if _windup <= 0.0:
			_breathe()
		return
	# It guards its hoard and does not follow the hero far.
	if is_hunting() and _home != Vector3.INF and global_position.distance_to(_home) > HOARD_LEASH:
		_awake = false
		_path.clear()
		_repath = 0.0
	if is_hunting():
		_calm = 0.0
	else:
		_calm += delta
		if _calm > RECOVER_AFTER and (hp < max_hp() or phase > 1):
			_recover()
	if is_hunting() and not player.dead and _busy <= 0.0 and not level.stacked(self, player):
		_breath_timer -= delta
		_bite_timer -= delta
		if phase >= 3:
			_rain_timer -= delta
			if _rain_timer <= 0.0:
				_fire_rain(player)
		if _bite_timer <= 0.0 and dist < BITE_RANGE + girth():
			_bite(player)
			return
		if _breath_timer <= 0.0 and dist < BREATH_RANGE and level.has_line_of_sight(global_position, player.global_position):
			_draw_breath(to_player)
			return
	super._physics_process(delta)


## Stands where it is (knockback still applies).
func _halt() -> void:
	velocity = _knockback
	velocity.y = -9.0
	_knockback = _knockback.move_toward(Vector3.ZERO, get_physics_process_delta_time() * 40.0)
	move_and_slide()


## It rears up and draws breath; red rings on the floor show where the fire
## will fall, a line towards the hero (three lines once furious).
func _draw_breath(to_player: Vector3) -> void:
	_windup = BREATH_WINDUP
	_breath_timer = BREATH_EVERY * (0.7 if phase >= 2 else 1.0) * randf_range(0.85, 1.15)
	_aim = to_player.normalized() if to_player.length() > 0.01 else ahead()
	_face(_aim)
	_current_anim = ""
	_play("Idle")
	Effects.float_text(level, global_position + Vector3(0, 3.4 * _stats.size, 0), "!!", Color(1.0, 0.35, 0.15))
	Sfx.play(level, "voice_koloss_%d" % (randi() % 2), -2.0, global_position, 0.7)
	_mouth_light = OmniLight3D.new()
	_mouth_light.light_color = Color(1.0, 0.45, 0.1)
	_mouth_light.light_energy = 3.0
	_mouth_light.omni_range = 5.0
	_mouth_light.position = Vector3(0, 1.6 * _stats.size, 0) + _aim * 1.2
	add_child(_mouth_light)
	_pending.clear()
	var lines: Array = [0.0] if phase < 2 else [-BREATH_FAN, 0.0, BREATH_FAN]
	var length: int = BREATH_LENGTH[phase - 1]
	for turn in lines:
		var dir := _aim.rotated(Vector3.UP, turn)
		for i in length:
			var pos := global_position + dir * (BREATH_FIRST + BREATH_STEP * i)
			if level.is_opaque(level.world_to_cell(pos)):
				break
			# The fire rolls outwards: the near rings catch first.
			_pending.append(FireField.spawn(level, pos, BREATH_WINDUP + 0.07 * i))


## The fire breath: a stream of flame over the rings, which catch fire. Then
## it sinks down, winded.
func _breathe() -> void:
	_play_once("1H_Ranged_Shoot", 0.7)
	Sfx.play(self, "magic", 0.0, global_position, 0.5)
	Comic.pop(global_position + _aim * 3.0, "big")
	var stream := CPUParticles3D.new()
	stream.amount = 60
	stream.lifetime = 0.55
	stream.one_shot = true
	stream.explosiveness = 0.2
	stream.direction = Vector3(0, 0, 1)
	stream.spread = 14.0
	stream.gravity = Vector3.ZERO
	stream.initial_velocity_min = 14.0
	stream.initial_velocity_max = 18.0
	stream.scale_amount_min = 1.0
	stream.scale_amount_max = 2.2
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	stream.mesh = quad
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.4, 1.0))
	ramp.set_color(1, Color(0.9, 0.2, 0.03, 0.0))
	stream.color_ramp = ramp
	level.add_child(stream)
	stream.global_position = global_position + Vector3(0, 1.6 * _stats.size, 0) + _aim * 1.2
	stream.look_at(stream.global_position - _aim, Vector3.UP)
	stream.emitting = true
	get_tree().create_timer(1.5).timeout.connect(stream.queue_free)
	_pending.clear()
	if is_instance_valid(_mouth_light):
		_mouth_light.queue_free()
	await get_tree().create_timer(0.6).timeout
	if dead or not is_inside_tree():
		return
	# Out of breath: down it sinks, open to the blade.
	_winded = WINDED_TIME
	_current_anim = ""
	_play("Idle")
	create_tween().tween_property(_model.get_child(0), "position:y", 0.2, 0.4)
	Effects.float_text(level, global_position + Vector3(0, 2.6 * _stats.size, 0), Lang.t("Schnauft!"), Color(1.0, 0.95, 0.5))


## Back up into the air after catching its breath.
func _rise() -> void:
	_current_anim = ""
	if not dead:
		create_tween().tween_property(_model.get_child(0), "position:y", float(_stats.get("lift", 0.0)), 0.5)


## Up close it snaps at the hero.
func _bite(player: Player) -> void:
	_bite_timer = BITE_EVERY
	_cooldown = maxf(_cooldown, 0.8)
	_face(player.global_position - global_position)
	_play_once("1H_Melee_Attack_Chop", 0.8)
	Sfx.play(self, "swing", -2.0, global_position, 0.6)
	await get_tree().create_timer(0.4).timeout
	if dead or not is_inside_tree() or player.dead:
		return
	var d := player.global_position - global_position
	d.y = 0.0
	if d.length() < BITE_RANGE + girth() + 0.6 and not level.stacked(self, player) and not level.door_between(global_position, player.global_position):
		player.take_damage(BITE_DAMAGE, global_position, self)


## Raging, it spits fire into the air: rings glow around the hero and the
## fire comes down on them a moment later.
func _fire_rain(player: Player) -> void:
	_rain_timer = RAIN_EVERY * randf_range(0.85, 1.15)
	Effects.float_text(level, global_position + Vector3(0, 3.4 * _stats.size, 0), Lang.t("Feuerregen!"), Color(1.0, 0.45, 0.15))
	Sfx.play(self, "magic", -2.0, global_position, 0.7)
	var spots: Array[Vector3] = [player.global_position]
	for i in RAIN_COUNT - 1:
		var angle := randf() * TAU
		spots.append(player.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(2.6, 4.2))
	for pos in spots:
		if not level.is_opaque(level.world_to_cell(pos)):
			FireField.spawn(level, pos, RAIN_WARN)


## A boss shrugs off a thunder weapon's crack (see Enemy.shock).
func can_be_stunned() -> bool:
	return false
