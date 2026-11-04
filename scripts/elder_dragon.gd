class_name ElderDragon
extends Enemy
## The Great Old One: a dragon older than the mountain, asleep on its hoard
## deep below the high valley (see ElderLair). It is not there to be slain.
## No blade or knife gets through its scales, and awake it burns everything
## in front of it, so the only way to its hoard is to sneak.
##
## How it works, kept simple and readable:
## - Asleep it is blind: light does not matter, only noise. Walking, running
##   or jumping within EAR range makes it restless; sneaking and standing
##   still do not. A hit wakes it at once, and so does bumping into it
##   without sneaking.
## - Restlessness shows over its head: the calm "Zzz" turns into "Zzz?" and
##   then a warning, and fades again while the hero keeps quiet.
## - Full restlessness wakes it: it roars, rears up and breathes fire at the
##   hero every few seconds. Each breath first marks its cone with red rings
##   (see FireField) and then burns hard (BREATH_DAMAGE, not blockable). Out
##   of its sight, it settles back to sleep after a while.
## - It never moves from its bed of gold: running away always works.

signal awakened
signal settled

const TITLE := "Der Große Alte"
## How far it hears a hero who does not sneak (metres), how fast it grows
## restless (share of full per second; louder up close and while running),
## and how fast it calms down again.
const EAR := 28.0
const STIR_RATE := 0.45
const RUN_STIR := 2.0
const CALM_RATE := 0.12
## The breath: how far it reaches, the half angle of its cone, how long it
## draws breath, how long between two, and what it does to the hero.
const BREATH_RANGE := 30.0
const BREATH_CONE := deg_to_rad(26.0)
const BREATH_WINDUP := 1.4
const BREATH_EVERY := 3.6
const BREATH_DAMAGE := 14
## The fields of the breath: rows out from the snout, how far apart (rows
## and the fields in a row), and how wide each one burns. The gap is smaller
## than a field is wide, so they overlap into one sheet of fire.
const BREATH_ROWS := 8
const BREATH_STEP := 2.4
const BREATH_FIELD := 1.6
## Out of the hero's sight this long, it goes back to sleep.
const SETTLE_AFTER := 8.0
## How often the "Zzz" shows while it sleeps.
const SNORE_EVERY := 3.2
## Closer than this (metres, to its middle) the hero bumps into its body.
const BUMP := 5.0
## How far its lying body is shifted to lie centred over its spot.
const SLEEP_SHIFT := Vector3(-3.3, 0, -0.4)

## Asleep or awake.
var asleep := true
## Restlessness, 0 (deep asleep) to 1 (awake).
var unrest := 0.0
var _breath_timer := 0.0
var _windup := 0.0
var _aim := Vector3.FORWARD
var _unseen := 0.0
var _snore := 1.0
var _warned_level := 0


func _init() -> void:
	kind = "grosser_alter"


func boss_title() -> String:
	return str(custom.get("title", TITLE))


func _ready() -> void:
	super._ready()
	add_to_group("elder_dragon")
	# It lies facing the hall and its hoard, and a pale light falls on it
	# from above, so the hero sees what sleeps there.
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 0.75, 1.0)
	light.light_energy = 1.6
	light.omni_range = 16.0
	light.position = Vector3(0, 7.0, 2.0)
	add_child(light)
	_lie_down(false)


## It cannot be slain, so it is no fair fight for anyone.
func is_level_boss() -> bool:
	return false


func can_be_stunned() -> bool:
	return false


func open_to_backstab(_from: Vector3) -> bool:
	return false


## No blade gets through: it only wakes up.
func take_hit(_damage: int, from: Vector3, _hit_kind := "hit", wakes := true) -> void:
	if dead:
		return
	Comic.pop(global_position, "block")
	Effects.head_text(level, self, 2.6 * _stats.size, Lang.t("Prallt an den uralten Schuppen ab!"), Color(0.85, 0.8, 0.95))
	if wakes:
		wake_up(from)


## Noise near it: it grows restless by `amount` (share of full).
func disturb(amount: float) -> void:
	if not asleep or dead:
		return
	unrest = clampf(unrest + amount, 0.0, 1.0)
	_show_unrest()
	if unrest >= 1.0:
		wake_up(level.player.global_position if level and level.player else global_position)


## Fully awake at once: a roar, and the fire comes.
func wake_up(at: Vector3) -> void:
	if not asleep or dead:
		return
	asleep = false
	unrest = 1.0
	_unseen = 0.0
	_breath_timer = 1.0
	_awake = true
	_last_known = at
	_rise_up()
	Sfx.play(level, "voice_koloss_%d" % (randi() % 2), 8.0, global_position, 0.35)
	Effects.float_text(level, global_position + Vector3(0, 3.4 * _stats.size, 0), Lang.t("BRÜLL") + "!", Color(1.0, 0.45, 0.25))
	Comic.pop(global_position, "rumble")
	awakened.emit()


## Back to sleep on its gold.
func settle() -> void:
	if asleep or dead:
		return
	asleep = true
	_awake = false
	unrest = 0.0
	_windup = 0.0
	_warned_level = 0
	_lie_down(true)
	settled.emit()


func is_hunting() -> bool:
	return not asleep and not dead


func is_breathing() -> bool:
	return _windup > 0.0


## Asleep: curled up on the floor, its eyes shut (the end of its fall,
## held still).
func _lie_down(blend: bool) -> void:
	if _anim == null:
		return
	var name: String = _stats.anims.Death_A
	_current_anim = "sleep"
	# Lying on its side its body reaches far to one side: shifted back so
	# it lies over its own spot (and its solid footprint, see Level).
	_model.rotation.y = 0.0
	_model.position = SLEEP_SHIFT * float(_stats.size) / 3.6
	_anim.play(name, 0.6 if blend else 0.0)
	_anim.seek(_anim.current_animation_length * 0.97, true)
	_anim.speed_scale = 0.0


