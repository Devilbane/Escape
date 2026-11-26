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
## Spare knives went from the bag into the belt, or back (see _settle_knives).
signal knives_settled
## Emitted when the hero runs into something solid, with a point just inside it.
signal bumped(point: Vector3)
## Emitted when training raises an attribute or a skill, with its new value.
signal trained(id: String, value: int)
## The hero reached a new level (see HeroLevel).
signal leveled_up(level: int)

## The hero's reference speed in m/s (100 % Tempo); walking is a share of it.
const SPEED := 5.2
## Walking pace as a share of SPEED: about 1.8 m/s, as fast as the short
## legs of the walk animation step without sliding (see Stride).
const WALK_FACTOR := 0.34
## The most the base speed (Tempo, gear, gifts, level, companions) can reach, as a
## share of SPEED. The run's boost and the slowing ailments are counted after it.
const BASE_SPEED_CAP := 2.0
## Running speeds up to this many times the walking pace (twice: 3.6 m/s)...
const RUN_TOP := 2.0
## ...over this many seconds of holding the run,
const RUN_RAMP_UP := 2.0
## and slows back down to walking within this many seconds once let go.
const RUN_RAMP_DOWN := 1.0
const WALK_ANIM := "Walking_A"
## Between the walk and the run, a jog (see Stride.gait).
const JOG_ANIM := "Running_B"
## Where in the walk cycle each foot touches the ground (left, right).
const WALK_LANDINGS := [0.02, 0.52]
## Seconds of running per point of Konstitution: 10 points run for 20 seconds.
const RUN_SECONDS_PER_CON := 2.0
## Seconds of running regained per second, per point of Konstitution: 10
## points bring one second back every second.
const RUN_RECOVERY_PER_CON := 0.1
## Out of breath, the hero walks until this share of the meter has come back.
const RUN_RESTART := 0.5
## From this many times the walking pace on (about 3.4 m/s), the hero is in
## a full run (see in_full_run).
const RUN_ANIM_FROM := 1.9
const JUMP_VELOCITY := 9.0
## A jump starts with half a step: the hero pushes off into a stride and leaves
## the ground JUMP_WINDUP seconds after the key. A runner is mid-stride
## already, so the push-off is shorter (JUMP_WINDUP_RUN) and a timed jump at
## a ledge shifts by well under a metre.
const JUMP_WINDUP := 0.12
const JUMP_WINDUP_RUN := 0.05
const GRAVITY := 26.0
const MAX_HP := 5
## The spot the hero takes up: no skeleton may stand inside it (see
## Level.push_apart).
var radius := 0.55
var tall := 2.4
## The name over the head (see _build_name_tag), and its height above the feet:
## clear of a helmet or a tall haircut seen from the tilted camera, with a
## little air between. NAME_TAG_TOP is about the top of its letters, where
## the messages over the head start (Game.place_message).
var name_tag: Label3D
const NAME_TAG_HEIGHT := 3.3
const NAME_TAG_TOP := NAME_TAG_HEIGHT + 0.25
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
## A strike that will find a vital point (see MonsterLore): a leap at the
## foe, up VITAL_LEAP_UP and forward VITAL_LEAP_AHEAD metres, the weapon
## raised and brought down in an overhead chop as the hero lands. The chop
## plays VITAL_ANIM_SPEED times as fast; the blade lands VITAL_HIT seconds
## after the leap starts (the top of the leap is at VITAL_TOP).
const VITAL_ANIM := "1H_Melee_Attack_Chop"
const VITAL_ANIM_SPEED := 1.6
const VITAL_LEAP_UP := 1.1
const VITAL_LEAP_AHEAD := 0.6
const VITAL_TOP := 0.28
const VITAL_HIT := 0.4
## Running into a skeleton starts a fight: the hero keeps swinging while
## standing next to it, and throws knives at it once the two are apart.
const ENGAGE_RANGE := MELEE_RANGE
const AUTO_MELEE_INTERVAL := 0.8
const AUTO_THROW_INTERVAL := 1.2
const AUTO_THROW_RANGE := 22.0
const HIDDEN_PARTS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"]

var level: Level
var controllable := true
## The hero is typing in the chat line (see ChatLine): the walking and
## running keys are not read then.
var typing := false
## While frozen, the game moves the hero itself (e.g. up the exit stairs).
var frozen := false
var dead := false
var hp := MAX_HP
## What one shrine gift gives: the player picks one of the three (life, a
## free attribute point, or Konstitution).
const SHRINE_LIFE := 5
const SHRINE_POINTS := 1
const SHRINE_CONSTITUTION := 1
## In the beginner dungeon a shrine's Konstitution gift is bigger.
const SHRINE_CONSTITUTION_BEGINNER := 2
## The most shrines a hero can use in the whole beginner dungeon; after that they stay quiet.
const SHRINE_CAP_BEGINNER := 9
# Gifts from shrines, kept for the whole run.
var gift_hp := 0
## Life from the trophy wall at home (see HomeUpgrades), set by the game.
var home_hp := 0
# Power and speed from shrines of older versions; still kept in old saves.
var gift_power := 0
var gift_speed := 0.0
## Attribute points from shrines this run, and where the hero put them
## (attribute id -> points). Unlike level points they end with the run.
var gift_points := 0
var gift_spent := {}
## Konstitution from shrines this run.
var gift_constitution := 0
## Shrines used so far in the beginner dungeon (counts against SHRINE_CAP_BEGINNER).
var beginner_shrines_used := 0
## From the fourth shrine gift, which only a wise hero is offered.
var gift_armor := 0
## The temple's blessing (see Blessing): the god's id ("" for none), how many
## thirds of its strength are left, and whether the hero ever had one (the
## first is free).
var blessing_god := ""
var blessing_thirds := 0
var blessed_before := false
## The injury a rescue left (see Injury): its id ("" for none) and the nights
## of rest it has had.
var injury := ""
var injury_severity := ""
var injury_rest := 0
var _injury_said := -10000
## Whether the blow that felled the hero came from a boss (set in take_damage).
var felled_by: Node = null
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
## The share of a hit (in percent) the worn armour takes off after the
## hardening (Rüstungswert, "armour_value" in Items.ALL), at most
## ARMOUR_VALUE_MAX.
var armour_value := 0
const ARMOUR_VALUE_MAX := 60
## How much each armour piece has worn down, by item id.
var wear := {}
## The hero's hair style, hair colour and head tattoo (see HairLook); the
## barber in the village changes them.
var hair := HairLook.DEFAULT.duplicate()
## The picture on the back of the cape (index into CapeDesigns.DESIGNS) and its quad.
var cape_design := CapeDesigns.DEFAULT
var _cape_logo: MeshInstance3D
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
## Whether the Tempo, gear, gifts and level would give more than BASE_SPEED_CAP.
var base_speed_capped := false
## The base speed they add up to before the cap, as a share of SPEED (1.0 = 100 %).
var base_speed_wanted := 1.0
## The speed the hero really runs at: everything carried (worn or in the bag)
## weighs them down.
var speed: float:
	get:
		return base_speed * Items.load_factor(load_weight())
## The share of the pace the ground underfoot allows right now: grass, scree
## and puddles slow the hero a little (see Surfaces).
var surface_pace := 1.0
## Throwing knives ready to hand, at most knife_cap() of them; spares ride
## in the bag as Items.KNIFE and are slipped back into the belt once no fight
## is on (see _settle_knives). A thrown knife lies where it fell until the
## hero walks over it (see Level.lay_knife).
var knives := 5
## How many knives the hero keeps ready with no skill in Messerwurf; each
## KNIFE_CAP_STEP levels of the skill add one more.
const KNIFE_CAP_BASE := 3
const KNIFE_CAP_STEP := 2
## Seconds one throw keeps the hero busy, and how many throws an empty belt's
## refill from the bag costs.
const THROW_COOLDOWN := 0.6
const KNIFE_REFILL_ATTACKS := 2
## Seconds between looks at the belt and the bag (see _settle_knives).
const KNIFE_SETTLE_EVERY := 0.5
var _knife_settle := 0.0
## Ailments and the seconds each has left. Poison ("gift") takes a life every
## few seconds but never the last one; a curse ("fluch") slows the hero;
## burning ("brand", from the dragon's fire) takes a life every
## BURN_TICK seconds for a few seconds, never the last one either; a spider's
## web ("netz") makes the hero much slower for a few seconds; fear ("angst",
## see scare) makes the hero flee towards the nearest way out for FEAR_TIME.
## Bleeding ("blut", see bleed and Bleeding) lasts as long as its wound has
## life to bleed: 1 a second, 2 while the hero moves, never the last one.
## All wear off soon; a fountain, a shrine or a healing potion cures them.
var ailments := {}
## The hero's open wound (see bleed).
var wound := Bleeding.new()
var _poison_tick := 0.0
var _burn_tick := 0.0
## A direction to run in, set every frame while the mouse button is held.
var steer := Vector3.ZERO
var _stuck_time := 0.0
var _wedge := HeroUnstick.new()
## The last place the hero stood and moved freely (where HeroUnstick leads them back to).
var free_spot := Vector3.INF
var _sidestepped := false
## Speed carried through the air by a running jump.
var _air_momentum := Vector3.ZERO
## Horizontal speed a jump may never exceed: the run speed it left the ground at.
var _air_speed_cap := 0.0
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

## Seconds left in which running still costs breath: set whenever the hero deals or takes
## damage, so running is free outside of combat (see COMBAT_WINDOW).
var combat_clock := 0.0
const FIGHT_SNEAK_BLOCK := 2.0

## How long after the last damage dealt or taken the hero counts as in combat.
const COMBAT_WINDOW := 5.0
## Sneaking pace as a share of SPEED, and what each level of Schleichen adds.
const SNEAK_SPEED := 0.16
const SNEAK_ANIM := "Walking_C"
var _lantern: OmniLight3D
var _fill: OmniLight3D
## See set_night_dim: how far the night closes in on the lantern, and what
## is left of its brightness and reach on a moonless night.
var night_dim := 0.0
const NIGHT_LANTERN_ENERGY := 0.55
## How bright the lantern over the hero's head burns, open and hooded (sneaking). It hangs
## close over the hero, so it lights them far more than the ground round them: kept low
## enough that the hero never glares white.
const LANTERN_ENERGY := 0.85
const SNEAK_LANTERN_ENERGY := 0.35
const NIGHT_LANTERN_RANGE := 0.62
## The render layer of the hero's own figure: the face light (FACE_LIGHT) reaches nothing else.
const HERO_LAYER := 1 << 14
## The soft light on the face and upper body in the dark, at full dark (see set_dark): a warm
## white just in front of the face, towards the camera, a little above it.
const FACE_LIGHT := 0.55
const FACE_LIGHT_COLOUR := Color(1.0, 0.9, 0.8)
const FACE_LIGHT_AT := Vector3(0, 2.2, 1.6)
const FACE_LIGHT_RANGE := 3.4
## How dark it is round the hero (see set_dark).
var dark := 0.0
## The hand torch that burns in the pitch-black places (see HandTorch).
var torch: HandTorch
## The hero's healing potions: the cooldown and the life over time of the
## last one drunk (see HealingPotions).
var potions := HealingPotions.new()
## Seconds until the arcane bolt can be cast again (see ArcaneBolt).
var spell_wait := 0.0
var _shown_alpha := -1.0

var _model: Node3D
var _anim: AnimationPlayer
## Where in the run cycle each foot touches the ground (left, right).
const FOOT_LANDINGS := [0.17, 0.67]
## The same for the jog.
const JOG_LANDINGS := [0.11, 0.61]
## The same for the sneaking walk, whose feet land later in its cycle.
const SNEAK_LANDINGS := [0.29, 0.79]
var _last_phase := -1.0
## How many more dry steps leave a wet footprint, after a step in a puddle.
var _wet_steps := 0
## Lifted onto the toes by the walk (see Stride.lift); anything else that
## moves the model (the leap of a vital strike) is left alone.
var _on_toes := false
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
## Whether the hunt is a sneak: the hero goes round to the back of a foe that
## has not noticed them, and strikes once there (see charge).
var _sneak_hunt := false
## How far behind a foe's middle the hero aims to stand for a sneak attack.
const SNEAK_BEHIND := 1.1
## How far from the enemy's middle the hunt stops: side by side, in reach.
const HUNT_STOP := 1.6
const HUNT_REPATH := 0.4
## Struck by a foe the hero cannot answer from where they stand (out of reach,
## and no knife can fly at it), the hero walks up to it on their own and
## strikes back. Such a chase gives up after CHASE_TIME seconds, or when the foe
## gets farther than CHASE_LEASH metres away, and the same foe is not chased
## again for CHASE_REST seconds after that, so a foe that keeps backing off
## cannot lead the hero across the map. A step or a click ends it at once.
const CHASE_TIME := 5.0
const CHASE_LEASH := 16.0
const CHASE_REST := 4.0
## Seconds left on the hero's own chase; 0 for a hunt that was clicked.
var _chase_left := 0.0
## The foe last given up on, and how long until it may be chased again.
var _chase_quit: Enemy = null
var _chase_rest := 0.0
var _auto_cooldown := 0.0
## Whether the current target was picked by the player (a click), not by the
## hero fighting back or bumping into a foe. Only then does the hero keep
## striking while sneaking.
var _target_chosen := false
## Time left on an animation that plays while the hero keeps moving.
var _anim_hold := 0.0
var _jump_windup := 0.0 ## Seconds left of the half step before a jump.
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
var _climb_time := CLIMB_TIME
## A hero in a dug pit (see HouseSketch) with no stairs scrambles out: pushing
## against the pit wall for PIT_PUSH_TIME seconds starts a climb onto the ground
## beyond it, as long as the Klettern skill (see Climbing) allows.
const PIT_DEPTH := 1.2
const PIT_PUSH_TIME := 0.5
var _pit_push := 0.0
var _pit_hinted := false
var _pit_slips := 0
var _climb := -1.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _on_crate := false
## Draws the model back from walls that the head or the gear would sink into (see WallClearance).
var _clearance := WallClearance.new()
var _clearance_pivot: Node3D


