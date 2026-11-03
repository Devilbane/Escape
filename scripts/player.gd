class_name Player
extends CharacterBody3D
## The rogue. Walks with WASD / arrow keys or to a clicked spot, runs while
## the mouse button (or Shift) is held for as long as their breath lasts,
## jumps, fights with a dagger up close and throws knives from afar.

signal hurt(amount: int)
signal defeated
signal ailments_changed
## Life came back by itself (see _regenerate).
signal regenerated
## Emitted when the hero runs into something solid, with a point just inside it.
signal bumped(point: Vector3)
## Emitted when training raises an attribute or a skill, with its new value.
signal trained(id: String, value: int)
## The hero reached a new level (see HeroLevel).
signal leveled_up(level: int)

## The hero's reference speed in m/s (100 % Tempo); walking is a share of it.
const SPEED := 5.2
## Walking pace as a share of SPEED.
const WALK_FACTOR := 0.5
## Running speeds up to this many times the walking pace...
const RUN_TOP := 2.5
## ...over this many seconds of holding the run,
const RUN_RAMP_UP := 2.0
## and slows back down to walking within this many seconds once let go.
const RUN_RAMP_DOWN := 1.0
const WALK_ANIM := "Walking_A"
## The ground speed at which the walk animation's feet keep pace (m/s).
const WALK_ANIM_SPEED := 1.7
## Where in the walk cycle each foot touches the ground (left, right).
const WALK_LANDINGS := [0.02, 0.52]
## Seconds of running per point of Konstitution: 10 points run for 20 seconds.
const RUN_SECONDS_PER_CON := 2.0
## Seconds of running regained per second, per point of Konstitution: 10
## points bring one second back every second.
const RUN_RECOVERY_PER_CON := 0.1
## Out of breath, the hero walks until this share of the meter has come back.
const RUN_RESTART := 0.5
## From this many times the walking pace on, the hero shows the run animation.
const RUN_ANIM_FROM := 1.4
const JUMP_VELOCITY := 9.0
const GRAVITY := 26.0
## How fast the feet travel over the ground in the run animation at normal
## playback (metres per second, measured from the foot bone).
const RUN_ANIM_SPEED := 3.5
const MAX_HP := 5
## The spot the hero takes up: no skeleton may stand inside it (see
## Level.push_apart).
var radius := 0.55
var tall := 2.4
## The name over the head (see _build_name_tag), and its height above the feet:
## just clear of a helmet or a tall haircut seen from the tilted camera.
var name_tag: Label3D
const NAME_TAG_HEIGHT := 3.0
var _display_name := ""
## A hero who loses more than this share of their life to hits taken while
## running, within KNOCKDOWN_WINDOW seconds, stumbles to the ground and gets
## up again. Hits taken while walking, standing or sneaking never count.
const KNOCKDOWN_SHARE := 0.15
const KNOCKDOWN_WINDOW := 2.0
## The fall to the ground (Death_A, played to its end) and the climb back up
## (Lie_StandUp, 2.33 s long, played a little faster).
const FALL_TIME := 0.8
const GET_UP_ANIM := "Lie_StandUp"
const GET_UP_SPEED := 1.4
const GET_UP_TIME := 2.33 / GET_UP_SPEED
const MELEE_RANGE := 2.8
## One enemy in reach gets a single strike at full power. With two or more in
## reach the hero sweeps the blade round instead: up to SPLASH_TARGETS of them
## are hit, each for SPLASH_SHARE of the damage (never less than 1).
const SPLASH_TARGETS := 3
const SPLASH_SHARE := 0.5
const STRIKE_ANIM := "1H_Melee_Attack_Slice_Horizontal"
const SPLASH_ANIM := "2H_Melee_Attack_Spinning"
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
## What one shrine gift gives: the player picks one of the three.
const SHRINE_LIFE := 4
const SHRINE_POWER := 1
const SHRINE_SPEED := 0.03
# Gifts from shrines, kept for the whole run.
var gift_hp := 0
## Life from the trophy wall at home (see HomeUpgrades), set by the game.
var home_hp := 0
var gift_power := 0
var gift_speed := 0.0
## From the fourth shrine gift, which only a wise hero is offered.
var gift_armor := 0
## What the companion at the hero's side gives (Companions.SPECIES of its
## kind: "speed", "power", "skills"); {} without one. Set by the game.
var companion_perks: Dictionary = {}
## Training so far, by attribute and skill id (see Training). It belongs to
## the hero's name and is kept from one run to the next.
var xp := {}
## Experience in all (see HeroLevel) and the level points put into Stärke,
## Geschick or Intelligenz (attribute id -> points). Kept with the training.
var hero_xp := 0
var level_points := {}
## Worn items by slot ("waffe", "schild", "amulett") and the bag of carried ones.
var equipped := {}
var bag: Array[String] = []
# Values from gifts and worn items together; see refresh_stats().
var max_hp := MAX_HP
var power := 1
## Taken off every hit by worn armour; a hit still keeps at least half its
## force (see soak), so armour softens blows but never shrugs them off.
var hardening := 0
## How much each armour piece has worn down, by item id.
var wear := {}
## The hero's hair style, hair colour and head tattoo (see HairLook); the
## barber in the village changes them.
var hair := HairLook.DEFAULT.duplicate()
## The hero's body, "male" or "female" (see BodyLook).
var sex := BodyLook.DEFAULT
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
		return base_speed * Items.load_factor(load_weight())
var knives := 5
## Ailments and the seconds each has left. Poison ("gift") takes a life every
## few seconds but never the last one; a curse ("fluch") slows the hero;
## burning ("brand", from the dragon's fire) takes a life every
## BURN_TICK seconds for a few seconds, never the last one either.
## Both wear off soon; a fountain, a shrine or a healing potion cures them.
var ailments := {}
var _poison_tick := 0.0
var _burn_tick := 0.0
## A direction to run in, set every frame while the mouse button is held.
var steer := Vector3.ZERO
var _stuck_time := 0.0
var _sidestepped := false
## Speed carried through the air by a running jump.
var _air_momentum := Vector3.ZERO
var path: Array[Vector3] = []
## Set every frame while the player asks to run (the mouse button held).
var wants_run := false
## Seconds of running left; filled up on the first frame.
var stamina := -1.0
## Ran dry: no running until RUN_RESTART of the meter has come back.
var winded := false
## Whether the hero is running (not walking) this frame.
var sprinting := false
## How many times the walking pace the hero moves at: 1 walking, up to RUN_TOP.
var run_boost := 1.0
## Sneaking: much slower, but silent, with the lantern hooded, and see-through
## (more so in the dark). Skeletons cannot hear a sneaking hero.
var sneaking := false
## Set by the level each frame: no light falls on the hero but the lantern.
var in_shadow := false
## Seconds left before the hero may start sneaking again after a fight:
## every blow given or taken, and every skeleton hunting them, resets it.
var fight_cooldown := 0.0
const FIGHT_SNEAK_BLOCK := 2.0
const SNEAK_SPEED := 0.4
const SNEAK_ANIM := "Walking_C"
var _lantern: OmniLight3D
## The hand torch that burns in the pitch-black places (see HandTorch).
var torch: HandTorch
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
## Seconds a flourish (see play_flourish) still shows while the hero stands.
var _flourish := 0.0
var _invulnerable := 0.0
var _attack_cooldown := 0.0
var _knockback := Vector3.ZERO
## The skeleton last fought up close, kept under fire from afar.
var _target: Enemy = null
## The enemy the hero was sent after with a click: walk up to it and strike
## it, no knives on the way. Cleared once it is in reach, dies, or the hero is
## sent elsewhere.
var _hunt: Enemy = null
var _hunt_repath := 0.0
## How far from the enemy's middle the hunt stops: side by side, in reach.
const HUNT_STOP := 1.6
const HUNT_REPATH := 0.4
var _auto_cooldown := 0.0
## Time left on an animation that plays while the hero keeps moving.
var _anim_hold := 0.0
## Recent hits taken while running, as [time, damage], and a clock for them.
var _run_hits: Array = []
var _clock := 0.0
## Seconds of the fall left before getting up, and of the whole knockdown
## (fall and getting up), during which the hero takes no more damage.
var _falling := 0.0
var _down := 0.0
## How often the hero has been knocked down this game.
var knockdowns := 0
## Walking into a crate (see Crate) whose top is at most this far above the
## feet lifts the hero onto it, and so does jumping against one whose top
## the hands reach: up to GRAB_REACH above the feet.
const STEP_UP := Crate.SIZE + 0.15
const GRAB_REACH := 0.7
## Seconds a climb onto a crate takes.
const CLIMB_TIME := 0.35
var _climb := -1.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _on_crate := false


