class_name Player
extends CharacterBody3D
## The rogue. Moves with WASD / arrow keys or walks to a clicked spot,
## jumps, fights with a dagger up close and throws knives from afar.

signal hurt(amount: int)
signal defeated
signal ailments_changed
## Emitted when the hero runs into something solid, with a point just inside it.
signal bumped(point: Vector3)

const SPEED := 4.0
const JUMP_VELOCITY := 9.0
const GRAVITY := 26.0
## How fast the feet travel over the ground in the run animation at normal
## playback (metres per second, measured from the foot bone).
const RUN_ANIM_SPEED := 3.5
const MAX_HP := 5
const MELEE_RANGE := 2.8
## Running into a skeleton starts a fight: the hero keeps swinging while
## standing next to it, and throws knives at it once the two are apart.
const ENGAGE_RANGE := MELEE_RANGE
const AUTO_MELEE_INTERVAL := 0.8
const AUTO_THROW_INTERVAL := 1.2
const AUTO_THROW_RANGE := 22.0
const HIDDEN_PARTS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

var level: Level
var controllable := true
## While frozen, the game moves the hero itself (e.g. up the exit stairs).
var frozen := false
var dead := false
var hp := MAX_HP
# Gifts from shrines, kept for the whole run.
var gift_hp := 0
var gift_power := 0
var gift_speed := 0.0
## Worn items by slot ("waffe", "schild", "amulett") and the bag of carried ones.
var equipped := {}
var bag: Array[String] = []
# Values from gifts and worn items together; see refresh_stats().
var max_hp := MAX_HP
var power := 1
## Taken off every hit by worn armour; a hit still costs at least 1 life.
var hardening := 0
## How much each armour piece has worn down, by item id.
var wear := {}
## Chance per hit that a worn armour piece loses a point of durability.
const WEAR_CHANCE := 0.05
## Chance to stop a whole hit with the worn shield (from the shield's "block").
var block_chance := 0.0
## Chance that a blocked hit costs the shield a point of durability.
const BLOCK_WEAR_CHANCE := 0.2
## Speed from gifts, worn items and ailments, before the load is counted.
var base_speed := SPEED
## The speed the hero really runs at: everything carried (worn or in the bag)
## weighs them down.
var speed: float:
	get:
		return base_speed * Items.load_factor(carried_weight())
var knives := 5
## Ailments and the seconds each has left. Poison ("gift") takes a life every
## few seconds but never the last one; a curse ("fluch") slows the hero.
## Both wear off soon; a fountain, a shrine or a healing potion cures them.
var ailments := {}
var _poison_tick := 0.0
## A direction to run in, set every frame while the mouse button is held.
var steer := Vector3.ZERO
var _stuck_time := 0.0
var _sidestepped := false
## Speed carried through the air by a running jump.
var _air_momentum := Vector3.ZERO
var path: Array[Vector3] = []
## Sneaking: much slower, but silent, with the lantern hooded, and see-through
## (more so in the dark). Skeletons cannot hear a sneaking hero.
var sneaking := false
## Set by the level each frame: no light falls on the hero but the lantern.
var in_shadow := false
const SNEAK_SPEED := 0.4
const SNEAK_ANIM := "Walking_C"
var _lantern: OmniLight3D
var _shown_alpha := -1.0

var _model: Node3D
var _anim: AnimationPlayer
## Where in the run cycle each foot touches the ground (left, right).
const FOOT_LANDINGS := [0.17, 0.67]
## The same for the sneaking walk, whose feet land later in its cycle.
const SNEAK_LANDINGS := [0.29, 0.79]
var _last_phase := -1.0
var _current_anim := ""
var _busy := 0.0
var _invulnerable := 0.0
var _attack_cooldown := 0.0
var _knockback := Vector3.ZERO
## The skeleton last fought up close, kept under fire from afar.
var _target: Enemy = null
var _auto_cooldown := 0.0
## Time left on an animation that plays while the hero keeps moving.
var _anim_hold := 0.0