func _ready() -> void:
	SmoothMotion.follow_ticks(self)
	add_to_group("combatant")
	add_to_group(Footprint.GROUP)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = tall
	shape.shape = capsule
	shape.position.y = tall * 0.5
	add_child(shape)

	_model = preload("res://assets/characters/Rogue.glb").instantiate()
	# The model hangs on a pivot that WallClearance draws back from walls, so the figure's
	# own moves (the leap of a vital strike) stay its own.
	_clearance_pivot = Node3D.new()
	_clearance_pivot.name = "WallClearance"
	add_child(_clearance_pivot)
	_clearance_pivot.add_child(_model)
	for part in HIDDEN_PARTS:
		var node := _model.find_child(part, true, false)
		if node:
			node.visible = false
	# The body comes first: everything else dresses whichever body it is.
	BodyLook.apply(_model, sex)
	_model.scale = Vector3.ONE * BodyLook.scale_of(sex)
	Breath.attach(_model)
	_add_cape_logo()
	_add_trim()
	GearLook.dress(_model.find_child("handslot_r", true, false).get_node("Knife"), "mixed") # The hero's own knife.
	for arm in ["Rogue_ArmLeft", "Rogue_ArmRight"]:
		GearLook.apply(_model.find_child(arm, true, false) as MeshInstance3D, "outfit")
	set_hair(hair)
	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Running_A", JOG_ANIM, "Walking_A", "Jump_Idle", SNEAK_ANIM]:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("Idle")

	# A warm lantern glow around the hero, so the way ahead is never pitch black.
	_lantern = OmniLight3D.new()
	_lantern.light_color = Color(1.0, 0.75, 0.5)
	_lantern.light_energy = LANTERN_ENERGY
	_lantern.omni_range = 8.5
	# A soft falloff: no hard-edged disc of light on the snow.
	_lantern.omni_attenuation = 1.8
	_lantern.position = Vector3(0, 3.2, 0.6)
	add_child(_lantern)
	# A soft light on the face and the upper body in the dark (see set_dark and _light_lantern):
	# the lantern hangs above the head, so without it the hair glows and the face goes black. It
	# lights the hero alone (HERO_LAYER), never the ground round them.
	_fill = OmniLight3D.new()
	_fill.light_color = FACE_LIGHT_COLOUR
	_fill.omni_range = FACE_LIGHT_RANGE
	_fill.omni_attenuation = 1.0
	_fill.light_cull_mask = HERO_LAYER
	_fill.set_meta(LightShadows.NO_SHADOW, true)
	_fill.position = FACE_LIGHT_AT
	_fill.visible = false
	add_child(_fill)
	_light_only_hero(_model)
	get_tree().node_added.connect(_on_node_added)
	# A hand torch for the pitch-black places (see HandTorch).
	torch = HandTorch.new(self)
	add_child(torch)
	potions.player = self
	_build_name_tag()


## The hero's name over the head, in the same look as the name tags of the
## townsfolk and dungeon folk (Villager, DungeonNpc): Cinzel Bold 30, warm
## white with a dark outline, always facing the camera. The life bar sits at
## a fixed spot under the feet (Game._place_hp_bar), so the two never meet.
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


## True while running costs breath: damage was dealt or taken a moment ago.
func in_combat() -> bool:
	return combat_clock > 0.0


## Called while a fight goes on; sneaking stays barred until it has been
## over for FIGHT_SNEAK_BLOCK seconds.
func mark_fight() -> void:
	fight_cooldown = FIGHT_SNEAK_BLOCK


## Switches between walking normally and sneaking.
func set_sneaking(on: bool) -> void:
	sneaking = on
	_light_lantern()


## How much the dark of the night above ground closes in on the lantern: 0
## by day, in the dungeon and under a full moon, 1 on a moonless night (see
## Game._moonlight). Then the glow shows the hero and a step or two around,
## and the rest of the night stays dark.
func set_night_dim(dim: float) -> void:
	dim = clampf(dim, 0.0, 1.0)
	if is_equal_approx(dim, night_dim):
		return
	night_dim = dim
	if not (torch and torch.in_dark()):
		_light_lantern()


## The lantern as bright and wide as the hood and the night allow. A hooded
## lantern: just enough to see the floor, too little to be seen by.
func _light_lantern() -> void:
	_lantern.light_energy = (SNEAK_LANTERN_ENERGY if sneaking else LANTERN_ENERGY) * lerpf(1.0, NIGHT_LANTERN_ENERGY, night_dim)
	_lantern.omni_range = (5.0 if sneaking else 8.5) * lerpf(1.0, NIGHT_LANTERN_RANGE, night_dim)
	# At night the lantern sits lower and further forward, so it lights the face
	# as much as the hair, and a gentle cool fill keeps the hero readable.
	_lantern.position = Vector3(0, lerpf(3.2, 2.3, night_dim), lerpf(0.6, 1.2, night_dim))
	_fill.light_energy = FACE_LIGHT * maxf(dark, night_dim) * (0.6 if sneaking else 1.0)
	_fill.visible = _fill.light_energy > 0.01