func _ready() -> void:
	add_to_group("combatant")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = tall
	shape.shape = capsule
	shape.position.y = tall * 0.5
	add_child(shape)

	_model = preload("res://assets/characters/Rogue.glb").instantiate()
	add_child(_model)
	for part in HIDDEN_PARTS:
		var node := _model.find_child(part, true, false)
		if node:
			node.visible = false
	# The body comes first: everything else dresses whichever body it is.
	BodyLook.apply(_model, sex)
	_model.scale = Vector3.ONE * BodyLook.scale_of(sex)
	_add_cape_logo()
	_add_trim()
	GearLook.dress(_model.find_child("handslot_r", true, false).get_node("Knife"), "mixed") # The hero's own knife.
	for arm in ["Rogue_ArmLeft", "Rogue_ArmRight"]:
		GearLook.apply(_model.find_child(arm, true, false) as MeshInstance3D, "outfit")
	set_hair(hair)
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
	# A hand torch for the pitch-black places (see HandTorch).
	torch = HandTorch.new(self)
	add_child(torch)
	_build_name_tag()


## The hero's name over the head, in the same look as the name tags of the
## townsfolk and dungeon folk (Villager, DungeonNpc): Cinzel Bold 30, warm
## white with a dark outline, always facing the camera. The life bar sits under
## the feet (Game._place_hp_bar), so the two never meet.
func _build_name_tag() -> void:
	name_tag = Label3D.new()
	name_tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_tag.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	name_tag.font_size = 30
	name_tag.pixel_size = 0.011
	name_tag.outline_size = 10
	name_tag.outline_modulate = Color(0.05, 0.03, 0.06, 0.85)
	name_tag.modulate = Color(1, 0.95, 0.85, 1)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.no_depth_test = true
	name_tag.render_priority = 18
	name_tag.outline_render_priority = 17
	name_tag.position.y = NAME_TAG_HEIGHT
	name_tag.text = _display_name
	name_tag.visible = _display_name != ""
	add_child(name_tag)


## Sets the name shown over the hero's head ("" hides it).
func set_display_name(text: String) -> void:
	_display_name = text
	if name_tag:
		name_tag.text = text
		name_tag.visible = text != ""


## Called while a fight goes on; sneaking stays barred until it has been
## over for FIGHT_SNEAK_BLOCK seconds.
func mark_fight() -> void:
	fight_cooldown = FIGHT_SNEAK_BLOCK


## Switches between walking normally and sneaking.
func set_sneaking(on: bool) -> void:
	sneaking = on
	# A hooded lantern: just enough to see the floor, too little to be seen by.
	_lantern.light_energy = 0.45 if on else 1.1
	_lantern.omni_range = 5.0 if on else 8.5


## Whether skeletons could see the hero by some light, the lantern included.
func is_lit() -> bool:
	if torch and torch.lit:
		return true # A burning torch cannot be hooded.
	return not sneaking or not in_shadow


## Whether the hero makes noise: moving without sneaking.
func is_noisy() -> bool:
	return not sneaking and (Vector2(velocity.x, velocity.z).length() > 0.5 or not is_on_floor())


## Turns the hero ash grey and see-through while sneaking, more so in the
## shadows.
func _update_sneak_look() -> void:
	var alpha := 0.0
	if sneaking:
		alpha = 0.65 if in_shadow else 0.4
	if is_equal_approx(alpha, _shown_alpha):
		return
	_shown_alpha = alpha
	look_sneaky(_model, alpha)


## Greys and fades a model of the hero (alpha 0 brings the plain look back).
## WorldPreload uses it on a copy, so the see-through shaders are built
## before the first sneak.
func look_sneaky(model: Node3D, alpha: float) -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if HairLook.is_hair(mesh.material_override):
			# Hair, scalp and face: their own shader greys and fades them.
			HairLook.fade(mesh.material_override as ShaderMaterial, alpha)
			continue
		if mesh.material_override is ShaderMaterial and (mesh.material_override as ShaderMaterial).shader in [TINT_SHADER, TINT_FADE_SHADER]:
			# A tinted part: swap in the shader that greys and fades.
			var tinted := mesh.material_override as ShaderMaterial
			tinted.shader = TINT_FADE_SHADER if alpha > 0.0 else TINT_SHADER
			tinted.set_shader_parameter("fade", alpha)
			continue
		if mesh.material_override != null:
			_ghost_override(mesh, alpha)
			continue
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			_ghost_surface(mesh, i, alpha)


## Puts a grey see-through stand-in over one surface of a part, keeping the
## material it had to bring back when the hero stops sneaking.
func _ghost_surface(mesh: MeshInstance3D, i: int, alpha: float) -> void:
	var key := "unghosted_%d" % i
	var mat := mesh.get_surface_override_material(i)
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == GHOST_SHADER:
		if alpha > 0.0:
			mat.set_shader_parameter("fade", alpha)
		else:
			mesh.set_surface_override_material(i, mesh.get_meta(key, null))
			mesh.remove_meta(key)
		return
	if alpha <= 0.0:
		return
	var base := mat if mat != null else mesh.mesh.surface_get_material(i)
	mesh.set_meta(key, mat)
	mesh.set_surface_override_material(i, _ghost(base, alpha))


## The same for a part drawn with one material over the whole of it.
func _ghost_override(mesh: MeshInstance3D, alpha: float) -> void:
	var mat := mesh.material_override
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == GHOST_SHADER:
		if alpha > 0.0:
			mat.set_shader_parameter("fade", alpha)
		else:
			mesh.material_override = mesh.get_meta("unghosted", null)
			mesh.remove_meta("unghosted")
		return
	if alpha <= 0.0 or not mat is BaseMaterial3D:
		return
	mesh.set_meta("unghosted", mat)
	mesh.material_override = _ghost(mat, alpha)


const GHOST_SHADER := preload("res://shaders/ghost.gdshader")


func _ghost(base: Material, alpha: float) -> ShaderMaterial:
	var ghost := ShaderMaterial.new()
	ghost.shader = GHOST_SHADER
	if base is BaseMaterial3D:
		var std := base as BaseMaterial3D
		ghost.set_shader_parameter("tex", std.albedo_texture)
		ghost.set_shader_parameter("use_tex", std.albedo_texture != null)
		ghost.set_shader_parameter("color", std.albedo_color)
	ghost.set_shader_parameter("fade", alpha)
	return ghost


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
	# The feather hangs from the head bone, in the head mesh's space.
	var attach := HairLook.head_slot(_model)
	if attach == null:
		return
	var bind: Transform3D = attach.get_meta("bind")
	var feather := MeshInstance3D.new()
	feather.name = "Feather"
	feather.mesh = Effects.feather_mesh()
	feather.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tucked into the hair on the left side of the head, or behind the left
	# ear of a shaved head, sweeping up and back.
	feather.set_meta("spots", [bind * Vector3(0.47, 1.66, -0.05), bind * Vector3(0.4, 1.68, -0.2)])
	feather.transform = Transform3D(Basis.from_euler(Vector3(-0.75, 0.0, -0.45)).scaled(Vector3.ONE * 1.3), bind * Vector3(0.47, 1.66, -0.05))
	attach.add_child(feather)


## Closed eyes for sleeping: a skin-coloured lid over each eye with a dark,
## gently curved lash line, built the first time the hero falls asleep.
var _eyelids: Node3D = null
## A lid is a squashed ball, a little taller than the eye and deep enough
## to cover the pupil.
const LID_SCALE := Vector3(1.0, 1.15, 0.75)


func set_asleep(asleep: bool) -> void:
	if asleep and _eyelids == null:
		_build_eyelids()
	if _eyelids:
		_eyelids.visible = asleep
	BodyLook.blink(_model, asleep)


## A game saved in bed is loaded: the hero lies on their back, asleep, the
## way Lie_Down left them, breathing slowly (Lie_Idle, over and over).
func lie_asleep() -> void:
	_anim.get_animation("Lie_Idle").loop_mode = Animation.LOOP_LINEAR
	_anim.speed_scale = 1.0
	_current_anim = ""
	play("Lie_Idle", 0.0)
	set_asleep(true)


## Opens the eyes and gets up from lying on the back, the way a knocked-down
## hero does (GET_UP_ANIM, GET_UP_TIME seconds).
func get_up_from_bed() -> void:
	set_asleep(false)
	_current_anim = ""
	play(GET_UP_ANIM, 0.3)
	_anim.speed_scale = GET_UP_SPEED


