class_name YokeArms
extends SkeletonModifier3D
## Both hands rest on the water carrier's yoke (see WaterYoke). The walk and run clips swing the arms
## hard, which would fling the beam about, so while she carries it this modifier replaces both arms'
## animation (it runs after the clips, see SkeletonModifier3D): the upper arms hang out and down, the
## elbows are bent and the hands lie on the beam, rocking only a few degrees with the steps. Standing,
## the arms simply hold. The angles were fitted on the rig (the right arm mirrors the left), and
## tests/water_yoke.gd checks where the hands end up.

const UPPER := ["upperarm.l", "upperarm.r"]
const LOWER := ["lowerarm.l", "lowerarm.r"]
## Per arm (left, right): the upper arm's swing (about the bone's Z), turn (Y) and roll (X), and the
## elbow's bend (Z) and fold (X), in degrees.
const POSE := [
	[-0.6, -40.1, -17.3, -74.7, 47.4],
	[0.6, 40.1, -17.3, 74.7, 47.4],
]
const ROCK_WALK := 2.5
const ROCK_RUN := 4.0
## The clips this takes over from: the arms only carry during these.
const CLIPS := ["Idle", "Walking_A", "Walking_B", "Walking_C", "Running_A", "Running_B"]
const EASE := 8.0

var player: AnimationPlayer
var _base := {}
var _on := 0.0
var _rock := 0.0


## Hangs a YokeArms on `skeleton` for the body animated by `anim` (the Idle pose is read first, as the
## pose to raise the arms from) and returns it, or null if the rig has no arms.
static func attach(skeleton: Skeleton3D, anim: AnimationPlayer) -> YokeArms:
	if skeleton == null or anim == null:
		return null
	for n: String in UPPER + LOWER:
		if skeleton.find_bone(n) < 0:
			return null
	var arms := YokeArms.new()
	arms.name = "YokeArms"
	arms.player = anim
	arms.active = false
	var was := anim.current_animation
	var at := anim.current_animation_position if was != "" else 0.0
	var speed := anim.speed_scale
	anim.play("Idle")
	anim.seek(0.0, true)
	for side in 2:
		arms._base[side] = [skeleton.get_bone_pose_rotation(skeleton.find_bone(UPPER[side])), skeleton.get_bone_pose_rotation(skeleton.find_bone(LOWER[side]))]
	if was != "" and anim.has_animation(was):
		anim.play(was)
		anim.seek(at, true)
	anim.speed_scale = speed
	skeleton.add_child(arms)
	return arms


static func carries_in(clip: String) -> bool:
	return clip in CLIPS


## The rotations of arm `side` (0 left, 1 right) as the pose gives them: the upper arm's and the elbow's.
static func rotations(base_upper: Quaternion, base_lower: Quaternion, side: int, rock: float) -> Array[Quaternion]:
	var p: Array = POSE[side]
	var upper := base_upper * Quaternion(Vector3.BACK, deg_to_rad(p[0] + rock)) * Quaternion(Vector3.UP, deg_to_rad(p[1])) * Quaternion(Vector3.RIGHT, deg_to_rad(p[2]))
	var lower := base_lower * Quaternion(Vector3.BACK, deg_to_rad(p[3] + rock * 0.7)) * Quaternion(Vector3.RIGHT, deg_to_rad(p[4]))
	return [upper, lower]


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _base.is_empty():
		return
	var clip: String = player.current_animation if player != null else ""
	# Paused means someone else poses the body bone by bone (a ladder, the alarm horn, a bed).
	var want: float = 1.0 if carries_in(clip) and player.is_playing() else 0.0
	var dt: float = get_physics_process_delta_time() if player != null and player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS else get_process_delta_time()
	_on = move_toward(_on, want, EASE * maxf(dt, 0.001))
	if _on <= 0.0:
		return
	var rock := 0.0
	if clip != "Idle" and want > 0.0 and player.current_animation_length > 0.0:
		var phase := player.current_animation_position / player.current_animation_length
		rock = (ROCK_RUN if clip.begins_with("Running") else ROCK_WALK) * sin(TAU * 2.0 * phase)
	_rock = lerpf(_rock, rock, clampf(EASE * 0.5 * maxf(dt, 0.001) * 2.0, 0.0, 1.0))
	for side in 2:
		var ua := skeleton.find_bone(UPPER[side])
		var la := skeleton.find_bone(LOWER[side])
		var r := rotations(_base[side][0], _base[side][1], side, _rock * (1.0 if side == 0 else -1.0))
		skeleton.set_bone_pose_rotation(ua, skeleton.get_bone_pose_rotation(ua).slerp(r[0], _on))
		skeleton.set_bone_pose_rotation(la, skeleton.get_bone_pose_rotation(la).slerp(r[1], _on))
