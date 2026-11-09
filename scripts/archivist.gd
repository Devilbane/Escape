class_name Archivist
extends Enemy
## Archivar Veth, the mage of the archive (a monster made in the map workshop
## with "special": "nova", see Archivist.make). He fights like a skeleton
## mage, with a health bar at the top (see BossBar), and has one special move:
## every NOVA_EVERY seconds, once the hero is close, he stops and a red ring
## grows on the floor. NOVA_WINDUP seconds later a burst of force breaks from
## him and hurts whoever still stands inside the ring: step out of it.

const NOVA_EVERY := 7.0
const NOVA_WINDUP := 1.4
const NOVA_RADIUS := 5.0
## What the burst costs a hero inside the ring: a share of their full life.
const NOVA_SHARE := 0.25
const NOVA_COLOR := Color(0.62, 0.4, 1.0)
const SHOUT := "Das Archiv vergisst nichts!"

var _nova_timer := 3.0
var _windup := 0.0
var _ring: MeshInstance3D


## The Archivist for a map-workshop spec, or null for any other monster.
static func make(spec: Dictionary) -> Enemy:
	return Archivist.new() if spec.get("special", "") == "nova" else null


func boss_title() -> String:
	return str(custom.get("title", "Archivar Veth"))


func phase_marks() -> Array:
	return []


func is_dazed() -> bool:
	return false


func take_hit(damage: int, from: Vector3, hit_kind := "hit", wakes := true) -> void:
	super.take_hit(damage, from, hit_kind, wakes)
	if dead:
		_drop_ring()


func _physics_process(delta: float) -> void:
	if dead or level == null or level.player == null:
		return
	var player: Player = level.player
	if _windup > 0.0:
		_windup -= delta
		_halt()
		if is_instance_valid(_ring):
			_ring.scale = Vector3.ONE * lerpf(0.3, 1.0, clampf(1.0 - _windup / NOVA_WINDUP, 0.0, 1.0))
		if _windup <= 0.0:
			_burst(player)
		return
	if is_hunting() and not player.dead and _busy <= 0.0:
		_nova_timer -= delta
		var to := player.global_position - global_position
		to.y = 0.0
		if _nova_timer <= 0.0 and to.length() < NOVA_RADIUS + 4.0:
			_wind_up()
			return
	super._physics_process(delta)


## Stands where he is (gravity and knockback still apply).
func _halt() -> void:
	velocity = _knockback
	velocity.y = -9.0
	_knockback = _knockback.move_toward(Vector3.ZERO, get_physics_process_delta_time() * 40.0)
	move_and_slide()


func _wind_up() -> void:
	_windup = NOVA_WINDUP
	_nova_timer = NOVA_EVERY * randf_range(0.9, 1.1)
	_play_once("Spellcast_Raise", NOVA_WINDUP)
	Effects.float_text(level, global_position + Vector3(0, 3.4 * _stats.size, 0), Lang.t(SHOUT), Color(0.8, 0.65, 1.0))
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