func _build_eyelids() -> void:
	var head := _model.find_child("Rogue_Head", true, false) as MeshInstance3D
	var slot := _model.find_child("HeadSlot", true, false) as Node3D
	if head == null or slot == null:
		return
	# The eyes are part of the head mesh, skinned to the head bone: work in
	# mesh space and carry it over into that bone's space.
	var bind := Transform3D.IDENTITY
	for i in head.skin.get_bind_count():
		if head.skin.get_bind_name(i) == "head":
			bind = head.skin.get_bind_pose(i)
	_eyelids = Node3D.new()
	_eyelids.name = "Eyelids"
	_eyelids.transform = bind
	slot.add_child(_eyelids)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color8(246, 192, 156)
	skin.roughness = 0.95
	var lash := StandardMaterial3D.new()
	lash.albedo_color = Color(0.16, 0.08, 0.06)
	lash.roughness = 1.0
	var lid_mesh := SphereMesh.new()
	lid_mesh.radius = 0.08
	lid_mesh.height = 0.16
	for side in [-1.0, 1.0]:
		var centre := Vector3(side * 0.207, 1.607, 0.41)
		var lid := MeshInstance3D.new()
		lid.mesh = lid_mesh
		lid.material_override = skin
		lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lid.position = centre
		lid.scale = LID_SCALE
		_eyelids.add_child(lid)
		# A thin dark arc across the lid, curving down like a smile: the
		# closed eye. It follows the lid's rounded surface.
		var points := []
		for k in 9:
			var a := lerpf(PI * 1.12, PI * 1.88, k / 8.0)
			var p := Vector2(cos(a) * 0.062, sin(a) * 0.024 + 0.012)
			var r := clampf(Vector2(p.x / LID_SCALE.x, p.y / LID_SCALE.y).length() / lid_mesh.radius, 0.0, 1.0)
			points.append(centre + Vector3(p.x, p.y, lid_mesh.radius * LID_SCALE.z * sqrt(1.0 - r * r) + 0.004))
		var segments := []
		for k in points.size() - 1:
			segments.append([points[k], points[k + 1]])
		var line := MeshInstance3D.new()
		line.mesh = Effects.cord_mesh(segments, 0.016, lash)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_eyelids.add_child(line)
	_eyelids.visible = false


## Makes the hero a man or a woman (see BodyLook). The hair, the worn gear
## and the colours of the clothes are put back on the new body.
func set_sex(id: String) -> void:
	sex = BodyLook.checked(id)
	if _model == null:
		return # Not built yet: _ready shapes it.
	BodyLook.apply(_model, sex)
	_model.scale = Vector3.ONE * BodyLook.scale_of(sex)
	for arm in ["Rogue_ArmLeft", "Rogue_ArmRight"]:
		GearLook.apply(_model.find_child(arm, true, false) as MeshInstance3D, "outfit")
	set_hair(hair)
	refresh_stats()


## Gives the hero a new hair style, colour or tattoo (see HairLook).
func set_hair(look: Dictionary) -> void:
	hair = HairLook.checked(look)
	if _model == null:
		return # Not built yet: _ready puts it on.
	HairLook.apply(_model, hair)
	var feather := _model.find_child("Feather", true, false) as Node3D
	if feather:
		feather.position = feather.get_meta("spots")[0 if hair.style == "natural" else 1] # Behind the ear of a cut head.
	_show_headgear()


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


## Plays a one-off animation that only shows off, such as taking a shrine's
## gift or drinking from a fountain. Unlike play_once it never holds the hero:
## any step, jump, click or attack ends it at once, so the player is never
## left waiting for the animation after a reward.
func play_flourish(anim_name: String, duration: float) -> void:
	_current_anim = ""
	play(anim_name, 0.1)
	_flourish = duration


## True while a flourish is still showing (see play_flourish).
func flourishing() -> bool:
	return _flourish > 0.0


# --- Sitting (see Seats) -------------------------------------------------------

## The hero sits on a seat (a bench on the square): from sit_down until any
## step, click, jump, attack or blow stands them up again (stand_up). There is
## no lock: the very input that stands the hero up also moves them.
var _seated := false
## Where the hero stands again: just in front of the seat, clear of it.
var _stand_spot := Vector3.ZERO
## Seconds since sitting down, to go from sitting down to sitting still.
var _sit_time := 0.0
## The animation that lowers the hero onto the seat, and how long it takes.
const SIT_DOWN_ANIM := "Sit_Chair_Down"
const SIT_DOWN_TIME := 0.75
const SIT_IDLE_ANIM := "Sit_Chair_Idle"

## When the hero last stood up (on the _clock), and how long a bump into a
## seat right after that does not sit them down again.
var _stood_at := -INF
const SIT_AGAIN := 0.5


## Sits down at `spot` facing `towards`; `stand_spot` is where the hero
## stands again. The hero's feet stay where the animation puts them, so
## `spot` is on the ground in front of the seat's middle.
func sit_down(spot: Vector3, towards: Vector3, stand_spot: Vector3) -> void:
	path.clear()
	_hunt = null
	_target = null
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_air_momentum = Vector3.ZERO
	_flourish = 0.0
	_seated = true
	_stand_spot = stand_spot
	_sit_time = 0.0
	global_position = spot
	face(towards)
	_anim.get_animation(SIT_IDLE_ANIM).loop_mode = Animation.LOOP_LINEAR
	_current_anim = ""
	play(SIT_DOWN_ANIM, 0.15)


func is_seated() -> bool:
	return _seated


## Gets up from the seat at once, back on the spot in front of it. Does
## nothing while standing.
func stand_up() -> void:
	if not _seated:
		return
	_seated = false
	_stood_at = _clock
	global_position = _stand_spot
	velocity = Vector3.ZERO
	_current_anim = ""
	play("Idle", 0.15)


## True while the hero has just stood up and keeps running into the seat
## (each bump keeps it true), so holding a key towards a bench does not sit
## them down again and again. Once they let go for SIT_AGAIN seconds, running
## into the seat sits them down as usual.
func still_getting_up() -> bool:
	if _clock - _stood_at < SIT_AGAIN:
		_stood_at = _clock
		return true
	return false


## While seated: any wish to move stands the hero up (and the same frame
## goes on to move them); otherwise they sit still. True while still seated.
func _stay_seated(delta: float) -> bool:
	if not _seated:
		return false
	var wish := Vector3.ZERO
	if controllable:
		wish = _keyboard_direction()
		if wish == Vector3.ZERO:
			wish = steer
	if dead or wish != Vector3.ZERO or not path.is_empty() or _hunt != null:
		stand_up()
		return false
	velocity = Vector3.ZERO
	_model.visible = true
	_sit_time += delta
	if _sit_time >= SIT_DOWN_TIME:
		play(SIT_IDLE_ANIM, 0.3)
	_anim.speed_scale = 1.0
	return true


func face(direction: Vector3) -> void:
	_model.rotation.y = atan2(direction.x, direction.z)


func facing() -> Vector3:
	return Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))


## Puts the hero at a level's start; `heal` fills up life again.
func revive(at: Vector3, heal := true) -> void:
	dead = false
	if heal or hp <= 0:
		hp = max_hp
	stamina = -1.0
	winded = false
	path.clear()
	_target = null
	_hunt = null
	velocity = Vector3.ZERO
	global_position = at
	_invulnerable = 1.5
	_busy = 0.0
	_flourish = 0.0
	_seated = false
	_falling = 0.0
	_down = 0.0
	_run_hits.clear()
	_climb = -1.0
	_on_crate = false
	set_asleep(false)
	play("Idle")


## Walks along the grid to `target`. With `stop_short` the hero walks right
## up to a thing standing there (a chest, a barrel, the merchant) and stops
## that far from its middle, instead of waiting a whole tile away.
func walk_to(target: Vector3, stop_short := 0.0) -> void:
	stand_up()
	var from := level.set_out_cell(global_position)
	var to := level.world_to_cell(target)
	path.clear()
	# Standing beside a piece of furniture on its tile: first step off it.
	var steps := level.grid_path(from, to)
	if from == level.world_to_cell(global_position) or steps.is_empty():
		steps = steps.slice(1)
	for c in steps:
		path.append(level.cell_to_world(c))
	if stop_short > 0.0:
		var last: Vector3 = path[-1] if not path.is_empty() else global_position
		var away := last - target
		away.y = 0.0
		if away.length() > stop_short:
			path.append(target + away.normalized() * stop_short)


