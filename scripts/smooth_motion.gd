class_name SmoothMotion
## Physics interpolation, switched on in project.godot, only for the bodies
## that move in physics ticks: the hero, monsters, villagers, animals, the
## companion and flying shots.
##
## The world ticks 60 times a second, but the screen may show 75, 120 or 144
## frames, or fewer than 60 in the browser. Without interpolation a running
## body jumps a whole tick on some frames and stands still on others, and the
## camera, which follows every frame, makes the hero jitter against the
## ground. With it, each frame draws the body between its last two ticks.
##
## Everything else is moved per frame (`_process`, tweens) and must not be
## interpolated: an interpolated node that moves per frame stutters. So the
## game's root turns it off (`off_below`), and each moving body turns it on
## for itself only (`follow_ticks`); its children, such as the model, the
## name tag or a held light, still ride along with the smoothed body.


## Turns interpolation off for `node` and everything below it that does not
## turn it on for itself.
static func off_below(node: Node) -> void:
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Draws `body` smoothly between its physics ticks. Its children, also ones
## added later, are not interpolated themselves: they move with the body.
static func follow_ticks(body: Node3D) -> void:
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	for child in body.get_children():
		_ride_along(child)
	if not body.child_entered_tree.is_connected(_ride_along):
		body.child_entered_tree.connect(_ride_along)


static func _ride_along(child: Node) -> void:
	child.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Where `node` is drawn this frame: between its last two ticks when it is
## interpolated, else where it is.
static func drawn_at(node: Node3D) -> Vector3:
	if node.is_physics_interpolated_and_enabled():
		return node.get_global_transform_interpolated().origin
	return node.global_position
