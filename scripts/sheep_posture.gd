class_name SheepPosture
extends SkeletonModifier3D
## Gives the alpaca model a sheep's carriage after its animation has played: the neck leans
## forward and low instead of standing straight up, the head hangs a little, and the ears
## stick out sideways. The animations turn these bones themselves, so the lean is added on
## top of them every frame. Angles are in degrees, turned about each bone's parent's X axis.

var neck_pitch := 0.0
var head_pitch := 0.0
var ear_roll := 0.0

var _neck := -1
var _head := -1
var _ears: Array[int] = []


func setup(skeleton: Skeleton3D) -> void:
	_neck = skeleton.find_bone("Neck1")
	_head = skeleton.find_bone("Head")
	for n in ["Ear1.L", "Ear1.R"]:
		_ears.append(skeleton.find_bone(n))


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _neck < 0:
		return
	_turn(skeleton, _neck, Vector3.RIGHT, neck_pitch)
	_turn(skeleton, _head, Vector3.RIGHT, head_pitch)
	_turn(skeleton, _ears[0], Vector3.BACK, ear_roll)
	_turn(skeleton, _ears[1], Vector3.BACK, -ear_roll)


static func _turn(skeleton: Skeleton3D, bone: int, axis: Vector3, degrees: float) -> void:
	if bone < 0 or is_zero_approx(degrees):
		return
	var q := Quaternion(axis, deg_to_rad(degrees))
	skeleton.set_bone_pose_rotation(bone, q * skeleton.get_bone_pose_rotation(bone))
