class_name BanditChief
extends Enemy
## Ravenheart, the bandit chief: the boss of the robbers' pass. He fights in
## three phases, shown on his health bar (see BossBar):
##   1. Sword and shield. Now and then, when the hero stands close, he rams
##      them with his shield: a blow that knocks them to the ground.
##   2. Below two thirds of his life he calls his cutthroats from the tents
##      and keeps bashing.
##   3. Below one third he is enraged: quicker, and from a distance he
##      lowers his head and charges in a straight line. Step aside or jump.
##      A charge that misses leaves him dazed for a moment, and a dazed
##      chief takes double damage.
## A stab in the back does not bring him down at once like a skeleton, it
## only hits three times as hard. He falls only once per saved game and
## leaves his own blade behind (see Outdoor).

signal phase_changed(phase: int)

const TITLE := "Rabenherz, der Räuberhauptmann"
## The unique blade he drops (see Items).
const TROPHY := "rabenklinge"
## Share of his life at which phase 2 and phase 3 begin.
const PHASE_AT := [0.66, 0.33]
## Shield bash: how often, how close the hero must be, and what it does.
const BASH_EVERY := 6.0
const BASH_RANGE := 2.6
const BASH_DAMAGE := 1
## How many cutthroats he calls in phase 2.
const CALL_COUNT := 2
## The charge in phase 3: wind-up, speed, how long it runs at most, the
## distances it is used from, its damage, and the pause between charges.
const CHARGE_WINDUP := 0.9
const CHARGE_SPEED := 15.0
const CHARGE_TIME := 1.1
const CHARGE_FROM := 5.0
const CHARGE_UP_TO := 18.0
const CHARGE_DAMAGE := 2
const CHARGE_EVERY := 5.0
const CHARGE_HITS_AT := 1.7
## How long a missed charge leaves him dazed.
const DAZED_TIME := 1.8
## How much quicker he gets once enraged.
const RAGE_SPEED := 1.25
const RAGE_COOLDOWN := 0.8
## Backstabs hit this many times as hard instead of killing outright.
const BACKSTAB_FACTOR := 3
## Off the hunt this long, he binds his wounds: full life, phase 1 again.
const RECOVER_AFTER := 12.0

var phase := 1
var _bash_timer := BASH_EVERY * 0.5
var _charge_timer := 1.5
var _windup := 0.0
var _charging := 0.0
var _charge_dir := Vector3.ZERO
var _dazed := 0.0
var _calm := 0.0
var _rage_light: OmniLight3D


func _init() -> void:
	kind = "hauptmann"


## His name and the shares of his life where his phases begin (see BossBar).
func boss_title() -> String:
	# One made in the map workshop goes by the name it was given there.
	return str(custom.get("title", TITLE))


func phase_marks() -> Array:
	return PHASE_AT


## His full life, gear included.
func max_hp() -> int:
	return int(_stats.hp)


func is_dazed() -> bool:
	return _dazed > 0.0


func is_charging() -> bool:
	return _windup > 0.0 or _charging > 0.0


func take_hit(damage: int, from: Vector3, hit_kind := "hit", wakes := true) -> void:
	if dead:
		return
	if hit_kind == "backstab":
		# Not one stab ends the chief, but it hurts.
		damage *= BACKSTAB_FACTOR
		hit_kind = "pierce"
		Comic.pop(global_position, "backstab")
	if _dazed > 0.0:
		# Dazed, the chief's armour does not help him either.
		damage *= 2
		hit_kind = "pierce"
	super.take_hit(damage, from, hit_kind, wakes)
	if dead:
		_windup = 0.0
		_charging = 0.0
		_dazed = 0.0
		return
	var share := float(hp) / float(max_hp())
	while phase < 3 and share <= PHASE_AT[phase - 1]:
		_enter_phase(phase + 1)


func _enter_phase(next: int) -> void:
	phase = next
	var head := global_position + Vector3(0, 3.6 * _stats.size, 0)
	if phase == 2:
		Effects.float_text(level, head, Lang.t("Zu mir, Jungs!"), Color(1.0, 0.75, 0.4))
		Events.say(Lang.t(boss_title()), Lang.t("Zu mir, Jungs!"), global_position)
		_play_once("Cheer", 1.0)
		if level.has_method("call_reinforcements"):
			level.call_reinforcements(self, CALL_COUNT)
	elif phase == 3:
		Effects.float_text(level, head, Lang.t("Genug gespielt!"), Color(1.0, 0.35, 0.25))
		Events.say(Lang.t(boss_title()), Lang.t("Genug gespielt!"), global_position)
		_stats.speed *= RAGE_SPEED
		_stats.cooldown *= RAGE_COOLDOWN
		_charge_timer = 1.0
		# A red glow about him, so the rage shows.
		_rage_light = OmniLight3D.new()
		_rage_light.light_color = Color(1.0, 0.2, 0.1)
		_rage_light.light_energy = 1.6
		_rage_light.omni_range = 4.0
		_rage_light.position = Vector3(0, 1.4, 0)
		add_child(_rage_light)
	Comic.pop(global_position, "big")
	phase_changed.emit(phase)


