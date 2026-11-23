class_name CarryArm
extends SkeletonModifier3D
## The arm that holds a torch or a lamp out in front of the body. The walk and run clips swing
## both arms hard, which sets a flame flying about, so while something burns in the left hand
## this modifier replaces that arm's animation (it runs after the clips, see SkeletonModifier3D):
## the upper arm reaches forward, the elbow is bent, and the arm only rocks gently with the
## steps (two a walk cycle). Standing still, the arm simply holds. Used by Villager and
## HandTorch; the hand slot (and with it the light) follows the arm.

const UPPER := "upperarm.l"
const LOWER := "lowerarm.l"
## The pose in degrees (ClimbPose's convention): how far the upper arm is raised forward and how
## far the elbow is bent.
const REACH := 84.0
const BEND := 10.0
## How far the arm rocks with each step (degrees), walking and running.
const ROCK_WALK := 3.0
const ROCK_RUN := 5.0
## The clips this takes over from: the arm only carries during these.
const CLIPS := ["Idle", "Walking_A", "Walking_B", "Walking_C", "Running_A", "Running_B"]
## How fast the arm eases into the carry pose and out of it (per second).
const EASE := 8.0

## The animation player whose clip is playing (for the step phase).
var player: AnimationPlayer
## The arm's rotations as the Idle clip leaves them (see capture).
var _base := {}
## How much of the carry pose is on (0..1) and the arm's current rock.
var _on := 0.0
var _rock := 0.0


## Hangs a CarryArm on `skeleton` for the body animated by `anim` and returns it, or null if the rig
## has no arms. The Idle pose is read first (and the clip put back), as the pose to raise the arm from.
static func attach(skeleton: Skeleton3D, anim: AnimationPlayer) -> CarryArm:
	if skeleton == null or anim == null:
		return null
	var ua := skeleton.find_bone(UPPER)
	var la := skeleton.find_bone(LOWER)
	if ua < 0 or la < 0:
		return null
	var arm := CarryArm.new()
	arm.name = "CarryArm"
	arm.player = anim
	arm.active = false
	var was := anim.current_animation
	var at := anim.current_animation_position
	var speed := anim.speed_scale
	anim.play("Idle")
	anim.seek(0.0, true)
	arm._base = {
		"ua": skeleton.get_bone_pose_rotation(ua),
		"la": skeleton.get_bone_pose_rotation(la),
	}
	if was != "" and anim.has_animation(was):
		anim.play(was)
		anim.seek(at, true)
	anim.speed_scale = speed
	skeleton.add_child(arm)
	return arm


## Whether `clip` is one the carry pose goes with.
static func carries_in(clip: String) -> bool:
	return clip in CLIPS


## The arm's angles (degrees) at `phase` (0..1) of a clip's cycle: the upper arm's raise and the
## elbow's bend. `rock` is the amplitude (see ROCK_WALK); the bend lags the raise a little, so the
## forearm follows the shoulder instead of moving with it.
static func angles(phase: float, rock: float) -> Vector2:
	var steps := TAU * 2.0 * phase
	return Vector2(REACH + rock * sin(steps), BEND + rock * 0.7 * sin(steps - 0.7))


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _base.is_empty():
		return
	var clip: String = player.current_animation if player != null else ""
	# Paused means someone else poses the body bone by bone (a ladder, the alarm horn).
	var want: float = 1.0 if carries_in(clip) and player.is_playing() else 0.0
	var dt: float = get_physics_process_delta_time() if player != null and player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS else get_process_delta_time()
	_on = move_toward(_on, want, EASE * maxf(dt, 0.001))
	if _on <= 0.0:
		return
	var moving: bool = clip != "Idle" and want > 0.0
	var rock := 0.0
	var phase := 0.0
	if moving and player.current_animation_length > 0.0:
		phase = player.current_animation_position / player.current_animation_length
		rock = ROCK_RUN if clip.begins_with("Running") else ROCK_WALK
	_rock = lerpf(_rock, rock, clampf(EASE * 0.5 * maxf(dt, 0.001), 0.0, 1.0))
	var a := angles(phase, _rock)
	var ua := skeleton.find_bone(UPPER)
	var la := skeleton.find_bone(LOWER)
	# The clip's own arm, then the carry pose over the idle arm by how far it is on: no jump when
	# the arm takes hold or lets go.
	var ua_pose := (_base.ua as Quaternion) * Quaternion(Vector3.BACK, -deg_to_rad(a.x))
	var la_pose := (_base.la as Quaternion) * Quaternion(Vector3.BACK, -deg_to_rad(a.y))
	skeleton.set_bone_pose_rotation(ua, skeleton.get_bone_pose_rotation(ua).slerp(ua_pose, _on))
	skeleton.set_bone_pose_rotation(la, skeleton.get_bone_pose_rotation(la).slerp(la_pose, _on))