## How dark it is round the hero, 0 by day out in the open to 1 at night, in a dungeon or in a
## cave (see Game): the soft light on the face and upper body (FACE_LIGHT) follows it.
func set_dark(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if is_equal_approx(amount, dark):
		return
	dark = amount
	_light_lantern()


## Puts everything drawn of the hero (`node` and what is under it) on HERO_LAYER as well, the
## only layer the face light reaches.
static func _light_only_hero(node: Node) -> void:
	if node is VisualInstance3D and not node is Light3D:
		(node as VisualInstance3D).layers |= HERO_LAYER
	for child in node.get_children():
		_light_only_hero(child)


## Gear, hair and the rest put on the hero later are lit by the face light too.
func _on_node_added(node: Node) -> void:
	if _model != null and node is VisualInstance3D and not node is Light3D and _model.is_ancestor_of(node):
		(node as VisualInstance3D).layers |= HERO_LAYER


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


## Leans back so the head rests up on a bed's pillows (`lying`), or upright
## again, over `time` seconds (see Level.lie_tilt).
func lean_on_pillow(lying: bool, time := 0.0) -> void:
	Level.lie_tilt(_model, lying, time)


## How big the body is (the woman's is a little smaller, see BodyLook.scale_of).
func body_scale() -> float:
	return _model.scale.x


## Whether the body is posed bone by bone for going to bed or getting up (see BedRise).
var _bed_posed := false
var _bed_base := {}


## Poses the hero as `state` (see BedRise.at) in the bed at `bed_pos` turned by `rot`: the body is
## put where the pose says (the hips on the mattress, the feet on the floor), the weapon put away.
func bed_pose(state: Dictionary, bed_pos: Vector3, rot: float, side := -1.0) -> void:
	if _skeleton == null:
		_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		return
	if not _bed_posed:
		_bed_posed = true
		_anim.speed_scale = 1.0
		_anim.play("Idle")
		_anim.seek(0.0, true)
		if _bed_base.is_empty():
			_bed_base = ClimbPose.base_of(_skeleton)
		_anim.pause()
		_current_anim = ""
		BedRise.arm(_model, false)
	global_position = BedRise.pose(_model, _skeleton, _bed_base, state, bed_pos, rot, side)
	reset_physics_interpolation()
	set_asleep(bool(state.shut))
	BedRise.yawn(_model, float(state.yawn))


## Back from bed_pose to the clips: standing at `spot`, facing `towards`, the weapon in hand again.
func bed_pose_end(spot: Vector3, towards: Vector3) -> void:
	if not _bed_posed:
		return
	_bed_posed = false
	if _skeleton != null:
		ClimbPose.apply(_skeleton, _bed_base, {})
	BedRise.clear(_model)
	BedRise.arm(_model, true)
	BedRise.yawn(_model, 0.0)
	set_asleep(false)
	global_position = spot
	reset_physics_interpolation()
	face(towards)
	_current_anim = ""
	play("Idle", 0.2)


## Whether the hero is posed for bed (see bed_pose).
func in_bed_pose() -> bool:
	return _bed_posed


## Opens the eyes and gets up from lying on the back, the way a knocked-down
## hero does (GET_UP_ANIM, GET_UP_TIME seconds).
func get_up_from_bed() -> void:
	set_asleep(false)
	lean_on_pillow(false, 0.4)
	_current_anim = ""
	play(GET_UP_ANIM, 0.3)
	_anim.speed_scale = GET_UP_SPEED


func _build_eyelids() -> void:
	_eyelids = EyeLids.build(_model)


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


## Puts another picture on the back of the cape (see CapeDesigns): the blank
## cape shows none.
func set_cape_design(design: int) -> void:
	cape_design = CapeDesigns.checked(design)
	if _cape_logo == null:
		return # Not built yet: _add_cape_logo puts it on.
	var tex := CapeDesigns.texture(cape_design)
	_cape_logo.visible = tex != null
	if tex != null:
		(_cape_logo.mesh.material as StandardMaterial3D).albedo_texture = tex


## The picture on the back of the cape: the glowing devilbane emblem unless the
## hero picked another at the cape wardrobe.
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
	logo.name = "CapeLogo"
	logo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Up near the shoulders, tilted to follow the cape's slope towards the hood.
	logo.position = Vector3(0, -0.36, -0.39)
	logo.rotation = Vector3(-0.3, PI, 0)
	cape.add_child(logo)
	_cape_logo = logo
	set_cape_design(cape_design)


func play(anim_name: String, blend := 0.2) -> void:
	if _current_anim == anim_name:
		return
	_current_anim = anim_name
	_anim.play(anim_name, blend)
	# Off the toes (see Stride.lift) when anything else begins.
	if _on_toes:
		_model.position.y = 0.0
		_on_toes = false


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
	var pace := maxf(Vector2(velocity.x, velocity.z).length(), SPEED * WALK_FACTOR)
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
	# Lowered onto the seat as the animation sits them down, not snapped onto it (a bump from afar snaps).
	if Vector2(spot.x - global_position.x, spot.z - global_position.z).length() <= SIT_GLIDE_MAX and absf(spot.y - global_position.y) < 1.0:
		_glide(global_position, spot, SIT_GLIDE, pace)
	else:
		global_position = spot
		_glide_left = 0.0
	face(towards)
	_anim.get_animation(SIT_IDLE_ANIM).loop_mode = Animation.LOOP_LINEAR
	_current_anim = ""
	play(SIT_DOWN_ANIM, 0.15)


func is_seated() -> bool:
	return _seated


## Whether the hero is still being lowered onto the seat: that always plays out in full before they
## can get up again (a blow or a death excepts it, see stand_up).
func sitting_down() -> bool:
	return _seated and _sit_time < SIT_DOWN_TIME


## Gets up from the seat, back on the spot in front of it. Does nothing while standing. While the
## sit-down animation still plays the hero stays put (a wish to move waits for its end) unless
## `force` (a blow, a shove or death). True when the hero stands (or already stood) afterwards.
func stand_up(force := false) -> bool:
	if not _seated:
		return true
	if sitting_down() and not force:
		return false
	_seated = false
	_stood_at = _clock
	# Steps out to where they stand again over a moment, instead of popping there.
	if Vector2(_stand_spot.x - global_position.x, _stand_spot.z - global_position.z).length() <= SIT_GLIDE_MAX:
		_glide(global_position, _stand_spot, GET_UP_GLIDE, SPEED * WALK_FACTOR)
	else:
		global_position = _stand_spot
		_glide_left = 0.0
	velocity = Vector3.ZERO
	_current_anim = ""
	play("Idle", 0.15)
	return true


## True while the hero has just stood up and keeps running into the seat
## (each bump keeps it true), so holding a key towards a bench does not sit
## them down again and again. Once they let go for SIT_AGAIN seconds, running
## into the seat sits them down as usual.
func still_getting_up() -> bool:
	if _clock - _stood_at < SIT_AGAIN:
		_stood_at = _clock
		return true
	return false


## Moving onto or off a seat takes a moment (the hero glides, no collisions asked): from where they
## were, to where they go, over `_glide_len` seconds of which `_glide_left` are left.
var _glide_from := Vector3.ZERO
var _glide_to := Vector3.ZERO
var _glide_left := 0.0
var _glide_len := 0.0
const SIT_GLIDE := 0.45
const GET_UP_GLIDE := 0.25
## A seat further than this (metres) is snapped to: the hero was put there, not walking up to it.
const SIT_GLIDE_MAX := 2.0


## It never goes faster than `pace` (m/s): the hero walking over a seat's spot is not hurried along it.
func _glide(from: Vector3, to: Vector3, seconds: float, pace: float) -> void:
	var span := Vector2(to.x - from.x, to.z - from.z).length()
	seconds = maxf(seconds, span / maxf(pace, 0.1))
	_glide_from = from
	_glide_to = to
	_glide_len = seconds
	_glide_left = seconds


## One tick of the glide onto or off a seat. True while the hero getting up is still on their way
## (nothing else moves them then); the glide onto a seat goes on while they sit.
func _glide_step(delta: float) -> bool:
	if _glide_left <= 0.0:
		return false
	_glide_left = maxf(0.0, _glide_left - delta)
	var k := 1.0 - _glide_left / _glide_len
	global_position = _glide_from.lerp(_glide_to, smoothstep(0.0, 1.0, k))
	velocity = Vector3.ZERO
	return not _seated


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
		if stand_up(dead):
			return false
		# Still sitting down: the animation plays out first, then the wish moves the hero.
	velocity = Vector3.ZERO
	_model.visible = true
	_sit_time += delta
	if _sit_time >= SIT_DOWN_TIME:
		play(SIT_IDLE_ANIM, 0.3)
	_anim.speed_scale = 1.0
	return true


# --- Blowing the alarm horn (see HornBlow, WarHorn.hero_blow) ---------------------

## The hero's blowing of the alarm horn while it lasts, the rig's standing
## pose it is posed over, and whether the body is posed for it yet.
var _horn: HornBlow
var _horn_base := {}
var _horn_posed := false
## The way the hero still pushes from walking into the horn: holding on that
## way keeps blowing; letting go, then any step, ends it (Vector3.ZERO: let go).
var _horn_push := Vector3.ZERO
## The walk round to the horn's mouthpiece.
const HORN_WALK := "Walking_A"


## Walks to the horn's mouthpiece and blows it (see HornBlow). There is no
## lock: any step, click, jump or attack, or a blow taken, ends it at once.
func blow_horn(blow: HornBlow) -> void:
	stand_up()
	_end_horn()
	path.clear()
	_hunt = null
	_target = null
	velocity = Vector3.ZERO
	_flourish = 0.0
	_horn = blow
	_horn_push = Vector3.INF


## Whether the hero is at the horn (or on the way to its mouthpiece) blowing it.
func blowing_horn() -> bool:
	return _horn != null


## One tick of blowing the horn: the walk to the mouthpiece, then the body
## posed for each blast and each breath. True while it goes on; any wish to
## do something else ends it, and the same tick goes on to do that.
func _horn_step(delta: float) -> bool:
	if _horn == null:
		return false
	var wish := Vector3.ZERO
	if controllable:
		wish = _keyboard_direction()
		if wish == Vector3.ZERO:
			wish = steer
	if _horn_push == Vector3.INF:
		_horn_push = wish
	if wish == Vector3.ZERO or wish.dot(_horn_push) < 0.7:
		_horn_push = Vector3.ZERO
	var pushing_on := wish != Vector3.ZERO and _horn_push != Vector3.ZERO
	if dead or not controllable or (wish != Vector3.ZERO and not pushing_on) or not path.is_empty() or _hunt != null or _busy > 0.0 or _knockback.length() > 0.5:
		_end_horn()
		return false
	var walk := Stride.top_speed("kaykit", HORN_WALK, _model.scale.x)
	var state := _horn.step(delta, walk)
	var pos: Vector3 = state.pos
	var face_to: Vector3 = state.face
	global_position = Vector3(pos.x, global_position.y, pos.z)
	velocity = Vector3.ZERO
	_model.rotation.y = lerp_angle(_model.rotation.y, atan2(face_to.x, face_to.z), 1.0 - exp(-14.0 * delta))
	if state.walking:
		play(HORN_WALK)
		_anim.speed_scale = Stride.playback("kaykit", HORN_WALK, _model.scale.x, walk)
	else:
		if _skeleton == null:
			_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
		if not _horn_posed and _skeleton != null:
			_horn_posed = true
			_anim.speed_scale = 1.0
			_anim.play("Idle")
			_anim.seek(0.0, true)
			if _horn_base.is_empty():
				_horn_base = ClimbPose.base_of(_skeleton)
			_anim.pause()
			_current_anim = ""
		_model.position.y = 0.0
		_on_toes = false
		if _horn_posed:
			ClimbPose.apply(_skeleton, _horn_base, state.pose)
	if _horn.done:
		_end_horn()
		return false
	return true


## Done with the horn, or off to do something else half way (the blast dies away).
func _end_horn() -> void:
	if _horn == null:
		return
	_horn.stop()
	_horn = null
	if _horn_posed:
		_horn_posed = false
		if _skeleton != null:
			ClimbPose.apply(_skeleton, _horn_base, {})
		_current_anim = ""
		play("Idle", 0.15)


func face(direction: Vector3) -> void:
	_model.rotation.y = atan2(direction.x, direction.z)


func facing() -> Vector3:
	return Vector3(sin(_model.rotation.y), 0, cos(_model.rotation.y))


## Puts the hero at a level's start; `heal` fills up life again.
func revive(at: Vector3, heal := true) -> void:
	dead = false
	DeadEyes.take_off(_model)
	if heal or hp <= 0:
		hp = max_hp
	stamina = -1.0
	combat_clock = 0.0
	winded = false
	path.clear()
	_target = null
	_hunt = null
	velocity = Vector3.ZERO
	global_position = at
	reset_physics_interpolation()
	_invulnerable = 1.5
	_busy = 0.0
	_flourish = 0.0
	_seated = false
	_glide_left = 0.0
	_falling = 0.0
	_down = 0.0
	_run_hits.clear()
	_climb = -1.0
	if _pit_climb:
		_end_pit_climb(false)
	if _rock != null:
		_end_rock(false)
	_end_horn()
	_on_crate = false
	set_asleep(false)
	play("Idle")


## Walks along the grid to `target`. With `stop_short` the hero walks right
## up to a thing standing there (a chest, a barrel, the merchant) and stops
## that far from its middle, instead of waiting a whole tile away.
func walk_to(target: Vector3, stop_short := 0.0) -> void:
	stand_up()
	path.clear()
	# Into, out of or about a village building one can walk into (see WalkIn): through its door.
	var walk_in = level.get("walk_in")
	if walk_in != null:
		var way: Array[Vector3] = walk_in.route(global_position, target)
		if not way.is_empty():
			path = way
			if stop_short > 0.0:
				var before: Vector3 = path[-2] if path.size() >= 2 else global_position
				var away := before - target
				away.y = 0.0
				if away.length() > stop_short:
					path[-1] = target + away.normalized() * stop_short
			return
	var from := level.set_out_cell(global_position)
	var to := level.world_to_cell(target)
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
	return controllable and not frozen and not dead and _busy <= 0.0 and not is_afraid()


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
	var run_key := not typing and Input.is_physical_key_pressed(KEY_SHIFT)
	sprinting = (wants_run or run_key) and moving and not sneaking and not winded and stamina > 0.0 and not Injury.cannot_run(self)
	if sprinting and in_combat():
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
	return not sneaking and Vector2(velocity.x, velocity.z).length() > SPEED * 0.25


## A jump from a run keeps its momentum and flies further the faster the
## hero runs; a standing jump goes straight up.
func jump() -> void:
	if not stand_up():
		return # Still sitting down.
	if Injury.cannot_jump(self) and _can_jump():
		_say_injury(Lang.t("Dein Bein erlaubt keinen Sprung!"))
		return
	if _jump_windup > 0.0 or not _can_jump():
		return
	_jump_windup = JUMP_WINDUP_RUN if is_running() else JUMP_WINDUP
	_anim_hold = _jump_windup
	_current_anim = ""
	play(WALK_ANIM, 0.04)
	Events.bus().hero_acted.emit("jump")


## True while the hero is in the half step before a jump leaves the ground.
func is_winding_up() -> bool:
	return _jump_windup > 0.0


## A short word over the hero's head when the injury stops what they tried, at
## most once in a while.
func _say_injury(text: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _injury_said < 2500:
		return
	_injury_said = now
	Effects.head_text(level, self, 2.2, text, Color(1.0, 0.55, 0.45))


func _can_jump() -> bool:
	return controllable and not frozen and not dead and is_on_floor() and not is_climbing()


## Counts the push-off down and launches the jump; a hit, a fall off a ledge,
## a climb or anything that takes the controls calls it off and frees the hold.
func _tick_jump(delta: float) -> void:
	if _jump_windup <= 0.0:
		return
	_jump_windup = maxf(0.0, _jump_windup - delta)
	if not _can_jump():
		_jump_windup = 0.0
		_anim_hold = 0.0
	elif _jump_windup == 0.0:
		_anim_hold = 0.0
		_launch_jump()


func _launch_jump() -> void:
	_air_momentum = Vector3.ZERO
	var jump_boost := 1.0
	if is_running():
		var run := Vector3(velocity.x, 0, velocity.z) - Vector3(_knockback.x, 0, _knockback.z)
		jump_boost = clampf(run.length() / SPEED, 0.6, 1.6)
		_air_momentum = run * (1.0 + 0.15 * jump_boost) * (1.0 + JUMP_PER_DEXTERITY * dexterity_points())
		# A jump is never faster than the run it started from.
		_air_speed_cap = run.length()
		_air_momentum = _air_momentum.limit_length(_air_speed_cap)
	velocity.y = JUMP_VELOCITY * (0.85 + 0.15 * jump_boost)
	train("tempo", 3.0)
	train("geschick", 2.0)
	_current_anim = ""
	play("Jump_Full_Short", 0.1)


## The nearest foe within `max_distance` metres that the hero can see, or null.
func nearest_foe(max_distance: float) -> Enemy:
	return _nearest_enemy(max_distance, true)


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


## Extra volume (dB) on the hero's footsteps inside a village, so they stand out
## from the townsfolk's steps and the village ambience. Tune here.
const VILLAGE_STEP_BOOST_DB := 6.0


## A step sounds each time a foot lands in the run animation, so the sound
## keeps the rhythm of the feet at any speed, and fits the ground underfoot.
## In a puddle it splashes.
var _foot_left := false


func _footsteps(ground_speed: float) -> void:
	var sneak := _current_anim == SNEAK_ANIM
	var walk := _current_anim == WALK_ANIM
	var jog := _current_anim == JOG_ANIM
	if not (sneak or walk or jog or _current_anim == "Running_A") or not is_on_floor() or ground_speed < 0.3:
		_last_phase = -1.0
		return
	var phase := _anim.current_animation_position / _anim.current_animation_length
	if _last_phase >= 0.0:
		for landing: float in (SNEAK_LANDINGS if sneak else (WALK_LANDINGS if walk else (JOG_LANDINGS if jog else FOOT_LANDINGS))):
			var crossed: bool = _last_phase < landing and phase >= landing
			if phase < _last_phase:
				crossed = _last_phase < landing or phase >= landing
			if crossed:
				# In a puddle every step splashes: rain puddles above ground
				# (see Puddles), drip puddles below (see DungeonLife).
				if level.in_puddle(global_position):
					# A nearly dried-out puddle gives a soft squelch, not a splash.
					var fill: float = level.puddle_fill(global_position)
					Sfx.play(self, Puddles.splash_sound(fill), (-21.0 if sneak else (-15.0 if walk else -8.0)) + Puddles.splash_volume(fill))
					level.splash_puddle(global_position, not sneak)
					_wet_steps = Puddles.PRINTS
				else:
					if _wet_steps > 0:
						_wet_steps -= 1
						level.wet_print(global_position, _model.rotation.y)
					# In snow every step leaves a grey print, the left and the right foot a little apart.
					_foot_left = not _foot_left
					var heading := _model.rotation.y
					var apart := Vector3(cos(heading), 0, -sin(heading)) * (0.09 if _foot_left else -0.09)
					level.snow_print(global_position + apart, heading, 1.0, "hero")
					# Every ground has its own steps (see Surfaces.STEPS). Sneaking
					# is only a very soft touch, barely to be heard: a brush of
					# cloth on hard floors, a hushed step on anything softer.
					var ground := Surfaces.step_ground(level, global_position)
					# The stairs built into a house are hollow wooden boards: they boom and
					# creak, a little differently up than down (see StairSteps).
					var stairs := StairSteps.on_stairs(level.house_floors, global_position, velocity)
					if stairs != 0:
						var stair_db := -26.0 if sneak else (-17.0 if walk else -14.0)
						Sfx.play(self, StairSteps.sound(stairs > 0), stair_db + StairSteps.LIFT_DB)
					elif sneak and Surfaces.hard(ground):
						Sfx.play(self, "sneak_%d" % (randi() % 4), -22.0)
					else:
						var step_db := -26.0 if sneak else (-17.0 if walk else -14.0)
						# In a village the hero's steps are lifted so they stand out
						# from the townsfolk and the ambience (see VILLAGE_STEP_BOOST_DB).
						if level is Outdoor and level._in_village(level.world_to_cell(global_position)):
							step_db += VILLAGE_STEP_BOOST_DB
						Sfx.play(self, Surfaces.step_sound(ground), step_db)
	_last_phase = phase


## The living enemies the blade can reach right now: close by, and in front
## of the hero unless they stand right next to them. Nearest first.
func enemies_in_reach() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for e in level.enemies:
		if not is_instance_valid(e) or e.dead or e.is_friend() or level.stacked(self, e):
			continue
		# No blow lands through a closed door, either way (see Level.door_between), nor through
		# the ground between the forgotten mine and the world above (see LostMine.apart).
		if level.door_between(global_position, e.global_position) or LostMine.apart(global_position, e.global_position):
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
	if not stand_up():
		return # Still sitting down.
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
	# Monster knowledge: a single strike rolls for a vital point as it starts,
	# so a hit that will find one looks different from the first frame.
	var vital_target: Enemy = null
	if not splash and target and not target.open_to_backstab(global_position) and finds_vital(target):
		vital_target = target
	# A blade swishes, an axe (or a mace or hammer) whooms (see Sfx.play_weapon).
	var arms := Sfx.weapon_family(weapon_skill())
	if splash:
		play_once(SPLASH_ANIM, 0.55)
		Sfx.play_weapon(self, arms, "sweep")
	elif vital_target:
		_attack_cooldown = VITAL_HIT + 0.35
		play_once(VITAL_ANIM, VITAL_HIT + 0.35)
		_anim.speed_scale = VITAL_ANIM_SPEED
		_leap_strike(arms)
	else:
		play_once(STRIKE_ANIM, 0.45)
		Sfx.play_weapon(self, arms, "swing")
	await get_tree().create_timer(VITAL_HIT if vital_target else 0.25 if splash else 0.18).timeout
	if vital_target and _current_anim == VITAL_ANIM:
		_anim.speed_scale = 1.0
	var weapon := weapon_skill()
	# One roll for a heavy hit per swing; a sweep shares it out.
	var heavy := heavy_hit(weapon)
	var full := power + heavy
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
	# A blade or an axe cuts and may leave a bleeding wound; a mace or a
	# hammer does not (see Bleeding).
	var cuts := Bleeding.weapon_cuts(equipped.get("waffe", ""))
	# The weapon's impact speaks for the blow (see blow_sound), so the comic
	# words of these hits only add a quiet echo of it.
	if not victims.is_empty():
		Comic.under_weapon()
	var blow := ""
	var blow_at := global_position
	for e in victims:
		var this_blow := "hit"
		if e.open_to_backstab(global_position):
			# A sneak attack never rolls: it lands SNEAK_ATTACK_FACTOR times
			# the hardest blow the hero can deal.
			this_blow = "sneak"
			var had: int = e.hp
			e.take_hit(sneak_attack_damage(), global_position, "backstab")
			wound_foe(e, had - e.hp, cuts)
			_touch_slime(e)
			train("schleichen", 4.0)
		else:
			# Monster knowledge: a blow may find a vital point (see MonsterLore).
			var vital := e == vital_target if not splash and e == target else finds_vital(e)
			if vital:
				this_blow = "vital"
			elif heavy > 0:
				this_blow = "heavy"
			var had: int = e.hp
			e.take_hit(vital_damage(power, weapon) if vital else damage, global_position)
			if vital:
				vital_struck(e, "")
			_touch_slime(e)
			wound_foe(e, had - e.hp, cuts, vital)
		if blow == "" or BLOWS.find(this_blow) > BLOWS.find(blow):
			blow = this_blow
			blow_at = e.global_position
			if not e.dead and randf() < shock_chance():
				e.shock()
		hits += 1
		mark_fight()
		# Every blow that lands trains the hand and the arm; a kill a little more.
		if not e.no_reward:
			train(weapon, 1.0)
			train("staerke", 3.0 if e.dead else 1.0)
		if e.dead and e.kind == "magier" and not e.no_reward:
			train("intelligenz", 4.0)
	if blow != "":
		Sfx.play_weapon(self, arms, blow, blow_at)
	if hits == 0 and target:
		Comic.pop(global_position + facing() * 1.5, "miss")


## The kinds of blow a melee swing can land, from the least to the most
## telling. A sweep that lands several kinds at once sounds only the most
## telling one, so a crowd fight stays a clear sound per swing.
const BLOWS := ["glance", "hit", "heavy", "vital", "sneak"]


## The chance that a blow of the held weapon cracks with lightning and stuns
## (a thunder weapon, see Items "shock" and Enemy.shock), else 0.
func shock_chance() -> float:
	return float(Items.ALL.get(equipped.get("waffe", ""), {}).get("shock", 0.0))


## Whether a blow (or a knife) at `e` finds a vital point: a roll on the
## hero's knowledge of its kind (see MonsterLore). Armour that only a stab in
## the back gets through hides every vital point.
func finds_vital(e: Enemy) -> bool:
	if e == null or e.dead or e.is_armored():
		return false
	return MonsterLore.roll_vital(e.kind)


## What a vital hit deals: MonsterLore.VITAL_FACTOR times the hardest blow of
## `base` (power for the blade, throw_power for a knife), that is with the
## heavy hit of `skill_id` whenever the skill can roll one at all (for the
## blade, the same as max_hit). No roll.
func vital_damage(base: int, skill_id: String) -> int:
	return MonsterLore.VITAL_FACTOR * (base + (1 if skill_chance(skill_id) > 0 else 0))


## The leap of a vital strike: the hero's figure springs up and forward at
## the foe while the weapon goes up, comes down with the chop as the blade
## lands, and steps back to the hero's place. Only the figure moves, not the
## body, so the hero's place on the map stays where it was. `arms` is the
## weapon family, whose swing sounds as the blade comes down. A weapon that
## cannot be found (nothing in hand) just skips the circle.
func _leap_strike(arms: String) -> void:
	var ahead := facing()
	var top := ahead * VITAL_LEAP_AHEAD * 0.6 + Vector3.UP * VITAL_LEAP_UP
	var landing := ahead * VITAL_LEAP_AHEAD
	VitalStrike.takeoff(level, global_position)
	# The weapon swings down and round in a full circle as the hero rises, with
	# a streak of light, and is overhead again as the chop begins (VitalCircle).
	VitalCircle.start(self, level, ahead)
	var tween := create_tween()
	tween.tween_property(_model, "position", top, VITAL_TOP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): Sfx.play_weapon(self, arms, "swing"))
	tween.tween_property(_model, "position", landing, VITAL_HIT - VITAL_TOP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_model, "position", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## After a vital hit landed on `e`: a burst at the point struck, the word over
## its head, and maybe a crippled attack (see MonsterLore; the bleeding
## wound is rolled in wound_foe). `sound` is the knife's impact; a melee blow passes "" and
## sounds its weapon instead.
func vital_struck(e: Enemy, sound := "hit") -> void:
	if sound != "":
		Sfx.play(self, sound, 2.0, e.global_position, 1.3)
	e.vital_burst()
	if sound == "":
		# A leap strike (see _leap_strike): the full show of the landing.
		VitalStrike.impact(level, self, e)
		Comic.pop(e.global_position, "vital")
	if e.dead:
		Effects.head_text(level, e, 2.7, Lang.t("Schwachstelle!"), MonsterLore.VITAL_COLOR)
		return
	e.vital_mark()
	if randf() < MonsterLore.SLOW_CHANCE:
		e.cripple()


## After a blow or a knife cost `e` `lost` life: a cutting hit opens a wound
## with Bleeding.CHANCE, a vital hit with MonsterLore.BLEED_CHANCE whatever
## the weapon (or the higher of the two). The wound bleeds as much life as
## the hit cost (see Bleeding, Enemy.bleed). Returns whether it bleeds.
func wound_foe(e: Enemy, lost: int, cutting: bool, vital := false) -> bool:
	if lost > 0:
		combat_clock = COMBAT_WINDOW
	if e == null or e.dead:
		return false
	var chance := Bleeding.CHANCE if cutting else 0.0
	if vital:
		chance = maxf(chance, MonsterLore.BLEED_CHANCE)
	if not Bleeding.rolls_wound(lost, chance):
		return false
	e.bleed(lost)
	return true


## What the compendium says about throwing knives: taught when one is picked
## up again, or when the hero reaches for one and has none at all.
const KNIFE_LORE := "Wurfmesser: Ein geworfenes Messer bleibt liegen, wo es landet, und du hebst es auf, wenn du darüberläufst. Bei einem von fünf Würfen zerbricht es allerdings. Griffbereit für den Kampf trägst du 3 Wurfmesser und eines mehr je zwei Stufen Messerwurf; weitere wandern in den Rucksack (10 auf einem Platz). Sobald kein Kampf mehr tobt, steckst du sie von dort nach. Neue verkauft der Händler im Dorf, Räuber tragen oft welche bei sich, und an der Werkbank im eigenen Haus schmiedest du sie aus Eisen."


## How many throwing knives the hero can keep ready for a fight:
## KNIFE_CAP_BASE, and one more per KNIFE_CAP_STEP levels of Messerwurf.
func knife_cap() -> int:
	return KNIFE_CAP_BASE + skill("werfen") / KNIFE_CAP_STEP


## Spare throwing knives in the bag.
func spare_knives() -> int:
	return bag.count(Items.KNIFE)


## Whether one more throwing knife can be taken: into the belt, else the bag.
func can_take_knife() -> bool:
	return knives < knife_cap() or bag_fits(Items.KNIFE)


## Takes `count` throwing knives: into the belt up to knife_cap(), the rest
## into the bag while it has room. Returns how many found no place (the
## caller lays those at the hero's feet).
func add_knives(count: int) -> int:
	var ready := clampi(knife_cap() - knives, 0, count)
	knives += ready
	var left := count - ready
	while left > 0 and bag_fits(Items.KNIFE):
		bag.append(Items.KNIFE)
		left -= 1
	return left


## Fills the belt from the bag up to knife_cap(). Returns whether anything moved.
func _refill_knives() -> bool:
	var moved := false
	while knives < knife_cap() and bag.has(Items.KNIFE):
		bag.erase(Items.KNIFE)
		knives += 1
		moved = true
	return moved


## Out of a fight, the belt is filled from the bag up to knife_cap(), and
## knives over it (the skill dropped, an old save) go back into the bag
## while it has room. In a fight only what is ready can be thrown.
## Returns whether anything moved.
func _settle_knives() -> bool:
	if fight_cooldown > 0.0 or dead:
		return false
	var cap := knife_cap()
	var moved := _refill_knives()
	while knives > cap and bag_fits(Items.KNIFE):
		bag.append(Items.KNIFE)
		knives -= 1
		moved = true
	return moved


## Throws a knife at `aim` (a world position), or at the closest enemy in sight.
## On the move the hero throws without stopping.
func throw_knife(aim = null, on_the_move := false) -> void:
	if not stand_up():
		return # Still sitting down.
	if not can_act() or _attack_cooldown > 0.0:
		return
	if knives <= 0:
		# With spares in the bag the belt is refilled on the spot, which costs
		# the time of two throws; with none at all, the compendium says where
		# to get more.
		var why := Lang.t("Keine Wurfmesser")
		if spare_knives() > 0:
			why = Lang.t("Wurfmesser werden nachgesteckt")
			_refill_knives()
			_attack_cooldown = KNIFE_REFILL_ATTACKS * THROW_COOLDOWN
		else:
			Events.teach(KNIFE_LORE)
		Effects.float_text(level, global_position + Vector3(0, 3.2, 0), why, Color(1, 1, 1, 0.8))
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
	_attack_cooldown = THROW_COOLDOWN
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
		_target_chosen = false
	_target = enemy


## Sent after an enemy with a click: the hero walks up to it and, once it
## is in reach, keeps striking it (see _pursue and _auto_attack).
func charge(enemy: Enemy) -> void:
	stand_up()
	if enemy == null or enemy.dead or enemy.is_friend() or dead:
		return
	_engage(enemy)
	_target_chosen = true
	_hunt = enemy
	_hunt_repath = 0.0
	# A foe that has not noticed the hero is circled to its back first, so the
	# opening blow is a sneak attack (see Enemy.open_to_backstab). The circling
	# is timed, so a foe that keeps turning cannot lead the hero round forever.
	_sneak_hunt = enemy.is_unaware()
	_chase_left = CHASE_TIME if _sneak_hunt else 0.0


## Gives up a hunt, when the hero is sent somewhere else.
func stop_hunt() -> void:
	_hunt = null
	_sneak_hunt = false


## Keeps the hunt's path on the enemy while it moves, and ends it in reach.
func _pursue(delta: float) -> void:
	if _hunt == null:
		return
	if not is_instance_valid(_hunt) or _hunt.dead or _target != _hunt:
		_hunt = null
		_sneak_hunt = false
		return
	if not can_act():
		return # Mid-swing or getting up: the hunt goes on afterwards.
	# The foe noticed the hero: the sneak is off, and the hunt goes on as a plain one.
	if _sneak_hunt and not _hunt.is_unaware():
		_sneak_hunt = false
		_chase_left = 0.0
	var to := _hunt.global_position - global_position
	to.y = 0.0
	if to.length() <= ENGAGE_RANGE and not (_sneak_hunt and not _hunt.open_to_backstab(global_position)):
		path.clear()
		_hunt = null
		_sneak_hunt = false
		return
	if _chase_left > 0.0:
		_chase_left -= delta
		if _chase_left <= 0.0 or to.length() > CHASE_LEASH:
			_give_up_chase()
			return
	_hunt_repath -= delta
	if _hunt_repath <= 0.0:
		_hunt_repath = HUNT_REPATH
		if _sneak_hunt:
			_walk_behind(_hunt)
		else:
			walk_to(_hunt.global_position, HUNT_STOP)


## Walks to the spot behind `foe`; where that cannot be reached (a wall there),
## straight at the foe instead.
func _walk_behind(foe: Enemy) -> void:
	walk_to(foe.global_position - foe.ahead() * SNEAK_BEHIND)
	if path.is_empty():
		walk_to(foe.global_position, HUNT_STOP)


## Attacked without a command, the hero fights back on their own: the
## attacker becomes the target, and _auto_attack strikes it up close or throws
## knives at it from afar. An enemy the hero is already fighting is kept.
func defend_against(attacker: Node) -> void:
	var enemy := attacker as Enemy
	if enemy == null or enemy.dead or dead:
		return
	if _target == null or not is_instance_valid(_target) or _target.dead:
		_engage(enemy)
	if _target == enemy and _should_chase(enemy):
		_hunt = enemy
		_hunt_repath = 0.0
		_chase_left = CHASE_TIME


## Whether a blow or a shot from `enemy` sends the hero after it: only when the
## hero is idle (no step, no errand, no hunt), cannot strike or throw at it from
## here, and it is near enough and was not just given up on.
func _should_chase(enemy: Enemy) -> bool:
	if not controllable or frozen or is_afraid() or _hunt != null or not path.is_empty():
		return false
	if _keyboard_direction() != Vector3.ZERO or steer != Vector3.ZERO:
		return false
	if _chase_rest > 0.0 and is_instance_valid(_chase_quit) and enemy == _chase_quit:
		return false
	var d := global_position.distance_to(enemy.global_position)
	if d <= ENGAGE_RANGE or d > CHASE_LEASH:
		return false
	return not _can_throw_at(enemy, d)


## Whether _auto_attack would answer `enemy`, `d` metres away, with a knife.
func _can_throw_at(enemy: Enemy, d: float) -> bool:
	return d <= AUTO_THROW_RANGE and (knives > 0 or spare_knives() > 0) and level.has_clear_shot(global_position, enemy.global_position)


## Ends the hero's own chase without reaching the foe: they stop where they are.
func _give_up_chase() -> void:
	_chase_quit = _hunt
	_chase_rest = CHASE_REST
	_chase_left = 0.0
	_hunt = null
	_sneak_hunt = false
	path.clear()


## A blow on a slime may leave the hero slimed (see SlimeCoat).
func _touch_slime(e: Enemy) -> void:
	if SlimeCoat.sticks(e):
		get_slimed(e.slime_colour())


## Keeps fighting the current target: blade while next to it, knives from afar.
func _auto_attack() -> void:
	if _target == null:
		return
	if not is_instance_valid(_target) or _target.dead or _target.is_friend():
		_target = null
		return
	if not can_act() or _auto_cooldown > 0.0 or _attack_cooldown > 0.0 or level.stacked(self, _target):
		return
	if sneaking and not _target_chosen:
		return # Sneaking stays quiet: only a foe the player picked is struck.
	if _sneak_hunt:
		return # Still going round to the foe's back: no blow until there.
	var d := global_position.distance_to(_target.global_position)
	if d <= ENGAGE_RANGE:
		_auto_cooldown = AUTO_MELEE_INTERVAL
		melee()
	elif _hunt == null and _can_throw_at(_target, d):
		_auto_cooldown = AUTO_THROW_INTERVAL
		throw_knife(_target.global_position, true)


# --- Training -----------------------------------------------------------------

const BLOCK_PER_LEVEL := 0.02
const ARMOR_LIGHTER_PER_LEVEL := 0.06
const SNEAK_PER_LEVEL := 0.008


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
	var lessons := Monastery.dodge_bonus(self)
	return clampf(DODGE_PER_DEXTERITY * dexterity_points() + lessons, 0.0, DODGE_MAX + lessons)


## The hero's odds against a foe's blows and hide, as the fight rolls them,
## with the gear and attributes of now. `foe` has "hp", "damage" and "armor"
## (see Enemy.reference_foe). A blow in reach always lands: there is no roll to
## hit, only one for a heavy hit (+1 damage) on the weapon's skill. A foe's
## blow is first blocked by the shield (block_chance), else maybe dodged
## (dodge_chance). Chances are 0..1.
func odds_against(foe: Dictionary) -> Dictionary:
	var weapon := weapon_skill()
	var block := clampf(block_chance, 0.0, 1.0)
	var dodge := dodge_chance()
	var blow := soak(power, int(foe.armor))
	return {
		"hit": 1.0,
		"heavy": clampf(skill_chance(weapon) / 100.0, 0.0, 1.0),
		"weapon": weapon,
		"block": block,
		"dodge": dodge,
		"unharmed": block + (1.0 - block) * dodge,
		"blow": blow,
		"blows": ceili(float(foe.hp) / maxi(1, blow)),
		"taken": soak(int(foe.damage), hardening),
	}


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
## Level points, the Konstitution of levels and the Geschick of a worn armour
## set (see ArmourSets) come on top of training, up to the attribute's
## highest value.
func attribute(id: String) -> int:
	var value := Training.attribute_value(id, xp.get(id, 0.0))
	var bonus: int = int(level_points.get(id, 0)) + int(gift_spent.get(id, 0)) - Injury.attribute_drop(self, id)
	if id == "konstitution":
		bonus += HeroLevel.constitution_bonus(hero_level()) + gift_constitution
	elif id == "geschick":
		bonus += ArmourSets.dexterity(equipped)
	if bonus == 0:
		return value
	return maxi(1, mini(value + bonus * Training.ATTRIBUTES[id].step, Training.ATTRIBUTES[id].max))


## The hero's level, from the experience earned (see HeroLevel).
func hero_level() -> int:
	return HeroLevel.level_for(hero_xp)


## Level points and shrine points not yet put into an attribute.
func free_points() -> int:
	return _free_level_points() + _free_gift_points()


func _free_level_points() -> int:
	var spent := 0
	for id in level_points:
		spent += int(level_points[id])
	return maxi(0, HeroLevel.points_earned(hero_level()) - spent)


func _free_gift_points() -> int:
	var spent := 0
	for id in gift_spent:
		spent += int(gift_spent[id])
	return maxi(0, gift_points - spent)


## Puts a free point into Stärke, Geschick or Intelligenz: a shrine's point
## first (it lasts this run), then a level point (it stays with the hero).
func spend_point(id: String) -> bool:
	if free_points() <= 0 or not id in HeroLevel.POINT_ATTRIBUTES:
		return false
	if _free_gift_points() > 0:
		gift_spent[id] = int(gift_spent.get(id, 0)) + 1
	else:
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
	return {"xp": hero_xp, "points": level_points.duplicate(), "sleep": sleep_state.duplicate(true)}


func set_level_data(data: Dictionary) -> void:
	sleep_state = SleepRoll.checked(data.get("sleep", {}))
	hero_xp = int(data.get("xp", 0))
	level_points = {}
	var points = data.get("points", {})
	if points is Dictionary:
		for id in points:
			if id in HeroLevel.POINT_ATTRIBUTES:
				level_points[id] = int(points[id])


## What the nights have given the hero so far (see SleepRoll): practice makes
## a skill ripe, a night turns it into a level.
var sleep_state := SleepRoll.empty()


## The level the hero has won in a skill: what training gave, held back until
## a night has made the next level real (see SleepRoll).
func trained_level(id: String) -> int:
	return SleepRoll.earned(sleep_state, id, xp)


## A skill's level: what was trained plus what worn items add. 0 while the
## gear it needs is not worn.
func skill(id: String) -> int:
	if not skill_enabled(id):
		return 0
	var level_now := trained_level(id)
	for slot in equipped:
		level_now += int(Items.ALL[equipped[slot]].get("skills", {}).get(id, 0))
	level_now += int(companion_perks.get("skills", {}).get(id, 0))
	if id == "klettern":
		level_now += Climbing.set_bonus(equipped) + Monastery.climb_bonus(self)
	return maxi(0, level_now - Injury.skill_drop(self))


## Whether the worn gear lets the hero use (and train) a skill.
func skill_enabled(id: String) -> bool:
	if not can_use(Training.SKILLS[id].get("requires", {})):
		return false
	# An advanced skill builds on basic skills.
	var needs: Dictionary = Training.SKILLS[id].get("needs", {})
	for basic in needs:
		if trained_level(basic) < int(needs[basic]):
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


## A sneak attack (a stab in the back of a foe that has not noticed the
## hero) deals this many times the hero's maximum hit.
const SNEAK_ATTACK_FACTOR := 3


## The hardest single blow the hero can deal right now: the power, plus the
## heavy hit when the weapon's skill can roll one at all.
func max_hit() -> int:
	return power + (1 if skill_chance(weapon_skill()) > 0 else 0)


## What a sneak attack deals: SNEAK_ATTACK_FACTOR times max_hit, no roll.
func sneak_attack_damage() -> int:
	return SNEAK_ATTACK_FACTOR * max_hit()


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
	# A skill's new level waits for the night: practice only makes it ripe.
	if Training.is_skill(id):
		SleepRoll.practise(sleep_state, id, xp)
		xp[id] = old_xp + amount
		return
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
	gift_points = 0
	gift_spent = {}
	gift_constitution = 0
	beginner_shrines_used = 0
	gift_armor = 0
	blessing_god = ""
	blessing_thirds = 0
	blessed_before = false
	injury = ""
	injury_severity = ""
	injury_rest = 0
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
	armour_value = 0
	block_chance = 0.0
	for slot in equipped:
		# A broken arm cannot hold a shield: it does nothing while it is worn.
		if slot == "schild" and Injury.cannot_use_shield(self):
			continue
		var item: Dictionary = Items.ALL[equipped[slot]]
		hp_bonus += item.get("hp", 0)
		power_bonus += item.get("power", 0)
		speed_bonus += item.get("speed", 0.0)
		hardening += item.get("armor", 0)
		armour_value += int(item.get("armour_value", 0))
		block_chance += item.get("block", 0.0)
	hardening += ArmourSets.hardening(equipped)
	# The god's boon and burden, at the strength left (see Blessing).
	hp_bonus += int(Blessing.amount(blessing_god, blessing_thirds, "hp"))
	power_bonus += int(Blessing.amount(blessing_god, blessing_thirds, "power"))
	speed_bonus += Blessing.amount(blessing_god, blessing_thirds, "speed")
	hardening += int(Blessing.amount(blessing_god, blessing_thirds, "hardening"))
	block_chance += Blessing.amount(blessing_god, blessing_thirds, "block")
	# An injury from a rescue (see Injury).
	hp_bonus -= Injury.life_lost(self)
	speed_bonus -= Injury.speed_lost(self)
	armour_value = mini(armour_value, ARMOUR_VALUE_MAX)
	if equipped.has("schild") and not Injury.cannot_use_shield(self):
		block_chance += BLOCK_PER_LEVEL * skill("blocken")
	var hero := hero_level()
	hp_bonus += HeroLevel.life_bonus(hero)
	speed_bonus += HeroLevel.speed_bonus(hero)
	max_hp = maxi(1, MAX_HP + hp_bonus + attribute("konstitution") - Training.ATTRIBUTES.konstitution.start)
	power = 1 + power_bonus + attribute("staerke") - Training.ATTRIBUTES.staerke.start
	base_speed_wanted = (1.0 + speed_bonus) * attribute("tempo") / 100.0
	base_speed_capped = base_speed_wanted > BASE_SPEED_CAP + 0.0001
	base_speed = SPEED * minf(base_speed_wanted, BASE_SPEED_CAP)
	if ailments.has("fluch"):
		base_speed *= CURSE_SLOW
	if ailments.has("netz"):
		base_speed *= WEB_SLOW
	if ailments.has(SlimeCoat.KIND):
		base_speed *= SlimeCoat.SLOW
	if ailments.has(BloatedBelly.KIND):
		base_speed *= BloatedBelly.SLOW
	# Last, so it stacks on everything above (gear, gifts, ailments).
	if godmode:
		base_speed *= Godmode.SPEED_FACTOR
	hp = mini(hp, max_hp)
	# The tunic is dressed on the plain body; the belly swells over it after.
	BloatedBelly.swell(_model, false)
	_show_held("waffe", "handslot_r", "Knife")
	_show_held("schild", "handslot_l", "")
	_show_headgear()
	_show_tint("umhang", ["Rogue_Cape"])
	_show_tint("ruestung", ["Rogue_Body"])
	_show_tint("schuhe", ["Rogue_LegLeft", "Rogue_LegRight"])
	BloatedBelly.swell(_model, ailments.has(BloatedBelly.KIND))
	_shown_alpha = -1.0 # New parts: fade them too if sneaking.
	# New parts: slimed too, if the hero is (see SlimeCoat).
	if slime_covered() and _model != null:
		SlimeCoat.coat(self, _model, slime_tint)


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
const AILMENT_COLORS := {"blut": Bleeding.COLOR, "gift": Color(0.45, 1.0, 0.35), "fluch": Color(0.75, 0.4, 1.0), "brand": Color(1.0, 0.5, 0.15), "netz": Color(0.93, 0.93, 0.86),
	"angst": Color(0.7, 0.85, 1.0), "schleimig": SlimeCoat.COLOR}
## Burning is short but fierce.
const BURN_TIME := 4.5
const BURN_TICK := 1.5
## A spider's web sticks only briefly, but slows the hero a lot.
const WEB_TIME := 3.0
const WEB_SLOW := 0.55
const AILMENT_WORDS := {"blut": "Blutet!", "gift": "Vergiftet!", "fluch": "Verflucht!", "brand": "Brennt!", "netz": "Eingesponnen!", "angst": "Verängstigt!", "schleimig": "Verschleimt!"}
## Fear (see scare): the hero runs for the nearest way out for FEAR_TIME
## seconds, and cannot be frightened again for FEAR_CALM seconds after.
const FEAR_TIME := 3.0
const FEAR_CALM := 8.0
## Each point of the Erkunden skill counts this many times towards the
## hero's nerve (see nerve).
const NERVE_PER_EXPLORE := 2
## Where a frightened hero runs (see scare), and the seconds before the hero
## can be frightened again.
var _flee: Array[Vector3] = []
var _fear_calm := 0.0


func afflict(kind: String) -> void:
	if dead:
		return
	var fresh := not ailments.has(kind)
	ailments[kind] = BURN_TIME if kind == "brand" else WEB_TIME if kind == "netz" else FEAR_TIME if kind == "angst" \
			else SlimeCoat.TIME if kind == SlimeCoat.KIND else AILMENT_TIME
	if fresh:
		if kind == "gift":
			_poison_tick = POISON_TICK
		elif kind == "brand":
			_burn_tick = BURN_TICK
		Effects.float_text(level, global_position + Vector3(0, 3.0, 0), Lang.t(AILMENT_WORDS[kind]), AILMENT_COLORS[kind])
		_ailments_changed()


## The colour of the slime the hero is coated in (see get_slimed).
var slime_tint := SlimeCoat.COLOR
## Seconds left under a slime's gooey cover after its blow (see goo).
var goo_left := 0.0


## Struck by a slime: under a clear cover of its goo for a few seconds
## (see SlimeCoat). It only shows; it does not slow.
func goo(colour: Color) -> void:
	if dead or _model == null:
		return
	goo_left = SlimeCoat.GOO_TIME
	slime_tint = colour
	SlimeCoat.coat(self, _model, slime_tint)


## Whether slime covers the hero now: slimed, or goo from a slime's blow.
func slime_covered() -> bool:
	return ailments.has(SlimeCoat.KIND) or goo_left > 0.0


## Coated in slime of `colour` (a blow on a slime, or its gob, see
## SlimeCoat): slower on foot and between blows for a few seconds.
func get_slimed(colour: Color) -> void:
	if dead:
		return
	var recoat := ailments.has(SlimeCoat.KIND) and colour != slime_tint
	slime_tint = colour
	afflict(SlimeCoat.KIND)
	Events.teach(SlimeCoat.LEARN)
	if recoat:
		refresh_stats()


## A cutting hit opened a wound (see Bleeding): the hero bleeds `amount`
## more life, 1 a second, twice as fast while moving, never the last one.
## A second wound adds to the first.
func bleed(amount: int) -> void:
	if dead or amount <= 0:
		return
	var fresh := wound.open(amount)
	ailments["blut"] = wound.seconds_left()
	if fresh:
		Effects.float_text(level, global_position + Vector3(0, 3.0, 0), Lang.t(AILMENT_WORDS.blut), AILMENT_COLORS.blut)
		_ailments_changed()
	else:
		ailments_changed.emit()


## Whether the hero moves on purpose (not just pushed back by a blow): a
## bleeding hero then bleeds twice as fast (see Bleeding).
func is_moving() -> bool:
	return (Vector3(velocity.x, 0, velocity.z) - Vector3(_knockback.x, 0, _knockback.z)).length() > Bleeding.MOVING_SPEED


## The hero's nerve against a ghost's fright (see scare): Weisheit, Intuition
## and the Erkunden skill, a well-travelled, wise and wary mind.
func nerve() -> int:
	return attribute("weisheit") + attribute("intuition") + NERVE_PER_EXPLORE * skill("erkunden")


## A ghost tries to frighten the hero (see Enemy.scare_strength). The fright
## (its `strength` and a roll of 1..20) is set against the hero's nerve and a
## roll of 1..20: a hero who stands firm says so and grows a little wiser;
## one who does not runs for the nearest way out for FEAR_TIME seconds, away
## from `from` where there is none (see Level.flee_path). Returns whether
## the hero was frightened. `roll` (two numbers, the ghost's and the hero's)
## is for the tests.
func scare(from: Vector3, strength: int, roll: Array = []) -> bool:
	if dead or level == null or ailments.has("angst") or _fear_calm > 0.0:
		return false
	var ghost: int = roll[0] if roll.size() == 2 else randi_range(1, 20)
	var hero: int = roll[1] if roll.size() == 2 else randi_range(1, 20)
	if strength + ghost <= nerve() + hero:
		Effects.head_text(level, self, 3.0, Lang.t("Standhaft!"), AILMENT_COLORS.angst)
		train("weisheit", 1.0)
		return false
	_fear_calm = FEAR_CALM
	path.clear()
	_hunt = null
	_target = null
	_flee = level.flee_path(global_position, from)
	afflict("angst")
	return true


## Whether the hero is running in fear (see scare).
func is_afraid() -> bool:
	return ailments.has("angst") and not dead


## Whether nothing can hurt the hero now: the run to the village after the
## crypt (see VillageRun).
## Godmode (the chat command, see Godmode): no harm lands and the pace is tripled.
var godmode := false


## Whether no harm can land: the village run's shield or godmode.
func shielded() -> bool:
	return godmode or protected()


func protected() -> bool:
	return ailments.has(VillageRun.KIND)


## Cures one ailment, or all of them; true if there was anything to cure.
## A belly swollen with water (see BloatedBelly) is no ailment to cure: it
## only goes down with time, so curing all of them leaves it.
func cure(kind := "") -> bool:
	var belly: Variant = ailments.get(BloatedBelly.KIND)
	var shield: Variant = ailments.get(VillageRun.KIND)
	var kept := (0 if belly == null else 1) + (0 if shield == null else 1)
	var had := ailments.has(kind) if kind != "" else ailments.size() > kept
	if kind == "":
		ailments.clear()
		if belly != null:
			ailments[BloatedBelly.KIND] = belly
		if shield != null:
			ailments[VillageRun.KIND] = shield
	else:
		ailments.erase(kind)
	if had:
		_ailments_changed()
	return had


## Too much water: the belly swells and the hero waddles at
## BloatedBelly.SLOW of their speed for BloatedBelly.TIME seconds.
func bloat() -> void:
	if dead:
		return
	ailments[BloatedBelly.KIND] = BloatedBelly.TIME
	_ailments_changed()


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
## Life per second on top of the hero's own recovery, healed steadily: the blessing of the
## household goddess in their own house (see HouseholdGods, set by Game._update_house_blessing).
var bonus_regen := 0.0


## Life per second, averaged over the interval (shown in the HUD and character page).
func life_regen() -> float:
	return attribute("konstitution") / REGEN_PER_CON_DIVISOR / REGEN_INTERVAL + bonus_regen + Monastery.regen_bonus(self)


## Whether a fresh hit is holding the healing back for now.
func regen_paused() -> bool:
	return _regen_pause > 0.0


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
	_regen += (bonus_regen + Monastery.regen_bonus(self)) * delta
	_regen_clock += delta
	if _regen_clock >= REGEN_INTERVAL:
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
		if kind == "blut":
			continue # Lasts as long as the wound bleeds (below).
		ailments[kind] -= delta
		if ailments[kind] <= 0.0:
			ailments.erase(kind)
			changed = true
	if ailments.has("gift"):
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = POISON_TICK
			if hp > 1 and not shielded():
				hp -= 1
				train("konstitution", 1.0)
				Effects.head_text(level, self, 2.2, "-1", AILMENT_COLORS.gift)
				hurt.emit(1)
	# Bleeding: the ailment lasts as long as the wound has life to bleed.
	if ailments.has("blut"):
		var moving := is_moving()
		if wound.drips(delta, moving):
			var way := Vector3(velocity.x, 0, velocity.z) if moving else Vector3.ZERO
			BloodDrops.drip(level, global_position, 1.0, way)
		var lost := wound.run(delta, moving)
		if lost > 0:
			var taken := 0 if shielded() else mini(lost, hp - 1)
			if taken > 0:
				hp -= taken
				train("konstitution", taken)
				Effects.head_text(level, self, 2.2, "-%d" % taken, AILMENT_COLORS.blut)
				hurt.emit(taken)
		if wound.active():
			ailments["blut"] = maxf(wound.seconds_left(), 0.01)
		else:
			ailments.erase("blut")
			changed = true
	elif wound.active():
		# Cured (a fountain, a shrine, a potion): the wound closes.
		wound.stop()
	if ailments.has("brand"):
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = BURN_TICK
			if hp > 1 and not shielded():
				hp -= 1
				train("konstitution", 1.0)
				Effects.head_text(level, self, 2.2, "-1", AILMENT_COLORS.brand)
				hurt.emit(1)
	if changed:
		_ailments_changed()


## A burn from the floor (see EmberCracks): `amount` lives lost, no knock-back,
## armour or grace. The caller keeps the last life.
func scorched(amount: int, colour: Color) -> void:
	if shielded():
		return
	hp = maxi(hp - amount, 1)
	_regen_pause = REGEN_PAUSE_AFTER_HIT
	train("konstitution", amount)
	Effects.head_text(level, self, 2.2, "-%d" % amount, colour)
	hurt.emit(amount)


## Updates strength and speed, and shows a coloured haze while ailing.
func _ailments_changed() -> void:
	refresh_stats()
	var old := get_node_or_null("AilmentHaze")
	if old:
		old.free()
	if not ailments.has("blut"):
		wound.stop()
	if not slime_covered() and get_node_or_null(SlimeCoat.NODE) != null:
		SlimeCoat.wipe(self, _model)
	for kind in ["angst", "netz", "brand", "blut", "gift", "fluch"]:
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
	# A hat with no model file is built from parts (see ClimbHelmet).
	if str(item.hat[0]) == "":
		slot.add_child(ClimbHelmet.build())
		return
	var source: Node = load(item.hat[0]).instantiate()
	var hat := source.find_child(item.hat[1], true, false).duplicate() as Node3D
	source.free()
	hat.name = "Headgear"
	slot.add_child(hat)
	if item.has("brim"):
		GearLook.narrow_brim(hat, item.brim)
	GearLook.dress(hat, item.get("material", ""), item.get("tint", Color.WHITE), item.get("metal", -1.0))


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
	if Items.is_broken(id, wear.get(id, 0)) or Items.is_book(id) or Items.is_recipe_scroll(id) or Items.is_crate(id) or Items.is_stone(id) or Items.is_material(id) or Items.is_ammo(id) or Items.is_bedroll(id) or Items.is_potion(id) or not can_use(Items.ALL[id].get("requires", {})):
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
	var was := ArmourSets.worn(equipped)
	bag.erase(id)
	if equipped.has(slot):
		bag.append(equipped[slot])
	equipped[slot] = id
	refresh_stats()
	_tell_set_change(was)
	return true


## Takes off a worn item. False when the bag has no room for it (without
## the backpack, when that is what comes off).
func unequip(slot: String) -> bool:
	var room := Items.BAG_SIZE if slot == "rucksack" else bag_size()
	if not equipped.has(slot) or not Items.fits(bag, room, equipped[slot]):
		return false
	var was := ArmourSets.worn(equipped)
	bag.append(equipped[slot])
	equipped.erase(slot)
	refresh_stats()
	_tell_set_change(was)
	return true


## Says so when putting something on or off made or broke an armour set.
func _tell_set_change(was: String) -> void:
	var news := ArmourSets.change_news(was, ArmourSets.worn(equipped))
	if news != "":
		Events.tell(news, Color(0.55, 0.75, 1.0))


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
		# Worn through: it comes off and stays in the bag, destroyed, to be melted down
		# (see Forge.melt). With no room in the bag it falls apart for good.
		if unequip(slot):
			Events.tell(Lang.t("%s ist zerstört: nur noch einzuschmelzen.") % Items.item_name(id), Color(0.75, 0.8, 0.9))
		else:
			wear.erase(id)
			equipped.erase(slot)
			refresh_stats()
		Effects.float_text(level, global_position + Vector3(0, 3.2, 0), Lang.t("%s zerbricht!") % Items.item_name(id), Color(0.75, 0.8, 0.9))
		Sfx.play(self, "bones")


## A shove with no harm: a goat's bump (see FarmAnimal). The hero stumbles back a
## few steps and loses no life; one lying down is left alone.
func shove(from: Vector3, force := 9.0) -> void:
	if dead or _down > 0.0 or frozen:
		return
	stand_up(true)
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * force
	path.clear()
	play_once("Hit_A", 0.35)


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


## What is left of a hit of `amount` after armour that takes `percent` of
## it off (the Rüstungswert, after the hardening). Hits are small whole
## numbers, so the share left over is rounded up with a chance equal to its
## fraction (`roll` in 0..1): on average exactly `percent` is taken off, and
## now and then a light hit is caught whole.
static func armour_cut(amount: int, percent: int, roll: float) -> int:
	if amount <= 0 or percent <= 0:
		return maxi(0, amount)
	var left := amount * (1.0 - clampi(percent, 0, 100) / 100.0)
	var whole := floori(left)
	if roll < left - whole:
		whole += 1
	return whole


## Seconds the hero cannot be hurt again after a hit. Short enough that a
## crowd of enemies is a real danger.
const HURT_GRACE := 0.6
## What the thorn rune deals back to a melee attacker; their hardening
## takes it off in full.
const THORNS_DAMAGE := 1


## Blows and shots can be blocked with a shield; spikes from below (blockable
## false) cannot.
func take_damage(amount: int, from: Vector3, attacker: Node = null, blockable := true) -> void:
	if dead or _invulnerable > 0.0 or _down > 0.0 or frozen or shielded():
		return
	# A blow or a trap never finds the hero sitting idly.
	stand_up(true)
	if _jump_windup > 0.0:
		_jump_windup = 0.0
		_anim_hold = 0.0
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
	amount = armour_cut(soak(amount, hardening), armour_value, randf())
	train("ruestung", 1.0)
	_wear_armor()
	if amount <= 0:
		# The armour caught the whole hit.
		_invulnerable = HURT_GRACE
		Effects.float_text(level, global_position + Vector3(0, 2.2, 0), Lang.t("Abgefangen!"), Color(0.72, 0.8, 0.95))
		return
	# Every life lost hardens the body a little.
	train("konstitution", amount)
	hp -= amount
	combat_clock = COMBAT_WINDOW
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
		felled_by = attacker
		play_once("Death_A", 99.0)
		# A fallen hero's eyes are crossed out in black, until they rise.
		DeadEyes.put_on(_model)
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
	return _climb >= 0.0 or _pit_climb or _rock != null or _ladder_t >= 0.0


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
		_climb_time = CLIMB_TIME
		_climb = 0.0
		_air_momentum = Vector3.ZERO
		velocity = Vector3.ZERO
		face(target - global_position)
		_current_anim = ""
		play("Jump_Idle", 0.1)
		train("geschick", 0.5)
		return true
	return false


## True when the hero stands in a dug pit deep enough that a jump cannot clear it.
func in_pit() -> bool:
	return global_position.y <= -PIT_DEPTH and is_on_floor()


## Whether something solid hangs over the hero's head up to the ground (a cellar
## ceiling, see HouseSketch.COVER): no climbing out through it.
func _under_ceiling() -> bool:
	var from := global_position + Vector3(0, 1.0, 0)
	if from.y >= 0.0:
		return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(from.x, 0.3, from.z), 0xFFFFFFFF, [get_rid()]))
	return not hit.is_empty()