func can_act() -> bool:
	return controllable and not frozen and not dead and _busy <= 0.0


## How many seconds the hero can run with full breath: Konstitution x 2.
func max_stamina() -> float:
	return RUN_SECONDS_PER_CON * attribute("konstitution")


## Seconds of running that come back per second: Konstitution / 10.
func stamina_recovery() -> float:
	return RUN_RECOVERY_PER_CON * attribute("konstitution")


## Spends breath while running and gets it back otherwise.
func _breathe(delta: float, moving: bool) -> void:
	var full := max_stamina()
	if stamina < 0.0:
		stamina = full
	var run_key := Input.is_physical_key_pressed(KEY_SHIFT)
	sprinting = (wants_run or run_key) and moving and not sneaking and not winded and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - delta)
		# Running out of breath slowly hardens the body.
		train("konstitution", delta * 0.1)
		if stamina <= 0.0:
			winded = true
	else:
		stamina = minf(full, stamina + stamina_recovery() * delta)
		if winded and stamina >= RUN_RESTART * full:
			winded = false
	# Speeds up gradually while running, and eases back to walking when the
	# run ends. Standing still or sneaking drops straight back to walking.
	if not moving or sneaking:
		run_boost = 1.0
	elif sprinting:
		run_boost = minf(RUN_TOP, run_boost + (RUN_TOP - 1.0) / RUN_RAMP_UP * delta)
	else:
		run_boost = maxf(1.0, run_boost - (RUN_TOP - 1.0) / RUN_RAMP_DOWN * delta)


## True while the hero is moving under its own steam.
func is_running() -> bool:
	return not sneaking and Vector2(velocity.x, velocity.z).length() > SPEED * 0.4


## A jump from a run keeps its momentum and flies further the faster the
## hero runs; a standing jump goes straight up.
func jump() -> void:
	stand_up()
	if not controllable or frozen or dead or not is_on_floor() or is_climbing():
		return
	_air_momentum = Vector3.ZERO
	var jump_boost := 1.0
	if is_running():
		var run := Vector3(velocity.x, 0, velocity.z) - Vector3(_knockback.x, 0, _knockback.z)
		jump_boost = clampf(run.length() / SPEED, 0.6, 1.6)
		_air_momentum = run * (1.0 + 0.15 * jump_boost) * (1.0 + JUMP_PER_DEXTERITY * dexterity_points())
	velocity.y = JUMP_VELOCITY * (0.85 + 0.15 * jump_boost)
	Events.bus().hero_acted.emit("jump")
	train("tempo", 3.0)
	train("geschick", 2.0)
	_current_anim = ""
	play("Jump_Full_Short", 0.1)


func _nearest_enemy(max_distance: float, need_sight: bool) -> Enemy:
	var best: Enemy = null
	var best_d := max_distance
	for e in level.enemies:
		# A skeleton standing inside the hero's spot cannot be fought until
		# the two are pushed apart, and the hero's friends are not fought at all.
		if not is_instance_valid(e) or e.dead or e.is_friend() or level.stacked(self, e):
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
	var walk := _current_anim == WALK_ANIM
	if not (sneak or walk or _current_anim == "Running_A") or not is_on_floor() or ground_speed < 0.3:
		_last_phase = -1.0
		return
	var phase := _anim.current_animation_position / _anim.current_animation_length
	if _last_phase >= 0.0:
		for landing: float in (SNEAK_LANDINGS if sneak else (WALK_LANDINGS if walk else FOOT_LANDINGS)):
			var crossed: bool = _last_phase < landing and phase >= landing
			if phase < _last_phase:
				crossed = _last_phase < landing or phase >= landing
			if crossed:
				# Sneaking: only a very soft touch, barely to be heard.
				if sneak:
					Sfx.play(self, "sneak_%d" % (randi() % 4), -22.0)
				else:
					Sfx.play(self, "step_%d" % (randi() % 6), -17.0 if walk else -14.0)
	_last_phase = phase


## The living enemies the blade can reach right now: close by, and in front
## of the hero unless they stand right next to them. Nearest first.
func enemies_in_reach() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead or e.is_friend() or level.stacked(self, e):
			continue
		# No blow lands through a closed door, either way (see Level.door_between).
		if level.door_between(global_position, e.global_position):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < MELEE_RANGE + e.girth() and (to.length() < 1.2 + e.girth() or facing().dot(to.normalized()) > 0.25):
			found.append(e)
	var here := global_position
	found.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return here.distance_squared_to(a.global_position) < here.distance_squared_to(b.global_position))
	return found


## Whether the next blow would be a sweep: two or more enemies in reach.
func would_splash() -> bool:
	return enemies_in_reach().size() >= 2


## A blow with the blade. Facing one enemy the hero strikes it alone for full
## damage. Facing a crowd the hero sweeps instead (see SPLASH_TARGETS): a wider
## swing with its own spin and a deeper swish, half the damage per enemy. The
## kind of blow is chosen as the swing starts and kept even if the crowd
## shifts before the blade lands.
func melee() -> void:
	stand_up()
	if not can_act() or _attack_cooldown > 0.0:
		return
	path.clear()
	var target := _nearest_enemy(MELEE_RANGE + 1.2, true)
	if target:
		_target = target
		face(target.global_position - global_position)
	_attack_cooldown = 0.5
	Events.bus().hero_acted.emit("melee")
	var splash := would_splash()
	if splash:
		play_once(SPLASH_ANIM, 0.55)
		Sfx.play(self, "swing", 0.0, null, 0.8)
	else:
		play_once(STRIKE_ANIM, 0.45)
		Sfx.play(self, "swing")
	await get_tree().create_timer(0.25 if splash else 0.18).timeout
	var weapon := weapon_skill()
	# One roll for a heavy hit per swing; a sweep shares it out.
	var full := power + heavy_hit(weapon)
	var damage := maxi(1, roundi(full * SPLASH_SHARE)) if splash else full
	var victims := enemies_in_reach()
	if splash:
		victims.resize(mini(victims.size(), SPLASH_TARGETS))
	elif not victims.is_empty():
		# The strike goes to the enemy the hero is fighting, else the nearest.
		if _target in victims:
			victims.erase(_target)
			victims.push_front(_target)
		victims.resize(1)
	var hits := 0
	for e in victims:
		if e.open_to_backstab(global_position):
			e.take_hit(power, global_position, "backstab")
			train("schleichen", 4.0)
		else:
			e.take_hit(damage, global_position)
			if not e.dead and randf() < shock_chance():
				e.shock()
		hits += 1
		mark_fight()
		# Every blow that lands trains the hand and the arm; a kill a little more.
		train(weapon, 1.0)
		train("staerke", 3.0 if e.dead else 1.0)
		if e.dead and e.kind == "magier":
			train("intelligenz", 4.0)
	if hits == 0 and target:
		Comic.pop(global_position + facing() * 1.5, "miss")


## The chance that a blow of the held weapon cracks with lightning and stuns
## (a thunder weapon, see Items "shock" and Enemy.shock), else 0.
func shock_chance() -> float:
	return float(Items.ALL.get(equipped.get("waffe", ""), {}).get("shock", 0.0))


## Throws a knife at `aim` (a world position), or at the closest enemy in sight.
## On the move the hero throws without stopping.
func throw_knife(aim = null, on_the_move := false) -> void:
	stand_up()
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
	train("geschick", 0.5)
	Events.bus().hero_acted.emit("throw")
	_attack_cooldown = 0.6
	if on_the_move:
		_current_anim = ""
		play("Throw", 0.1)
		_anim_hold = 0.45
	else:
		play_once("Throw", 0.45)
	await get_tree().create_timer(0.2).timeout
	Sfx.play(self, "throw")
	Projectile.spawn(level, global_position + Vector3(0, 1.5, 0) + dir.normalized() * 0.6, dir, true).damage = throw_power() + heavy_hit("werfen")


func _engage(enemy: Enemy) -> void:
	if enemy.dead or enemy.is_friend():
		return
	if _target != enemy:
		_auto_cooldown = 0.0
	_target = enemy


## Sent after an enemy with a click: the hero walks up to it and, once it
## is in reach, keeps striking it (see _pursue and _auto_attack).
func charge(enemy: Enemy) -> void:
	stand_up()
	if enemy == null or enemy.dead or enemy.is_friend() or dead:
		return
	_engage(enemy)
	_hunt = enemy
	_hunt_repath = 0.0