## Back to how he was before the fight: full life, calm, no rage.
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


func _physics_process(delta: float) -> void:
	if dead or level == null or level.player == null:
		return
	var player: Player = level.player
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if _dazed > 0.0:
		_dazed -= delta
		_halt()
		if _dazed <= 0.0:
			_busy = 0.0
			_current_anim = ""
		return
	if _windup > 0.0:
		_windup -= delta
		_face(to_player, delta)
		_halt()
		if _windup <= 0.0:
			_start_charge(to_player)
		return
	if _charging > 0.0:
		_charge(delta, player)
		return
	if is_hunting():
		_calm = 0.0
	else:
		_calm += delta
		if _calm > RECOVER_AFTER and (hp < max_hp() or phase > 1):
			_recover()
	if is_hunting() and not player.dead and _busy <= 0.0 and not level.stacked(self, player):
		_bash_timer -= delta
		_charge_timer -= delta
		if _bash_timer <= 0.0 and dist < BASH_RANGE:
			_shield_bash(player)
			return
		if phase >= 3 and _charge_timer <= 0.0 and dist > CHARGE_FROM and dist < CHARGE_UP_TO \
				and level.has_line_of_sight(global_position, player.global_position):
			_wind_up()
			return
	super._physics_process(delta)


## Stands where he is (gravity and knockback still apply).
func _halt() -> void:
	velocity = _knockback
	velocity.y = -9.0
	_knockback = _knockback.move_toward(Vector3.ZERO, get_physics_process_delta_time() * 40.0)
	move_and_slide()


## He rams the hero with his shield: unblockable, and it knocks a running
## hero down.
func _shield_bash(player: Player) -> void:
	_bash_timer = BASH_EVERY * randf_range(0.8, 1.2)
	_cooldown = maxf(_cooldown, float(_stats.cooldown))
	_face(player.global_position - global_position)
	_play_once("Block_Attack", 0.8)
	Sfx.play(self, "swing", -2.0, global_position, 0.7)
	await get_tree().create_timer(0.35).timeout
	if dead or not is_inside_tree() or player.dead:
		return
	var d := player.global_position - global_position
	d.y = 0.0
	if d.length() < BASH_RANGE + 0.6 and not level.stacked(self, player) and not level.door_between(global_position, player.global_position):
		# The shield sends a running hero sprawling even when the blow
		# itself finds them still reeling from the last one.
		player.take_damage(BASH_DAMAGE, global_position, self, false)
		Comic.pop(player.global_position, "big")
		if not player.dead:
			player.knock_down()


## Lowers his head before the charge, so the hero can see it coming.
func _wind_up() -> void:
	_windup = CHARGE_WINDUP
	_play_once("Block", CHARGE_WINDUP)
	Effects.float_text(level, global_position + Vector3(0, 3.4 * _stats.size, 0), "!!", Color(1.0, 0.3, 0.2))


func _start_charge(to_player: Vector3) -> void:
	_charging = CHARGE_TIME
	_busy = 0.0
	_charge_timer = CHARGE_EVERY
	_charge_dir = to_player.normalized() if to_player.length() > 0.01 else ahead()
	_face(_charge_dir)
	_current_anim = ""
	_play("Running_B", 0.1)
	_anim.speed_scale = 2.0
	Sfx.play(self, "swing", 0.0, global_position, 0.6)


## Straight ahead at full tilt. A hit ends the charge; a miss or a wall
## leaves him dazed.
func _charge(delta: float, player: Player) -> void:
	_charging -= delta
	velocity = _charge_dir * CHARGE_SPEED
	velocity.y = -9.0
	move_and_slide()
	var d := player.global_position - global_position
	d.y = 0.0
	if not player.dead and d.length() < CHARGE_HITS_AT and absf(player.global_position.y - global_position.y) < 1.4 \
			and not level.door_between(global_position, player.global_position):
		_charging = 0.0
		_anim.speed_scale = 1.0
		var before := player.hp
		player.take_damage(CHARGE_DAMAGE, global_position, self)
		Comic.pop(player.global_position, "big")
		if player.hp < before and not player.dead:
			player.knock_down()
		_current_anim = ""
		_cooldown = float(_stats.cooldown)
		return
	var blocked := get_slide_collision_count() > 0 and get_real_velocity().length() < CHARGE_SPEED * 0.3
	if _charging <= 0.0 or blocked:
		_charging = 0.0
		_daze()


func _daze() -> void:
	_dazed = DAZED_TIME
	_anim.speed_scale = 1.0
	_play_once("Hit_B", DAZED_TIME)
	Effects.float_text(level, global_position + Vector3(0, 3.0 * _stats.size, 0), Lang.t("Benommen!"), Color(1.0, 0.95, 0.5))
	Comic.pop(global_position, "rumble")


## A boss shrugs off a thunder weapon's crack (see Enemy.shock).
func can_be_stunned() -> bool:
	return false
