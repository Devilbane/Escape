extends SceneTree
## Builds assets/animals/Sheep.glb: the sheep of Quaternius' "Farm Animals" pack (CC0), whose
## FBX comes with an Idle and a Jump only, plus a Walk, a Gallop and an Eating made here by
## turning its bones. Run it after downloading the pack (it is on opengameart.org, "LowPoly
## Animated Farm Animal Pack") and copying FBX/Sheep.fbx to a folder of your own:
##   godot --headless --import   (with the FBX copied into assets/animals/ as SheepFarm.fbx, not committed)
##   godot --headless -s tools/build_sheep.gd -- res://assets/animals/SheepFarm.fbx
## Skeleton space is Blender's: X across the body, -Y forward, Z up, legs hang down -Z, so a
## turn about X swings a leg (a positive turn takes a foot backwards) or a neck.

const OUT := "res://assets/animals/Sheep.glb"
const PATH := "Armature/Skeleton3D:"

var sk: Skeleton3D
var model: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var source: String = args[0] if args.size() > 0 else "res://assets/animals/SheepFarm.fbx"
	model = load(source).instantiate()
	root.add_child(model)
	sk = model.find_child("Skeleton3D", true, false)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var lib := player.get_animation_library(player.get_animation_library_list()[0])
	var idle: Animation = lib.get_animation("Armature|Idle").duplicate()
	for n in lib.get_animation_list():
		lib.remove_animation(n)
	lib.add_animation("Idle", idle)
	lib.add_animation("Walk", _walk())
	lib.add_animation("Gallop", _gallop())
	lib.add_animation("Eating", _eating())
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(model, state)
	if err == OK:
		err = doc.write_to_filesystem(state, OUT)
	print("wrote ", OUT, " ", error_string(err))
	quit(0 if err == OK else 1)


func _rest(bone: String) -> Basis:
	return sk.get_bone_global_rest(sk.find_bone(bone)).basis


## Turns a chain of bones (each the child of the one before, the first one's parent staying
## at rest) about X by the running sum of `angles` and adds a rotation key to each.
##
## `foot` names a bone that is no child of the chain but must ride on its last bone (the model
## skins its hooves partly to these bones, so a still one stretches the hoof): it keeps its
## place relative to that bone.
func _key_chain(anim: Animation, tracks: Dictionary, t: float, bones: Array, angles: Array, foot := "", shift := Vector3.ZERO) -> void:
	var parent_index := sk.get_bone_parent(sk.find_bone(bones[0]))
	var parent := sk.get_bone_global_rest(parent_index).basis
	var global := Transform3D(Basis(), shift) * sk.get_bone_global_rest(parent_index)
	var total := 0.0
	for i in bones.size():
		total += angles[i]
		var want := Basis(Quaternion(Vector3.RIGHT, total)) * _rest(bones[i])
		var local := parent.inverse() * want
		anim.rotation_track_insert_key(_track(anim, tracks, bones[i]), t, local.get_rotation_quaternion())
		global = global * Transform3D(local, sk.get_bone_rest(sk.find_bone(bones[i])).origin)
		parent = want
	if foot != "":
		var low := sk.get_bone_global_rest(sk.find_bone(bones[-1]))
		var foot_rest := sk.get_bone_global_rest(sk.find_bone(foot))
		var moved := global * (low.affine_inverse() * foot_rest)
		var up := sk.get_bone_global_rest(sk.get_bone_parent(sk.find_bone(foot))).affine_inverse() * moved
		anim.rotation_track_insert_key(_track(anim, tracks, foot), t, up.basis.get_rotation_quaternion())
		if not tracks.has(foot + "#p"):
			var added := anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(added, NodePath(PATH + foot))
			tracks[foot + "#p"] = added
		var pos: int = tracks[foot + "#p"]
		anim.position_track_insert_key(pos, t, up.origin)


func _track(anim: Animation, tracks: Dictionary, bone: String) -> int:
	if not tracks.has(bone):
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath(PATH + bone))
		tracks[bone] = t
	return tracks[bone]


func _bob(anim: Animation, t: float, height: float, track: int) -> void:
	var rest := sk.get_bone_rest(sk.find_bone("Body")).origin
	anim.position_track_insert_key(track, t, rest + Vector3(0, 0, height))


## `legs`: for each of FR, FL, BR, BL its phase (0..1 of the cycle). `swing` and `lift` are
## the hip swing and the knee fold in radians, `front` and `back` scale them.
func _gait(length: float, phase: Array, swing: Array, lift: float, bob: float) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	var tracks := {}
	var body := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(body, NodePath(PATH + "Body"))
	var legs := [["FrontUpLeg.R", "FrontLowLeg.R"], ["FrontUpLeg.L", "FrontLowLeg.L"],
		["BackUpLeg.R", "BackLowLeg.R"], ["BackUpLeg.L", "BackLowLeg.L"]]
	var feet := ["FrontFoot.R", "FrontFoot.L", "BackFoot.R", "BackFoot.L"]
	var steps := 24
	for s in steps + 1:
		var t := length * s / steps
		var u := float(s) / steps
		var rise := bob * absf(sin(TAU * u * 2.0))
		for i in 4:
			var phi: float = TAU * (u + float(phase[i]))
			# Foot back while it is on the ground (a long, even push), forward and folded in the air.
			var hip: float = swing[i] * sin(phi)
			var fold: float = lift * maxf(0.0, -cos(phi)) * (1.0 if i < 2 else 1.3)
			_key_chain(anim, tracks, t, legs[i], [hip, fold], feet[i], Vector3(0, 0, rise))
		_bob(anim, t, rise, body)
	return anim


func _walk() -> Animation:
	# The diagonal pairs go together: front right with back left.
	return _gait(1.0, [0.0, 0.5, 0.5, 0.0], [0.34, 0.34, 0.3, 0.3], 0.4, 0.0004)


func _gallop() -> Animation:
	return _gait(0.5, [0.0, 0.06, 0.45, 0.5], [0.6, 0.6, 0.55, 0.55], 0.45, 0.0014)


## Head down to the grass, nibbling.
func _eating() -> Animation:
	var anim := Animation.new()
	anim.length = 2.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var tracks := {}
	var steps := 24
	for s in steps + 1:
		var t := anim.length * s / steps
		var u := float(s) / steps
		var chew := 0.08 * sin(TAU * u * 4.0)
		_key_chain(anim, tracks, t, ["Neck", "Head"], [0.95, 0.0 + chew])
	return anim