## Gives up a hunt, when the hero is sent somewhere else.
func stop_hunt() -> void:
	_hunt = null


## Keeps the hunt's path on the enemy while it moves, and ends it in reach.
func _pursue(delta: float) -> void:
	if _hunt == null:
		return
	if not is_instance_valid(_hunt) or _hunt.dead or _target != _hunt:
		_hunt = null
		return
	if not can_act():
		return # Mid-swing or getting up: the hunt goes on afterwards.
	var to := _hunt.global_position - global_position
	to.y = 0.0
	if to.length() <= ENGAGE_RANGE:
		path.clear()
		_hunt = null
		return
	_hunt_repath -= delta
	if _hunt_repath <= 0.0:
		_hunt_repath = HUNT_REPATH
		walk_to(_hunt.global_position, HUNT_STOP)


## Attacked without a command, the hero fights back on their own: the
## attacker becomes the target, and _auto_attack strikes it up close or throws
## knives at it from afar. An enemy the hero is already fighting is kept.
func defend_against(attacker: Node) -> void:
	var enemy := attacker as Enemy
	if enemy == null or enemy.dead or dead:
		return
	if _target == null or not is_instance_valid(_target) or _target.dead:
		_engage(enemy)


## Keeps fighting the current target: blade while next to it, knives from afar.
func _auto_attack() -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or _target.dead or _target.is_friend():
		_target = null
		return
	if not can_act() or _auto_cooldown > 0.0 or _attack_cooldown > 0.0 or level.stacked(self, _target):
		return
	var d := global_position.distance_to(_target.global_position)
	if d <= ENGAGE_RANGE:
		_auto_cooldown = AUTO_MELEE_INTERVAL
		melee()
	elif _hunt == null and d <= AUTO_THROW_RANGE and knives > 0 and level.has_clear_shot(global_position, _target.global_position):
		_auto_cooldown = AUTO_THROW_INTERVAL
		throw_knife(_target.global_position, true)


# --- Training -----------------------------------------------------------------

const BLOCK_PER_LEVEL := 0.02
const ARMOR_LIGHTER_PER_LEVEL := 0.06
const SNEAK_PER_LEVEL := 0.03


const SECRET_PER_INTUITION := 2
const JUMP_PER_DEXTERITY := 0.02
const DODGE_PER_DEXTERITY := 0.04
## Dodging blows and shots: DODGE_PER_DEXTERITY per point of Geschick, up to
## this much.
const DODGE_MAX := 0.4
## Each point of Intelligenz above the start makes skills and crafts train
## this much quicker, and adds this much to all experience (EP).
const SKILL_LEARNING_PER_INTELLIGENCE := 0.1
const XP_PER_INTELLIGENCE := 0.03


## Points of Stärke above the start: each is +1 damage in close combat.
func strength_points() -> int:
	return attribute("staerke") - Training.ATTRIBUTES.staerke.start


## The damage of a thrown knife before a heavy hit: the hero's power, with
## Geschick in place of Stärke (a deft hand throws, a strong arm strikes).
func throw_power() -> int:
	return maxi(1, power - strength_points() + dexterity_points())


## The chance to dodge a blow or a shot, 0..DODGE_MAX.
func dodge_chance() -> float:
	return clampf(DODGE_PER_DEXTERITY * dexterity_points(), 0.0, DODGE_MAX)


## Points of Intelligenz above the start.
func intelligence_points() -> int:
	return attribute("intelligenz") - Training.ATTRIBUTES.intelligenz.start


## How much quicker skills and crafts train thanks to Intelligenz (0.2 = 20 %).
func skill_learning_bonus() -> float:
	return SKILL_LEARNING_PER_INTELLIGENCE * intelligence_points()


## Experience as a clever hero earns it: XP_PER_INTELLIGENCE more per point
## of Intelligenz.
func clever_xp(amount: int) -> int:
	return roundi(amount * (1.0 + XP_PER_INTELLIGENCE * intelligence_points()))


## Points of Geschick above the start: each makes running jumps 2 % longer
## and gives 4 % chance to slip past spikes shooting up.
func dexterity_points() -> int:
	return attribute("geschick") - Training.ATTRIBUTES.geschick.start


## Spikes shoot up under the hero: a deft hero may jump aside in time.
## Either way the trap teaches a little. Hidden spike traps (see Traps) hurt
## more in deeper places.
func spring_trap(damage := 1) -> void:
	if dead or _invulnerable > 0.0 or frozen:
		return
	if randf() < DODGE_PER_DEXTERITY * dexterity_points():
		train("geschick", 4.0)
		_invulnerable = 0.6
		Effects.head_text(level, self, 2.2, Lang.t("Ausgewichen!"), Color(0.72, 0.9, 0.78))
		return
	train("geschick", 2.0)
	take_damage(damage, global_position - facing(), null, false)


## Intuition sharpens the hero's gut feeling: +2 percent per point above 10
## to notice a lever to a secret room or a hidden trap (see Traps).
func intuition_bonus() -> int:
	return SECRET_PER_INTUITION * (attribute("intuition") - Training.ATTRIBUTES.intuition.start)


## What the Erkunden skill adds to a chance, in percent: `per_level` for each
## level (one of Training.EXPLORE_SECRET, EXPLORE_TORCH, EXPLORE_WRITING,
## EXPLORE_TRAP).
func explore_bonus(per_level: int) -> int:
	return per_level * skill("erkunden")


## An attribute's value now: Stärke and Konstitution 10..30, Tempo 100..150 (%).
## Level points and the Konstitution of levels come on top of training, up
## to the attribute's highest value.
func attribute(id: String) -> int:
	var value := Training.attribute_value(id, xp.get(id, 0.0))
	var bonus: int = int(level_points.get(id, 0))
	if id == "konstitution":
		bonus += HeroLevel.constitution_bonus(hero_level())
	if bonus == 0:
		return value
	return mini(value + bonus * Training.ATTRIBUTES[id].step, Training.ATTRIBUTES[id].max)


## The hero's level, from the experience earned (see HeroLevel).
func hero_level() -> int:
	return HeroLevel.level_for(hero_xp)


## Level points not yet put into an attribute.
func free_points() -> int:
	var spent := 0
	for id in level_points:
		spent += int(level_points[id])
	return maxi(0, HeroLevel.points_earned(hero_level()) - spent)


## Puts a free level point into Stärke, Geschick or Intelligenz.
func spend_point(id: String) -> bool:
	if free_points() <= 0 or not id in HeroLevel.POINT_ATTRIBUTES:
		return false
	level_points[id] = int(level_points.get(id, 0)) + 1
	refresh_stats()
	return true


## Earns experience; tells of every level reached. Returns the levels gained.
func gain_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := hero_level()
	hero_xp += amount
	var after := hero_level()
	if after > before:
		refresh_stats()
		# The new life of each level comes filled.
		hp = mini(hp + HeroLevel.life_bonus(after) - HeroLevel.life_bonus(before), max_hp)
		for level_now in range(before + 1, after + 1):
			leveled_up.emit(level_now)
	return after - before


## Level and experience as they are kept with the training.
func level_data() -> Dictionary:
	return {"xp": hero_xp, "points": level_points.duplicate()}


func set_level_data(data: Dictionary) -> void:
	hero_xp = int(data.get("xp", 0))
	level_points = {}
	var points = data.get("points", {})
	if points is Dictionary:
		for id in points:
			if id in HeroLevel.POINT_ATTRIBUTES:
				level_points[id] = int(points[id])


## A skill's level: what was trained plus what worn items add. 0 while the
## gear it needs is not worn.
func skill(id: String) -> int:
	if not skill_enabled(id):
		return 0
	var level_now := Training.skill_level(xp.get(id, 0.0), id)
	for slot in equipped:
		level_now += int(Items.ALL[equipped[slot]].get("skills", {}).get(id, 0))
	level_now += int(companion_perks.get("skills", {}).get(id, 0))
	return level_now


## Whether the worn gear lets the hero use (and train) a skill.
func skill_enabled(id: String) -> bool:
	if not can_use(Training.SKILLS[id].get("requires", {})):
		return false
	# An advanced skill builds on basic skills.
	var needs: Dictionary = Training.SKILLS[id].get("needs", {})
	for basic in needs:
		if Training.skill_level(xp.get(basic, 0.0), basic) < int(needs[basic]):
			return false
	match id:
		"klingen", "aexte":
			return weapon_skill() == id
		"blocken":
			return equipped.has("schild")
		"ruestung":
			return equipped.values().any(func(item): return Items.ALL[item].get("armor", 0) > 0)
	return true