func _ready() -> void:
	add_to_group("combatant")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.4
	shape.shape = capsule
	shape.position.y = 1.2
	add_child(shape)

	_model = preload("res://assets/characters/Rogue.glb").instantiate()
	add_child(_model)
	for part in HIDDEN_PARTS:
		var node := _model.find_child(part, true, false)
		if node:
			node.visible = false
	_add_cape_logo()
	_add_trim()
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A", "Walking_A", "Jump_Idle", SNEAK_ANIM]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("Idle")

	# A warm lantern glow around the hero, so the way ahead is never pitch black.
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(1.0, 0.75, 0.5)
	_lantern.light_energy = 1.1
	_lantern.omni_range = 8.5
	_lantern.position = Vector3(0, 3.2, 0.6)
	add_child(_lantern)


## Switches between walking normally and sneaking.
func set_sneaking(on: bool) -> void:
	sneaking = on
	# A hooded lantern: just enough to see the floor, too little to be seen by.
	_lantern.light_energy = 0.45 if on else 1.1
	_lantern.omni_range = 5.0 if on else 8.5


## Whether skeletons could see the hero by some light, the lantern included.
func is_lit() -> bool:
	return not sneaking or not in_shadow


## Whether the hero makes noise: moving without sneaking.
func is_noisy() -> bool:
	return not sneaking and (Vector2(velocity.x, velocity.z).length() > 0.5 or not is_on_floor())


## Fades the hero while sneaking, and further in the shadows.
func _update_sneak_look() -> void:
	var alpha := 0.0
	if sneaking:
		alpha = 0.65 if in_shadow else 0.4
	if is_equal_approx(alpha, _shown_alpha):
		return
	_shown_alpha = alpha
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override is ShaderMaterial:
			# A tinted part: swap in the shader that can fade.
			var tinted := mesh.material_override as ShaderMaterial
			tinted.shader = TINT_FADE_SHADER if alpha > 0.0 else TINT_SHADER
			tinted.set_shader_parameter("fade", alpha)
			continue
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.get_surface_override_material(i) as StandardMaterial3D
			if mat == null:
				if alpha <= 0.0:
					continue # Never faded: nothing to undo.
				var base := mesh.mesh.surface_get_material(i) as StandardMaterial3D
				if base == null:
					continue
				mat = base.duplicate()
				mesh.set_surface_override_material(i, mat)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha > 0.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color.a = 1.0 - alpha


## A golden cord along the edge of the cape, and a white feather at the head.
func _add_trim() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.76, 0.28)
	gold.metallic = 0.7
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color(0.55, 0.36, 0.08)
	var cape := _model.find_child("Rogue_Cape", true, false) as MeshInstance3D
	if cape:
		var cord := MeshInstance3D.new()
		cord.mesh = Effects.cord_mesh(Effects.open_edges(cape.mesh), 0.075, gold)
		cape.add_child(cord)
	var head := _model.find_child("Rogue_Head", true, false) as MeshInstance3D
	var skeleton := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if head == null or skeleton == null:
		return
	# The head is skinned to the head bone: place the feather in that bone's space.
	var bind := Transform3D.IDENTITY
	for i in head.skin.get_bind_count():
		if head.skin.get_bind_name(i) == "head":
			bind = head.skin.get_bind_pose(i)
	var attach := BoneAttachment3D.new()
	attach.name = "HeadSlot"
	attach.bone_name = "head"
	skeleton.add_child(attach)
	var feather := MeshInstance3D.new()
	feather.name = "Feather"
	feather.mesh = Effects.feather_mesh()
	feather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tucked in on the left side of the head, sweeping up and back.
	feather.transform = Transform3D(Basis.from_euler(Vector3(-0.75, 0.0, -0.45)).scaled(Vector3.ONE * 1.3), bind * Vector3(0.47, 1.66, -0.05))
	attach.add_child(feather)


