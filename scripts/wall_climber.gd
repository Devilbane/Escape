class_name WallClimber
extends RefCounted
## The mountaineer on the climbing wall: Kletterer Wolfram's own body and the whole climbing set (helmet,
## harness, rope, hammer, gloves, boots; see Villager.ROLES and ClimberOutfit), dressed the way the village
## dresses him, posed bone by bone with RopeClimbPose (the poses he and the hero climb the mountain with).
## Used by WallStage; nothing here needs a level.

var model: Node3D
var skeleton: Skeleton3D
var base := {}
var anim: AnimationPlayer


static func make() -> WallClimber:
	var c := WallClimber.new()
	var info: Dictionary = Villager.ROLES[ClimberNpc.ROLE]
	c.model = load("res://assets/characters/%s.glb" % info.model).instantiate()
	c.model.scale = Vector3.ONE * float(info.get("scale", 1.0)) * BodyLook.scale_of(info.get("sex", BodyLook.DEFAULT))
	Villager.dress_model(c.model, info)
	Villager.sheathe_weapons(c.model, info)
	BodyLook.apply(c.model, info.get("sex", BodyLook.DEFAULT))
	var look := TownsfolkLook.look_for(ClimberNpc.ROLE, info)
	HairLook.apply(c.model, TownsfolkLook.hair_of(info, look))
	GearLook.dress_body(c.model, "outfit")
	TownsfolkLook.apply(c.model, info, look)
	ClimberOutfit.put_on(c.model)
	c.skeleton = c.model.find_child("Skeleton3D", true, false) as Skeleton3D
	c.anim = c.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if c.anim != null:
		c.anim.play("Idle")
		c.anim.seek(0.0, true)
		c.anim.advance(0.0)
		c.anim.pause()
	if c.skeleton != null:
		c.base = ClimbPose.base_of(c.skeleton)
	return c


## Poses the body (a ClimbPose dictionary, see RopeClimbPose.at); an empty one is standing.
func pose(p: Dictionary) -> void:
	if skeleton != null and not base.is_empty():
		ClimbPose.apply(skeleton, base, p)


## The hammer in his hand (true) or on his belt.
func hammer(in_hand: bool) -> void:
	ClimberOutfit.hammer_in_hand(model, in_hand)