## The skill the weapon in hand needs; the hero's own dagger is a blade.
func weapon_skill() -> String:
	return Items.ALL.get(equipped.get("waffe", ""), {}).get("uses", "klingen")


## A heavy hit (+1 damage) is a roll on the weapon's skill.
func heavy_hit(skill_id: String) -> int:
	return 1 if skill_check(skill_id) else 0


## The average of the attributes that govern a skill.
func skill_attribute_average(id: String) -> float:
	var governing: Array = Training.SKILLS[id].attributes
	var total := 0
	for a in governing:
		total += attribute(a)
	return float(total) / governing.size()


## The chance in percent that a roll on this skill succeeds (see Training).
## 0 while the gear it needs is not worn.
func skill_chance(id: String) -> int:
	if not skill_enabled(id):
		return 0
	return Training.skill_chance(skill_attribute_average(id), skill(id))


## A roll on a skill: d100 against skill_chance.
func skill_check(id: String) -> bool:
	return randi_range(1, 100) <= skill_chance(id)


## Adds training to an attribute or skill. Skills only train while their gear
## is worn, unless need_gear is false (reading a book about it, see Offline).
## Tells the game when a new point or level is reached.
func train(id: String, amount: float, need_gear := true) -> void:
	# Even a fall teaches wisdom.
	if amount <= 0.0 or (dead and id != "weisheit"):
		return
	if id != "weisheit":
		amount *= 1.0 + Training.LEARNING_PER_WISDOM * (attribute("weisheit") - Training.ATTRIBUTES.weisheit.start)
	var is_craft := Training.CRAFTS.has(id)
	var is_skill := Training.is_skill(id) or is_craft
	if is_skill:
		amount *= 1.0 + skill_learning_bonus()
	if is_skill and need_gear and not is_craft and not skill_enabled(id):
		return
	var old_xp: float = xp.get(id, 0.0)
	xp[id] = old_xp + amount
	var before := Training.skill_level(old_xp, id) if is_skill else Training.attribute_value(id, old_xp)
	var after := Training.skill_level(xp[id], id) if is_skill else Training.attribute_value(id, xp[id])
	if after == before:
		return
	var old_max := max_hp
	refresh_stats()
	# A tougher body: the new life is there at once.
	hp += max_hp - old_max
	trained.emit(id, after)


## Everything the hero carries, as it weighs on them: a trained wearer feels
## hard armour less, and a strong hero feels every load less.
func load_weight() -> float:
	var armor_skill := skill("ruestung")
	var total := 0.0
	for slot in equipped:
		var id: String = equipped[slot]
		var kg := Items.weight(id)
		if Items.ALL[id].get("armor", 0) > 0:
			kg *= maxf(0.0, 1.0 - ARMOR_LIGHTER_PER_LEVEL * armor_skill)
		total += kg
	for id in bag:
		total += Items.weight(id)
	return total * Training.ATTRIBUTES.staerke.start / float(attribute("staerke"))


## A fresh hero for a new game: no gifts, no items.
func reset_gifts() -> void:
	gift_hp = 0
	home_hp = 0
	gift_power = 0
	gift_speed = 0.0
	gift_armor = 0
	companion_perks = {}
	equipped = {}
	wear.clear()
	bag.clear()
	refresh_stats()


## Recomputes life, strength and speed from gifts and worn items,
## and shows the worn weapon and shield in the hero's hands.
func refresh_stats() -> void:
	var hp_bonus := gift_hp + home_hp
	var power_bonus: int = gift_power + int(companion_perks.get("power", 0))
	var speed_bonus: float = gift_speed + float(companion_perks.get("speed", 0.0))
	hardening = gift_armor
	block_chance = 0.0
	for slot in equipped:
		var item: Dictionary = Items.ALL[equipped[slot]]
		hp_bonus += item.get("hp", 0)
		power_bonus += item.get("power", 0)
		speed_bonus += item.get("speed", 0.0)
		hardening += item.get("armor", 0)
		block_chance += item.get("block", 0.0)
	if equipped.has("schild"):
		block_chance += BLOCK_PER_LEVEL * skill("blocken")
	var hero := hero_level()
	hp_bonus += HeroLevel.life_bonus(hero)
	speed_bonus += HeroLevel.speed_bonus(hero)
	max_hp = MAX_HP + hp_bonus + attribute("konstitution") - Training.ATTRIBUTES.konstitution.start
	power = 1 + power_bonus + attribute("staerke") - Training.ATTRIBUTES.staerke.start
	base_speed = SPEED * (1.0 + speed_bonus) * attribute("tempo") / 100.0
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


## Colours the hero's cloak, body or legs after the worn cloak, armour or shoes,
## and gives them the grain of what they are made of (see GearLook). With
## nothing worn there, the hero's own clothes keep their colours.
func _show_tint(slot: String, parts: Array) -> void:
	var item: Dictionary = Items.ALL.get(equipped.get(slot, ""), {})
	for part in parts:
		var mesh := _model.find_child(part, true, false) as MeshInstance3D
		if item.has("tint"):
			GearLook.apply(mesh, item.get("material", ""), item.tint, true, item.get("metal", -1.0))
		else:
			GearLook.apply(mesh, "outfit")


const AILMENT_TIME := 20.0
const POISON_TICK := 8.0
const CURSE_SLOW := 0.85
const AILMENT_COLORS := {"gift": Color(0.45, 1.0, 0.35), "fluch": Color(0.75, 0.4, 1.0), "brand": Color(1.0, 0.5, 0.15)}
## Burning is short but fierce.
const BURN_TIME := 4.5
const BURN_TICK := 1.5
const AILMENT_WORDS := {"gift": "Vergiftet!", "fluch": "Verflucht!", "brand": "Brennt!"}


func afflict(kind: String) -> void:
	if dead:
		return
	var fresh := not ailments.has(kind)
	ailments[kind] = BURN_TIME if kind == "brand" else AILMENT_TIME
	if fresh:
		if kind == "gift":
			_poison_tick = POISON_TICK
		elif kind == "brand":
			_burn_tick = BURN_TICK
		Effects.float_text(level, global_position + Vector3(0, 3.0, 0), Lang.t(AILMENT_WORDS[kind]), AILMENT_COLORS[kind])
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


## Life the hero gets back: Konstitution / REGEN_PER_CON_DIVISOR every REGEN_INTERVAL seconds.
const REGEN_PER_CON_DIVISOR := 10.0
const REGEN_INTERVAL := 5.0
## Fractions of a life healed so far, until they add up to a whole one.
var _regen := 0.0
## Seconds since the last heal pulse.
var _regen_clock := 0.0
## Healing rests this long after every blow that costs life.
const REGEN_PAUSE_AFTER_HIT := 1.5
## Seconds left before healing goes on after the last blow.
var _regen_pause := 0.0


## Life per second, averaged over the interval (shown in the HUD and character page).
func life_regen() -> float:
	return attribute("konstitution") / REGEN_PER_CON_DIVISOR / REGEN_INTERVAL


## Heals the hero once every REGEN_INTERVAL seconds, more with more Konstitution.
func _regenerate(delta: float) -> void:
	if dead or hp >= max_hp:
		_regen = 0.0
		_regen_clock = 0.0
		_regen_pause = 0.0
		return
	# Freshly hurt: healing waits, then picks up where it left off.
	if _regen_pause > 0.0:
		_regen_pause = maxf(0.0, _regen_pause - delta)
		return
	_regen_clock += delta
	if _regen_clock < REGEN_INTERVAL:
		return
	_regen_clock -= REGEN_INTERVAL
	_regen += attribute("konstitution") / REGEN_PER_CON_DIVISOR
	if _regen >= 1.0:
		var whole := floori(_regen)
		_regen -= whole
		hp = mini(max_hp, hp + whole)
		regenerated.emit()


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
				train("konstitution", 1.0)
				Effects.head_text(level, self, 2.2, "-1", AILMENT_COLORS.gift)
				hurt.emit(1)
	if ailments.has("brand"):
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = BURN_TICK
			if hp > 1:
				hp -= 1
				train("konstitution", 1.0)
				Effects.head_text(level, self, 2.2, "-1", AILMENT_COLORS.brand)
				hurt.emit(1)
	if changed:
		_ailments_changed()