## The glowing devilbane emblem on the back of the cape.
func _add_cape_logo() -> void:
	var cape := _model.find_child("Rogue_Cape", true, false) as Node3D
	if cape == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.64)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/logo/devilbane_logo.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.3, 1.3, 1.3)
	quad.material = mat
	var logo := MeshInstance3D.new()
	logo.mesh = quad
	logo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Up near the shoulders, tilted to follow the cape's slope towards the hood.
	logo.position = Vector3(0, -0.36, -0.39)
	logo.rotation = Vector3(-0.3, PI, 0)
	cape.add_child(logo)


func play(anim_name: String, blend := 0.2) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_anim.play(anim_name, blend)


## Plays a one-off animation and pauses movement for its duration.
func play_once(anim_name: String, duration: float) -> void:
	_current_anim = ""
	play(anim_name, 0.1)
	_busy = duration


func face(direction: Vector3) -> void:
	_model.rotation.y = atan2(direction.x, direction.z)


func facing() -> Vector3:
	return Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))


## Puts the hero at a level's start; `heal` fills up life again.
func revive(at: Vector3, heal := true) -> void:
	dead = false
	if heal or hp <= 0:
		hp = max_hp
	path.clear()
	_target = null
	velocity = Vector3.ZERO
	global_position = at
	_invulnerable = 1.5
	_busy = 0.0
	play("Idle")


## Walks along the grid to `target`. With `stop_short` the hero walks right
## up to a thing standing there (a chest, a barrel, the merchant) and stops
## that far from its middle, instead of waiting a whole tile away.
func walk_to(target: Vector3, stop_short := 0.0) -> void:
	var from := level.world_to_cell(global_position)
	var to := level.world_to_cell(target)
	path.clear()
	for c in level.astar.get_id_path(from, to, true).slice(1):
		path.append(level.cell_to_world(c))
	if stop_short > 0.0:
		var last: Vector3 = path[-1] if not path.is_empty() else global_position
		var away := last - target
		away.y = 0.0
		if away.length() > stop_short:
			path.append(target + away.normalized() * stop_short)


func can_act() -> bool:
	return controllable and not frozen and not dead and _busy <= 0.0


## True while the hero is moving under its own steam.
func is_running() -> bool:
	return not sneaking and Vector2(velocity.x, velocity.z).length() > SPEED * 0.4


## A jump from a run keeps its momentum and flies further the faster the
## hero runs; a standing jump goes straight up.
func jump() -> void:
	if not controllable or frozen or dead or not is_on_floor():
		return
	_air_momentum = Vector3.ZERO
	var jump_boost := 1.0
	if is_running():
		var run := Vector3(velocity.x, 0, velocity.z) - Vector3(_knockback.x, 0, _knockback.z)
		jump_boost = clampf(run.length() / SPEED, 0.6, 1.6)
		_air_momentum = run * (1.0 + 0.15 * jump_boost)
	velocity.y = JUMP_VELOCITY * (0.85 + 0.15 * jump_boost)
	_current_anim = ""
	play("Jump_Full_Short", 0.1)


func _nearest_enemy(max_distance: float, need_sight: bool) -> Enemy:
	var best: Enemy = null
	var best_d := max_distance
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d and (not need_sight or level.has_line_of_sight(global_position, e.global_position)):
			best = e
			best_d = d
	return best


## A step sounds each time a foot lands in the run animation, so the sound
## keeps the rhythm of the feet at any speed.
func _footsteps(ground_speed: float) -> void:
	var sneak := _current_anim == SNEAK_ANIM
	if not (sneak or _current_anim == "Running_A") or not is_on_floor() or ground_speed < 0.3:
		_last_phase = -1.0
		return
	var phase := _anim.current_animation_position / _anim.current_animation_length
	if _last_phase >= 0.0:
		for landing: float in (SNEAK_LANDINGS if sneak else FOOT_LANDINGS):
			var crossed: bool = _last_phase < landing and phase >= landing
			if phase < _last_phase:
				crossed = _last_phase < landing or phase >= landing
			if crossed:
				# Sneaking: only a very soft touch, barely to be heard.
				if sneak:
					Sfx.play(self, "sneak_%d" % (randi() % 4), -22.0)
				else:
					Sfx.play(self, "step_%d" % (randi() % 6), -14.0)
	_last_phase = phase


