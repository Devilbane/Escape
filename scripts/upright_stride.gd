class_name UprightStride
extends SkeletonModifier3D
## Keeps the hero upright while moving. The legs play the run animation, so
## the feet still keep pace with the ground at full speed, but the spine,
## head and arms take their pose from the calm upright walk instead of the
## forward-leaning run. The walk is played in step with the run's legs, so
## each arm still swings against the opposite leg.

## The animation whose legs carry the hero.
const LEGS_ANIM := "Running_A"
## The animation that lends its upper body.
const UPPER_ANIM := "Walking_A"
## Where the walk cycle is when the run cycle starts: both have the left foot
## furthest forward there.
const PHASE_OFFSET := 0.84
## How fast the upright pose fades in and out (full fade in 0.2 seconds).
const FADE_SPEED := 5.0

var anim: AnimationPlayer
## Whether the upright pose should be shown; it fades in and out smoothly.
var wanted := false

var _upper: Animation
## Upper body bones and the walk's rotation track for each.
var _bones: Array[int] = []
var _tracks: Array[int] = []
var _hips := -1
var _hips_track := -1
var _spine := -1
var _phase := 0.0


func setup(player: AnimationPlayer) -> void:
	anim = player
	_upper = anim.get_animation(UPPER_ANIM)
	var skeleton := get_skeleton()
	_hips = skeleton.find_bone("hips")
	_spine = skeleton.find_bone("spine")
	_hips_track = _rotation_track("hips")
	if _spine < 0 or _hips < 0 or _hips_track < 0:
		active = false
		return
	for bone in skeleton.get_bone_count():
		if _is_upper(skeleton, bone):
			var track := _rotation_track(skeleton.get_bone_name(bone))
			if track >= 0:
				_bones.append(bone)
				_tracks.append(track)
	influence = 0.0


func _rotation_track(bone_name: String) -> int:
	for i in _upper.get_track_count():
		if _upper.track_get_type(i) == Animation.TYPE_ROTATION_3D \
				and _upper.track_get_path(i).get_concatenated_subnames() == bone_name:
			return i
	return -1


## The spine and everything above it: chest, neck, head, arms and hands.
func _is_upper(skeleton: Skeleton3D, bone: int) -> bool:
	while bone >= 0:
		if bone == _spine:
			return true
		bone = skeleton.get_bone_parent(bone)
	return false


func _process(delta: float) -> void:
	influence = move_toward(influence, 1.0 if wanted else 0.0, FADE_SPEED * delta)


func _process_modification_with_delta(_delta: float) -> void:
	if influence <= 0.0 or _bones.is_empty():
		return
	# While fading out after the run, the upper body holds its last pose.
	if anim.current_animation == LEGS_ANIM and anim.current_animation_length > 0.0:
		_phase = anim.current_animation_position / anim.current_animation_length
	var t := fposmod(_phase + PHASE_OFFSET, 1.0) * _upper.length
	var skeleton := get_skeleton()
	# The run tilts the hips forward. The spine undoes that tilt, so the
	# chest stands as straight as in the walk while the legs stay as they are.
	var hips_walk := _upper.rotation_track_interpolate(_hips_track, t)
	var hips_now := skeleton.get_bone_pose_rotation(_hips)
	for i in _bones.size():
		var rot := _upper.rotation_track_interpolate(_tracks[i], t)
		if _bones[i] == _spine:
			rot = hips_now.inverse() * hips_walk * rot
		skeleton.set_bone_pose_rotation(_bones[i], rot)