## Updates strength and speed, and shows a coloured haze while ailing.
func _ailments_changed() -> void:
	refresh_stats()
	var old := get_node_or_null("AilmentHaze")
	if old:
		old.free()
	for kind in ["brand", "gift", "fluch"]:
		if ailments.has(kind):
			var haze := Effects.make_sparkles(AILMENT_COLORS[kind])
			haze.name = "AilmentHaze"
			add_child(haze)
			break
	ailments_changed.emit()


## Puts the worn helmet or hat on the hero's head, unless the hero chose to
## hide it; the mohawk and the feather make room for it.
func _show_headgear() -> void:
	var slot := _model.find_child("HeadSlot", true, false)
	if slot == null:
		return
	var old := slot.get_node_or_null("Headgear")
	if old:
		old.free()
	var item: Dictionary = Items.ALL.get(equipped.get("kopf", ""), {})
	# A hidden helmet still protects, it just does not cover the haircut.
	var shown: bool = item.has("hat") and hair.get("show_helmet", true)
	var feather := slot.get_node_or_null("Feather") as Node3D
	if feather:
		feather.visible = not shown
	HairLook.cover(_model, shown)
	if not shown:
		return
	# The hats sit on the head bone of their own character, which matches the hero's.
	var source: Node = load(item.hat[0]).instantiate()
	var hat := source.find_child(item.hat[1], true, false).duplicate() as Node3D
	source.free()
	hat.name = "Headgear"
	slot.add_child(hat)
	if item.has("brim"):
		GearLook.narrow_brim(hat, item.brim)
	GearLook.dress(hat, item.get("material", ""))


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
		GearLook.dress(model, Items.ALL[id].get("material", ""))
		if Items.ALL[id].get("shock", 0.0) > 0.0:
			# A thunder weapon crackles with small blue sparks.
			var sparks := Effects.make_sparkles(Enemy.SHOCK_COLOR)
			sparks.emission_sphere_radius = 0.35
			sparks.amount = 8
			sparks.position = Vector3(0, 0.6, 0)
			model.add_child(sparks)


## Whether the hero has what an item asks for ("requires"), e.g. Intelligenz.
func can_use(requires: Dictionary) -> bool:
	for attr in requires:
		if attribute(attr) < int(requires[attr]):
			return false
	return true


## How many items the bag holds: a worn backpack makes room for more.
func bag_size() -> int:
	return Items.bag_size(equipped.get("rucksack", ""))


## How many bag slots are taken: bundled items (torches) share one.
func bag_used() -> int:
	return Items.slots_used(bag)


## Whether one more of `id` fits in the bag (on a bundle of it, or a free slot).
func bag_fits(id: String) -> bool:
	return Items.fits(bag, bag_size(), id)


## Moves a bag item into its slot; whatever was worn there goes into the bag.
## Items the hero is not yet able to use stay in the bag, and so do books,
## and so does a smaller backpack that could not hold everything carried,
## and so does an item whose swap would leave the bag with too few slots.
## Returns whether the item was put on.
func equip(id: String) -> bool:
	if Items.is_book(id) or Items.is_crate(id) or Items.is_stone(id) or Items.is_material(id) or not can_use(Items.ALL[id].get("requires", {})):
		return false
	var slot: String = Items.ALL[id].slot
	if slot == "spezial":
		# Two places for specials: take a free one, else swap out the first.
		slot = "spezial_2" if equipped.has("spezial_1") and not equipped.has("spezial_2") else "spezial_1"
	var after := bag.duplicate()
	after.erase(id)
	if equipped.has(slot):
		after.append(equipped[slot])
	if slot == "rucksack" and Items.slots_used(after) > Items.bag_size(id):
		return false
	# Taking one ring off a bundle and putting the worn one back can need one
	# more slot than before; with none free, nothing is swapped.
	if slot != "rucksack" and Items.slots_used(after) > maxi(bag_size(), bag_used()):
		return false
	bag.erase(id)
	if equipped.has(slot):
		bag.append(equipped[slot])
	equipped[slot] = id
	refresh_stats()
	return true


## Takes off a worn item. False when the bag has no room for it (without
## the backpack, when that is what comes off).
func unequip(slot: String) -> bool:
	var room := Items.BAG_SIZE if slot == "rucksack" else bag_size()
	if not equipped.has(slot) or not Items.fits(bag, room, equipped[slot]):
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
	Effects.head_text(level, self, 2.2, Lang.t("Geblockt!"), Color(0.72, 0.78, 0.88))
	Comic.pop(global_position, "block")


## What a hit of `amount` costs through `hardening`: the hardening is taken
## off, but the hit keeps at least half its force (rounded up) and at least 1.
## The same rule holds for the hero and for monsters.
static func soak(amount: int, hardening: int) -> int:
	if amount <= 0:
		return 0
	return maxi(ceili(amount / 2.0), amount - maxi(0, hardening))


## Seconds the hero cannot be hurt again after a hit. Short enough that a
## crowd of enemies is a real danger.
const HURT_GRACE := 0.6
## What the thorn rune deals back to a melee attacker; their hardening
## takes it off in full.
const THORNS_DAMAGE := 1


## Blows and shots can be blocked with a shield; spikes from below (blockable
## false) cannot.
func take_damage(amount: int, from: Vector3, attacker: Node = null, blockable := true) -> void:
	if dead or _invulnerable > 0.0 or _down > 0.0 or frozen:
		return
	# A blow or a trap never finds the hero sitting idly.
	stand_up()
	if blockable:
		mark_fight() # A blow or a shot, blocked or not; spikes are no fight.
		defend_against(attacker)
	if blockable and block_chance > 0.0 and randf() < block_chance:
		train("blocken", 2.0)
		train("staerke", 1.0)
		_block(from)
		return
	# A deft hero steps aside from a blow or a shot (see dodge_chance).
	if blockable and randf() < dodge_chance():
		train("geschick", 1.0)
		_invulnerable = 0.4
		Effects.float_text(level, global_position + Vector3(0, 2.2, 0), Lang.t("Ausgewichen!"), Color(0.72, 0.9, 0.78))
		return
	if blockable:
		train("blocken", 0.5)
	amount = soak(amount, hardening)
	train("ruestung", 1.0)
	_wear_armor()
	# Every life lost hardens the body a little.
	train("konstitution", amount)
	hp -= amount
	_regen_pause = REGEN_PAUSE_AFTER_HIT
	var knocked := _note_run_hit(amount)
	if attacker and has_special("dornenrune") and attacker.has_method("take_hit"):
		attacker.take_hit(THORNS_DAMAGE, global_position, "thorns")
	if hp <= 0 and has_special("phoenixfeder"):
		# The feather burns up and brings the hero back.
		equipped.erase("spezial_1" if equipped.get("spezial_1", "") == "phoenixfeder" else "spezial_2")
		refresh_stats()
		hp = mini(3, max_hp)
		Effects.float_text(level, global_position + Vector3(0, 3.0, 0), Lang.t("Phönixfeder!"), Color(1.0, 0.6, 0.2))
	_invulnerable = HURT_GRACE
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 10.0
	path.clear()
	Effects.head_text(level, self, 2.2, "-%d" % amount, Color(1, 0.3, 0.3))
	# The blow lands; the comic word's cry ("AUA!") comes with the bubble.
	Comic.pop(global_position, "hurt")
	Sfx.play(self, "hit", -3.0)
	hurt.emit(amount)
	if hp <= 0:
		dead = true
		play_once("Death_A", 99.0)
		defeated.emit()
	elif knocked:
		_knock_down()
	else:
		play_once("Hit_A", 0.35)


## Whether the hero is really running right now (fast enough for the run
## animation), not just walking.
func in_full_run() -> bool:
	return run_boost > RUN_ANIM_FROM and not sneaking


## Remembers a hit taken while running, and tells whether the running hits of
## the last KNOCKDOWN_WINDOW seconds took more than KNOCKDOWN_SHARE of the
## hero's life. A hit taken while not running never makes the hero stumble.
func _note_run_hit(amount: int) -> bool:
	while not _run_hits.is_empty() and _clock - _run_hits[0][0] > KNOCKDOWN_WINDOW:
		_run_hits.pop_front()
	if not in_full_run():
		return false
	_run_hits.append([_clock, amount])
	var total := 0
	for h in _run_hits:
		total += int(h[1])
	return total > max_hp * KNOCKDOWN_SHARE


## Knocks the hero down from outside, e.g. the bandit chief's shield bash.
## Like any stumble, it only happens to a running hero; already lying on the
## ground, nothing more happens.
func knock_down() -> void:
	if dead or _down > 0.0 or not in_full_run():
		return
	_knock_down()