func _rise_up() -> void:
	if _anim == null:
		return
	_anim.speed_scale = 1.0
	_model.position = Vector3.ZERO
	_current_anim = ""
	_play("Idle", 0.5)


func _show_unrest() -> void:
	var step := 0 if unrest < 0.34 else (1 if unrest < 0.67 else 2)
	if step <= _warned_level:
		return
	_warned_level = step
	var head := global_position + Vector3(0, 2.2 * _stats.size, 0)
	if step == 1:
		Effects.float_text(level, head, "Zzz?", Color(1.0, 0.85, 0.45), true)
		Sfx.play(level, "voice_koloss_0", -6.0, global_position, 0.3)
	else:
		Effects.float_text(level, head, Lang.t("Er regt sich!"), Color(1.0, 0.5, 0.25), true)
		Sfx.play(level, "voice_koloss_1", -2.0, global_position, 0.32)


func _physics_process(delta: float) -> void:
	if dead or level == null or level.player == null:
		return
	if _home == Vector3.INF:
		_home = global_position
	visible = level.fog == null or level.fog.is_cell_visible(level.world_to_cell(global_position))
	var player: Player = level.player
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if asleep:
		_sleep(delta, player, dist)
		return
	var sees := not player.dead and dist < BREATH_RANGE + 6.0 and level.has_line_of_sight(global_position + Vector3(0, 2, 0), player.global_position + Vector3(0, 1, 0))
	_unseen = 0.0 if sees else _unseen + delta
	if _windup > 0.0:
		_windup -= delta
		_turn_to(_aim, delta)
		if _windup <= 0.0:
			_breathe(player)
		return
	if _unseen > SETTLE_AFTER or player.dead:
		settle()
		return
	if sees:
		_turn_to(to_player, delta)
		_breath_timer -= delta
		if _breath_timer <= 0.0 and dist < BREATH_RANGE:
			_draw_breath(to_player)


func _sleep(delta: float, player: Player, dist: float) -> void:
	_snore -= delta
	if _snore <= 0.0:
		_snore = SNORE_EVERY
		if unrest < 0.34:
			Effects.float_text(level, global_position + Vector3(0, 1.8 * _stats.size, 0), "Zzz", Color(0.75, 0.8, 1.0), true)
	if player.dead:
		return
	# Bumping into it without sneaking wakes it at once.
	if dist < BUMP and not player.sneaking:
		wake_up(player.global_position)
		return
	if dist < EAR and player.is_noisy():
		var near := 1.0 - dist / EAR
		var loud := RUN_STIR if player.sprinting else 1.0
		disturb(STIR_RATE * loud * (0.4 + near) * delta)
	elif unrest > 0.0:
		unrest = maxf(0.0, unrest - CALM_RATE * delta)
		if unrest < 0.34:
			_warned_level = 0
		elif unrest < 0.67:
			_warned_level = mini(_warned_level, 1)


func _turn_to(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.01:
		return
	var want := atan2(dir.x, dir.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, want, minf(1.0, delta * 2.5))


## It rears up and draws breath: red rings mark the cone of fire.
func _draw_breath(to_player: Vector3) -> void:
	_windup = BREATH_WINDUP
	_breath_timer = BREATH_EVERY
	_aim = to_player.normalized() if to_player.length() > 0.01 else Vector3.BACK
	_current_anim = ""
	_play("Idle")
	Effects.float_text(level, global_position + Vector3(0, 3.0 * _stats.size, 0), "!!", Color(1.0, 0.35, 0.15), true)
	Sfx.play(level, "voice_koloss_%d" % (randi() % 2), 2.0, global_position, 0.4)
	var count := 0
	for row in BREATH_ROWS:
		var out := BUMP + BREATH_STEP * row
		# As many fields across as fit at BREATH_STEP apart on this row's arc.
		var spread := ceili(out * BREATH_CONE / BREATH_STEP)
		for k in range(-spread, spread + 1):
			var turn := BREATH_CONE * float(k) / float(maxi(1, spread))
			var pos := global_position + _aim.rotated(Vector3.UP, turn) * out
			if level.is_opaque(level.world_to_cell(pos)):
				continue
			# Only every third field casts its own light: the blaze is lit
			# well enough, and dozens of lights would cost too much.
			FireField.spawn(level, pos, BREATH_WINDUP + 0.04 * row, 4.0, BREATH_FIELD, count % 3 == 0)
			count += 1


## The breath itself: whoever still stands in the cone burns badly.
func _breathe(player: Player) -> void:
	_play_once("1H_Ranged_Shoot", 0.8)
	Sfx.play(self, "magic", 2.0, global_position, 0.4)
	Comic.pop(global_position + _aim * 4.0, "big")
	if player.dead:
		return
	var to := player.global_position - global_position
	to.y = 0.0
	if in_breath(to) and level.has_line_of_sight(global_position + Vector3(0, 2, 0), player.global_position + Vector3(0, 1, 0)):
		player.take_damage(BREATH_DAMAGE, global_position, self, false)
		Effects.float_text(level, player.global_position + Vector3(0, 2.6, 0), Lang.t("Drachenfeuer!"), Color(1.0, 0.45, 0.15))


## Whether a spot (offset from it, flat) lies in the cone of its breath.
func in_breath(to: Vector3) -> bool:
	return to.length() < BREATH_RANGE and to.length() > 0.01 and to.normalized().angle_to(_aim) <= BREATH_CONE + deg_to_rad(6.0)
