class_name SternBoss
extends Enemy
## A warden of Sternhall (see SternHall): a monster of the map's header with
## "boss": true, the robbers' leader in the courtyard, the jailer in the
## cellars and the fallen archmagus in the vault. Each fights like its base
## kind, with its health bar at the top (see BossBar), in three phases:
##   1. As its kind fights.
##   2. Below PHASE_AT[0] of its life it calls for help: CALL_COUNT of the
##      kind in its header's "calls" come running (see SternHall.call_help).
##   3. Below PHASE_AT[1] it is enraged: quicker, and every NOVA_EVERY
##      seconds a burst of force breaks from it. A red ring on the floor shows
##      how far it reaches, NOVA_WINDUP seconds before it hits: step out of it.
## Off the hunt for RECOVER_AFTER seconds it binds its wounds. It falls only
## once (see SternHall), and one with "keys" drops the key ring of its floor.

const PHASE_AT := [0.6, 0.3]
const CALL_COUNT := 3
const NOVA_EVERY := 6.5
const NOVA_WINDUP := 1.1
const NOVA_RADIUS := 4.8
## What the burst costs a hero inside the ring: a share of their full life.
const NOVA_SHARE := 0.22
const RAGE_SPEED := 1.2
const RAGE_COOLDOWN := 0.85
const RECOVER_AFTER := 15.0
const NOVA_COLOR := Color(1.0, 0.25, 0.15)
## What each warden calls out as it enters phase 2 and 3, by its base kind.
const SHOUTS := {
	"schlaeger": ["Jungs! Frischfleisch!", "Ich mach dich kalt!"],
	"koloss": ["Wachen! Ein Ausbrecher!", "In die Zelle mit dir, in Stücken!"],
	"magier": ["Erhebt euch, ihr Toten!", "Die Sterne gehören MIR!"],
}

var phase := 1
## What its header says it calls for help (an Enemy.KINDS id).
var calls := ""
var _nova_timer := 3.0
var _windup := 0.0
var _ring: MeshInstance3D
var _calm := 0.0


func boss_title() -> String:
	return str(custom.get("title", Creations.MONSTER_NAMES.get(kind, kind)))


func phase_marks() -> Array:
	return PHASE_AT


func is_dazed() -> bool:
	return false


func take_hit(damage: int, from: Vector3, hit_kind := "hit", wakes := true) -> void:
	if dead:
		return
	super.take_hit(damage, from, hit_kind, wakes)
	if dead:
		_drop_ring()
		return
	var share := float(hp) / float(max_hp())
	while phase < 3 and share <= PHASE_AT[phase - 1]:
		_enter_phase(phase + 1)


func _enter_phase(next: int) -> void:
	phase = next
	var shouts: Array = SHOUTS.get(kind, ["", ""])
	var line: String = shouts[clampi(phase - 2, 0, 1)]
	if line != "":
		Effects.float_text(level, global_position + Vector3(0, 3.4 * _stats.size, 0), Lang.t(line), Color(1.0, 0.6, 0.4))
		Events.say(Lang.t(boss_title()), Lang.t(line), global_position)
	_play_once("Cheer", 0.9)
	Comic.pop(global_position, "big")
	if phase == 2 and calls != "" and level.stern:
		level.stern.call_help(self, calls, CALL_COUNT)
	elif phase == 3:
		_stats.speed *= RAGE_SPEED
		_stats.cooldown *= RAGE_COOLDOWN
		_nova_timer = 1.5


## Back to how it was before the fight: full life, calm, no rage.
func _recover() -> void:
	if phase >= 3:
		_stats.speed /= RAGE_SPEED
		_stats.cooldown /= RAGE_COOLDOWN
	hp = max_hp()
	phase = 1


func _physics_process(delta: float) -> void:
	if dead or level == null or level.player == null:
		return
	var player: Player = level.player
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if _windup > 0.0:
		_windup -= delta
		_halt()
		if is_instance_valid(_ring):
			var grow := clampf(1.0 - _windup / NOVA_WINDUP, 0.0, 1.0)
			_ring.scale = Vector3.ONE * lerpf(0.3, 1.0, grow)
		if _windup <= 0.0:
			_burst(player)
		return
	if is_hunting():
		_calm = 0.0
	else:
		_calm += delta
		if _calm > RECOVER_AFTER and (hp < max_hp() or phase > 1):
			_recover()
	if phase >= 3 and is_hunting() and not player.dead and _busy <= 0.0:
		_nova_timer -= delta
		if _nova_timer <= 0.0 and to_player.length() < NOVA_RADIUS + 3.0:
			_wind_up()
			return
	super._physics_process(delta)


## Stands where it is (gravity and knockback still apply).
func _halt() -> void:
	velocity = _knockback
	velocity.y = -9.0
	_knockback = _knockback.move_toward(Vector3.ZERO, get_physics_process_delta_time() * 40.0)
	move_and_slide()


func _wind_up() -> void:
	_windup = NOVA_WINDUP
	_nova_timer = NOVA_EVERY * randf_range(0.85, 1.15)
	_play_once("Spellcast_Raise" if kind == "magier" else "Cheer", NOVA_WINDUP)
	_clear_ring()
	_ring = SternParts.warning_ring(level, global_position, NOVA_RADIUS, NOVA_COLOR)
	_ring.reparent(self)
	Sfx.play(self, "rumble", -6.0, global_position, 1.4)


## The burst: whoever stands inside the ring is thrown back and hurt.
func _burst(player: Player) -> void:
	_clear_ring()
	Comic.pop(global_position, "big")
	Events.bus().camera_punched.emit(0.5)
	Sfx.play(self, "magic", -2.0, global_position, 0.6)
	var dust := Effects.make_sparkles(NOVA_COLOR, true)
	dust.position = global_position + Vector3(0, 0.8, 0)
	dust.amount = 60
	level.add_child(dust)
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() <= NOVA_RADIUS and not player.dead:
		player.take_damage(maxi(1, roundi(player.max_hp * NOVA_SHARE)), global_position, self, false)


func _clear_ring() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null


func _drop_ring() -> void:
	_windup = 0.0
	_clear_ring()


func _exit_tree() -> void:
	_clear_ring()
	super._exit_tree()