## The Klettern level the hero climbs with: nobody has less than Climbing.MIN_LEVEL.
func climbing_level() -> int:
	return maxi(Climbing.MIN_LEVEL, skill("klettern"))


## How long (seconds) the wall contact of a push out of a pit may drop out without ending the push.
const PIT_GAP := 0.12
var _pit_gap := 0.0


## Scrambles out of a pit with no stairs: pushing against its wall for a moment
## pulls the hero up onto the ground beyond (a slow climb, so stairs stay the
## quick way). Returns true when the climb starts.
func _try_climb_out(dir: Vector3, delta: float) -> bool:
	if not in_pit():
		_pit_push = 0.0
		_pit_slips = 0
		return false
	var push := dir.normalized()
	var wall := false
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().y) < 0.5 and push.dot(-hit.get_normal()) > 0.5 and not hit.get_collider() is Enemy:
			wall = true
			break
	if dir != Vector3.ZERO and not wall and _pit_push > 0.0 and _pit_gap < PIT_GAP and not _under_ceiling():
		# Pressed against the wall the contact drops out for a physics tick now and then: the hold rides
		# over such a gap (as on a rock face) instead of starting again from nothing.
		_pit_gap += delta
		return false
	_pit_gap = 0.0
	if dir == Vector3.ZERO or not wall or _under_ceiling():
		_pit_push = 0.0
		return false
	if not _pit_hinted:
		_pit_hinted = true
		Events.tell(Lang.t("Keine Treppe: Halte dich an der Wand, dann kletterst du aus der Grube."), Color(0.8, 0.85, 1.0))
	_pit_push += delta
	if _pit_push < PIT_PUSH_TIME:
		return false
	var target := Vector3(global_position.x, 0.02, global_position.z) + push * (radius + 0.6)
	var ground := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target + Vector3(0, 1.0, 0), target - Vector3(0, 0.3, 0), 0xFFFFFFFF, [get_rid()]))
	if ground.is_empty() or not _room_at(target) or not Climbing.can_climb(-global_position.y, climbing_level()):
		return false
	_pit_push = 0.0
	_start_pit_climb(push, target)
	return true