func melee() -> void:
	if not can_act() or _attack_cooldown > 0.0:
		return
	path.clear()
	var target := _nearest_enemy(MELEE_RANGE + 1.2, true)
	if target:
		_target = target
		face(target.global_position - global_position)
	_attack_cooldown = 0.5
	play_once("1H_Melee_Attack_Slice_Horizontal", 0.45)
	Sfx.play(self, "swing")
	await get_tree().create_timer(0.18).timeout
	var hits := 0
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < MELEE_RANGE + e.girth() and (to.length() < 1.2 + e.girth() or facing().dot(to.normalized()) > 0.25):
			if e.open_to_backstab(global_position):
				e.take_hit(power, global_position, "backstab")
			else:
				e.take_hit(power, global_position)
			hits += 1
	if hits == 0 and target:
		Comic.pop(global_position + facing() * 1.5, "miss")


## Throws a knife at `aim` (a world position), or at the closest enemy in sight.
## On the move the hero throws without stopping.
func throw_knife(aim = null, on_the_move := false) -> void:
	if not can_act() or _attack_cooldown > 0.0:
		return
	if knives <= 0:
		Effects.float_text(level, global_position + Vector3(0, 3.2, 0), Lang.t("Keine Wurfmesser"), Color(1, 1, 1, 0.8))
		return
	path.clear()
	var dir := facing()
	if aim is Vector3:
		dir = aim - global_position
	else:
		var target := _nearest_enemy(26.0, true)
		if target:
			dir = target.global_position - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = facing()
	face(dir)
	knives -= 1
	_attack_cooldown = 0.6
	if on_the_move:
		_current_anim = ""
		play("Throw", 0.1)
		_anim_hold = 0.45
	else:
		play_once("Throw", 0.45)
	await get_tree().create_timer(0.2).timeout
	Sfx.play(self, "throw")
	Projectile.spawn(level, global_position + Vector3(0, 1.5, 0) + dir.normalized() * 0.6, dir, true).damage = power


func _engage(enemy: Enemy) -> void:
	if enemy.dead:
		return
	if _target != enemy:
		_auto_cooldown = 0.0
	_target = enemy


## Keeps fighting the current target: blade while next to it, knives from afar.
func _auto_attack() -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or _target.dead:
		_target = null
		return
	if not can_act() or _auto_cooldown > 0.0 or _attack_cooldown > 0.0:
		return
	var d := global_position.distance_to(_target.global_position)
	if d <= ENGAGE_RANGE:
		_auto_cooldown = AUTO_MELEE_INTERVAL
		melee()
	elif d <= AUTO_THROW_RANGE and knives > 0 and level.has_line_of_sight(global_position, _target.global_position):
		_auto_cooldown = AUTO_THROW_INTERVAL
		throw_knife(_target.global_position, true)


## A fresh hero for a new game: no gifts, no items.
func reset_gifts() -> void:
	gift_hp = 0
	gift_power = 0
	gift_speed = 0.0
	equipped = {}
	wear.clear()
	bag.clear()
	refresh_stats()


## Recomputes life, strength and speed from gifts and worn items,
## and shows the worn weapon and shield in the hero's hands.
func refresh_stats() -> void:
	var hp_bonus := gift_hp
	var power_bonus := gift_power
	var speed_bonus := gift_speed
	hardening = 0
	block_chance = 0.0
	for slot in equipped:
		var item: Dictionary = Items.ALL[equipped[slot]]
		hp_bonus += item.get("hp", 0)
		power_bonus += item.get("power", 0)
		speed_bonus += item.get("speed", 0.0)
		hardening += item.get("armor", 0)
		block_chance += item.get("block", 0.0)
	max_hp = MAX_HP + hp_bonus
	power = 1 + power_bonus
	base_speed = SPEED * (1.0 + speed_bonus)
	if ailments.has("fluch"):
		base_speed *= CURSE_SLOW
	hp = mini(hp, max_hp)
	_show_held("waffe", "handslot_r", "Knife")
	_show_held("schild", "handslot_l", "")
	_show_headgear()
	_show_tint("umhang", ["Rogue_Cape"])
	_show_tint("ruestung", ["Rogue_Body"])
	_show_tint("schuhe", ["Rogue_LegLeft", "Rogue_LegRight"])
	_shown_alpha = -1.0 # New parts: fade them too if sneaking.


