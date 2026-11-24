class_name SpringCave
extends RefCounted
## The cave behind the river's spring waterfall (see Waterfall and the map "Die Quellhöhle"):
##
## - There is no path to the porch behind the fall. The pool lies in front of it, and only in winter,
##   when the river is frozen (see Outdoor.set_ice), can the hero walk across it.
## - The frozen fall is a wall of ice over the porch. A climbing hammer in the hero's hand breaks a
##   doorway through it (run into the ice); without one, or in a thaw, there is nothing to be done.
## - Once the ice is open the porch is reachable. The way into the hill is disguised as the rock at the
##   porch's back (like every secret entrance: no dark opening, the walls around it are the same stone);
##   only the faint wave worn into one boulder gives it away. Running into it leads down.
## - The doorway stays open for the rest of the winter. When the fall thaws, the ice is gone and with it
##   the way in; the next frost closes the curtain again, and the hammer must be swung once more.
##
## The state is the entry `ID` in the treasure maps' saved state (see TreasureMaps), `OPEN` while the
## doorway stands. The hero who comes out of the cave in a thaw stands on the shore, not on the porch
## (see exit_point), so nobody is stranded behind open water.

## The cave's building id in its map header ("building: quelle1").
const ID := "quelle1"
const NAME := "die Quellhöhle"
## The stations: the wall of ice (before it is broken) and the boulder with the wave (after).
const KIND := "eisvorhang"
const PLUG := "quellfels"
## From how frozen the fall stands as a wall of ice; below THAW an open doorway is shut for good.
const FROZEN := 0.85
const THAW := 0.5
## How long the hammer swings.
const BREAK_TIME := 1.3
## Where the hero stands to break the ice, and the porch's back to run into: metres from the notch's middle.
const ICE_AT := Vector3(0, 0, 2.1)
const PLUG_AT := Vector3(0, 0, -0.7)
## The wall of ice: where it stands and its size (it fills the curtain, a hand deep).
const WALL_AT := Vector3(0, 0, Waterfall.CURTAIN_V - 0.1)
const WALL_SIZE := Vector3(Waterfall.CURTAIN_WIDTH, 4.0, 0.7)
## Tiles south of the notch to the shore in front of the pool.
const SHORE_TILES := 5
const ICE_CHIPS := Color(0.82, 0.93, 1.0)


static func is_open(lvl: Outdoor) -> bool:
	return lvl.treasure.get(ID, "") == TreasureMaps.OPEN


## Sets up the fall's wall and stations when it is built (see Waterfall.build).
static func attach(lvl: Outdoor, fall: Waterfall) -> void:
	sync(lvl, fall)


## Makes the world match the state: a wall of ice and its station while the doorway is shut; an open
## doorway and the boulder's station once it is open.
static func sync(lvl: Outdoor, fall: Waterfall) -> void:
	var open := is_open(lvl)
	if open and is_instance_valid(fall.wall):
		fall.wall.queue_free()
		fall.wall = null
	elif not open and not is_instance_valid(fall.wall):
		fall.wall = StaticBody3D.new()
		fall.wall.name = "Eiswand"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = WALL_SIZE
		shape.shape = box
		shape.position = WALL_AT + Vector3(0, WALL_SIZE.y * 0.5, 0)
		fall.wall.add_child(shape)
		fall.add_child(fall.wall)
	fall.set_doorway(open)
	for s in lvl.stations.duplicate():
		if s.kind == KIND or s.kind == PLUG:
			lvl.stations.erase(s)
	var at := ICE_AT if not open else PLUG_AT
	var pos := fall.position + at
	lvl.stations.append({"kind": PLUG if open else KIND, "cell": lvl.world_to_cell(pos), "pos": pos, "reach": 2.6, "used": false})
	lvl.doors[ID] = fall.position + Vector3(0, 0, 0.2)


## The fall's ice changed (see Waterfall.set_ice): in a thaw an open doorway closes for good.
static func on_ice(fall: Waterfall) -> void:
	var lvl := fall.get_parent() as Outdoor
	if lvl == null or fall.ice >= THAW or not is_open(lvl):
		return
	lvl.treasure.erase(ID)
	sync(lvl, fall)