## The hands of a hero climbing out of a pit: where the pull-up may fail (see
## ClimbPose.U_ROLL) the hero holds on once and falls back the second time.
enum PitStage { CLIMB, CATCH, FALL }
var _pit_climb := false
var _pit_stage := PitStage.CLIMB
var _pit_u := 0.0
var _pit_seconds := 1.0
var _pit_dir := Vector3.ZERO
var _pit_wall := Vector3.ZERO
var _pit_floor := 0.0
var _pit_forward := -0.4
var _pit_rolled := false
var _pit_misses := 0
var _pit_hold := 0.0
var _pit_vy := 0.0
var _pit_height := 0.0
var _pit_at := -0.4
var _pit_pose := {}
var _pit_target := Vector3.ZERO
var _pit_base := {}
## Tests: the roll of the hands (0..1) instead of a random one; a roll above the chance slips.
var pit_roll_forced := -1.0
var _skeleton: Skeleton3D


## Starts the climb out of the pit up to `target` (feet there), pushing along `push`.
func _start_pit_climb(push: Vector3, target: Vector3) -> void:
	if _skeleton == null:
		_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		# No rig to pose: the plain pull-up.
		_climb_from = global_position
		_climb_to = target
		_climb_time = Climbing.seconds(-global_position.y, climbing_level(), speed * WALK_FACTOR)
		_climb = 0.0
		return
	if _pit_base.is_empty():
		_anim.play("Idle")
		_anim.seek(0.0, true)
		_pit_base = ClimbPose.base_of(_skeleton)
	_anim.pause()
	_pit_climb = true
	_pit_stage = PitStage.CLIMB
	_pit_u = 0.0
	_pit_rolled = false
	_pit_misses = 0
	_pit_dir = push
	_pit_wall = global_position + push * radius
	_pit_floor = global_position.y
	_pit_forward = -radius
	_pit_target = target
	_pit_seconds = Climbing.seconds(-global_position.y, climbing_level(), speed * WALK_FACTOR)
	_air_momentum = Vector3.ZERO
	velocity = Vector3.ZERO
	face(push)
	_current_anim = ""
	train("geschick", 0.5)


