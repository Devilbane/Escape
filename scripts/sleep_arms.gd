class_name SleepArms
extends SkeletonModifier3D
## Both arms of a villager asleep at a table or a counter with the head in the hands: the upper
## arms come forward and down so the elbows rest on the surface, the forearms fold up, and the
## hands meet under the face. Like CarryArm it runs after the clips and eases in and out, and only
## while a sitting or standing idle plays (the sleeper is paused on nothing else).
##
## The angles (degrees) are a first estimate by analogy with CarryArm's measured left arm, the
## right arm mirrored (the Y and Z turns flipped); they still want measuring on the rig.

const UPPER := ["upperarm.l", "upperarm.r"]
const LOWER := ["lowerarm.l", "lowerarm.r"]
## The upper arm swings forward (REACH, about the bone's Z), turns in (IN, Y) and rolls (ROLL, X).
const REACH := -35.0
const IN := -25.0
const ROLL := 30.0
## The elbow folds the forearm up (BEND about Z, FOLD about X).
const BEND := 105.0
const FOLD := 25.0
## The clips this goes with.
const CLIPS := ["Sit_Chair_Idle", "Idle"]
## How fast the arms ease in and out (per second).
const EASE := 5.0

var player: AnimationPlayer
var _base := {}
var _on := 0.0


## Hangs SleepArms on `skeleton` (animated by `anim`); null when the rig has no arms.
static func attach(skeleton: Skeleton3D, anim: AnimationPlayer) -> SleepArms:
	if skeleton == null or anim == null:
		return null
	for name: String in UPPER + LOWER:
		if skeleton.find_bone(name) < 0:
			return null
	var arms := SleepArms.new()
	arms.name = "SleepArms"
	arms.player = anim
	arms.active = false
	var was := anim.current_animation
	var at := anim.current_animation_position
	var speed := anim.speed_scale
	anim.play("Idle")
	anim.seek(0.0, true)
	for name: String in UPPER + LOWER:
		arms._base[name] = skeleton.get_bone_pose_rotation(skeleton.find_bone(name))
	if was != "" and anim.has_animation(was):
		anim.play(was)
		anim.seek(at, true)
	anim.speed_scale = speed
	skeleton.add_child(arms)
	return arms


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _base.is_empty():
		return
	var clip: String = player.current_animation if player != null else ""
	var want := 1.0 if clip in CLIPS else 0.0
	var dt: float = get_physics_process_delta_time() if player != null and player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS else get_process_delta_time()
	_on = move_toward(_on, want, EASE * maxf(dt, 0.001))
	if _on <= 0.0:
		return
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var ua := skeleton.find_bone(UPPER[i])
		var la := skeleton.find_bone(LOWER[i])
		var ua_pose := (_base[UPPER[i]] as Quaternion) * Quaternion(Vector3.BACK, deg_to_rad(REACH * side)) \
				* Quaternion(Vector3.UP, deg_to_rad(IN * side)) * Quaternion(Vector3.RIGHT, deg_to_rad(ROLL))
		var la_pose := (_base[LOWER[i]] as Quaternion) * Quaternion(Vector3.BACK, deg_to_rad(BEND * side)) \
				* Quaternion(Vector3.RIGHT, deg_to_rad(FOLD))
		skeleton.set_bone_pose_rotation(ua, skeleton.get_bone_pose_rotation(ua).slerp(ua_pose, _on))
		skeleton.set_bone_pose_rotation(la, skeleton.get_bone_pose_rotation(la).slerp(la_pose, _on))