## Knocks the hero to the ground: they fall over backwards, lie a moment and
## get up again. No blow lands while they are down.
func _knock_down() -> void:
	knockdowns += 1
	_run_hits.clear()
	run_boost = 1.0
	_falling = FALL_TIME
	_down = FALL_TIME + GET_UP_TIME
	_invulnerable = 0.0
	play_once("Death_A", _down)


## Lets a knocked-down hero lie until the fall is over, then stand up.
func _get_up(delta: float) -> void:
	if _down <= 0.0:
		return
	_down = maxf(0.0, _down - delta)
	if _falling > 0.0:
		_falling -= delta
		if _falling <= 0.0 and not dead:
			_current_anim = ""
			play(GET_UP_ANIM, 0.4)
	if _down <= 0.0 and not dead:
		# A short blink once back on the feet, so a waiting blade does not
		# land the very moment the hero stands.
		_invulnerable = 0.6


## Running trains speed, carrying a heavy load trains strength, sneaking
## trains sneaking. Knockback and the stairs do not count.
func _train_legs(metres: float) -> void:
	if metres <= 0.0 or metres > 1.0 or _knockback.length() > 1.0 or not controllable:
		return
	if sneaking:
		train("schleichen", metres * 0.1)
	else:
		train("tempo", metres)
		train("staerke", metres * carried_weight() * 0.0005)


## Whether the hero stands on a crate (see Level.stacked: up there they
## are never stacked with a skeleton below).
func on_crate() -> bool:
	return _on_crate and is_on_floor()


## Whether the hero is climbing onto a crate right now.
func is_climbing() -> bool:
	return _climb >= 0.0


## Starts climbing onto a crate the hero pushes against: walking into one
## that is a step high, or jumping against one whose top the hands reach.
func _try_climb(dir: Vector3) -> bool:
	var push := dir
	if push == Vector3.ZERO and not is_on_floor():
		push = Vector3(_air_momentum.x, 0, _air_momentum.z)
	if push.length() < 0.01:
		return false
	push = push.normalized()
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var crate := hit.get_collider() as Crate
		if crate == null or absf(hit.get_normal().y) > 0.5 or push.dot(-hit.get_normal()) < 0.5:
			continue
		var target: Vector3
		if crate is StoneBlock:
			# Onto the top of the blocks on the grid cell just past the edge
			# the hero pushes against.
			var into := hit.get_position() - hit.get_normal() * StoneBlock.CELL * 0.5
			var c := StoneBlock.grid_cell(into)
			target = Vector3((c.x + 0.5) * StoneBlock.CELL, level.stone_surface(into) + 0.02, (c.y + 0.5) * StoneBlock.CELL)
		else:
			var top: Crate = level.stack_top(crate)
			target = Vector3(top.global_position.x, top.top() + 0.02, top.global_position.z)
		var rise := target.y - 0.02 - global_position.y
		if rise <= 0.05 or rise > (STEP_UP if is_on_floor() else GRAB_REACH):
			continue
		if not _room_at(target):
			continue
		_climb_from = global_position
		_climb_to = target
		_climb = 0.0
		_air_momentum = Vector3.ZERO
		velocity = Vector3.ZERO
		face(target - global_position)
		_current_anim = ""
		play("Jump_Idle", 0.1)
		train("geschick", 0.5)
		return true
	return false


## Whether the hero fits standing at `spot` (feet there): nothing in the way.
func _room_at(spot: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius - 0.05
	capsule.height = tall - 0.1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis(), spot + Vector3(0, tall * 0.5 + 0.05, 0))
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## One step of a climb: up first, then over the edge onto the top.
func _climb_step(delta: float) -> void:
	_climb = minf(1.0, _climb + delta / CLIMB_TIME)
	var up := smoothstep(0.0, 0.65, _climb)
	var over := smoothstep(0.3, 1.0, _climb)
	var p := _climb_from.lerp(_climb_to, over)
	p.y = lerpf(_climb_from.y, _climb_to.y + 0.1, up) if _climb < 1.0 else _climb_to.y
	global_position = p
	velocity = Vector3.ZERO
	if _climb >= 1.0:
		_climb = -1.0
		_current_anim = ""
		play("Idle")


## Nothing but the hero's own steps takes them onto a tile with furniture: a
## skeleton pressing in, or a blow throwing them back, would wedge them in
## beside it. Such a move is taken back (the skeleton is pushed aside
## instead, see Level._push_apart); walking there on purpose is fine.
func _keep_off_furniture(before: Vector3, dir: Vector3) -> void:
	if level == null:
		return
	var moved := global_position - before
	moved.y = 0.0
	if moved.length() < 0.0001:
		return
	var on_purpose := dir != Vector3.ZERO and dir.dot(moved) > 0.0 and _knockback.length() < 1.0
	if on_purpose or not level.shoves_onto_furniture(self, Vector3.ZERO, before):
		return
	global_position = Vector3(before.x, global_position.y, before.z)
	_knockback = Vector3.ZERO


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
	_flourish = maxf(0.0, _flourish - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	fight_cooldown = maxf(0.0, fight_cooldown - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_auto_cooldown = maxf(0.0, _auto_cooldown - delta)
	_anim_hold = maxf(0.0, _anim_hold - delta)
	_clock += delta
	_get_up(delta)
	_tick_ailments(delta)
	_regenerate(delta)
	_pursue(delta)
	_auto_attack()
	if _stay_seated(delta):
		return
	if _climb >= 0.0:
		_climb_step(delta)
		return
	var dir := Vector3.ZERO
	if controllable and not dead and _busy <= 0.0:
		dir = _keyboard_direction()
		if dir == Vector3.ZERO:
			dir = steer
		if dir != Vector3.ZERO:
			path.clear()
			_hunt = null
		elif not path.is_empty():
			var to := path[0] - global_position
			to.y = 0.0
			if to.length() < 0.3:
				path.remove_at(0)
			if not path.is_empty():
				to = path[0] - global_position
				to.y = 0.0
				dir = to.normalized()
	_breathe(delta, dir != Vector3.ZERO)
	var vy := velocity.y - GRAVITY * delta
	var pace := speed * (SNEAK_SPEED + SNEAK_PER_LEVEL * skill("schleichen") if sneaking else WALK_FACTOR * run_boost)
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
	_keep_off_furniture(before, dir)
	_train_legs(Vector2(global_position.x - before.x, global_position.z - before.z).length())
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
	_on_crate = false
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if hit.get_collider() is Crate and hit.get_normal().y > 0.7:
			_on_crate = true
	if dir != Vector3.ZERO:
		for i in get_slide_collision_count():
			var hit := get_slide_collision(i)
			if dir.dot(-hit.get_normal()) > 0.5:
				var enemy := hit.get_collider() as Enemy
				if enemy:
					_engage(enemy)
				elif not hit.get_collider() is Crate:
					bumped.emit(hit.get_position() - hit.get_normal() * 0.2)
	if controllable and not dead and _busy <= 0.0 and _down <= 0.0 and _falling <= 0.0 and _try_climb(dir):
		return
	if dir != Vector3.ZERO and _anim_hold <= 0.0:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-14.0 * delta))
	# Blink while invulnerable after a hit.
	_model.visible = dead or _invulnerable <= 0.0 or int(_invulnerable * 12.0) % 2 == 0
	# Feet keep pace with the ground: the run and the walk play faster or
	# slower with the speed.
	var ground_speed := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if _current_anim == "Running_A":
		_anim.speed_scale = clampf(ground_speed / RUN_ANIM_SPEED, 0.5, 2.5)
	elif _current_anim == WALK_ANIM:
		_anim.speed_scale = clampf(ground_speed / WALK_ANIM_SPEED, 0.5, 2.5)
	elif _current_anim == GET_UP_ANIM:
		_anim.speed_scale = GET_UP_SPEED
	else:
		_anim.speed_scale = 1.0
	_footsteps(ground_speed)
	_update_sneak_look()
	# A flourish shows only while the hero stands still; moving ends it.
	if dir != Vector3.ZERO or not is_on_floor() or _busy > 0.0:
		_flourish = 0.0
	if _busy > 0.0 or _anim_hold > 0.0 or _flourish > 0.0 or not controllable or dead:
		return
	if not is_on_floor():
		if _current_anim != "Jump_Full_Short":
			play("Jump_Idle")
		return
	if dir == Vector3.ZERO:
		play("Idle")
	else:
		play(SNEAK_ANIM if sneaking else ("Running_A" if run_boost > RUN_ANIM_FROM else WALK_ANIM))