## One step of the climb out of a pit: the pose and place for this moment of the
## climb (ClimbPose), the roll when the hands take the weight, a catch or a fall.
func _pit_climb_step(delta: float) -> void:
	velocity = Vector3.ZERO
	match _pit_stage:
		PitStage.CLIMB:
			_pit_u = minf(1.0, _pit_u + delta / _pit_seconds)
			if not _pit_rolled and _pit_u >= ClimbPose.U_ROLL:
				_pit_u = ClimbPose.U_ROLL
				_pit_rolled = true
				if (pit_roll_forced if pit_roll_forced >= 0.0 else randf()) >= Climbing.chance(climbing_level(), _pit_slips):
					_pit_slips += 1
					_pit_misses += 1
					train("klettern", Training.CLIMB_PER_METRE * 0.5)
					if _pit_misses >= 2:
						_pit_stage = PitStage.FALL
						_pit_vy = 0.0
						Events.tell(Lang.t("Abgerutscht! Du fällst zurück in die Grube."), Color(0.8, 0.85, 1.0))
					else:
						_pit_stage = PitStage.CATCH
						_pit_hold = 0.8
						Events.tell(Lang.t("Fast abgerutscht! Du hältst dich fest."), Color(0.8, 0.85, 1.0))
			var state := ClimbPose.at(_pit_u, _pit_floor, _pit_forward)
			_pit_pose = state.pose
			_pit_height = state.height
			_pit_at = state.forward
			_pit_place(state.forward, state.height)
			if _pit_u >= 1.0:
				_end_pit_climb(true)
		PitStage.CATCH:
			# The hands slip but hold: the body drops a little and swings, then tries again.
			_pit_hold -= delta
			var state := ClimbPose.at(ClimbPose.U_ROLL, _pit_floor, _pit_forward)
			var wave := sin(clampf(1.0 - _pit_hold / 0.8, 0.0, 1.0) * PI)
			_pit_pose = ClimbPose.mix(state.pose, ClimbPose.POSES["pull"], wave * 0.15)
			_pit_pose["hip_l"] = float(_pit_pose.get("hip_l", 0.0)) + wave * 30.0
			_pit_height = state.height - wave * 0.22
			_pit_at = state.forward
			_pit_place(state.forward, _pit_height)
			if _pit_hold <= 0.0:
				_pit_stage = PitStage.CLIMB
				_pit_rolled = false
		PitStage.FALL:
			_pit_vy -= GRAVITY * delta
			_pit_height += _pit_vy * delta
			var land := _pit_floor
			_pit_pose = ClimbPose.mix(_pit_pose, ClimbPose.POSES["crouch"], clampf(delta * 6.0, 0.0, 1.0))
			if _pit_height <= land:
				_pit_height = land
				_pit_place(_pit_at, land)
				_end_pit_climb(false)
			else:
				_pit_place(_pit_at, _pit_height)
	if _pit_climb and _skeleton != null:
		ClimbPose.apply(_skeleton, _pit_base, _pit_pose)


## Puts the hero `forward` metres past the wall's face at `height` (world y).
func _pit_place(forward: float, height: float) -> void:
	global_position = Vector3(_pit_wall.x + _pit_dir.x * forward, height, _pit_wall.z + _pit_dir.z * forward)


## The climb is over: out on the ground (`out`), or fallen back to the pit floor.
func _end_pit_climb(out: bool) -> void:
	_pit_climb = false
	_pit_stage = PitStage.CLIMB
	if out:
		_pit_slips = 0
		global_position = _pit_target
		train("klettern", Training.CLIMB_PER_METRE * (-_pit_floor))
	else:
		_pit_push = -PIT_PUSH_TIME
	if _skeleton != null:
		ClimbPose.apply(_skeleton, _pit_base, {})
	velocity = Vector3.ZERO
	_current_anim = ""
	play("Idle", 0.15)


# --- Climbing the mountain rock (see ClimbSpots, RockClimb and RopeClimbPose) ----------------

enum RockPhase { PULL, SLIP, REST, HAMMER, THREAD, FALL, ARREST, DESCEND, TOP }
const NAIL := "kletterhaken"
const HAMMER := "kletterhammer"
const ROPE := "kletterseil"
## Seconds of one pull-up at the first Klettern level; each level above takes a little off.
const ROCK_PULL_SECONDS := 2.0
const ROCK_SLIP_SECONDS := 0.6
const ROCK_HAMMER_SECONDS := 2.4
const ROCK_THREAD_SECONDS := 1.6
const ROCK_ARREST_SECONDS := 1.6
## Seconds of one hold going down, and the tests' roll for a fall (see RockClimb.fall_chance).
const ROCK_DESCEND_SECONDS := 1.6
const ROCK_TOP_SECONDS := 1.4
const ROCK_FALL_SPEED := 7.0
var _rock: RockClimb = null
var _rock_phase := RockPhase.PULL
var _rock_spot := {}
var _rock_u := 0.0
var _rock_seconds := 1.0
var _rock_left := true
var _rock_rolled := false
var _rock_result := RockClimb.Result.UP
var _rock_y := 0.0
var _rock_from := 0.0
var _rock_warned := false
## Whether the viper in the face (see SummitGarden.bite) has bitten on this climb.
var _rock_bitten := false
var _rock_push := 0.0
## Pressed hard against a wall, the hero's contact with it can drop out for a physics tick now and then; the hold on
## the rock goes on through such a gap (seconds).
var _rock_wall_grace := 0.0
const ROCK_WALL_GRACE := 0.12
var _rock_start := Vector3.ZERO
var _rock_fall_top := 0.0
var _rock_pose := {}
## Along the face (a traverse, see ROCK_SIDE_*): the sideways offset from where the climb began, the
## offset at the start of this step, which way it goes (-1, 0, 1), where the spot's middle is, and
## the offsets of the nails.
var _rock_dx := 0.0
var _rock_dx_from := 0.0
var _rock_side := 0
var _rock_mid_x := 0.0
var _rock_nail_dx: Array[float] = []
var _rock_hinted := false
const ROCK_SIDE_STEP := 0.8
const ROCK_SIDE_MAX := 1.6
var _rock_rope: Node3D = null
## Tests: the roll of the hands (0..1) instead of a random one; a roll at or above the chance slips.
var rock_roll_forced := -1.0
var rock_fall_forced := -1.0
const ROCK_DIR := Vector3(0, 0, -1)