const TINT_SHADER := preload("res://shaders/tint.gdshader")
const TINT_FADE_SHADER := preload("res://shaders/tint_fade.gdshader")


## Colours the hero's cloak, body or legs after the worn cloak, armour or shoes.
func _show_tint(slot: String, parts: Array) -> void:
	var item: Dictionary = Items.ALL.get(equipped.get(slot, ""), {})
	for part in parts:
		var mesh := _model.find_child(part, true, false) as MeshInstance3D
		if not item.has("tint"):
			mesh.material_override = null
			continue
		var mat := ShaderMaterial.new()
		mat.shader = TINT_SHADER
		mat.set_shader_parameter("tex", (mesh.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture)
		mat.set_shader_parameter("tint", item.tint)
		mat.set_shader_parameter("metal", item.get("metal", 0.0))
		mesh.material_override = mat


const AILMENT_TIME := 20.0
const POISON_TICK := 8.0
const CURSE_SLOW := 0.85
const AILMENT_COLORS := {"gift": Color(0.45, 1.0, 0.35), "fluch": Color(0.75, 0.4, 1.0)}


func afflict(kind: String) -> void:
	if dead:
		return
	var fresh := not ailments.has(kind)
	ailments[kind] = AILMENT_TIME
	if fresh:
		if kind == "gift":
			_poison_tick = POISON_TICK
		Effects.float_text(level, global_position + Vector3(0, 3.0, 0), Lang.t("Vergiftet!" if kind == "gift" else "Verflucht!"), AILMENT_COLORS[kind])
		_ailments_changed()


## Cures one ailment, or all of them; true if there was anything to cure.
func cure(kind := "") -> bool:
	var had := ailments.has(kind) if kind != "" else not ailments.is_empty()
	if kind == "":
		ailments.clear()
	else:
		ailments.erase(kind)
	if had:
		_ailments_changed()
	return had


func _tick_ailments(delta: float) -> void:
	if ailments.is_empty() or dead:
		return
	var changed := false
	for kind in ailments.keys():
		ailments[kind] -= delta
		if ailments[kind] <= 0.0:
			ailments.erase(kind)
			changed = true
	if ailments.has("gift"):
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = POISON_TICK
			if hp > 1:
				hp -= 1
				Effects.float_text(level, global_position + Vector3(0, 2.2, 0), "-1", AILMENT_COLORS.gift)
				hurt.emit(1)
	if changed:
		_ailments_changed()


## Updates strength and speed, and shows a coloured haze while ailing.
func _ailments_changed() -> void:
	refresh_stats()
	var old := get_node_or_null("AilmentHaze")
	if old:
		old.free()
	for kind in ["gift", "fluch"]:
		if ailments.has(kind):
			var haze := Effects.make_sparkles(AILMENT_COLORS[kind])
			haze.name = "AilmentHaze"
			add_child(haze)
			break
	ailments_changed.emit()


## Puts the worn helmet or hat on the hero's head; the feather makes room for it.
func _show_headgear() -> void:
	var slot := _model.find_child("HeadSlot", true, false)
	if slot == null:
		return
	var old := slot.get_node_or_null("Headgear")
	if old:
		old.free()
	var item: Dictionary = Items.ALL.get(equipped.get("kopf", ""), {})
	var feather := slot.get_node_or_null("Feather") as Node3D
	if feather:
		feather.visible = not item.has("hat")
	if not item.has("hat"):
		return
	# The hats sit on the head bone of their own character, which matches the hero's.
	var source: Node = load(item.hat[0]).instantiate()
	var hat := source.find_child(item.hat[1], true, false).duplicate() as Node3D
	source.free()
	hat.name = "Headgear"
	slot.add_child(hat)


func has_special(id: String) -> bool:
	return equipped.get("spezial_1", "") == id or equipped.get("spezial_2", "") == id


func _show_held(slot: String, hand_name: String, default_part: String) -> void:
	var hand := _model.find_child(hand_name, true, false)
	var old := hand.get_node_or_null("Held")
	if old:
		old.free()
	var id: String = equipped.get(slot, "")
	if default_part != "":
		hand.get_node(default_part).visible = id == ""
	if id != "" and Items.ALL[id].has("model"):
		var model: Node3D = load(Items.ALL[id].model).instantiate()
		model.name = "Held"
		hand.add_child(model)


## Moves a bag item into its slot; whatever was worn there goes into the bag.
func equip(id: String) -> void:
	var slot: String = Items.ALL[id].slot
	if slot == "spezial":
		# Two places for specials: take a free one, else swap out the first.
		slot = "spezial_2" if equipped.has("spezial_1") and not equipped.has("spezial_2") else "spezial_1"
	bag.erase(id)
	if equipped.has(slot):
		bag.append(equipped[slot])
	equipped[slot] = id
	refresh_stats()


## Takes off a worn item. False when the bag has no room for it.
func unequip(slot: String) -> bool:
	if not equipped.has(slot) or bag.size() >= Items.BAG_SIZE:
		return false
	bag.append(equipped[slot])
	equipped.erase(slot)
	refresh_stats()
	return true


## Everything the hero carries, worn or in the bag, in kg.
func carried_weight() -> float:
	var total := 0.0
	for slot in equipped:
		total += Items.weight(equipped[slot])
	for id in bag:
		total += Items.weight(id)
	return total


## Every hit may wear down each worn armour piece and shield; a piece worn
## through falls apart.
func _wear_armor() -> void:
	for slot in equipped.keys():
		if randf() < WEAR_CHANCE:
			_wear_down(slot)


## Takes a point of durability off the item in a slot; at 0 it breaks.
func _wear_down(slot: String) -> void:
	var id: String = equipped.get(slot, "")
	var durability: int = Items.ALL[id].get("durability", 0) if id != "" else 0
	if durability <= 0:
		return
	wear[id] = wear.get(id, 0) + 1
	if wear[id] >= durability:
		wear.erase(id)
		equipped.erase(slot)
		refresh_stats()
		Effects.float_text(level, global_position + Vector3(0, 3.2, 0), Lang.t("%s zerbricht!") % Items.item_name(id), Color(0.75, 0.8, 0.9))
		Sfx.play(self, "bones")


## The worn shield stops a whole hit: no harm, only a short shove.
func _block(from: Vector3) -> void:
	if randf() < BLOCK_WEAR_CHANCE:
		_wear_down("schild")
	_invulnerable = 0.5
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 4.0
	Effects.float_text(level, global_position + Vector3(0, 2.2, 0), Lang.t("Geblockt!"), Color(0.72, 0.78, 0.88))
	Comic.pop(global_position, "block")


## Blows and shots can be blocked with a shield; spikes from below (blockable
## false) cannot.
func take_damage(amount: int, from: Vector3, attacker: Node = null, blockable := true) -> void:
	if dead or _invulnerable > 0.0 or frozen:
		return
	if blockable and block_chance > 0.0 and randf() < block_chance:
		_block(from)
		return
	if hardening > 0:
		amount = maxi(1, amount - hardening)
	_wear_armor()
	hp -= amount
	if attacker and has_special("dornenrune") and attacker.has_method("take_hit"):
		attacker.take_hit(1, global_position)
	if hp <= 0 and has_special("phoenixfeder"):
		# The feather burns up and brings the hero back.
		equipped.erase("spezial_1" if equipped.get("spezial_1", "") == "phoenixfeder" else "spezial_2")
		refresh_stats()
		hp = mini(3, max_hp)
		Effects.float_text(level, global_position + Vector3(0, 3.0, 0), Lang.t("Phönixfeder!"), Color(1.0, 0.6, 0.2))
	_invulnerable = 0.9
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 10.0
	path.clear()
	Effects.float_text(level, global_position + Vector3(0, 2.2, 0), "-%d" % amount, Color(1, 0.3, 0.3))
	# The blow lands; the comic word's cry ("AUA!") comes with the bubble.
	Comic.pop(global_position, "hurt")
	Sfx.play(self, "hit", -3.0)
	hurt.emit(amount)
	if hp <= 0:
		dead = true
		play_once("Death_A", 99.0)
		defeated.emit()
	else:
		play_once("Hit_A", 0.35)


func _keyboard_direction() -> Vector3:
	var x := 0.0
	var z := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D):
		x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W):
		z -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S):
		z += 1.0
	return Vector3(x, 0, z).normalized()


