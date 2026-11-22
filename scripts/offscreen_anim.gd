class_name OffscreenAnim
extends VisibleOnScreenNotifier3D
## Off screen, a body's animations move on in coarse steps.
##
## Every villager, monster and animal in a level has its own animation player,
## and each one poses a whole skeleton every frame, seen or not. In the village
## that is some eighty of them. A body nobody can see keeps doing everything it
## does (walking its route, working, fighting, noticing the hero: none of that
## waits for its animation), only its skeleton is posed every few ticks instead
## of every frame (EVERY). Its animations still reach their ends as before, so
## whatever waits for one (a throw, a hammer blow) happens on time, at most a
## few ticks late. The moment its box (with a margin for its shadow) comes into
## view, its animations are caught up and run every frame again.
##
## A body sets it up with `OffscreenAnim.watch(self)` in _ready. An animation
## player already driven by hand (callback mode manual, like a pet's) is left
## alone. Headless (the tests) nothing is ever on screen and nothing changes,
## unless a test calls rest() itself. Tested by tests/offscreen_anim.gd.

## Physics ticks between two steps of an unseen body's animations.
const EVERY := 6
## The box watched, for a body of size 1: wider and taller than a person, so a
## shadow or a raised arm at the edge of the screen counts as seen.
const BOX := AABB(Vector3(-2.0, -0.5, -2.0), Vector3(4.0, 4.5, 4.0))

## The animation players slowed down, each with its own callback mode to give back.
var _players: Array[AnimationPlayer] = []
var _modes: Array[int] = []
## Time gathered since the last step, and the ticks counted towards the next one.
var _held := 0.0
var _ticks := 0


## Watches `body`; `size` scales the box for big ones.
static func watch(body: Node3D, size := 1.0) -> OffscreenAnim:
	var n := OffscreenAnim.new()
	n.name = "OffscreenAnim"
	n.aabb = AABB(BOX.position * size, BOX.size * size)
	body.add_child(n)
	return n


## Whether its animations are stepped coarsely right now.
func resting() -> bool:
	return not _players.is_empty()


func _ready() -> void:
	set_physics_process(false)
	screen_entered.connect(wake)
	screen_exited.connect(rest)
	if DisplayServer.get_name() == "headless":
		return
	# A body that starts out of view never leaves the screen, so it never
	# hears screen_exited: look once it has been drawn a first time.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree() and not is_on_screen():
		rest()


## Out of view: its animations from now on step every few ticks.
func rest() -> void:
	if resting():
		return
	for p: Node in get_parent().find_children("*", "AnimationPlayer", true, false):
		var player := p as AnimationPlayer
		if player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
			continue
		_players.append(player)
		_modes.append(player.callback_mode_process)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_held = 0.0
	_ticks = 0
	set_physics_process(resting())


## In view again: its animations catch up and run every frame.
func wake() -> void:
	_step()
	for i in _players.size():
		if is_instance_valid(_players[i]):
			_players[i].callback_mode_process = _modes[i]
	_players.clear()
	_modes.clear()
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_held += delta
	_ticks += 1
	if _ticks >= EVERY:
		_step()


func _step() -> void:
	if _held > 0.0:
		for player in _players:
			if is_instance_valid(player):
				player.advance(_held)
	_held = 0.0
	_ticks = 0