## Pushing against a rock face: after ClimbSpots.HOLD seconds the hero tries the face. At a spot with
## enough Klettern the climb begins; everywhere else, whatever the reason, the only answer is the same
## message (ClimbSpots.TOO_STEEP), so nobody can tell a spot from plain rock.
func _try_climb_rock(dir: Vector3, delta: float) -> bool:
	if not level is Outdoor or dir == Vector3.ZERO or not is_on_floor() or global_position.y > 0.3 or _under_ceiling():
		_rock_push = 0.0
		return false
	var push := dir.normalized()
	var wall := false
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().y) < 0.5 and push.dot(-hit.get_normal()) > 0.5 and not hit.get_collider() is Enemy and not hit.get_collider() is Crate:
			wall = true
			break
	_rock_wall_grace = ROCK_WALL_GRACE if wall else _rock_wall_grace - delta
	wall = _rock_wall_grace > 0.0
	# Standing right at the rock counts too: a foot of rubble in front of it (see MountainFoot) can take the
	# contact with the wall out of the slide list while the hero is stopped by it.
	if not wall and level.cell_char(level.world_to_cell(global_position + push * (radius + 0.12))) == Mountains.ROCK_LETTER:
		wall = true
	var cell := level.world_to_cell(global_position + push * (radius + 0.4))
	if not wall or level.cell_char(cell) != Mountains.ROCK_LETTER:
		_rock_push = 0.0
		return false
	_rock_push += delta
	if _rock_push < ClimbSpots.HOLD:
		return false
	_rock_push = -ClimbSpots.HOLD
	# A placed climbing wall (see WallPlacements) takes the hero to the wall screen.
	var placed := WallPlacements.at(level.level_name, cell)
	if not placed.is_empty():
		Events.bus().wall_climb_requested.emit(String(placed.wall))
		return false
	var spot := ClimbSpots.at(level, cell)
	if spot.is_empty() or skill("klettern") < maxi(1, int(spot.level)) or not Climbing.can_climb(float(spot.height), skill("klettern")):
		Events.tell(Lang.t(ClimbSpots.TOO_STEEP), Color(0.8, 0.85, 1.0))
		return false
	_start_rock(spot)
	return true


func _rock_has_gear() -> bool:
	return equipped.get("waffe", "") == HAMMER and equipped.get("schild", "") == ROPE and bag.has(NAIL)


func _start_rock(spot: Dictionary) -> void:
	if _skeleton == null:
		_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		return
	if _pit_base.is_empty():
		_anim.play("Idle")
		_anim.seek(0.0, true)
		_pit_base = ClimbPose.base_of(_skeleton)
	_anim.pause()
	_rock = RockClimb.new(float(spot.height), int(spot.level), skill("klettern"))
	_rock_spot = spot
	var mid := level.cell_to_world(spot.cell)
	_rock_start = Vector3(clampf(global_position.x, mid.x - 1.4, mid.x + 1.4), 0.0, mid.z + Level.TILE * 0.5 + radius + 0.05)
	_rock_mid_x = mid.x
	_rock_dx = 0.0
	_rock_nail_dx.clear()
	_rock_y = 0.0
	_rock_warned = false
	_rock_bitten = false
	_rock_left = true
	_air_momentum = Vector3.ZERO
	velocity = Vector3.ZERO
	face(ROCK_DIR)
	_current_anim = ""
	_rock_begin_pull()
	_rock_place(0.0)
	_rock_pose = RopeClimbPose.at("pull_l", 0.0)
	# Both hands are needed for rock, hammer and rope: the weapons are stowed.
	_stow_hands(true)
	if not _rock_hinted:
		_rock_hinted = true
		Events.tell(Lang.t("Halte links oder rechts gedrückt, um dich am Fels entlangzuhangeln."), Color(0.8, 0.85, 1.0))
	_rock_rope = Node3D.new()
	_rock_rope.name = "ClimbRope"
	level.add_child(_rock_rope)
	train("geschick", 0.5)


func _rock_begin_pull() -> void:
	_rock_phase = RockPhase.PULL
	_rock_u = 0.0
	_rock_rolled = false
	_rock_from = _rock_y
	_rock_left = not _rock_left
	_rock_dx_from = _rock_dx
	_rock_side = _rock_wanted_side()
	if _rock_side != 0:
		_rock_left = _rock_side < 0
	_rock_seconds = maxf(1.1, ROCK_PULL_SECONDS - 0.04 * (climbing_level() - 1))


## Left (-1) or right (1) when the hero holds a sideways key on the face and there is room along it; else 0
## and the climb goes up. Only a purely sideways key counts, so up and sideways together still climb.
func _rock_wanted_side() -> int:
	if _rock_y < 0.1 or not controllable:
		return 0
	var dir := _keyboard_direction()
	if absf(dir.x) < 0.9:
		return 0
	var side := 1 if dir.x > 0.0 else -1
	if absf(_rock_start.x + _rock_dx + side * ROCK_SIDE_STEP - _rock_mid_x) > ROCK_SIDE_MAX:
		return 0
	return side


## Puts the hero on the face at height `y`: the face leans back, so the hero moves in with it.
func _rock_place(y: float) -> void:
	_rock_y = y
	if _rock_spot.get("viper", false) and not _rock_bitten and y >= float(_rock_spot.height) * SummitGarden.VIPER_AT:
		_rock_bitten = true
		SummitGarden.bite(self)
	var along := 2.0 * y / maxf(0.5, float(_rock_spot.height))
	global_position = _rock_start + ROCK_DIR * along + Vector3(_rock_dx, y, 0)


## Where the rock's surface is at height `y` (the safe spots are set there).
func _rock_surface(y: float, dx := 0.0) -> Vector3:
	return _rock_start + ROCK_DIR * (2.0 * y / maxf(0.5, float(_rock_spot.height)) + radius) + Vector3(dx, y, 0)


func _rock_step(delta: float) -> void:
	velocity = Vector3.ZERO
	match _rock_phase:
		RockPhase.PULL:
			_rock_u = minf(1.0, _rock_u + delta / _rock_seconds)
			if not _rock_rolled and _rock_u >= RopeClimbPose.PULL_ROLL:
				_rock_rolled = true
				var gear := _rock_has_gear()
				var roll := rock_roll_forced if rock_roll_forced >= 0.0 else randf()
				var fall_roll := rock_fall_forced if rock_fall_forced >= 0.0 else randf()
				_rock_result = _rock.traverse(roll, gear, fall_roll) if _rock_side != 0 else _rock.pull(roll, gear, fall_roll)
				match _rock_result:
					RockClimb.Result.FELL, RockClimb.Result.GAVE_UP:
						train("klettern", Training.CLIMB_PER_METRE * 0.3)
						_rock_fall_top = _rock_y
						_rock_phase = RockPhase.FALL
						_rock_u = 0.0
					RockClimb.Result.SLIP:
						_rock_phase = RockPhase.SLIP
						_rock_u = 0.0
					RockClimb.Result.REST:
						_rock_phase = RockPhase.REST
						_rock_u = 0.0
					_:
						if _rock.streak >= _rock.needed() and not gear and not _rock_warned and _rock_result != RockClimb.Result.TOP:
							_rock_warned = true
							Events.tell(Lang.t("Dir fehlen Hammer, Seil oder ein Kletternagel für einen Sicherungspunkt."), Color(0.8, 0.85, 1.0))
			if _rock_phase == RockPhase.PULL:
				var lift := smoothstep(RopeClimbPose.PULL_ROLL, RopeClimbPose.PULL_LIFTED, _rock_u) if _rock_rolled else 0.0
				if _rock_side != 0:
					_rock_pose = RopeClimbPose.at("side_l" if _rock_side < 0 else "side_r", _rock_u)
					_rock_dx = _rock_dx_from + _rock_side * ROCK_SIDE_STEP * lift
					_rock_place(_rock_from)
				else:
					_rock_pose = RopeClimbPose.at("pull_l" if _rock_left else "pull_r", _rock_u)
					_rock_place(_rock_from + RockClimb.PULL * lift)
				if _rock_u >= 1.0:
					match _rock_result:
						RockClimb.Result.TOP:
							_rock_phase = RockPhase.TOP
							_rock_u = 0.0
						RockClimb.Result.PITON:
							bag.erase(NAIL)
							_rock_phase = RockPhase.HAMMER
							_rock_u = 0.0
						_:
							_rock_begin_pull()
		RockPhase.SLIP:
			# The hands hold on; the next try follows at once.
			_rock_u = minf(1.0, _rock_u + delta / ROCK_SLIP_SECONDS)
			_rock_pose = RopeClimbPose.at("slip", _rock_u)
			if _rock_u >= 1.0:
				_rock_begin_pull()
		RockPhase.REST:
			# Hanging on the hands, getting the breath back.
			_rock_u = minf(1.0, _rock_u + delta / RockClimb.REST_SECONDS)
			_rock_pose = RopeClimbPose.at("rest", _rock_u)
			if _rock_u >= 1.0:
				_rock_begin_pull()
		RockPhase.HAMMER:
			_rock_u = minf(1.0, _rock_u + delta / ROCK_HAMMER_SECONDS)
			_rock_pose = RopeClimbPose.at("hammer", _rock_u)
			if _rock_u >= 1.0:
				_rock.set_nail()
				_rock_nail_dx.append(_rock_dx)
				_rock_phase = RockPhase.THREAD
				_rock_u = 0.0
				_rock_add_nail()
		RockPhase.THREAD:
			_rock_u = minf(1.0, _rock_u + delta / ROCK_THREAD_SECONDS)
			_rock_pose = RopeClimbPose.at("thread", _rock_u)
			if _rock_u >= 1.0:
				Events.tell(Lang.t("Du schlägst einen Kletternagel in den Fels und fädelst das Seil ein: ein Sicherungspunkt."), Color(0.8, 0.85, 1.0))
				train("klettern", Training.CLIMB_PER_METRE * 0.2)
				_rock_begin_pull()
		RockPhase.FALL:
			# The slip, then the drop down to the last safe spot (or the ground).
			_rock_u = minf(1.0, _rock_u + delta / 0.6)
			_rock_pose = RopeClimbPose.at("fall", _rock_u)
			var low := _rock.safe
			if _rock_u >= 0.4:
				_rock_dx = move_toward(_rock_dx, _rock_last_nail_dx(), ROCK_FALL_SPEED * 0.5 * delta)
				_rock_place(maxf(low, _rock_y - ROCK_FALL_SPEED * delta))
			if _rock_y <= low + 0.001:
				var hurt := RockClimb.fall_damage(_rock_fall_top - low)
				# A climbing helmet takes half of the blow.
				if equipped.get("kopf", "") == "kletterhelm":
					hurt = (hurt + 1) / 2
				hurt = mini(hurt, hp - 1)
				if hurt > 0:
					hp -= hurt
				if low <= 0.0:
					Events.tell(Lang.t("Abgerutscht! Du fällst zu Boden."), Color(0.8, 0.85, 1.0))
					_end_rock(false)
				else:
					Events.tell(Lang.t("Abgerutscht! Das Seil fängt dich am Sicherungspunkt auf."), Color(0.8, 0.85, 1.0))
					_rock_phase = RockPhase.ARREST
					_rock_u = 0.0
		RockPhase.ARREST:
			# The rope goes taut and stretches, the feet brace against the wall, the hero settles.
			_rock_u = minf(1.0, _rock_u + delta / ROCK_ARREST_SECONDS)
			_rock_pose = RopeClimbPose.at("arrest", _rock_u)
			_rock_dx = move_toward(_rock_dx, _rock_last_nail_dx(), 2.0 * delta)
			_rock_place(_rock.safe - 0.35 * sin(minf(1.0, _rock_u * 2.0) * PI))
			if _rock_u >= 1.0:
				_rock_dx = _rock_last_nail_dx()
				_rock_place(_rock.safe)
				if _rock_result == RockClimb.Result.GAVE_UP:
					Events.tell(Lang.t("Du gibst auf und kletterst am Seil hinunter."), Color(0.8, 0.85, 1.0))
					_rock_phase = RockPhase.DESCEND
					_rock_u = 0.0
					_rock_left = true
				else:
					_rock_begin_pull()
		RockPhase.DESCEND:
			# Down hold by hold, one metre in a step, to the ground.
			_rock_u = minf(1.0, _rock_u + delta / ROCK_DESCEND_SECONDS)
			_rock_pose = RopeClimbPose.at("desc_l" if _rock_left else "desc_r", _rock_u)
			_rock_place(maxf(0.0, _rock_y - delta / ROCK_DESCEND_SECONDS))
			if _rock_u >= 1.0:
				_rock_left = not _rock_left
				_rock_u = 0.0
			if _rock_y <= 0.001:
				_end_rock(false)
				return
		RockPhase.TOP:
			_rock_u = minf(1.0, _rock_u + delta / ROCK_TOP_SECONDS)
			_rock_pose = RopeClimbPose.at("top", _rock_u)
			var on_edge := _rock_start + ROCK_DIR * 2.0 + Vector3(0, float(_rock_spot.height), 0)
			global_position = on_edge.lerp(ClimbSpots.top(level, _rock_spot), smoothstep(0.3, 1.0, _rock_u))
			if _rock_u >= 1.0:
				_end_rock(true)
				return
	if _rock != null and _skeleton != null:
		ClimbPose.apply(_skeleton, _pit_base, _rock_pose)
		_rock_rope_update()


## Where the last safe spot sits along the face (where the hero hangs when there is none).
func _rock_last_nail_dx() -> float:
	return _rock_nail_dx.back() if not _rock_nail_dx.is_empty() else _rock_dx


## Hides (or shows again) what the hands hold: the weapon and the shield.
func _stow_hands(stowed: bool) -> void:
	for hand_name in ["handslot_r", "handslot_l"]:
		var hand := _model.find_child(hand_name, true, false) as Node3D
		if hand != null:
			hand.visible = not stowed


## An iron nail in the rock where the hero hangs.
func _rock_add_nail() -> void:
	var nail := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.012
	mesh.height = 0.22
	nail.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.32, 0.35)
	mat.metallic = 0.7
	mat.roughness = 0.45
	nail.material_override = mat
	nail.name = "Nail"
	nail.rotation.x = PI * 0.5
	nail.position = _rock_surface(_rock_y + 0.9, _rock_dx) - ROCK_DIR * 0.08
	_rock_rope.add_child(nail)