## Where the hero stands coming out of the cave: on the porch while the doorway is open and the river
## frozen, otherwise on the shore in front of the pool.
static func exit_point(lvl: Outdoor, ice: float) -> Vector3:
	var fall: Waterfall = lvl.waterfall
	if fall == null:
		return lvl.doors.get(ID, Vector3.ZERO)
	if is_open(lvl) and ice >= THAW:
		return fall.position + Vector3(0, 0, 0.2)
	return fall.position + Vector3(0, 0, Level.TILE * SHORE_TILES)


## The hero ran into a station: the wall of ice, or the boulder with the wave.
static func use(game, s: Dictionary) -> void:
	var lvl: Outdoor = game.level
	if s.kind == PLUG:
		game.player.face(s.pos - game.player.global_position)
		game.player.play("Idle")
		Events.tell(Lang.t("Der Fels gibt unter deiner Hand nach: ein schmaler Gang führt in den Berg."), game.GOLD)
		game.go_inside(ID)
		return
	var fall: Waterfall = lvl.waterfall
	if fall == null:
		return
	if fall.ice < FROZEN:
		game.show_message(Lang.t("Das Wasser stürzt dir entgegen. Dahinter ist nur nasser Fels."), 3.0)
	elif not game.player.bag.has(Player.HAMMER) and game.player.equipped.get("waffe", "") != Player.HAMMER:
		game.show_message(Lang.t("Das Eis ist armdick und hart wie Stein. Mit bloßen Händen kommst du nicht hindurch."), 3.5)
	elif game.player.equipped.get("waffe", "") != Player.HAMMER:
		game.show_message(Lang.t("Das Eis ist hart wie Stein. Mit dem Kletterhammer in der Hand ließe es sich aufschlagen."), 3.5)
	else:
		_break_ice(game, lvl, fall, s)


## The hammer swings at the wall of ice: chips fly, and a doorway opens.
static func _break_ice(game, lvl: Outdoor, fall: Waterfall, s: Dictionary) -> void:
	game.player.path.clear()
	game.player.face(fall.position + WALL_AT - game.player.global_position)
	game.player.play_once("Interact", BREAK_TIME)
	Sfx.play(game, "chop")
	_chips(lvl, fall)
	game.get_tree().create_timer(BREAK_TIME * 0.55).timeout.connect(func():
		if is_instance_valid(lvl) and game.level == lvl:
			Sfx.play(game, "chop", -2.0)
			_chips(lvl, fall))
	game.get_tree().create_timer(BREAK_TIME).timeout.connect(func():
		if not is_instance_valid(lvl) or game.level != lvl or not is_instance_valid(fall):
			return
		lvl.treasure[ID] = TreasureMaps.OPEN
		sync(lvl, fall)
		_chips(lvl, fall)
		Sfx.play(game, "rumble", -6.0)
		Events.tell(Lang.t("Das Eis splittert! Hinter dem Wasserfall liegt ein schmaler Felsvorsprung."), game.GOLD))


static func _chips(lvl: Outdoor, fall: Waterfall) -> void:
	var chips := Effects.make_wood_chips(ICE_CHIPS)
	chips.position = fall.position + Vector3(0, 1.3, Waterfall.CURTAIN_V + 0.5)
	lvl.add_child(chips)
	chips.restart()
	chips.emitting = true
	lvl.get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(chips):
			chips.queue_free())


## The hint at the bottom of the screen: only the hero who can use it is told how.
static func prompt(game, s: Dictionary) -> String:
	if s.kind == PLUG:
		return Lang.t("Dagegenlaufen, um den Fels mit der Welle zu untersuchen")
	var fall: Waterfall = game.level.waterfall if game.level is Outdoor else null
	if fall != null and fall.ice >= FROZEN and game.player.equipped.get("waffe", "") == Player.HAMMER:
		return Lang.t("Dagegenlaufen, um das Eis aufzuschlagen")
	return ""