func _physics_process(delta: float) -> void:
	if frozen:
		return
	_busy = maxf(0.0, _busy - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_auto_cooldown = maxf(0.0, _auto_cooldown - delta)
	_anim_hold = maxf(0.0, _anim_hold - delta)
	_tick_ailments(delta)
	_auto_attack()
	var dir := Vector3.ZERO
	if controllable and not dead and _busy <= 0.0:
		dir = _keyboard_direction()
		if dir == Vector3.ZERO:
			dir = steer
		if dir != Vector3.ZERO:
			path.clear()
		elif not path.is_empty():
			var to := path[0] - global_position
			to.y = 0.0
			if to.length() < 0.3:
				path.remove_at(0)
			if not path.is_empty():
				to = path[0] - global_position
				to.y = 0.0
				dir = to.normalized()
	var vy := velocity.y - GRAVITY * delta
	var pace := speed * (SNEAK_SPEED if sneaking else 1.0)
	velocity = dir * pace + _knockback
	if _air_momentum != Vector3.ZERO:
		if is_on_floor() and vy <= 0.0:
			_air_momentum = Vector3.ZERO
		else:
			# In the air the run carries on; steering only nudges it.
			velocity = _air_momentum + dir * pace * 0.25 + _knockback
	velocity.y = vy
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 45.0)
	var before := global_position
	move_and_slide()
	# Walking a path but pressed against something, like a door frame: first
	# step back to the middle of the tile, and give the path up if that fails.
	if not path.is_empty() and dir != Vector3.ZERO and (global_position - before).length() < pace * delta * 0.2:
		_stuck_time += delta
		var middle := level.cell_to_world(level.world_to_cell(global_position))
		if _stuck_time > 0.15 and not _sidestepped and Vector2(middle.x - global_position.x, middle.z - global_position.z).length() > 0.4:
			_sidestepped = true
			_stuck_time = 0.0
			path.push_front(middle)
		elif _stuck_time > 0.3:
			path.clear()
	else:
		_stuck_time = 0.0
		if path.is_empty():
			_sidestepped = false
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	if dir != Vector3.ZERO:
		for i in get_slide_collision_count():
			var hit := get_slide_collision(i)
			if dir.dot(-hit.get_normal()) > 0.5:
				var enemy := hit.get_collider() as Enemy
				if enemy:
					_engage(enemy)
				else:
					bumped.emit(hit.get_position() - hit.get_normal() * 0.2)
	if dir != Vector3.ZERO and _anim_hold <= 0.0:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-14.0 * delta))
	# Blink while invulnerable after a hit.
	_model.visible = dead or _invulnerable <= 0.0 or int(_invulnerable * 12.0) % 2 == 0
	# Feet keep pace with the ground: the run plays faster or slower with the speed.
	var ground_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	_anim.speed_scale = clampf(ground_speed / RUN_ANIM_SPEED, 0.5, 2.5) if _current_anim == "Running_A" else 1.0
	_footsteps(ground_speed)
	_update_sneak_look()
	if _busy > 0.0 or _anim_hold > 0.0 or not controllable or dead:
		return
	if not is_on_floor():
		if _current_anim != "Jump_Full_Short":
			play("Jump_Idle")
		return
	if dir == Vector3.ZERO:
		play("Idle")
	else:
		play(SNEAK_ANIM if sneaking else "Running_A")