## The rope from the foot of the face through every nail to the hero's belt.
func _rock_rope_update() -> void:
	if _rock_rope == null:
		return
	var points: Array[Vector3] = [_rock_surface(0.0) + Vector3(0, 0.05, 0) - ROCK_DIR * 0.15]
	for i in _rock.nails.size():
		points.append(_rock_surface(_rock.nails[i] + 0.9, _rock_nail_dx[i] if i < _rock_nail_dx.size() else 0.0) - ROCK_DIR * 0.15)
	points.append(global_position + Vector3(0, 0.9, 0) - ROCK_DIR * 0.0)
	var segs := _rock_rope.find_children("Seg*", "MeshInstance3D", false, false)
	while segs.size() < points.size() - 1:
		var seg := MeshInstance3D.new()
		seg.name = "Seg%d" % segs.size()
		var m := CylinderMesh.new()
		m.top_radius = 0.022
		m.bottom_radius = 0.022
		m.height = 1.0
		m.radial_segments = 6
		seg.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.62, 0.5, 0.3)
		mat.roughness = 0.95
		seg.material_override = mat
		_rock_rope.add_child(seg)
		segs.append(seg)
	for i in segs.size():
		var seg := segs[i] as MeshInstance3D
		seg.visible = i < points.size() - 1
		if not seg.visible:
			continue
		var a := points[i]
		var b := points[i + 1]
		var len := maxf(0.01, a.distance_to(b))
		seg.global_position = (a + b) * 0.5
		seg.scale = Vector3(1, len, 1)
		var up := (b - a) / len
		var axis := Vector3.UP.cross(up)
		seg.global_basis = Basis(axis.normalized(), Vector3.UP.angle_to(up)).scaled(Vector3(1, len, 1)) if axis.length() > 0.001 else Basis().scaled(Vector3(1, len, 1))


## The climb is over: up on the terrace (`up`), or back on the ground.
func _end_rock(up: bool) -> void:
	if _rock == null:
		return
	if up:
		train("klettern", Training.CLIMB_PER_METRE * _rock.height)
	else:
		global_position = _rock_start + Vector3(_rock_dx, 0, 0)
		_rock_push = -ClimbSpots.HOLD
	_rock = null
	_stow_hands(false)
	if _rock_rope != null:
		_rock_rope.queue_free()
		_rock_rope = null
	if _skeleton != null:
		ClimbPose.apply(_skeleton, _pit_base, {})
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_current_anim = ""
	play("Idle", 0.15)


# --- Ladders (see HouseSketcher._ladder) ------------------------------------------

## The group of the built ladders: each a Node3D with the metas "foot" (where the
## hero stands at its foot), "top" (where he steps off at the top), "edge" (a
## point on the edge it leans on) and "push" (the flat direction from foot to top).
const LADDER_GROUP := "house_ladders"
## How near the foot or the top the hero must be to step onto a ladder.
const LADDER_REACH := 0.75
## The climb (see LadderPose): its keys, the time so far (-1 when not on a ladder),
## the ladder's edge, push and foot height, and the sideways offset the hero started at.
var _ladder_keys: Array = []
var _ladder_t := -1.0
var _ladder_edge := Vector3.ZERO
var _ladder_push := Vector3.ZERO
var _ladder_low := 0.0
var _ladder_aside := 0.0
## The ladder the player clicked and the end of it the hero walks to first (see use_ladder), and
## for how many physics ticks the walk has gone on. Walking into a ladder never climbs it: a foot
## stands in a corner (or at a dead end in the sewers), so the way out of it led straight back up.
var _ladder_goal: Node3D
var _ladder_goal_up := true
var _ladder_goal_ticks := 0


## Which end of `ladder` the hero could climb from now: 1 at its foot (up), -1 at its top (down), 0 when
## he is on neither floor. A sewer ladder is climbed down by the hatch's lid, not from the street.
func ladder_end(ladder: Node3D) -> int:
	var foot: Vector3 = ladder.get_meta("foot")
	var top: Vector3 = ladder.get_meta("top")
	var here := global_position.y
	if absf(here - foot.y) < 0.45:
		return 1
	if absf(here - top.y) < 0.45 and not (ladder.has_meta("flush") and ladder.get_meta("flush")):
		return -1
	return 0


## Clicking a ladder: the hero walks to the end of it he stands on the floor of, and climbs it there.
## Returns false when he is on neither floor of it.
func use_ladder(ladder: Node3D) -> bool:
	var which := ladder_end(ladder)
	if which == 0 or on_ladder() or not is_inside_tree():
		return false
	_ladder_goal = ladder
	_ladder_goal_up = which > 0
	_ladder_goal_ticks = 0
	var end: Vector3 = ladder.get_meta("foot") if _ladder_goal_up else ladder.get_meta("top")
	if _near(end):
		path.clear() # Standing at it already: a step off it first would only take the hero away.
	else:
		walk_to(end)
	return true


## Gives up the walk to a ladder (another click, or another way taken).
func cancel_ladder() -> void:
	_ladder_goal = null


## Steps onto the clicked ladder (see use_ladder) once the hero has walked up to its end. Returns
## whether a climb began.
func _try_ladder(_dir: Vector3) -> bool:
	if _ladder_goal == null:
		return false
	if not is_instance_valid(_ladder_goal) or not is_inside_tree() or on_ladder():
		_ladder_goal = null
		return false
	var foot: Vector3 = _ladder_goal.get_meta("foot")
	var top: Vector3 = _ladder_goal.get_meta("top")
	if is_on_floor() and _near(foot if _ladder_goal_up else top):
		var ladder := _ladder_goal
		_ladder_goal = null
		path.clear()
		_start_ladder(ladder.get_meta("edge"), ladder.get_meta("push"), foot.y, top.y, _ladder_goal_up)
		return true
	_ladder_goal_ticks += 1
	if path.is_empty() and steer == Vector3.ZERO and _ladder_goal_ticks > 30:
		_ladder_goal = null
	return false


## Climbs down the ladder whose top is by `near` (within 1.4 m): a click on a manhole does this once
## the hero has walked up to it. Returns whether a climb began.
func climb_down_at(near: Vector3) -> bool:
	if not is_inside_tree() or on_ladder():
		return false
	for ladder: Node3D in get_tree().get_nodes_in_group(LADDER_GROUP):
		var top: Vector3 = ladder.get_meta("top")
		if Vector2(top.x - near.x, top.z - near.z).length() > 1.4 or top.y < near.y - 0.5:
			continue
		var foot: Vector3 = ladder.get_meta("foot")
		_start_ladder(ladder.get_meta("edge"), ladder.get_meta("push"), foot.y, top.y, false)
		return true
	return false


## Whether the hero stands at `spot`: on its height and within reach of it.
func _near(spot: Vector3) -> bool:
	var at := global_position
	return absf(at.y - spot.y) < 0.45 and Vector2(at.x - spot.x, at.z - spot.z).length() < LADDER_REACH


func _start_ladder(edge: Vector3, push: Vector3, low: float, high: float, up: bool) -> void:
	_ladder_edge = Vector3(edge.x, 0, edge.z)
	_ladder_push = push
	_ladder_low = low
	var from := global_position - _ladder_edge
	var forward := from.dot(push)
	_ladder_aside = from.dot(Vector3(-push.z, 0, push.x))
	_ladder_keys = LadderPose.up_keys(high - low, forward) if up else LadderPose.down_keys(high - low, forward)
	_ladder_t = 0.0
	_air_momentum = Vector3.ZERO
	velocity = Vector3.ZERO
	face(push)
	if _skeleton == null:
		_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton != null and _pit_base.is_empty():
		_anim.play("Idle")
		_anim.seek(0.0, true)
		_pit_base = ClimbPose.base_of(_skeleton)
	if _skeleton != null:
		_anim.pause()
	_current_anim = ""
	train("geschick", 0.2)


## Where the climb puts the hero's feet: `state` from LadderPose.at.
func _ladder_spot(state: Dictionary) -> Vector3:
	var side := Vector3(-_ladder_push.z, 0, _ladder_push.x)
	return _ladder_edge + _ladder_push * float(state.forward) + side * _ladder_aside * float(state.side) \
		+ Vector3(0, _ladder_low + float(state.height), 0)


## One step of a ladder climb: the hero is carried along the climb, hand over
## hand and foot over foot on the rungs (see LadderPose).
func _ladder_step(delta: float) -> void:
	velocity = Vector3.ZERO
	_ladder_t += delta
	var state := LadderPose.at(_ladder_keys, _ladder_t)
	global_position = _ladder_spot(state)
	face(_ladder_push)
	if _skeleton != null:
		ClimbPose.apply(_skeleton, _pit_base, state.pose)
	if _ladder_t >= LadderPose.length(_ladder_keys):
		_end_ladder()


func _end_ladder() -> void:
	_ladder_t = -1.0
	global_position = _ladder_spot(LadderPose.at(_ladder_keys, LadderPose.length(_ladder_keys))) + Vector3(0, 0.02, 0)
	reset_physics_interpolation()
	if _skeleton != null:
		ClimbPose.apply(_skeleton, _pit_base, {})
	velocity = Vector3.ZERO
	_current_anim = ""
	play("Idle", 0.15)


## Whether the hero is on a ladder now.
func on_ladder() -> bool:
	return _ladder_t >= 0.0


## Whether the drawn hero is kept out of walls now: not while seated, lying, climbing
## (that keeps clear on its own, see ClimbPose) or dead, which put the model where it belongs.
func _keeps_clear_of_walls() -> bool:
	if dead or _seated or _bed_posed or _pit_climb or _rock != null or _horn != null or _climb >= 0.0 or _ladder_t >= 0.0 or _clearance_pivot == null:
		return false
	return not (_current_anim.begins_with("Lie_") or _current_anim.begins_with("Sit_") or _current_anim.begins_with("Death"))


## Lifts the hero onto the top of a crate or block set down under them: the
## same pull-up as a climb, to `target` (feet there).
func lift_onto(target: Vector3) -> void:
	_climb_from = global_position
	_climb_to = target
	_climb_time = CLIMB_TIME
	_climb = 0.0
	_air_momentum = Vector3.ZERO
	velocity = Vector3.ZERO
	_current_anim = ""
	play("Jump_Idle", 0.1)


## Whether the hero would fit standing at `spot` (feet there).
func has_room_at(spot: Vector3) -> bool:
	return _room_at(spot)


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
	_climb = minf(1.0, _climb + delta / _climb_time)
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
	if typing:
		return Vector3.ZERO
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


## The next step of a frightened hero's run along the flee path.
func _flee_step() -> Vector3:
	while not _flee.is_empty():
		var to := _flee[0] - global_position
		to.y = 0.0
		if to.length() > 0.4:
			return to.normalized()
		_flee.remove_at(0)
	return Vector3.ZERO


func _physics_process(delta: float) -> void:
	if frozen:
		return
	_clearance.tick(self, _clearance_pivot, _model, delta, _keeps_clear_of_walls())
	_busy = maxf(0.0, _busy - delta)
	_flourish = maxf(0.0, _flourish - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_fear_calm = maxf(0.0, _fear_calm - delta)
	fight_cooldown = maxf(0.0, fight_cooldown - delta)
	combat_clock = maxf(0.0, combat_clock - delta)
	# Slimed, the hero's arms are slow too (see SlimeCoat).
	var arms := delta / (SlimeCoat.ATTACK_SLOW if ailments.has(SlimeCoat.KIND) else 1.0)
	_attack_cooldown = maxf(0.0, _attack_cooldown - arms)
	_auto_cooldown = maxf(0.0, _auto_cooldown - arms)
	_anim_hold = maxf(0.0, _anim_hold - delta)
	_tick_jump(delta)
	_clock += delta
	_get_up(delta)
	_tick_ailments(delta)
	if goo_left > 0.0:
		goo_left -= delta
		if not slime_covered():
			SlimeCoat.wipe(self, _model)
	_regenerate(delta)
	potions.tick(delta)
	spell_wait = maxf(0.0, spell_wait - delta)
	_knife_settle -= delta
	if _knife_settle <= 0.0:
		_knife_settle = KNIFE_SETTLE_EVERY
		if _settle_knives():
			knives_settled.emit()
	_chase_rest = maxf(0.0, _chase_rest - delta)
	_pursue(delta)
	_auto_attack()
	if _glide_step(delta):
		return
	if _stay_seated(delta):
		return
	if _horn_step(delta):
		return
	if _pit_climb:
		_pit_climb_step(delta)
		return
	if _rock != null:
		_rock_step(delta)
		return
	if _ladder_t >= 0.0:
		_ladder_step(delta)
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
	if is_afraid() and controllable and _busy <= 0.0:
		dir = _flee_step()
	_breathe(delta, dir != Vector3.ZERO)
	var vy := velocity.y - GRAVITY * delta
	if is_on_floor():
		surface_pace = Surfaces.ease_pace(surface_pace, level, global_position, delta)
	var pace := speed * surface_pace * (SNEAK_SPEED + SNEAK_PER_LEVEL * skill("schleichen") if sneaking else WALK_FACTOR * run_boost)
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
	var stepped := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_train_legs(stepped)
	# Pressed on for a second without getting anywhere and no way out in any direction: get free.
	if _wedge.tick(dir != Vector3.ZERO and is_on_floor(), stepped, pace * delta, delta) and HeroUnstick.is_wedged(self):
		HeroUnstick.release(self, free_spot, level.cell_to_world(level.start_cell) if level != null else Vector3.INF)
	elif is_on_floor() and stepped > 0.0 and stepped >= pace * delta * 0.8:
		free_spot = global_position
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
	if controllable and not dead and _busy <= 0.0 and _down <= 0.0 and _falling <= 0.0 and (_try_ladder(dir) or _try_climb(dir) or _try_climb_out(dir, delta) or _try_climb_rock(dir, delta)):
		return
	if dir != Vector3.ZERO and (_anim_hold <= 0.0 or _jump_windup > 0.0):
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-14.0 * delta))
	# Blink while invulnerable after a hit.
	_model.visible = dead or _invulnerable <= 0.0 or int(_invulnerable * 12.0) % 2 == 0
	# Feet keep pace with the ground: the walk, the jog and the run play just
	# as fast as the planted foot must travel (see Stride), and the hero rises
	# onto the toes as each back foot rolls off.
	var ground_speed := SmoothMotion.ground_speed(self)
	if _current_anim in Stride.GAITS.kaykit or _current_anim == SNEAK_ANIM:
		_anim.speed_scale = Stride.playback("kaykit", _current_anim, _model.scale.x, ground_speed)
	elif _current_anim == GET_UP_ANIM:
		_anim.speed_scale = GET_UP_SPEED
	else:
		_anim.speed_scale = 1.0
	var lift := Stride.lift(_anim, _current_anim, _model.scale.x, ground_speed)
	if lift > 0.0 or _on_toes:
		_model.position.y = lift
		_on_toes = lift > 0.0
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
		play(SNEAK_ANIM if sneaking else Stride.gait("kaykit", Stride.GAITS.kaykit, _model.scale.x, pace, _current_anim))
