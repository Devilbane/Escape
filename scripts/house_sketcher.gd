class_name HouseSketcher
extends Node3D
## The blueprint tool on the hero's plot (see Plots and HouseSketch). The
## blueprint button on the HUD opens it while the hero stands on their plot or
## near it (see toggle and Game._setup_blueprint_button). The hero then draws their house
## like a floor plan: drag along the grid to draw a wall, click a wall to turn
## it into a door or a window, click a piece with the eraser to take it back.
## A ghost shows what the next click does (green fits, red does not, and the
## message line says why), and undo and redo take edits back.
##
## The sketch is only a blueprint: faint, see-through pieces without collision.
## Building it solid is the character's work: the hero hands stone blocks and
## timber over in the tool, orders the build, and while they are near the plot
## the character turns one sketched piece after another solid (every BUILD_SECONDS),
## using up the material. Erasing a built piece marks it for demolition: the
## character takes it down and the material comes back. The stage banner shows
## the cycle: Plan, Build, Done, and Done leads back to Plan.
##
## Garden walls (two stone blocks high, of stone or timber) are drawn like
## walls, anywhere on the plot and free of the house; a door drawn on one
## becomes a gate. On the upper level the same tool draws the railing round a
## flat roof (see HouseSketch.RAIL_STOREY): drag it along the roof's edge, or
## click the roof once to ring all its open edges; the stairs keep their gap.
##
## A ballista (see HouseBallista) is set on one cell with a click: on the flat
## roof where one is planned, else on the ground. Built, it shoots at the slimes
## that come near; while the tool is open a circle shows how far it reaches.
##
## The tool bar sits at the bottom of the screen with fixed sizes, so a tool or
## a stage never reshapes it.

const KIND := "bauplan"
## Space kept free between the plot and the screen edges or the tool bar (pixels).
const FRAME_MARGIN := 24.0
## How far the camera may be pulled back to fit a big plot, and how fast (metres).
const FRAME_PULL_LIMIT := 90.0
const FRAME_PULL_STEP := 2.0
const TOOL_WALL := "wall"
const TOOL_DOOR := "door"
const TOOL_WINDOW := "window"
const TOOL_ERASE := "erase"
const TOOL_DIG := "dig"
## Stairs, down to the cellar or up to the upper floor: one tool, see _stairs_choice.
const TOOL_STAIRS := "stairs"
## The ground floor's floor, over the cellar its ceiling too (see HouseSketch.COVER).
const TOOL_COVER := "cover"
const TOOL_FENCE := "fence"
const TOOL_BALLISTA := "ballista"
## A ladder: on the level shown, up to a slab, or in the cellar up the pit wall (see HouseSketch.LADDER).
const TOOL_LADDER := "ladder"
const TOOLS := [TOOL_WALL, TOOL_DOOR, TOOL_WINDOW, TOOL_FENCE, TOOL_BALLISTA, TOOL_LADDER, TOOL_ERASE]
## Tools that drag a straight run of edges.
const RUN_TOOLS := [TOOL_WALL, TOOL_FENCE]
## The cellar's tools (their own row in the tool bar).
const CELLAR_TOOLS := [TOOL_DIG, TOOL_STAIRS, TOOL_COVER]
## Floors and roofs: they work on the level chosen with the level button (0
## ground floor, 1 upper floor, -1 cellar).
const TOOL_SLAB := "slab"
const TOOL_SADDLE := "saddle"
## The stairs up are the stairs tool on the ground or upper floor (kept as a
## name for callers; select_tool turns it into TOOL_STAIRS).
const TOOL_UP := "up"
const ROOF_TOOLS := [TOOL_SLAB, TOOL_SADDLE]
## Tools that drag a rectangle of cells.
const RECT_TOOLS := [TOOL_DIG, TOOL_COVER, TOOL_SLAB, TOOL_SADDLE]
const LEVEL_NAMES := {-1: "im Keller", 0: "im Erdgeschoss", 1: "im Obergeschoss"}
const SLAB_COLOR := Color(0.9, 0.75, 0.4, 0.7)
const ROOF_COLOR := Color(0.55, 0.22, 0.16)
## An empty house's old roof (see HouseSketch.abandoned): weathered grey, and moss on it.
const OLD_ROOF := Color(0.33, 0.27, 0.24)
const MOSS := Color(0.24, 0.32, 0.17)
const SURFACE_NAMES := {"": "roh", "stone": "aus Stein", "wood": "aus Holz"}
const COVER_COLOR := Color(0.75, 0.6, 0.35, 0.8)
const DIG_COLOR := Color(0.9, 0.55, 0.15, 0.8)
const STAIRS_COLOR := Color(1.0, 0.85, 0.3, 0.8)
const PLANK_COLOR := Color(0.5, 0.34, 0.18)
## A cellar's side wall reaches this far either side of the rim, and its top lies this far
## under the ground (see _solid_cellar).
const RIM_THICK := 0.2
const RIM_SINK := 0.01
## How wide the steps of built stairs are: a cell less the cellar walls beside them.
const STAIRS_WIDTH := HouseSketch.CELL - 0.2
const WALL_HEIGHT := 2.6
const THICK := 0.2
## How far two built surfaces that would lie in one plane are kept apart: two faces
## in the same place flicker through each other (z-fighting).
const FACE_GAP := 0.01
## How far a cellar wall stops under a cellar ceiling: inside the ceiling's
## thickness, so the ceiling hides its top.
const CEILING_GAP := HouseSketch.COVER_THICK * 0.5
## How far a cellar ceiling is drawn above the ground level it is walked on at (metres, see _cellar_ceiling).
const CEILING_LIFT := 0.02
## The doorway: high enough for the hero to walk through upright (2.4 m with
## their reach, see Player.tall), under a timber lintel up to the wall's top;
## stone jambs JAMB wide at each side.
const DOOR_HEIGHT := 2.4
const JAMB := 0.35
## The jambs of a doorway are slimmer, so the hero (1.1 m across) walks straight through with a hand's
## breadth to spare on each side and is never nudged sideways by the frame (a window keeps JAMB).
const DOOR_JAMB := 0.25
const SILL := 0.9
const WINDOW_TOP := 1.9
## How high the timber lintel over a built window is.
const WINDOW_LINTEL := 0.2
const GRID_COLOR := Color(0.7, 0.85, 1.0, 0.35)
const WALL_COLOR := Color(0.55, 0.75, 1.0, 0.4)
const DOOR_COLOR := Color(1.0, 0.8, 0.4, 0.55)
const WINDOW_COLOR := Color(0.6, 0.95, 1.0, 0.5)
const FENCE_COLOR := Color(0.7, 0.95, 0.55, 0.45)
const FENCE_NAMES := {"stone": "aus Stein", "wood": "aus Holz"}
const FENCE_THICK := 0.3
const GATE_POST := 0.3
## How high above the roof a railing stops the hero: higher than the railing
## itself, so a jump does not carry them over it.
const RAIL_GUARD := 2.2
const OK_COLOR := Color(0.4, 0.95, 0.4, 0.55)
const BAD_COLOR := Color(1.0, 0.4, 0.35, 0.55)
const STAGES := ["plan", "build", "done"]
const STAGE_NAMES := {"plan": "Planen", "build": "Bauen", "done": "Fertig"}
const ON_COLOR := Color(1.0, 0.82, 0.4)
const OFF_COLOR := Color(1, 1, 1, 0.4)
## Where a roof or slab sketch is drawn above the floor of its storey.
const SILL_TOP := 2.7
const STATUS_WIDTH := 880.0
## How wide each material button of row 2 is: room for the longest text in both languages.
const MATERIAL_WIDTH := 250.0
## The character builds one piece this often (seconds) while the hero is near
## the plot, and works only within this many metres of its middle.
const BUILD_SECONDS := 12.0
## Digging a square of the cellar goes faster than raising a wall.
const DIG_SECONDS := 3.0
const BUILD_RANGE := 16.0
const WOOD_COLOR := Color(0.4, 0.27, 0.15)
## What is left of the panes of an empty house: dull, dirty glass.
const BROKEN_GLASS := Color(0.32, 0.36, 0.36, 0.55)
const DEMOLISH_COLOR := Color(1.0, 0.45, 0.35, 0.6)
const BALLISTA_COLOR := Color(1.0, 0.6, 0.3, 0.6)
## How much thicker a ghost is drawn over a built piece on the same edge.
const GHOST_GROW := 0.12

var game: Node
var active := false
var tool := TOOL_WALL
var plan: HouseSketch
## Where the hero's own house keeps the weather out (see HouseGround.shelter): inside it, the
## blessing of its household goddess holds (see HouseholdGods.active).
var own_shelter := {}
## The node where a wall drag started, or (-1, -1).
var drag_from := Vector2i(-1, -1)
var _plot := Rect2i()
var _built := Node3D.new()
## The built pieces of every house on the map, drawn solid, and their collision.
var _solid := Node3D.new()
var _body := StaticBody3D.new()
var _work := 0.0
var _warned := false
var _order_button: Button
var _deposit_button: Button
var _stock_label: Label
var _ghost := Node3D.new()
var _grid := MeshInstance3D.new()
var _bar: PanelContainer
var _stage_labels := {}
var _tool_buttons := {}
var _undo_button: Button
## The two material buttons of row 2: what they set depends on the tool (see
## _materials); unused, a slot keeps its place but shows nothing.
var _mat_a: Button
var _mat_b: Button
var _level_button: Button
## The level the wall, door, window, eraser and roof tools work on.
var storey := 0
## Added to the height of everything drawn for the storey being drawn.
var _lift := 0.0
## The wall piece being built and where its wall runs on (see _hidden_faces).
var _piece_run := {}
## How far the garden wall piece being built reaches past its first and its last
## node (negative: it stops short of it), see _fence_run.
var _fence_ends := Vector2(FENCE_THICK * 0.5, FENCE_THICK * 0.5)
## Built roof cells by ground cell on the 2 m lattice: the highest storey whose ceiling is there.
var _covered := {}
var _fade_state := ""
var _redo_button: Button
var _status: Label
## Whether the slab being built is a flat roof under the open sky (see _floor_box).
var _open_roof := false
var _hover_key := ""
var _refresh_in := 0.0
var _frame_shift := Vector3.ZERO
var _frame_pending := false
## The furnishing tool (see HouseFurnisher) looks at one storey: while it is set, the storeys
## above it fade as if the hero stood inside on it (NO_VIEW: the hero's own place decides).
const NO_VIEW := -99
var view_storey := NO_VIEW
## The highest storey that shows now (the ones above have faded away), 99 when nothing fades.
var fade_storey := 99
## The built ballistae of every house on the map (see HouseBallista).
var _guns := Node3D.new()
## The door leaves of every built door and gate, by "plot|piece key".
var doors := {}
## The shutters of built windows, by "plot|piece key" (see BuiltShutters).
var shutters := {}
## The cells inside the house being drawn (see HouseGround.inside_cells), so a
## window knows which face of its wall is the outside.
var _inside_now := {}
var _new_shutters: BuiltShutters
## The leaf _solid_piece just made, for _redraw to hang.
var _new_door: BuiltDoor
## Which side of the wall being drawn is the outside (see _outside_of).
var _outside := 1.0
## Down in a cellar the surface hides and the cellar sits in earth (see CellarView).
var cellar_view := CellarView.new()
## The forgotten mine under the woods (see LostMine): shown only while the hero is down in a
## cellar, as it all lies under the ground. Its buried cells' walls and floors (_deep_walls;
## they stop the light like the houses' walls) and what lies about down there (_deep_props).
## The mine never changes, so it is drawn once (see _draw_mine), with the walls of its open
## shaft and the hut's floor in _mine_open (always shown) and its floors and ceilings in
## _mine_body; _mine_cache keeps what the houses' drawing collects from it. The bank's vault
## cellar (see BankVault) is drawn the same way, once, into the same layers.
var deep := Node3D.new()
var _deep_walls := Node3D.new()
var _deep_props: Node3D = null
var _mine_open := Node3D.new()
var _mine_body := StaticBody3D.new()
var _mine_cache := {}
var _vault_cache := {}
var _vault_props: Node3D = null
## The village's sewers (see Sewers), drawn the same way, once.
var _sewer_cache := {}
var _sewer_props: Node3D = null
## Where the next drawn box goes: the houses' own pieces, or the mine's.
var _into: Node3D = _solid
var _open_into: Node3D = _solid
## Whether the house being drawn stands empty (see HouseSketch.abandoned): dark, broken panes.
var _abandoned := false
## The forgotten mine's hut inside: dust, debris, cobwebs and a little cold light (see
## LostMine.furnish_hut), shown while the hero is up on the ground.
var _hut_props: Node3D


func _ready() -> void:
	add_child(_built)
	# The built house's walls, roofs and floors stop the light of its torches and
	# candles (see LightShadows).
	_solid.set_meta(LightShadows.WALL, true)
	add_child(_solid)
	add_child(_body)
	add_child(_ghost)
	add_child(_guns)
	_deep_walls.set_meta(LightShadows.WALL, true)
	deep.add_child(_deep_walls)
	_mine_open.set_meta(LightShadows.WALL, true)
	add_child(_mine_open)
	add_child(_mine_body)
	deep.visible = false
	add_child(deep)
	cellar_view.game = game
	add_child(cellar_view)
	_grid.visible = false
	add_child(_grid)
	_build_bar()
	refresh()


func _exit_tree() -> void:
	if is_instance_valid(_bar):
		_bar.queue_free()


# --- The character builds ---------------------------------------------------

func _process(delta: float) -> void:
	_update_fade()
	if deep.visible != cellar_view.active:
		deep.visible = cellar_view.active
	if _hut_props != null and _hut_props.visible == cellar_view.active:
		_hut_props.visible = not cellar_view.active
	if cellar_view.active and game.player != null and LostMine.holds(game.player.global_position):
		LostMine.entered(game)
	if cellar_view.active and game.player != null and Sewers.holds(game.player.global_position):
		Sewers.entered(game)
	if active:
		if _frame_pending:
			_frame_pending = false
			solve_frame()
		# The bag changes behind the open bar (blocks picked up, material handed in).
		_refresh_in -= delta
		if _refresh_in <= 0.0:
			_refresh_in = 0.25
			_update_bar()
	if plan == null or not plan.ordered or game.state != game.State.PLAYING or not game.player.can_act():
		return
	var middle := plan.node_world(plan.nodes().x / 2, plan.nodes().y / 2)
	if Vector2(game.player.global_position.x - middle.x, game.player.global_position.z - middle.z).length() > BUILD_RANGE + plan.nodes().length() * HouseSketch.CELL * 0.25:
		return
	_work += delta
	if _work < (DIG_SECONDS if plan.next_kind() == HouseSketch.DIG else BUILD_SECONDS):
		return
	_work = 0.0
	work_once()


## One piece of the character's work: builds or takes down a piece, and says so.
## Returns whether a piece was done.
func work_once() -> bool:
	if plan == null:
		return false
	var result := plan.build_next()
	if result.is_empty():
		_changed()
		return false
	if result.has("why"):
		if not _warned:
			_warned = true
			game.show_message(Lang.t("Dein Held wartet auf Material für den Bau: Gib Steinblöcke und Bauholz im Bauplan ab."), 5.0)
		_update_bar()
		return false
	_warned = false
	game.player.play_once("Interact", 0.55)
	Sfx.play(game, "swing", -4.0, node_pos(result.edge))
	if plan.stage() == "done":
		Events.tell(Lang.t("Dein Haus ist fertig gebaut. Skizziere neue Teile, wenn du es ändern willst."), Color(1.0, 0.82, 0.4))
	_changed()
	return true


func node_pos(edge: Array) -> Vector3:
	return plan.node_world(edge[0], edge[1])


# --- The plot ----------------------------------------------------------------

## Draws the hero's plan again (after a plot is registered or the plan changed).
func refresh() -> void:
	if game == null or not game.level is Outdoor:
		return
	_plot = Plots.plot_of(game.hero_name)
	if _plot.size == Vector2i.ZERO:
		plan = null
		_redraw()
		return
	if plan == null or plan.plot != _plot:
		plan = HouseSketch.of(game.hero_name, _plot)
	_redraw()


# --- Entering and leaving -----------------------------------------------------

## How many map cells round the plot the hero may stand for the blueprint
## button to work ("on or near the plot").
const NEAR_CELLS := 4
## Above this height (metres) the hero stands on an upper storey or a roof of a house.
const UP_HIGH := 1.0


## Whether the hero stands on their plot or within NEAR_CELLS of it.
func hero_near() -> bool:
	if plan == null or game == null or game.player == null or game.level == null or not game.level is Outdoor:
		return false
	var cell: Vector2i = game.level.world_to_cell(game.player.global_position)
	return _plot.grow(NEAR_CELLS).has_point(cell)


## Whether `pos` lies in the hero's own house: anywhere on their plot (on the ground floor,
## whatever walls or roof stand there), down in its cellar, or up on an upper storey or the
## roof. With `on_floor` it must also have
## something to stand on there as the house is built now: a dug cellar cell below the
## ground, a built slab or roof under an upper storey (see _covered). A saved game made
## there wakes up at that spot (see Game._built_house_spot).
func holds(pos: Vector3, on_floor := false) -> bool:
	if plan == null or game == null or game.level == null or not game.level is Outdoor:
		return false
	if not _plot.has_point(game.level.world_to_cell(pos)):
		return false
	if pos.y < CellarView.BELOW:
		var floors: HouseFloors = game.level.house_floors
		return floors != null and floors.node_at(pos).z == HouseFloors.CELLAR
	if pos.y > UP_HIGH:
		if not on_floor:
			return true
		var up := floori((pos.y + 0.2) / HouseSketch.STOREY_HEIGHT)
		return up <= 0 or int(_covered.get(HouseFloors.cell_of(pos), -2)) >= up - 1
	# On the ground of the plot: a house with an open doorway or no roof yet (which keeps
	# no weather out, see HouseGround.shelter) is still the hero's home.
	return true


## Whether the blueprint button shows: one of the two building tools is open,
## or the hero could open the blueprint tool from where they stand.
func can_show() -> bool:
	return active or (game != null and game.house_furnisher != null and game.house_furnisher.active) or hero_near()


## The blueprint button on the HUD: opens the blueprint tool, or closes it (or
## the furnishing tool, which is reached from the tool's "Einrichten" button)
## when one is open. Returns why it did nothing, or "".
func toggle() -> String:
	if active:
		leave()
		return ""
	if game.house_furnisher != null and game.house_furnisher.active:
		game.house_furnisher.leave()
		return ""
	if plan == null:
		return Lang.t("Du hast noch kein Grundstück. Das Amt der Krone trägt es dir ein.")
	if not hero_near():
		return Lang.t("Geh zu deinem Grundstück, um an deinem Haus zu bauen.")
	enter()
	return ""


## Opens the tool (the blueprint button, see toggle).
func enter() -> void:
	if plan == null:
		game.show_message(Lang.t("Du hast noch kein Grundstück. Das Amt der Krone trägt es dir ein."), 3.0)
		return
	active = true
	_frame_pending = true
	drag_from = Vector2i(-1, -1)
	if game.plot_marker != null:
		game.plot_marker.cancel()
	_grid.visible = true
	_bar.visible = true
	_show_ranges(true)
	_draw_grid()
	select_tool(TOOL_WALL)
	game.show_message(Lang.t("Bauplan: Ziehe Wände auf dem Raster. Das Haus darf kleiner sein als das Grundstück."), 4.0)
	_update_bar()


## Where the camera looks while the tool is open: the middle of the plot plus the
## shift `solve_frame` found (see Game._process). The shift and the pull-back are
## worked out once when the tool opens and then stay fixed, so the camera glides to
## one framing and the player's own zoom (the mouse wheel) works on top of it.
func view_centre() -> Vector3:
	var mid := plan.node_world(plan.nodes().x / 2, plan.nodes().y / 2)
	return mid + _frame_shift


## The part of the screen the plot may use: everything above the tool bar.
func _free_area(bar: Control = null) -> Rect2:
	var view: Rect2 = game.get_viewport().get_visible_rect()
	var top := view.end.y
	if bar == null:
		bar = _bar
	if bar != null and bar.visible:
		top = minf(top, bar.get_global_rect().position.y)
	return Rect2(view.position, Vector2(view.size.x, top - view.position.y)).grow(-FRAME_MARGIN)


## The size on screen of the plot's four corners from the camera as it stands now.
func _plot_extent() -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var n := plan.nodes()
	for corner in [Vector2i(0, 0), Vector2i(n.x, 0), Vector2i(0, n.y), n]:
		var p: Vector2 = game.camera.unproject_position(plan.node_world(corner.x, corner.y))
		lo = lo.min(p)
		hi = hi.max(p)
	return hi - lo


## Whether the whole plot is inside the free area on screen at the current camera.
func plot_fits() -> bool:
	if plan == null:
		return true
	var free := _free_area()
	var n := plan.nodes()
	for corner in [Vector2i(0, 0), Vector2i(n.x, 0), Vector2i(0, n.y), n]:
		if not free.has_point(game.camera.unproject_position(plan.node_world(corner.x, corner.y))):
			return false
	return true


## Works out, once, how far the camera must be pulled back for the whole plot to fit
## above the tool bar and how far it must shift to centre it there. The camera is put
## where it will be, measured, and put back within the same frame, so nothing is
## drawn from the trial positions and nothing here depends on where the camera was
## gliding from. (Measuring on the live camera every frame made it hunt back and
## forth: pulling back moved the corners, which asked for another correction.)
## `bar` is the tool bar to keep the plot above (the furnishing tool passes its own).
func solve_frame(bar: Control = null) -> void:
	_frame_shift = Vector3.ZERO
	game.frame_pull = 0.0
	if plan == null:
		return
	var cam: Camera3D = game.camera
	var saved := cam.global_position
	var mid := plan.node_world(plan.nodes().x / 2, plan.nodes().y / 2)
	var free := _free_area(bar)
	var pull := 0.0
	while pull <= FRAME_PULL_LIMIT:
		game.frame_pull = pull
		cam.global_position = mid + game._camera_offset()
		var extent := _plot_extent()
		if extent.x <= free.size.x and extent.y <= free.size.y:
			break
		pull += FRAME_PULL_STEP
	game.frame_pull = minf(pull, FRAME_PULL_LIMIT)
	cam.global_position = mid + game._camera_offset()
	# Move the view until the plot's middle sits in the middle of the free area; the
	# ground is seen at an angle, so a few rounds of correcting the error are needed.
	for round in 6:
		cam.global_position = mid + _frame_shift + game._camera_offset()
		var at = game._mouse_to_floor(cam.unproject_position(mid))
		var want = game._mouse_to_floor(free.get_center())
		if at == null or want == null:
			break
		_frame_shift += Vector3(at.x - want.x, 0.0, at.z - want.z)
	cam.global_position = saved


func leave() -> void:
	if not active:
		return
	active = false
	game.frame_pull = 0.0
	drag_from = Vector2i(-1, -1)
	_grid.visible = false
	_bar.visible = false
	_show_ranges(false)
	_clear(_ghost)
	if plan != null:
		plan.save(game.hero_name)


## Over to the furnishing tool, to put furniture down in the house.
func furnish() -> void:
	leave()
	if game.house_furnisher != null:
		game.house_furnisher.enter()


## Gives up the drag in progress (the mouse was let go off the ground).
func cancel_drag() -> void:
	drag_from = Vector2i(-1, -1)
	_clear(_ghost)


func select_tool(next: String) -> void:
	if next == TOOL_UP:
		next = TOOL_STAIRS
		if storey < 0:
			storey = 0
	tool = next
	# Garden walls stand on the ground, railings round the roof of the upper
	# level; there are none in the cellar.
	if next == TOOL_FENCE and storey < 0:
		storey = 0
	drag_from = Vector2i(-1, -1)
	_clear(_ghost)
	_update_bar()


# --- Input ---------------------------------------------------------------------

## A mouse button on the ground while the tool is open.
func mouse(point: Vector3, pressed: bool, button: int) -> void:
	if plan == null:
		return
	if button == MOUSE_BUTTON_RIGHT:
		if pressed:
			if drag_from.x >= 0:
				drag_from = Vector2i(-1, -1)
				_clear(_ghost)
			else:
				leave()
		return
	if button != MOUSE_BUTTON_LEFT:
		return
	if tool in ROOF_TOOLS and storey < 0:
		_say(Lang.t("Im Keller gibt es kein Dach: Stelle die Ebene auf das Erd- oder Obergeschoss."))
		return
	if tool in [TOOL_WALL, TOOL_DOOR, TOOL_WINDOW] and storey < 0:
		_say(Lang.t("Im Keller graben und verkleiden die Keller-Werkzeuge: Stelle die Ebene um."))
		return
	if tool == TOOL_LADDER:
		if pressed:
			var c := plan.cell_at(point)
			var choice := _ladder_choice(point)
			if choice[1] == "":
				_say(reason(choice[2]))
			else:
				plan.sketch_ladder(c.x, c.y, choice[1], choice[0])
				_changed()
				_say(Lang.t("Leiter vorgemerkt. Beauftrage den Bau: Dein Held baut sie dann."))
		return
	if tool == TOOL_BALLISTA:
		if pressed:
			var c := plan.cell_at(point)
			var up := plan.ballista_storey(c.x, c.y)
			var why := plan.problem_ballista(c.x, c.y, up)
			if why != "":
				_say(reason(why))
			else:
				plan.sketch_ballista(c.x, c.y, up)
				_changed()
				_say(Lang.t("Balliste vorgemerkt. Beauftrage den Bau: Dein Held baut sie dann."))
		return
	if tool in RECT_TOOLS:
		if pressed:
			drag_from = plan.cell_at(point)
			hover(point)
		elif drag_from.x >= 0:
			var cells := plan.cells_between(drag_from, plan.cell_at(point))
			var wide: bool = cells.size() > 0 and absi(cells[-1][0] - cells[0][0]) >= absi(cells[-1][1] - cells[0][1])
			drag_from = Vector2i(-1, -1)
			_clear(_ghost)
			var done := 0
			match tool:
				TOOL_DIG:
					done = plan.sketch_dig(cells)
				TOOL_COVER:
					done = plan.sketch_cover(cells)
				TOOL_SLAB:
					done = plan.sketch_roof(cells, HouseSketch.SLAB, storey)
				_:
					done = plan.sketch_roof(cells, HouseSketch.SADDLE, storey, "rx" if wide else "ry")
			_changed()
			if done == 0 and tool == TOOL_COVER:
				var why := "taken"
				for c in cells:
					var no: String = plan.problem_cover(c[0], c[1])
					if no == "stairs" or (no == "no dig" and why != "stairs"):
						why = no
				_say(reason(why) if why != "taken" else Lang.t("Dort ist schon gegraben oder gebaut."))
			elif done == 0:
				_say(Lang.t("Dort ist schon gegraben oder gebaut."))
			else:
				_say(Lang.t("%d Felder vorgemerkt. Beauftrage den Bau: Dein Held baut es dann.") % done)
		return
	if tool == TOOL_STAIRS:
		if pressed:
			var c := plan.cell_at(point)
			var choice := _stairs_choice(c)
			if choice[1] == "":
				var why := "no slab"
				if storey < 0:
					why = "no cellar"
					for d in HouseSketch.DOWN:
						if plan.problem_stairs(c.x, c.y, d) == "covered":
							why = "covered"
				_say(reason(why))
			else:
				if choice[0]:
					plan.sketch_upstairs(c.x, c.y, choice[1])
				else:
					plan.sketch_stairs(c.x, c.y, choice[1])
				_changed()
				_say(Lang.t("Treppe vorgemerkt. Beauftrage den Bau: Dein Held baut sie dann."))
		return
	if tool in RUN_TOOLS:
		if pressed:
			drag_from = plan.node_at(point)
			hover(point)
		elif drag_from.x >= 0:
			var run := plan.run_between(drag_from, plan.node_at(point))
			drag_from = Vector2i(-1, -1)
			_clear(_ghost)
			if run.is_empty():
				# A click without a drag on a flat roof rings it with a railing.
				if _railing():
					var c := plan.cell_at(point)
					var ringed := plan.ring_roof(c.x, c.y)
					_changed()
					if ringed < 0:
						_say(reason("no roof"))
					elif ringed == 0:
						_say(Lang.t("Das Dach hat schon rundum ein Geländer."))
					else:
						_say(Lang.t("Geländer rund um das Dach vorgemerkt: %d m.") % int(ringed * HouseSketch.CELL))
				return
			var n := plan.sketch(run, plan.fence_kind(), _fence_storey()) if tool == TOOL_FENCE else plan.sketch(run, HouseSketch.WALL, storey)
			_changed()
			if n == 0 and _railing():
				_say(reason(plan.problem(run[0][0], run[0][1], run[0][2], plan.fence_kind(), HouseSketch.RAIL_STOREY)))
			elif n == 0:
				_say(Lang.t("Dort steht schon eine Wand."))
		return
	if not pressed:
		return
	var edge := plan.edge_near(point, HouseSketch.CELL * 0.3) if tool == TOOL_ERASE else plan.edge_near(point)
	if tool == TOOL_ERASE and (edge.is_empty() or storey < 0 or plan.piece(edge[0], edge[1], edge[2], storey).is_empty()):
		var c := plan.cell_at(point)
		var key := _eraser_key(c)
		var was_built: bool = key != "" and plan.pieces[key].state == HouseSketch.BUILT
		var why_not := plan.erase_cell(c.x, c.y) if storey < 0 else plan.erase_above(c.x, c.y, storey)
		if why_not == "needed":
			_say(Lang.t("Die Treppe führt hierher: Nimm zuerst die Treppe zurück."))
		elif why_not == "ladder needed":
			_say(reason(why_not))
		elif why_not == "ballista":
			_say(reason("ballista"))
		elif why_not == "" and was_built:
			_say(Lang.t("Zum Abriss vorgemerkt: Dein Held reißt es ab und bekommt das Material zurück."))
		_changed()
		return
	if edge.is_empty():
		return
	if tool == TOOL_ERASE:
		var had := plan.piece(edge[0], edge[1], edge[2], storey)
		if plan.erase([edge], storey) > 0 and had.has("into"):
			_say(Lang.t("Umbau zurückgenommen: Das Stück bleibt, wie es gebaut ist."))
		elif had.get("state", "") == HouseSketch.BUILT and plan.piece(edge[0], edge[1], edge[2], storey).get("state", "") == HouseSketch.DEMOLISH:
			_say(Lang.t("Zum Abriss vorgemerkt: Dein Held reißt es ab und bekommt das Material zurück."))
		_changed()
		return
	var kind := plan.door_kind(edge[0], edge[1], edge[2], storey) if tool == TOOL_DOOR else tool
	var why := plan.problem(edge[0], edge[1], edge[2], kind, storey)
	if why != "":
		_say(reason(why))
		return
	var built: bool = plan.piece(edge[0], edge[1], edge[2], storey).get("state", "") == HouseSketch.BUILT
	plan.sketch([edge], kind, storey)
	_changed()
	if built:
		_say(Lang.t("Umbau vorgemerkt, ohne Material. Beauftrage den Bau: Dein Held baut es dann um.")
				if plan.piece(edge[0], edge[1], edge[2], storey).has("into") else Lang.t("Umbau zurückgenommen: Das Stück bleibt, wie es gebaut ist."))


## The ghost follows the mouse.
func hover(point: Vector3) -> void:
	if not active or plan == null:
		return
	var key := ""
	if tool == TOOL_LADDER:
		var c := plan.cell_at(point)
		var choice := _ladder_choice(point)
		key = "l:%s:%s:%d" % [c, choice[1], storey]
		if key == _hover_key:
			return
		_hover_key = key
		_clear(_ghost)
		var high := maxf(0.0, choice[0]) * HouseSketch.STOREY_HEIGHT + 0.08
		if choice[1] == "":
			_cell_quad(_ghost, c, BAD_COLOR, high)
			_say(reason(choice[2]))
		else:
			_cell_quad(_ghost, c, OK_COLOR, high)
			_cell_quad(_ghost, HouseSketch.ladder_top(c.x, c.y, HouseSketch.LADDER_ORIENTS[choice[1]]), OK_COLOR,
					(choice[0] + 1) * HouseSketch.STOREY_HEIGHT + 0.08 if choice[0] >= 0 else 0.08)
			_say("")
		return
	if tool == TOOL_BALLISTA:
		var c := plan.cell_at(point)
		key = "b:%s" % c
		if key == _hover_key:
			return
		_hover_key = key
		_clear(_ghost)
		var up := plan.ballista_storey(c.x, c.y)
		var why := plan.problem_ballista(c.x, c.y, up)
		var high := up * HouseSketch.STOREY_HEIGHT
		_cell_quad(_ghost, c, OK_COLOR if why == "" else BAD_COLOR, high)
		if why == "":
			_range_ring(_ghost, plan.cell_world(c.x, c.y) + Vector3(0, high, 0))
		_say(reason(why) if why != "" else Lang.t("Balliste: Sie schießt auf Schleime bis %d m weit (der Kreis).") % int(HouseBallista.RANGE))
		return
	if tool in RECT_TOOLS or tool == TOOL_STAIRS:
		var c := plan.cell_at(point)
		var from_cell := drag_from if drag_from.x >= 0 and tool in RECT_TOOLS else c
		key = "c:%s:%s:%d" % [from_cell, c, storey]
		if key == _hover_key:
			return
		_hover_key = key
		_clear(_ghost)
		var high := 0.0 if tool in CELLAR_TOOLS else storey * HouseSketch.STOREY_HEIGHT + SILL_TOP
		if tool in RECT_TOOLS:
			var cells := plan.cells_between(from_cell, c)
			for cell in cells:
				var why_not := plan.problem_dig(cell[0], cell[1]) if tool == TOOL_DIG else (plan.problem_cover(cell[0], cell[1]) if tool == TOOL_COVER
						else plan.problem_roof(cell[0], cell[1], storey))
				_cell_quad(_ghost, Vector2i(cell[0], cell[1]), OK_COLOR if why_not == "" else BAD_COLOR, high)
			_say(Lang.t("%d Felder") % cells.size() if drag_from.x >= 0 else "")
		else:
			var dir: String = _stairs_choice(c)[1]
			if dir == "":
				_cell_quad(_ghost, c, BAD_COLOR)
			else:
				for cell in HouseSketch.stairs_cells(c.x, c.y, dir).slice(0, 2):
					_cell_quad(_ghost, cell, OK_COLOR)
			_say("")
		return
	if tool in RUN_TOOLS:
		var to := plan.node_at(point)
		var from := drag_from if drag_from.x >= 0 else to
		var rail := _railing()
		var cell := plan.cell_at(point)
		key = "w:%s:%s:%s:%s" % [from, to, rail, cell if rail else Vector2i.ZERO]
		if key == _hover_key:
			return
		_hover_key = key
		_clear(_ghost)
		var fence := tool == TOOL_FENCE
		_lift = _fence_storey() * HouseSketch.STOREY_HEIGHT if fence else storey * HouseSketch.STOREY_HEIGHT
		if drag_from.x >= 0:
			var run := plan.run_between(from, to)
			for e in run:
				var fits := not rail or plan.problem(e[0], e[1], e[2], plan.fence_kind(), HouseSketch.RAIL_STOREY) == ""
				_segment(_ghost, e, plan.fence_kind() if fence else HouseSketch.WALL, OK_COLOR if fits else BAD_COLOR)
			var label := "Wand: %d m"
			if fence:
				label = "Geländer: %d m" if rail else "Gartenmauer: %d m"
			_say(Lang.t(label) % int(run.size() * HouseSketch.CELL) if not run.is_empty() else "")
		elif rail:
			# Over a flat roof the ghost shows the ring a click would draw.
			var ring := plan.ring_edges(cell.x, cell.y)
			for e in ring:
				_segment(_ghost, e, plan.fence_kind(), OK_COLOR)
			_marker(_ghost, to)
			_say(Lang.t("Klicken: Geländer rund um das Dach (%d m).") % int(ring.size() * HouseSketch.CELL) if not ring.is_empty() else "")
		else:
			_marker(_ghost, to)
		_lift = 0.0
		return
	var edge := plan.edge_near(point, HouseSketch.CELL * 0.3) if tool == TOOL_ERASE else plan.edge_near(point)
	key = "e:%s:%d" % [edge, storey]
	if key == _hover_key:
		return
	_hover_key = key
	_clear(_ghost)
	var piece_here: Dictionary = {} if edge.is_empty() else plan.piece(edge[0], edge[1], edge[2], storey)
	if tool == TOOL_ERASE and (edge.is_empty() or piece_here.is_empty()):
		var cell := plan.cell_at(point)
		var cell_key := _eraser_key(cell)
		if cell_key != "":
			_cell_quad(_ghost, cell, DEMOLISH_COLOR, 0.0 if storey < 0 else storey * HouseSketch.STOREY_HEIGHT + SILL_TOP)
		_say("")
		return
	if edge.is_empty():
		_say("")
		return
	_lift = storey * HouseSketch.STOREY_HEIGHT
	if tool == TOOL_ERASE:
		if piece_here.has("into"):
			# The eraser calls the rebuild off first.
			_segment(_ghost, edge, piece_here.into, OK_COLOR, GHOST_GROW)
			_lift = 0.0
			_say(Lang.t("Klicken: Umbau zurücknehmen."))
			return
		_segment(_ghost, edge, piece_here.get("kind", HouseSketch.WALL), DEMOLISH_COLOR if piece_here.state != HouseSketch.SKETCH else OK_COLOR)
		_lift = 0.0
		return
	var kind := plan.door_kind(edge[0], edge[1], edge[2], storey) if tool == TOOL_DOOR else tool
	var why := plan.problem(edge[0], edge[1], edge[2], kind, storey)
	var rebuild: bool = why == "" and piece_here.get("state", "") == HouseSketch.BUILT
	# Over a built wall the ghost is a little thicker, so it shows on the stone.
	_segment(_ghost, edge, kind, OK_COLOR if why == "" else BAD_COLOR, GHOST_GROW if not piece_here.is_empty() and piece_here.state != HouseSketch.SKETCH else 0.0)
	_lift = 0.0
	if rebuild:
		_say(_rebuild_text(kind, piece_here))
	else:
		_say(reason(why) if why != "" else "")


## What a click with the door or window tool on a built piece does.
func _rebuild_text(kind: String, here: Dictionary) -> String:
	if kind == here.kind:
		return Lang.t("Klicken: Umbau zurücknehmen.")
	match kind:
		HouseSketch.DOOR:
			return Lang.t("Klicken: Dein Held baut hier eine Tür ein, ohne Material und ohne Abriss.")
		HouseSketch.WINDOW:
			return Lang.t("Klicken: Dein Held baut hier ein Fenster ein, ohne Material und ohne Abriss.")
	return Lang.t("Klicken: Dein Held baut hier ein Gartentor ein, ohne Material und ohne Abriss.")


## The key of the cell piece the eraser takes at a cell on the current level, or "":
## in the cellar the ceiling, then the dug cell or stairs; above, the slab or roof,
## on the ground floor then the stairs up, then the cellar ceiling (its floor).
func _eraser_key(c: Vector2i) -> String:
	var cover := HouseSketch.key_of(c.x, c.y, HouseSketch.COVER_ORIENT, HouseSketch.CELLAR_STOREY)
	if storey < 0:
		if plan.pieces.has(cover) and plan.pieces[cover].state != HouseSketch.DEMOLISH:
			return cover
		if plan.ladder_key(c.x, c.y, storey) != "":
			return plan.ladder_key(c.x, c.y, storey)
		return plan.hole_key(c.x, c.y)
	if not plan.ballista_at(c.x, c.y, storey).is_empty():
		return HouseSketch.key_of(c.x, c.y, HouseSketch.BALLISTA_ORIENT, storey)
	if plan.ladder_key(c.x, c.y, storey) != "":
		return plan.ladder_key(c.x, c.y, storey)
	if plan.roof_key(c.x, c.y, storey) != "":
		return plan.roof_key(c.x, c.y, storey)
	if storey == 0 and plan.up_key(c.x, c.y) != "":
		return plan.up_key(c.x, c.y)
	if storey == 0 and plan.pieces.has(cover):
		return cover
	return ""


static func reason(why: String) -> String:
	match why:
		"outside":
			return Lang.t("Das liegt außerhalb deines Grundstücks.")
		"needs wall":
			return Lang.t("Hier fehlt eine Wand: Zeichne erst die Wand.")
		"needs fence":
			return Lang.t("Ein Gartentor braucht eine Gartenmauer.")
		"garden storey":
			return Lang.t("Gartenmauern stehen auf dem Boden.")
		"no roof":
			return Lang.t("Ein Geländer steht am Rand einer Decke oder eines Flachdachs.")
		"stairs edge":
			return Lang.t("Hier kommt die Treppe an: Lass den Rand offen oder setze ein Tor.")
		"railing":
			return Lang.t("Oben steht dort ein Geländer: Nimm es zurück oder mach ein Tor daraus.")
		"built":
			return Lang.t("Das ist schon gebaut. Reiß es mit dem Radierer ab, um es zu ändern.")
		"taken":
			return Lang.t("Dort ist schon gegraben oder gebaut.")
		"no cellar":
			return Lang.t("Eine Treppe braucht zwei freie Felder und danach einen gegrabenen Keller.")
		"no slab":
			return Lang.t("Eine Treppe nach oben braucht zwei freie Felder und danach eine Decke.")
		"no dig":
			return Lang.t("Dieses Feld wird zugeschüttet: Dort kommt kein Boden hin.")
		"stairs":
			return Lang.t("Über der Kellertreppe und an ihrem Fuß bleibt der Boden offen, damit du aufrecht hinabsteigen kannst.")
		"covered":
			return Lang.t("Über dem Fuß der Treppe liegt ein Boden: Nimm ihn dort erst zurück.")
		"storey":
			return Lang.t("Höher als das Obergeschoss baut dein Held nicht.")
		"under roof":
			return Lang.t("Eine Balliste braucht freien Himmel: Stell sie in den Garten oder auf ein Flachdach.")
		"ballista no roof":
			return Lang.t("Auf dem Obergeschoss steht eine Balliste auf einem Flachdach.")
		"many":
			return Lang.t("Mehr als %d Ballisten passen nicht auf ein Grundstück.") % HouseSketch.MAX_BALLISTAE
		"ballista":
			return Lang.t("Auf dem Dach steht eine Balliste: Nimm sie zuerst zurück (Ebene: Obergeschoss).")
		"ladder":
			return Lang.t("Über einer Leiter im Keller bleibt der Boden offen.")
		"ladder needed":
			return Lang.t("Eine Leiter lehnt hier oder steht darauf: Nimm zuerst die Leiter zurück.")
		"ladder no slab":
			return Lang.t("Eine Leiter lehnt an einer Decke oder einem Flachdach: Klicke ein Feld daneben an, nahe an ihrem Rand.")
		"ladder no cellar":
			return Lang.t("Im Keller steht eine Leiter in einem gegrabenen Feld an der Grubenwand.")
		"ladder covered":
			return Lang.t("Über diesem Kellerfeld liegt ein Boden: Dort kommt keine Leiter hinauf.")
		"ladder no roof":
			return Lang.t("Auf dem Obergeschoss steht eine Leiter auf einem Flachdach.")
		"no ledge":
			return Lang.t("Oben an der Leiter muss fester Boden sein, keine Grube oder Treppe.")
	return ""


func _changed() -> void:
	plan.save(game.hero_name)
	_hover_key = ""
	_redraw()
	_update_bar()


func undo() -> void:
	if plan != null and plan.undo():
		_changed()


func redo() -> void:
	if plan != null and plan.redo():
		_changed()


# --- The tool bar --------------------------------------------------------------

## The tool bar is small so most of the screen stays free to draw on: three
## rows of small buttons (what to draw; level, surfaces and undo; the build
## and the stage) and two lines of text. Every button keeps its size, only
## texts change.
func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.visible = false
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.offset_bottom = -8
	var style := UiKit.panel_style(UiKit.BRONZE)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_bar.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_bar.add_child(box)
	# Row 1: what to draw. Walls, doors and windows; floors and roofs; the cellar; the eraser.
	var tools := _row(box)
	var names := {TOOL_WALL: "Wand", TOOL_DOOR: "Tür", TOOL_WINDOW: "Fenster", TOOL_FENCE: "Gartenmauer", TOOL_BALLISTA: "Balliste", TOOL_LADDER: "Leiter", TOOL_ERASE: "Radierer"}
	var roof_names := {TOOL_SLAB: "Decke oder Flachdach", TOOL_SADDLE: "Satteldach", TOOL_STAIRS: "Treppe hinauf"}
	var cellar_names := {TOOL_DIG: "Keller graben", TOOL_COVER: "Boden"}
	for t in [TOOL_WALL, TOOL_DOOR, TOOL_WINDOW, TOOL_FENCE, TOOL_SLAB, TOOL_SADDLE, TOOL_STAIRS, TOOL_LADDER, TOOL_DIG, TOOL_COVER, TOOL_BALLISTA, TOOL_ERASE]:
		var label: String = names.get(t, roof_names.get(t, cellar_names.get(t, "")))
		var b := _small_button(Lang.t(label), select_tool.bind(t))
		tools.add_child(b)
		_tool_buttons[t] = b
	# Row 2: the level the tools work on, the materials of the selected tool
	# (two slots of fixed width, see _materials), undo and redo.
	var options := _row(box)
	_level_button = _small_button("", cycle_level, 210)
	options.add_child(_level_button)
	_mat_a = _small_button("", _press_material.bind(0), MATERIAL_WIDTH)
	options.add_child(_mat_a)
	_mat_b = _small_button("", _press_material.bind(1), MATERIAL_WIDTH)
	options.add_child(_mat_b)
	_undo_button = _small_button(Lang.t("Rückgängig"), undo)
	options.add_child(_undo_button)
	_redo_button = _small_button(Lang.t("Wiederholen"), redo)
	options.add_child(_redo_button)
	# Row 3: where the plan stands, and the build.
	var actions := _row(box)
	for i in STAGES.size():
		if i > 0:
			var arrow: Label = UiKit.label(UiKit.TEXT_FONT, 14, OFF_COLOR)
			arrow.text = "▸"
			actions.add_child(arrow)
		var l: Label = UiKit.label(UiKit.TEXT_FONT, 15, OFF_COLOR)
		l.text = Lang.t(STAGE_NAMES[STAGES[i]])
		l.custom_minimum_size = Vector2(60, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		actions.add_child(l)
		_stage_labels[STAGES[i]] = l
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	actions.add_child(gap)
	_deposit_button = _small_button(Lang.t("Material abgeben"), deposit_materials, 150)
	actions.add_child(_deposit_button)
	_order_button = _small_button(Lang.t("Bau beauftragen"), toggle_order, 150)
	actions.add_child(_order_button)
	# Into the furnishing tool (see HouseFurnisher): the furniture bought from the furnisher.
	actions.add_child(_small_button(Lang.t("Einrichten"), furnish, 120))
	var done := _small_button(Lang.t("Schließen"), leave)
	actions.add_child(done)
	_stock_label = _line(Color(0.8, 0.9, 1.0))
	box.add_child(_stock_label)
	_status = _line(Color(1.0, 0.75, 0.5))
	box.add_child(_status)
	if game != null and game._hud != null:
		game._hud.add_child(_bar)
	else:
		add_child(_bar)


## A row of the bar. Its buttons stand 4 px apart (the house spacing scale), so
## the tool row with every tool still fits 1280 px in German.
func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	return row


## A small button: low, with small text, and at least `width` wide.
func _small_button(text: String, action: Callable, width := 0.0) -> Button:
	var b: Button = UiKit.button(text, action)
	b.custom_minimum_size = Vector2(width, 32)
	b.add_theme_font_size_override("font_size", 14)
	return b


## A one-line text of the bar: it keeps its height and clips what does not fit.
func _line(colour: Color) -> Label:
	var l: Label = UiKit.label(UiKit.TEXT_FONT, 14, colour)
	l.custom_minimum_size = Vector2(STATUS_WIDTH, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _update_bar() -> void:
	if _bar == null:
		return
	var stage := plan.stage() if plan != null else "plan"
	for s in STAGES:
		_stage_labels[s].add_theme_color_override("font_color", ON_COLOR if s == stage else OFF_COLOR)
	for t in TOOLS + CELLAR_TOOLS + ROOF_TOOLS:
		var b: Button = _tool_buttons[t]
		var on: bool = t == tool
		b.add_theme_color_override("font_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
		b.add_theme_color_override("font_hover_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed") if on else b.get_theme_stylebox("hover"))
	_undo_button.disabled = plan == null or not plan.can_undo()
	_redo_button.disabled = plan == null or not plan.can_redo()
	if plan != null:
		_level_button.text = Lang.t("Ebene: %s") % Lang.t(LEVEL_NAMES[storey])
		var mats := _materials()
		for i in 2:
			var b: Button = [_mat_a, _mat_b][i]
			var used: bool = i < mats.size()
			b.text = mats[i][0] if used else ""
			# An unused slot keeps its place, so nothing in the row moves.
			b.disabled = not used
			b.modulate.a = 1.0 if used else 0.0
			b.focus_mode = Control.FOCUS_ALL if used else Control.FOCUS_NONE
			b.mouse_filter = Control.MOUSE_FILTER_STOP if used else Control.MOUSE_FILTER_IGNORE
		# The garden wall tool is called "railing" on the upper level: its button
		# is as wide as the longer name, so the row does not move.
		var fence_tool: Button = _tool_buttons[TOOL_FENCE]
		for label in ["Geländer", "Gartenmauer"]:
			fence_tool.text = Lang.t(label)
			fence_tool.custom_minimum_size.x = maxf(fence_tool.custom_minimum_size.x, fence_tool.get_combined_minimum_size().x)
		fence_tool.text = Lang.t("Geländer") if storey == HouseSketch.RAIL_STOREY else Lang.t("Gartenmauer")
		# The stairs tool says which way it goes on this level, as wide as its longer name.
		var stairs_tool: Button = _tool_buttons[TOOL_STAIRS]
		for label in ["Treppe hinab", "Treppe hinauf"]:
			stairs_tool.text = Lang.t(label)
			stairs_tool.custom_minimum_size.x = maxf(stairs_tool.custom_minimum_size.x, stairs_tool.get_combined_minimum_size().x)
		stairs_tool.text = _stairs_name()
		_status.text = _hint()
		var have := plan.stock
		var short := plan.missing()
		_stock_label.text = Lang.t("Vorrat: %d Steinblöcke, %d Bauholz. Es fehlen noch: %d Steinblöcke, %d Bauholz.") % [
				int(have.get(HouseSketch.STONE, 0)), int(have.get(HouseSketch.TIMBER, 0)),
				int(short.get(HouseSketch.STONE, 0)), int(short.get(HouseSketch.TIMBER, 0))]
		_order_button.text = Lang.t("Bau anhalten") if plan.ordered else Lang.t("Bau beauftragen")
		_order_button.disabled = not plan.ordered and plan.open_pieces() == 0
		var carried: int = game.player.bag.count(HouseSketch.STONE) + game.player.bag.count(HouseSketch.TIMBER)
		_deposit_button.disabled = carried == 0


## The level the tools work on: the ground floor, the upper floor, the cellar.
func cycle_level() -> void:
	storey = {0: 1, 1: -1, -1: 0}[storey]
	_hover_key = ""
	_clear(_ghost)
	_update_bar()


## The surface the next dug cells get on their floor; "roh" leaves the earth bare.
func cycle_floor() -> void:
	if plan == null:
		return
	plan.floor_surface = _next_surface(plan.floor_surface)
	_changed()


func cycle_wall() -> void:
	if plan == null:
		return
	plan.wall_surface = _next_surface(plan.wall_surface)
	_changed()


## The material settings of the selected tool, as [text, action] (at most two):
## digging sets the cellar's floor and walls, the floor tool its wood or stone,
## the garden wall tool (a railing up on a roof) its stone or timber. The other
## tools have none.
func _materials() -> Array:
	match tool:
		TOOL_DIG:
			return [[Lang.t("Kellerboden: %s") % Lang.t(SURFACE_NAMES[plan.floor_surface]), cycle_floor],
					[Lang.t("Kellerwände: %s") % Lang.t(SURFACE_NAMES[plan.wall_surface]), cycle_wall]]
		TOOL_COVER:
			return [[Lang.t("Boden: %s") % Lang.t(SURFACE_NAMES[plan.ceiling_surface]), cycle_ceiling]]
		TOOL_FENCE:
			var name := Lang.t("Geländer: %s") if storey == HouseSketch.RAIL_STOREY else Lang.t("Gartenmauer: %s")
			return [[name % Lang.t(FENCE_NAMES[plan.fence_material]), cycle_fence]]
	return []


func _press_material(slot: int) -> void:
	if plan == null:
		return
	var mats := _materials()
	if slot < mats.size():
		(mats[slot][1] as Callable).call()


## What the next floor is made of: wood or stone, never bare earth.
func cycle_ceiling() -> void:
	if plan == null:
		return
	plan.ceiling_surface = HouseSketch.CEILINGS[(HouseSketch.CEILINGS.find(plan.ceiling_surface) + 1) % HouseSketch.CEILINGS.size()]
	_changed()


## What the next garden walls are made of: stone or timber.
func cycle_fence() -> void:
	if plan == null:
		return
	plan.fence_material = "wood" if plan.fence_material == "stone" else "stone"
	_changed()


func _next_surface(now: String) -> String:
	return HouseSketch.SURFACES[(HouseSketch.SURFACES.find(now) + 1) % HouseSketch.SURFACES.size()]


## The hero hands over the stone blocks and timber in their bag.
func deposit_materials() -> void:
	if plan == null:
		return
	var moved := 0
	for id in HouseSketch.MATERIALS:
		var n: int = game.player.bag.count(id)
		for i in n:
			game.player.bag.erase(id)
		plan.deposit(id, n)
		moved += n
	if moved == 0:
		_say(Lang.t("Du trägst weder Steinblöcke noch Bauholz."))
		return
	Sfx.play(game, "gear_soft_0", -2.0)
	game._update_hud()
	plan.save(game.hero_name)
	# The bag and the plot's stock must agree, or the material could be had twice.
	game.save_game()
	_say(Lang.t("%d Stück Material abgegeben.") % moved)
	_update_bar()


## The order to build, or the order to stop.
func toggle_order() -> void:
	if plan == null:
		return
	if plan.ordered:
		plan.ordered = false
		_say(Lang.t("Der Bau ruht."))
	elif plan.order():
		_work = BUILD_SECONDS
		_warned = false
		_say(Lang.t("Dein Held baut, solange du in der Nähe bist."))
	plan.save(game.hero_name)
	_update_bar()


func _hint() -> String:
	match tool:
		TOOL_WALL:
			return Lang.t("Wand: Maustaste halten und auf dem Raster ziehen. Rechtsklick oder Esc beendet.")
		TOOL_DOOR:
			return Lang.t("Tür: Klicke eine Wand an, auch eine schon gebaute. In einer Gartenmauer wird sie zum Gartentor.")
		TOOL_FENCE:
			if storey == HouseSketch.RAIL_STOREY:
				return Lang.t("Geländer: Klicke auf ein Flachdach, um es rundum einzufassen, oder ziehe es am Rand entlang. An der Treppe bleibt eine Lücke.")
			return Lang.t("Gartenmauer: Ziehe sie frei auf dem Grundstück, zwei Blöcke hoch. Eine Tür darin wird zum Tor.")
		TOOL_WINDOW:
			return Lang.t("Fenster: Klicke eine Wand an, auch eine schon gebaute.")
		TOOL_DIG:
			return Lang.t("Graben: Maustaste halten, Rechteck aufziehen, loslassen. Rechtsklick oder Esc beendet.")
		TOOL_STAIRS:
			if storey < 0:
				return Lang.t("Treppe hinab: Klicke ein Feld vor dem Keller an. Sie führt vier Meter nach unten. Für eine Treppe hinauf stelle die Ebene um.")
			return Lang.t("Treppe hinauf: Klicke ein Feld vor einer Decke an. Sie führt vier Meter hinauf. Für eine Treppe in den Keller stelle die Ebene auf den Keller.")
		TOOL_COVER:
			return Lang.t("Boden: Ziehe ein Rechteck im Haus. Über dem Keller ist er zugleich die Kellerdecke.")
		TOOL_SLAB:
			return Lang.t("Decke: Ziehe ein Rechteck. Sie ist Boden des Stockwerks darüber oder ein begehbares Flachdach.")
		TOOL_SADDLE:
			return Lang.t("Satteldach: Ziehe ein Rechteck. Der First läuft entlang der langen Seite.")
		TOOL_BALLISTA:
			return Lang.t("Balliste: Klicke ein Feld im Garten oder auf einem Flachdach an. Sie kostet 6 Bauholz und 2 Steinblöcke.")
		TOOL_LADDER:
			return Lang.t("Leiter: Klicke ein Feld neben einer Decke an, nahe am Rand, oder im Keller an der Grubenwand. 1 Bauholz. Begleiter nehmen die Treppe.")
	return Lang.t("Radierer: Klicke ein Stück an, um es zurückzunehmen.")


## Which ladder a click at `point` puts, as [storey, direction, why not]: on
## the level shown (the cellar's when it fits only there, from the ground floor),
## leaning on the cell edge nearest the click that takes it. The direction is ""
## when none fits, with the reason for the nearest edge.
func _ladder_choice(point: Vector3) -> Array:
	var c := plan.cell_at(point)
	var mid := plan.cell_world(c.x, c.y)
	var prefer := Vector2(point.x - mid.x, point.z - mid.z)
	var storeys := [storey]
	if storey == 0:
		storeys.append(HouseSketch.CELLAR_STOREY)
	elif storey == HouseSketch.CELLAR_STOREY:
		storeys.append(0)
	for s in storeys:
		var dir := plan.ladder_dir(c.x, c.y, s, prefer)
		if dir != "":
			return [s, dir, ""]
	var nearest := "e"
	for dir in HouseSketch.DOWN:
		if prefer.dot(Vector2(HouseSketch.DOWN[dir])) > prefer.dot(Vector2(HouseSketch.DOWN[nearest])):
			nearest = dir
	var why := plan.problem_ladder(c.x, c.y, nearest, storey)
	return [storey, "", "ladder " + why if why in ["no slab", "no cellar", "covered", "no roof"] else why]


## Which stairs a click on cell c puts, as [up, direction] (direction "" when
## none fits): the level says which way first (down from the cellar level, up
## from the ground or upper floor), and when only the other way fits there,
## that one, so a click in front of the cellar or a slab always does the obvious.
func _stairs_choice(c: Vector2i) -> Array:
	var down := plan.stairs_dir(c.x, c.y)
	var up := plan.upstairs_dir(c.x, c.y)
	if storey < 0:
		return [false, down] if down != "" or up == "" else [true, up]
	return [true, up] if up != "" or down == "" else [false, down]


## The stairs tool's name on the level shown: down on the cellar level, up above.
func _stairs_name() -> String:
	return Lang.t("Treppe hinab") if storey < 0 else Lang.t("Treppe hinauf")


## Whether the garden wall tool draws railings round the roof now.
func _railing() -> bool:
	return tool == TOOL_FENCE and storey == HouseSketch.RAIL_STOREY


## The storey the garden wall tool draws on: the ground, or the roof's edge.
func _fence_storey() -> int:
	return HouseSketch.RAIL_STOREY if _railing() else 0


## How high a garden wall or railing is: pieces of the kind are drawn on the
## ground, or with a lift on the roof, where they are railings.
func _fence_high() -> float:
	return HouseSketch.RAIL_HEIGHT if _lift > 0.0 else HouseSketch.FENCE_HEIGHT


func _say(text: String) -> void:
	if _status != null:
		_status.text = text if text != "" else _hint()


# --- Drawing -------------------------------------------------------------------

func _clear(node: Node3D) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
	_hover_key = ""


func _redraw() -> void:
	var was := {}
	for k in doors:
		if is_instance_valid(doors[k]):
			was[k] = doors[k].state()
	doors.clear()
	shutters.clear()
	_clear(_built)
	_clear(_solid)
	for gun in _guns.get_children():
		_guns.remove_child(gun)
		gun.queue_free()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if game == null or not game.level is Outdoor:
		return
	game.level.reach_walls.clear()
	game.level.built_windows.clear()
	game.level.built_floors.clear()
	# Everyone's built pieces stand on the map for all to see.
	var holes := []
	var floored := []
	var ceilinged := []
	var built_ground := []
	var buried := []
	var shelters := {}
	var roofs := {}
	var pits := {}
	own_shelter = {}
	_covered.clear()
	_fade_state = ""
	# Every registered plot's house, and the forgotten mine with its empty hut (see LostMine).
	var houses: Array = []
	for deed in Plots.all():
		houses.append([plan if plan != null and deed.rect == _plot else HouseSketch.of(deed.owner, deed.rect), deed.rect == _plot])
	var mine := LostMine.sketch()
	houses.append([mine, false])
	# The bank over its vault cellar (see BankVault), with its switch on.
	var vault: HouseSketch = BankVault.sketch() if BankVault.on else null
	if vault != null:
		houses.append([vault, false])
	# The village's sewers under the streets (see Sewers).
	var sewers := Sewers.sketch()
	houses.append([sewers, false])
	for entry: Array in houses:
		var house: HouseSketch = entry[0]
		var own: bool = entry[1]
		_abandoned = house.abandoned
		if house == mine or house == vault or house == sewers or _has_floors(house):
			floored.append(house)
		# The mine's hundreds of dug cells are drawn once (see _draw_mine): only its hut's pieces
		# here; the same for the vault and its bank.
		var keys: Array = house.pieces.keys()
		if house == mine:
			keys = LostMine.surface_keys()
		elif house == vault:
			keys = _surface_keys(vault)
		elif house == sewers:
			keys = _surface_keys(sewers)
		if house == mine:
			_inside_now = LostMine.hut_inside()
		elif house == vault:
			_inside_now = BankVault.bank_inside()
		elif house == sewers:
			_inside_now = {}
		else:
			_inside_now = HouseGround.inside_cells(house) if house.count(HouseSketch.WINDOW) > 0 else {}
		for key in keys:
			var p := HouseSketch.parts_of(key)
			var piece: Dictionary = house.pieces[key]
			if piece.state != HouseSketch.SKETCH and not HouseSketch.CELL_KINDS.has(piece.kind):
				_outside = _outside_of(p[1], p[2], p[3])
				_lift = p[0] * HouseSketch.STOREY_HEIGHT
				_solid_piece(house, [p[1], p[2], p[3]], piece.kind, piece.state == HouseSketch.DEMOLISH)
				_lift = 0.0
				if _new_door != null:
					_hang_door(_new_door, house, key, own, was)
					_new_door = null
				if _new_shutters != null:
					_hang_shutters(_new_shutters, house, key, own)
					_new_shutters = null
		if house == mine or house == vault or house == sewers:
			var cache := _mine_cache
			if house == mine:
				_draw_mine()
				cache = _mine_cache
			elif house == sewers:
				if _sewer_cache.is_empty():
					_sewer_cache = _draw_once(sewers)
				cache = _sewer_cache
			else:
				if _vault_cache.is_empty():
					_vault_cache = _draw_once(vault)
				cache = _vault_cache
			holes.append_array(cache.holes)
			ceilinged.append_array(cache.ceilinged)
			buried.append_array(cache.buried)
			built_ground.append_array(cache.ground)
			shelters.merge(cache.shelter, true)
			roofs.merge(HouseGround.roofed(house, cache.shelter), true)
			_solid_above(house, keys)
			continue
		_solid_cellar(house, holes, ceilinged, buried)
		_solid_above(house)
		_solid_ballistae(house)
		built_ground.append_array(HouseGround.rects(house))
		var shelter := HouseGround.shelter(house)
		shelters.merge(shelter, true)
		roofs.merge(HouseGround.roofed(house, shelter), true)
		pits.merge(HouseGround.pits(house), true)
		if house == plan:
			own_shelter = shelter
	(game.level as Outdoor).roofs = roofs
	(game.level as Outdoor).pits = pits
	(game.level as Outdoor).shelters = shelters
	# The cellars under the village's halls (the guildhall's, see GuildHall), under their floors.
	holes.append_array((game.level as Outdoor).hall_holes)
	ceilinged.append_array((game.level as Outdoor).hall_holes)
	game.level.set_floor_holes(holes, ceilinged, buried)
	cellar_view.holes = holes
	if _hut_props == null:
		_hut_props = Node3D.new()
		_hut_props.name = "EmptyHut"
		add_child(_hut_props)
		LostMine.furnish_hut(_hut_props)
		LostMine.furnish_yard(game.level, _hut_props)
		LostMine.furnish_entrance(game.level, _hut_props)
	if _deep_props == null:
		_deep_props = Node3D.new()
		_deep_props.name = "LostMine"
		deep.add_child(_deep_props)
		LostMine.build(game.level, _deep_props)
	if vault != null and _vault_props == null:
		_vault_props = Node3D.new()
		_vault_props.name = "BankVault"
		deep.add_child(_vault_props)
		BankVault.build(game.level, _vault_props)
	if _sewer_props == null:
		_sewer_props = Node3D.new()
		_sewer_props.name = "Sewers"
		deep.add_child(_sewer_props)
		Sewers.build(game.level, _sewer_props)
	if vault != null:
		# The banking hall over it, with Goldwin's desk (see BankHall): built once per level.
		BankHall.build(game.level)
	# No grass tufts, twigs or leaves inside a built house (see HouseGround).
	if (game.level as Outdoor).surface_life != null:
		(game.level as Outdoor).surface_life.set_built(built_ground)
	game.level.house_floors = HouseFloors.new(floored) if not floored.is_empty() else null
	_raise_roofs()
	# Furniture that no longer fits the changed house goes back into the store (see HouseFurnisher).
	if game.house_furnisher != null and game.house_furnisher.is_inside_tree():
		game.house_furnisher.refresh()
	if plan == null:
		return
	for key in plan.pieces:
		if plan.pieces[key].has("into") and plan.pieces[key].state == HouseSketch.BUILT:
			# A built piece to be rebuilt shows what it becomes over the stone.
			var q := HouseSketch.parts_of(key)
			_lift = q[0] * HouseSketch.STOREY_HEIGHT
			_segment(_built, [q[1], q[2], q[3]], plan.pieces[key].into, Color(0, 0, 0, 0), GHOST_GROW)
			_lift = 0.0
		if plan.pieces[key].state == HouseSketch.SKETCH:
			var p := HouseSketch.parts_of(key)
			var kind: String = plan.pieces[key].kind
			var up: float = p[0] * HouseSketch.STOREY_HEIGHT + SILL_TOP
			if kind == HouseSketch.DIG:
				_cell_quad(_built, Vector2i(p[1], p[2]), DIG_COLOR)
			elif kind == HouseSketch.COVER:
				_cell_quad(_built, Vector2i(p[1], p[2]), COVER_COLOR, 0.12)
			elif kind == HouseSketch.STAIRS or kind == HouseSketch.UPSTAIRS:
				for c in HouseSketch.stairs_cells(p[1], p[2], p[3]).slice(0, 2):
					_cell_quad(_built, c, STAIRS_COLOR)
			elif kind == HouseSketch.SLAB or kind == HouseSketch.SADDLE:
				_cell_quad(_built, Vector2i(p[1], p[2]), SLAB_COLOR if kind == HouseSketch.SLAB else ROOF_COLOR, up)
			elif kind == HouseSketch.LADDER:
				_cell_quad(_built, Vector2i(p[1], p[2]), STAIRS_COLOR, maxf(0.0, p[0]) * HouseSketch.STOREY_HEIGHT + 0.06)
				_ladder(plan, p, _built, _material(STAIRS_COLOR))
			elif kind == HouseSketch.BALLISTA:
				var foot := plan.cell_world(p[1], p[2]) + Vector3(0, p[0] * HouseSketch.STOREY_HEIGHT, 0)
				_cell_quad(_built, Vector2i(p[1], p[2]), BALLISTA_COLOR, p[0] * HouseSketch.STOREY_HEIGHT)
				_box(_built, foot + Vector3(0, 0.7, 0), Vector3(0.5, 1.4, 0.5), _material(BALLISTA_COLOR))
				_box(_built, foot + Vector3(0, 1.25, 0), Vector3(2.2, 0.15, 0.3), _material(BALLISTA_COLOR))
			else:
				_lift = p[0] * HouseSketch.STOREY_HEIGHT
				_segment(_built, [p[1], p[2], p[3]], kind, Color(0, 0, 0, 0))
				_lift = 0.0


## The forgotten mine's cellar (see LostMine), drawn the first time only: it never changes.
## What the houses' drawing collects from a cellar goes into _mine_cache.
func _draw_mine() -> void:
	if not _mine_cache.is_empty():
		return
	_mine_cache = _draw_once(LostMine.sketch())


## The keys of a fixed sketch's pieces above the ground and its ladders and stairs, drawn every
## time; its dug cells and their floors and ceilings are drawn once (see _draw_once).
static func _surface_keys(house: HouseSketch) -> Array:
	var out := []
	for key in house.pieces:
		var kind: String = house.pieces[key].kind
		if kind != HouseSketch.DIG and kind != HouseSketch.COVER:
			out.append(key)
	return out


## Draws the cellar of a sketch that never changes (the forgotten mine, the bank's vault) into the
## mine's layers, once; returns what the houses' drawing collects from it.
func _draw_once(mine: HouseSketch) -> Dictionary:
	var keep_body := _body
	_body = _mine_body
	_open_into = _mine_open
	var holes := []
	var ceilinged := []
	var buried := []
	_solid_cellar(mine, holes, ceilinged, buried)
	_open_into = _solid
	_into = _solid
	_body = keep_body
	return {"holes": holes, "ceilinged": ceilinged, "buried": buried, "ground": HouseGround.rects(mine), "shelter": HouseGround.shelter(mine)}


## The built ballistae of a house: they stand and shoot (see HouseBallista), and
## their post stops the hero.
func _solid_ballistae(house: HouseSketch) -> void:
	for key in house.pieces:
		var piece: Dictionary = house.pieces[key]
		if piece.kind != HouseSketch.BALLISTA or piece.state == HouseSketch.SKETCH:
			continue
		var p := HouseSketch.parts_of(key)
		var foot := house.cell_world(p[1], p[2]) + Vector3(0, p[0] * HouseSketch.STOREY_HEIGHT, 0)
		var gun := HouseBallista.new()
		gun.level = game.level
		gun.demolish = piece.state == HouseSketch.DEMOLISH
		gun.position = foot
		_guns.add_child(gun)
		gun.show_range(active)
		_collide(foot + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0))


## The built ballistae on the map, for the tests and the game.
func ballistae() -> Array:
	return _guns.get_children()


func _show_ranges(on: bool) -> void:
	for gun: HouseBallista in _guns.get_children():
		gun.show_range(on)


## A faint circle of a ballista's reach round `at`.
func _range_ring(parent: Node3D, at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = HouseBallista.RANGE - 0.15
	torus.outer_radius = HouseBallista.RANGE + 0.15
	torus.rings = 96
	ring.mesh = torus
	ring.scale = Vector3(1, 0.05, 1)
	ring.material_override = _material(HouseBallista.RING_COLOR)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = at + Vector3(0, 0.08, 0)
	parent.add_child(ring)


## Whether a house has a built cellar, floor slab or stairs: somewhere a
## companion walks by other rules than on the open ground (see HouseFloors).
static func _has_floors(house: HouseSketch) -> bool:
	for key in house.pieces:
		var piece: Dictionary = house.pieces[key]
		if piece.state != HouseSketch.SKETCH and piece.kind in [HouseSketch.DIG, HouseSketch.STAIRS, HouseSketch.SLAB, HouseSketch.UPSTAIRS]:
			return true
	return false


## The cellar of a house: the ground opens over every built cell, the pit gets
## a floor, walls and stairs, and `holes` collects the open cells (Rect2 in
## world x/z) so the map can cut its ground there; `ceilinged` collects those of
## them a cellar ceiling closes again, and `buried` those of them that lie under
## whole ground (a ceiling of earth, HouseSketch.BURIED): their walls and floors are
## drawn into the mine's own layer (see deep).
func _solid_cellar(house: HouseSketch, holes: Array, ceilinged: Array = [], buried: Array = []) -> void:
	var open := {}
	for key in house.pieces:
		var piece: Dictionary = house.pieces[key]
		if piece.state == HouseSketch.SKETCH or not HouseSketch.CELLAR_KINDS.has(piece.kind):
			continue
		var p := HouseSketch.parts_of(key)
		if piece.kind == HouseSketch.DIG:
			open[Vector2i(p[1], p[2])] = piece
		else:
			for c in HouseSketch.stairs_cells(p[1], p[2], p[3]).slice(0, 2):
				open[c] = piece
	# The dug cells a cellar ceiling closes: their walls stop under it, so the wall's top
	# never lies in the ceiling's top face and flickers through the ground floor.
	var roofed := {}
	var earthed := {}
	for key in house.pieces:
		var piece: Dictionary = house.pieces[key]
		if piece.state != HouseSketch.SKETCH and piece.kind == HouseSketch.COVER:
			var p := HouseSketch.parts_of(key)
			roofed[Vector2i(p[1], p[2])] = true
			if piece.get("surface", "") == HouseSketch.BURIED:
				earthed[Vector2i(p[1], p[2])] = true
	for c: Vector2i in open:
		_into = _deep_walls if earthed.has(c) else _open_into
		var piece: Dictionary = open[c]
		var demolish: bool = piece.state == HouseSketch.DEMOLISH
		var corner := house.node_world(c.x, c.y)
		holes.append(Rect2(corner.x, corner.z, HouseSketch.CELL, HouseSketch.CELL))
		var middle := house.cell_world(c.x, c.y)
		var is_dig: bool = piece.kind == HouseSketch.DIG
		if is_dig:
			_floor_box(middle + Vector3(0, -HouseSketch.DEPTH - 0.04, 0), Vector3(HouseSketch.CELL, 0.08, HouseSketch.CELL), piece.get("floor", ""), demolish)
			# Down in the pit no snow settles on the floor (seen from above through an open shaft it showed
			# as a flat pale square).
			_into.get_child(_into.get_child_count() - 1).set_meta("no_snow", true)
			_collide(middle + Vector3(0, -HouseSketch.DEPTH - 0.25, 0), Vector3(HouseSketch.CELL, 0.5, HouseSketch.CELL))
		var wall_mat := _wall_material(piece.get("wall", "") if is_dig else "", demolish)
		var tall: float = HouseSketch.DEPTH - (CEILING_GAP if roofed.has(c) else 0.0)
		for dir in HouseSketch.DOWN:
			var step: Vector2i = HouseSketch.DOWN[dir]
			if open.has(c + step):
				continue
			# The wall straddles the rim and its top lies just under the ground (or under the
			# ceiling), so no crack opens between the cut ground and the wall (it showed as a
			# fine light line).
			var side := Vector3(step.x, 0, step.y) * (HouseSketch.CELL * 0.5)
			var high := minf(tall, HouseSketch.DEPTH - RIM_SINK)
			# Panels along one wall meet end to end, never overlapping: two faces in one
			# place flicker (z-fighting). At a corner the wall along x fills the corner
			# and the one along z stops at its face (see _lining_reach).
			var along := Vector2i(step.y, step.x).abs()
			var reach_lo := _lining_reach(open, c, step, -along)
			var reach_hi := _lining_reach(open, c, step, along)
			var length := HouseSketch.CELL + reach_lo + reach_hi
			var axis := Vector3(along.x, 0, along.y)
			var size := Vector3(RIM_THICK, high, length) if step.x != 0 else Vector3(length, high, RIM_THICK)
			var at := middle + side + axis * ((reach_hi - reach_lo) * 0.5) + Vector3(0, -HouseSketch.DEPTH + high * 0.5, 0)
			# Its top lies under the ground (or the ceiling) and its ends against the next
			# panel or in a corner: those edges stay sharp (a rounded top edge showed as
			# a bright line along the rim).
			_visual_box(at, size, wall_mat, [Vector3.DOWN, Vector3.UP, -axis, axis])
	_into = _open_into
	for key in house.pieces:
		var piece: Dictionary = house.pieces[key]
		if piece.state == HouseSketch.SKETCH:
			continue
		var p := HouseSketch.parts_of(key)
		if piece.kind == HouseSketch.STAIRS:
			_ramp(house, p[1], p[2], p[3], piece.state == HouseSketch.DEMOLISH)
		elif piece.kind == HouseSketch.COVER and open.has(Vector2i(p[1], p[2])):
			var corner := house.node_world(p[1], p[2])
			var cell := Rect2(corner.x, corner.z, HouseSketch.CELL, HouseSketch.CELL)
			ceilinged.append(cell)
			if earthed.has(Vector2i(p[1], p[2])):
				# Whole ground on top: nothing to draw, only the ground's top to walk on.
				var thick := HouseSketch.COVER_THICK
				_collide(house.cell_world(p[1], p[2]) + Vector3(0, -thick * 0.5, 0), Vector3(HouseSketch.CELL, thick, HouseSketch.CELL))
				buried.append(cell)
			else:
				_cellar_ceiling(house, p[1], p[2], piece)
		elif piece.kind == HouseSketch.COVER and house.hole_key(p[1], p[2]) == "":
			_ground_floor(house, p[1], p[2], piece)


## How far the cellar wall of open cell `c` on its side `step` reaches past the
## cell's edge towards `toward`: not at all where the wall runs on in line (the
## next panel starts there), half its thickness out where the wall along x turns a
## corner (it fills the corner), and half its thickness short where a wall along
## z meets one along x (it stops at that wall's face).
func _lining_reach(open: Dictionary, c: Vector2i, step: Vector2i, toward: Vector2i) -> float:
	if open.has(c + toward) and not open.has(c + toward + step):
		return 0.0
	return RIM_THICK * 0.5 if step.x == 0 else -RIM_THICK * 0.5


## The cellar ceiling over a dug cell: a floor of the pen's planks or of
## flagstones (see _floor_box) whose top is the ground, so the hero walks over
## the cellar on the ground floor. The ground stays cut open under it (the cellar is still there). While the hero is down in
## the cellar under it, it fades like a roof (see _update_fade).
func _cellar_ceiling(house: HouseSketch, x: int, y: int, piece: Dictionary) -> void:
	var thick := HouseSketch.COVER_THICK
	var at := house.cell_world(x, y) + Vector3(0, -thick * 0.5, 0)
	var size := Vector3(HouseSketch.CELL, thick, HouseSketch.CELL)
	# Drawn a hair above the ground (CEILING_LIFT): its top lay exactly in the ground's plane, so the
	# snow on the ceiling and the snow on the ground fought over the same depth and thin lines along
	# the ceiling's edges flickered through. The hero still walks on the ground's level.
	_floor_box(at + Vector3(0, CEILING_LIFT, 0), size, piece.get("surface", "wood"), piece.state == HouseSketch.DEMOLISH, true)
	_collide(at, size)
	# The mesh: fades away while the hero is in the cellar below it. It went where the cellar is
	# drawn into (the houses' own pieces, or the bank's and the mine's, see _draw_once).
	var mesh: Node = _into.get_child(_into.get_child_count() - 1)
	mesh.set_meta("ymin", 0.0)
	_cover(house, x, y, HouseSketch.CELLAR_STOREY)
	_hide_under(house, x, y, -thick * 0.5)


## A floor on plain ground: the pen's planks or the square's flagstones laid on
## the grass, FLOOR_RISE high, that the hero walks on.
func _ground_floor(house: HouseSketch, x: int, y: int, piece: Dictionary) -> void:
	var thick := HouseSketch.FLOOR_RISE + 0.05
	var at := house.cell_world(x, y) + Vector3(0, HouseSketch.FLOOR_RISE - thick * 0.5, 0)
	var size := Vector3(HouseSketch.CELL, thick, HouseSketch.CELL)
	_floor_box(at, size, piece.get("surface", "wood"), piece.state == HouseSketch.DEMOLISH)
	_collide(at, size)
	# Down in a cellar it fades with the rest of the house above (see _update_fade).
	_into.get_child(_into.get_child_count() - 1).set_meta("ymin", 0.0)


## The floors, roofs and stairs up of a house. Everything is solid: a slab
## carries the hero (a flat roof too), a saddle roof only keeps the rain out.
func _solid_above(house: HouseSketch, keys: Array = []) -> void:
	for key in keys if not keys.is_empty() else house.pieces.keys():
		var piece: Dictionary = house.pieces[key]
		if piece.state == HouseSketch.SKETCH:
			continue
		var p := HouseSketch.parts_of(key)
		var demolish: bool = piece.state == HouseSketch.DEMOLISH
		var base: float = p[0] * HouseSketch.STOREY_HEIGHT + WALL_HEIGHT
		var mid := house.cell_world(p[1], p[2])
		match piece.kind:
			HouseSketch.SLAB:
				var slab := Vector3(HouseSketch.CELL, HouseSketch.SLAB_THICK, HouseSketch.CELL)
				# A slab with nothing built over it is a flat roof in the open: its boards lie tight.
				_open_roof = not house.pieces.has(HouseSketch.key_of(p[1], p[2], HouseSketch.CELL_ORIENT, p[0] + 1))
				_floor_box(mid + Vector3(0, base + HouseSketch.SLAB_THICK * 0.5, 0), slab, "wood", demolish, true)
				_open_roof = false
				_collide(mid + Vector3(0, base + HouseSketch.SLAB_THICK * 0.5, 0), slab)
				_cover(house, p[1], p[2], p[0])
				_hide_under(house, p[1], p[2], base + HouseSketch.SLAB_THICK * 0.5)
			HouseSketch.SADDLE:
				_saddle(mid, base + HouseSketch.SLAB_THICK, p[3] == "rx", demolish, _open_sides(house, p))
				_cover(house, p[1], p[2], p[0])
				_hide_under(house, p[1], p[2], base + HouseSketch.SLAB_THICK + HouseSketch.ROOF_RISE * 0.5)
			HouseSketch.UPSTAIRS:
				_ramp(house, p[1], p[2], p[3], demolish, HouseSketch.STOREY_HEIGHT)
			HouseSketch.LADDER:
				var wood: Material = _solid_material(DEMOLISH_COLOR) if demolish else HouseLooks.stair_wood()
				_ladder(house, p, _solid, wood).add_to_group(Player.LADDER_GROUP)


## Where a ladder (key parts `p`, see HouseSketch.LADDER) stands: the foot and top
## heights, the point on the edge it leans on and the flat direction up it.
static func ladder_frame(house: HouseSketch, p: Array) -> Dictionary:
	var foot_cell := Vector2i(p[1], p[2])
	var top_cell := HouseSketch.ladder_top(p[1], p[2], p[3])
	var a := house.cell_world(foot_cell.x, foot_cell.y)
	var b := house.cell_world(top_cell.x, top_cell.y)
	var push := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var edge := Vector3((a.x + b.x) * 0.5, 0, (a.z + b.z) * 0.5)
	var low: float = -HouseSketch.DEPTH if p[0] == HouseSketch.CELLAR_STOREY else p[0] * HouseSketch.STOREY_HEIGHT
	var high: float = 0.0 if p[0] == HouseSketch.CELLAR_STOREY else (p[0] + 1) * HouseSketch.STOREY_HEIGHT
	return {"push": push, "edge": edge, "low": low, "high": high}


## A ladder: two rails against the edge, a rung every 30 cm, the rails standing
## a metre over the top to hold on to. Returns the node that tells the hero
## where to climb it (see Player.LADDER_GROUP), under `parent`.
func _ladder(house: HouseSketch, p: Array, parent: Node3D, mat: Material) -> Node3D:
	var f := ladder_frame(house, p)
	var push: Vector3 = f.push
	var side := Vector3(-push.z, 0, push.x)
	var line: Vector3 = f.edge - push * (THICK * 0.5 + 0.08)
	var low: float = f.low
	# The rails stand a metre over the top to hold on to, except in the sewers: there the ladder ends
	# below the ground, so it does not stick out of a shut hatch.
	var over := -0.1 if house.flush_ladders else 1.0
	var tall: float = f.high - low + over
	var parts: Array[MeshInstance3D] = []
	for sign_ in [-1.0, 1.0]:
		parts.append(_box(parent, line + side * sign_ * 0.3 + Vector3(0, low + tall * 0.5, 0), (side * 0.07 + push * 0.07).abs() + Vector3(0, tall, 0), mat))
	var y := low + 0.3
	while y < f.high + (over - 0.25):
		parts.append(_box(parent, line + Vector3(0, y, 0), (side * 0.6 + push * 0.05).abs() + Vector3(0, 0.05, 0), mat))
		y += 0.3
	# A ladder on the ground or higher belongs to its floor: it fades with the storeys over the
	# hero (see _update_fade), so from down in the cellar or from a floor below it does not
	# stand there on its own. A cellar ladder (low below ground) stays, it is part of the pit.
	if low >= 0.0:
		for part in parts:
			part.set_meta("ymin", low)
	var spot := Node3D.new()
	spot.set_meta("push", push)
	spot.set_meta("edge", f.edge)
	spot.set_meta("foot", f.edge - push * 0.65 + Vector3(0, low, 0))
	spot.set_meta("top", f.edge + push * 0.7 + Vector3(0, f.high, 0))
	# For the click on it (see LadderClick): the rungs that glow under the mouse, and whether a hatch's lid
	# stands over it (the hatch is clicked, not the ladder, from above).
	spot.set_meta("parts", parts)
	spot.set_meta("flush", house.flush_ladders)
	parent.add_child(spot)
	return spot


## Tells the map that a floor or roof `height` high covers a cell of `house`, so
## no monster sees, strikes or shoots through it (see Level.built_between).
func _hide_under(house: HouseSketch, x: int, y: int, height: float) -> void:
	var corner := house.node_world(x, y)
	game.level.built_floors.append({"rect": Rect2(corner.x, corner.z, HouseSketch.CELL, HouseSketch.CELL), "y": corner.y + height})


## One cell of pitched roof: two boards up to the ridge and a triangle at each end. The boards
## are tiled like the villagers' roofs (VillageHouse's aged tiles). Over an outer wall (`open`,
## see _open_sides) a board reaches on down to the top of the wall with a little overhang, and
## under a gable a timber knee wall closes the gap down to the wall, so the roof sits on the house
## instead of floating a slab's thickness over it.
func _saddle(mid: Vector3, eave: float, ridge_x: bool, demolish: bool, open := {}) -> void:
	var half := HouseSketch.CELL * 0.5
	var rise := HouseSketch.ROOF_RISE
	var colour := DEMOLISH_COLOR if demolish else ROOF_COLOR
	var across := Vector3(0, 0, half) if ridge_x else Vector3(half, 0, 0)
	var peak := mid + Vector3(0, eave + rise, 0)
	var wall_top := eave - HouseSketch.SLAB_THICK
	# An empty house's roof is old: grey and mossy, and here and there a board has fallen in.
	var cx := floori(mid.x / HouseSketch.CELL)
	var cz := floori(mid.z / HouseSketch.CELL)
	if _abandoned and not demolish:
		colour = OLD_ROOF.lerp(MOSS, 0.55 if posmod(cx + cz, 2) == 0 else 0.15)
	for sign_ in [-1.0, 1.0]:
		var foot: Vector3 = mid + across * sign_ + Vector3(0, eave, 0)
		# What one bumps into ends over the wall, a slab's height up: the eave below it is only seen,
		# so it never catches the head of someone walking out of a door under it.
		var stop: Vector3 = foot
		# Down to the wall's top on the house's outside, along the same slope, and a hand over it.
		if bool(open.get("across%d" % int(sign_), false)):
			var slope: Vector3 = foot - peak
			foot = peak + slope * ((peak.y - wall_top + EAVE_DROP) / (peak.y - foot.y))
		if _abandoned and not demolish and posmod(cz if ridge_x else cx, 3) == 1 and posmod((cx if ridge_x else cz) + (1 if sign_ > 0.0 else 0), 3) == 0:
			_rafters(foot, peak, eave - 0.15)
			continue
		_slanted(stop, peak, HouseSketch.CELL, 0.15, colour, true, false)
		# Here and there on an empty house the lower half of a board has broken off, down to the rafters.
		if _abandoned and not demolish and posmod(cx * 7 + cz * 3 + (1 if sign_ > 0.0 else 0), 5) == 2:
			_rafters(foot, peak, eave - 0.15)
			foot = foot.lerp(peak, 0.5)
		if demolish:
			_slanted(foot, peak, HouseSketch.CELL, 0.15, colour, false)
		else:
			_tiled_board(foot, peak, HouseSketch.CELL, eave - 0.15)
	var along := Vector3(half - 0.05, 0, 0) if ridge_x else Vector3(0, 0, half - 0.05)
	# An empty house's gables are stone, like its walls; a lived-in house's are timber.
	var gable: Material = _solid_material(colour) if demolish else (HouseLooks.temple_stone() if _abandoned else HouseLooks.stair_wood())
	for sign_ in [-1.0, 1.0]:
		var prism := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(HouseSketch.CELL, rise, 0.1)
		prism.mesh = mesh
		prism.material_override = gable
		prism.position = mid + along * sign_ + Vector3(0, eave + rise * 0.5, 0)
		if ridge_x:
			prism.rotation.y = PI * 0.5
		prism.set_meta("ymin", eave)
		_solid.add_child(prism)
		# The knee wall under an outer gable, from the wall's top up to the roof.
		if bool(open.get("along%d" % int(sign_), false)):
			var knee := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.1, HouseSketch.SLAB_THICK, HouseSketch.CELL) if ridge_x else Vector3(HouseSketch.CELL, HouseSketch.SLAB_THICK, 0.1)
			knee.mesh = box
			knee.material_override = gable
			knee.position = mid + along * sign_ + Vector3(0, wall_top + HouseSketch.SLAB_THICK * 0.5, 0)
			knee.set_meta("ymin", eave)
			_solid.add_child(knee)
	if not demolish:
		_saddle_caps(mid, eave, ridge_x, open)


## The cap shingles of one cell of saddle roof (RoofCaps): along its ridge, and down the edge of an
## outer gable (`open`, see _saddle), over the line where the boards end.
func _saddle_caps(mid: Vector3, eave: float, ridge_x: bool, open: Dictionary) -> void:
	var half := HouseSketch.CELL * 0.5
	var rise := HouseSketch.ROOF_RISE
	var along := Vector3(1, 0, 0) if ridge_x else Vector3(0, 0, 1)
	var across := Vector3(0, 0, 1) if ridge_x else Vector3(1, 0, 0)
	var peak := mid + Vector3(0, eave + rise + 0.02, 0)
	var seed := hash(mid)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	RoofCaps.ridge(st, peak - along * half, peak + along * half, rise / half, seed)
	for sign_ in [-1.0, 1.0]:
		if not bool(open.get("along%d" % int(sign_), false)):
			continue
		for side_ in [-1.0, 1.0]:
			var top: Vector3 = peak + along * sign_ * half
			var foot: Vector3 = mid + across * side_ * half + along * sign_ * half + Vector3(0, eave, 0)
			var slope := foot - top
			var dir := slope.normalized()
			var up := (Vector3.UP - dir * dir.dot(Vector3.UP)).normalized()
			RoofCaps.edge(st, top, foot, up, along * sign_, seed + int(sign_ * 7.0 + side_ * 3.0))
	var caps := MeshInstance3D.new()
	caps.mesh = st.commit()
	caps.material_override = _old_roof() if _abandoned else VillageHouse._roof_material(0)
	caps.set_meta("ymin", eave - 0.15)
	_solid.add_child(caps)


## The bare rafters under a fallen-in roof board, from `foot` (the eaves) up to `peak`: three
## dark beams across the cell's width, and a purlin halfway up.
## `ymin` hides them with the storey under them.
func _rafters(foot: Vector3, peak: Vector3, ymin: float) -> void:
	var slope := peak - foot
	var along := slope.normalized()
	var up := (Vector3.UP - along * along.dot(Vector3.UP)).normalized()
	var side := along.cross(up)
	var wood := _rafter_wood()
	for k in [-0.42, 0.0, 0.42]:
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(slope.length() + 0.1, 0.14, 0.12)
		beam.mesh = box
		beam.material_override = wood
		beam.transform = Transform3D(Basis(along, up, side), foot + slope * 0.5 + side * HouseSketch.CELL * k - up * 0.1)
		beam.set_meta("ymin", ymin)
		_solid.add_child(beam)
	var purlin := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.12, 0.12, HouseSketch.CELL)
	purlin.mesh = bar
	purlin.material_override = wood
	purlin.transform = Transform3D(Basis(along, up, side), foot + slope * 0.45 - up * 0.2)
	purlin.set_meta("ymin", ymin)
	_solid.add_child(purlin)


## The grey, weathered wood of bare rafters, darker than the boards still on the roof.
static var _old_rafter: StandardMaterial3D = null


static func _rafter_wood() -> StandardMaterial3D:
	if _old_rafter == null:
		_old_rafter = StandardMaterial3D.new()
		_old_rafter.albedo_color = Color(0.27, 0.22, 0.17)
		_old_rafter.roughness = 0.95
	return _old_rafter


## How far a roof's eaves reach down past the top of the wall under them (metres).
const EAVE_DROP := 0.12


## Which sides of the saddle roof cell `p` (key parts, see HouseSketch.SADDLE) are the house's
## outside, with no roof of the same storey beyond them: "across-1"/"across1" for the two eaves
## (down the slopes), "along-1"/"along1" for the two gables (along the ridge).
func _open_sides(house: HouseSketch, p: Array) -> Dictionary:
	var ridge_x: bool = p[3] == "rx"
	var across := Vector2i(0, 1) if ridge_x else Vector2i(1, 0)
	var along := Vector2i(1, 0) if ridge_x else Vector2i(0, 1)
	var out := {}
	for s: int in [-1, 1]:
		var a: Vector2i = Vector2i(p[1], p[2]) + across * s
		var b: Vector2i = Vector2i(p[1], p[2]) + along * s
		out["across%d" % s] = house.roof_key(a.x, a.y, p[0]) == ""
		out["along%d" % s] = house.roof_key(b.x, b.y, p[0]) == ""
	return out


## The tiles over a roof board from `a` (the eaves) to `b` (the ridge), `width` wide: patches of
## the villagers' aged roof tiles (see VillageHouse._roof), on a timber board. `ymin` is where it
## hides with the storey under it (see _fade_storeys).
func _tiled_board(a: Vector3, b: Vector3, width: float, ymin: float) -> void:
	var slope := b - a
	var length := slope.length()
	var along := slope / length
	var up := (Vector3.UP - along * along.dot(Vector3.UP)).normalized()
	var side := along.cross(up)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seeds := RandomNumberGenerator.new()
	seeds.seed = hash(a)
	var cols := maxi(1, roundi(width / VillageHouse.TILES_PATCH.x))
	var rows := maxi(1, roundi(length / VillageHouse.TILES_PATCH.y))
	var uv := VillageHouse.TILES_UV
	var uvs := [uv.position, uv.position + Vector2(uv.size.x, 0), uv.end, uv.position + Vector2(0, uv.size.y)]
	# From the ridge (row 0) down to the eaves, as on the villagers' roofs.
	var origin := b + up * 0.03 - side * width * 0.5
	for r in rows:
		for c in cols:
			var p0 := origin + side * (c * width / cols) - along * (r * length / rows)
			var dx := side * (width / cols)
			var dz := -along * (length / rows)
			var quad := [p0, p0 + dx, p0 + dx + dz, p0 + dz]
			var seed_colour := Color(seeds.randf(), 0, 0)
			# Wound to face up, out of the roof.
			var order := [0, 1, 2, 0, 2, 3] if (dx.cross(dz)).dot(up) < 0.0 else [0, 2, 1, 0, 3, 2]
			for k: int in order:
				st.set_color(seed_colour)
				st.set_normal(up)
				st.set_uv(uvs[k])
				st.add_vertex(quad[k])
	var tiles := MeshInstance3D.new()
	tiles.mesh = st.commit()
	tiles.material_override = _old_roof() if _abandoned else VillageHouse._roof_material(0)
	tiles.set_meta("ymin", ymin)
	_solid.add_child(tiles)
	# The board under the tiles, seen from inside and at its edges.
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, 0.12, width)
	board.mesh = box
	board.material_override = HouseLooks.stair_wood()
	board.transform = Transform3D(Basis(along, up, side), a + slope * 0.5 - up * 0.06)
	board.set_meta("ymin", ymin)
	_solid.add_child(board)


## The tiles of an empty house's roof: greyer and far more weathered (see aged_roof.gdshader).
static var _old_tiles: ShaderMaterial = null


static func _old_roof() -> ShaderMaterial:
	if _old_tiles == null:
		_old_tiles = (VillageHouse._roof_material(2) as ShaderMaterial).duplicate()
		_old_tiles.set_shader_parameter("age", 1.3)
	return _old_tiles


## Tells the map which stone-block cells stand on a slab (a flat roof or an
## upper floor), so blocks and the hero's own pile can be set down up there.
## Blocks that lost the slab under them go back into the plot's stock.
func _raise_roofs() -> void:
	var level: Level = game.level
	var raised := {}
	for deed in Plots.all():
		var house := plan if plan != null and deed.rect == _plot else HouseSketch.of(deed.owner, deed.rect)
		for key in house.pieces:
			var piece: Dictionary = house.pieces[key]
			if piece.kind != HouseSketch.SLAB or piece.state == HouseSketch.SKETCH:
				continue
			var p := HouseSketch.parts_of(key)
			var corner := house.node_world(p[1], p[2])
			var layer := roundi((p[0] + 1) * HouseSketch.STOREY_HEIGHT / StoneBlock.HEIGHT)
			for cx in range(floori(corner.x / StoneBlock.CELL), ceili((corner.x + HouseSketch.CELL) / StoneBlock.CELL)):
				for cz in range(floori(corner.z / StoneBlock.CELL), ceili((corner.z + HouseSketch.CELL) / StoneBlock.CELL)):
					var middle := Vector2((cx + 0.5) * StoneBlock.CELL, (cz + 0.5) * StoneBlock.CELL)
					if middle.x >= corner.x and middle.x < corner.x + HouseSketch.CELL and middle.y >= corner.z and middle.y < corner.z + HouseSketch.CELL:
						raised[Vector2i(cx, cz)] = maxi(int(raised.get(Vector2i(cx, cz), 0)), layer)
	var before: Dictionary = level.roof_layers
	level.roof_layers = raised
	var dropped := false
	for stone: StoneBlock in level.stones.duplicate():
		if not is_instance_valid(stone) or stone.layer == 0:
			continue
		var was := 0
		var now := 0
		for c in stone.cells():
			was = maxi(was, int(before.get(c, 0)))
			now = maxi(now, int(raised.get(c, 0)))
		if was > now and stone.layer >= was:
			level.take_stone(stone)
			dropped = true
			if plan != null:
				plan.deposit(HouseSketch.STONE, 1)
	# Only then: the saved list of blocks (level.built) is read back after the
	# level is built, so it must not be rewritten from a still empty level.
	if dropped:
		level._sync_built()


## Notes that a built slab or roof lies over a ground cell, for _update_fade.
func _cover(house: HouseSketch, x: int, y: int, level: int) -> void:
	var corner := house.node_world(x, y)
	var at := Vector2i(floori((corner.x + Level.TILE * 0.5) / HouseSketch.CELL), floori((corner.z + Level.TILE * 0.5) / HouseSketch.CELL))
	_covered[at] = maxi(int(_covered.get(at, -1)), level)


## Inside a house the hero sees what is outside and above: the roof and the
## storeys over their head fade away while they stand under a roof, and come
## back when they step out or climb onto the roof.
func _update_fade() -> void:
	if game == null or game.player == null or (_covered.is_empty() and _fade_state == "" and view_storey == NO_VIEW and not cellar_view.active):
		return
	var pos: Vector3 = game.player.global_position
	var level := -1 if pos.y < -0.5 else clampi(floori((pos.y + 0.2) / HouseSketch.STOREY_HEIGHT), 0, HouseSketch.MAX_STOREY + 1)
	var at := Vector2i(floori((pos.x + Level.TILE * 0.5) / HouseSketch.CELL), floori((pos.z + Level.TILE * 0.5) / HouseSketch.CELL))
	var inside := false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if int(_covered.get(at + Vector2i(dx, dy), -2)) >= level:
				inside = true
	if view_storey != NO_VIEW:
		level = view_storey
		inside = true
	elif cellar_view.active:
		# Down in a cellar nothing of the house above shows (see CellarView).
		level = -1
		inside = true
	fade_storey = level if inside else 99
	var state := "%d:%s" % [level, inside]
	if state == _fade_state:
		return
	_fade_state = state
	var limit := (level * HouseSketch.STOREY_HEIGHT + WALL_HEIGHT - 0.05) if level >= 0 else -0.05
	# The fixed houses' floors over their cellars too (the bank over its vault, the mine's hut, see
	# _draw_once): down there no floor of the house above hangs overhead.
	for layer: Node3D in [_solid, _mine_open]:
		for node in layer.get_children():
			if node.has_meta("ymin"):
				LightShadows.lift(node, inside and float(node.get_meta("ymin")) >= limit)
	for gun: Node3D in _guns.get_children():
		gun.visible = not (inside and gun.position.y >= limit)


## The stairs of a stairs piece: from the ground at the top of its first cell
## down to the cellar floor (or up to the next storey) at the end of its second.
## The hero and companions walk a smooth ramp there (it alone collides); what
## shows is a flight of worn wooden steps like the town houses' on Weavers'
## Lane (see WoodStairs.build_flight), the ramp running through every tread.
func _ramp(house: HouseSketch, x: int, y: int, dir: String, demolish: bool, rise := -HouseSketch.DEPTH) -> void:
	var step: Vector2i = HouseSketch.DOWN[dir]
	var flat := Vector3(step.x, 0, step.y)
	var start := house.cell_world(x, y) - flat * (HouseSketch.CELL * 0.5)
	var length := HouseSketch.CELL * 2.0
	# A floor laid on the ground at the top of stairs down stands FLOOR_RISE over it: the
	# walking ramp starts on that floor's top, or its edge stops a hero coming up.
	var top := Vector3.ZERO
	var landing := Vector2i(x, y) - step
	if rise < 0.0 and house.is_covered(landing.x, landing.y) and house.hole_key(landing.x, landing.y) == "":
		top.y = HouseSketch.FLOOR_RISE
	_slanted(start + top, start + flat * length + Vector3(0, rise, 0), HouseSketch.CELL, 0.3, PLANK_COLOR, true, false)
	var red: Material = _solid_material(DEMOLISH_COLOR) if demolish else null
	# Into the layer the cellar is drawn into: the bank's and the mine's stairs are drawn once
	# (see _draw_once) and must outlive the next drawing of the houses' own pieces.
	var flight := WoodStairs.build_flight(_open_into if rise < 0.0 else _solid, start, flat, length, rise, STAIRS_WIDTH, red, red)
	# Fades with the floor it stands on, never with the storey it reaches.
	flight.set_meta("ymin", minf(0.0, rise))


## A thick slanted board from point `a` to point `b` (its upper face runs
## through both), `width` wide across the slope. It stops the hero.
## `show` false: only the collision, nothing drawn.
func _slanted(a: Vector3, b: Vector3, width: float, thick: float, colour: Color, collide: bool, show := true) -> void:
	var slope := b - a
	var length := slope.length()
	var along := slope / length
	var up := (Vector3.UP - along * along.dot(Vector3.UP)).normalized()
	var basis := Basis(along, up, along.cross(up))
	var at := Transform3D(basis, a + slope * 0.5 - up * thick * 0.5)
	var size := Vector3(length, thick, width)
	if show:
		# The drawn board lies a little under and inside the tiled board over it (_tiled_board), so the
		# two never share a face (z-fighting at the roof's edges).
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size - Vector3(0, 0, 0.04)
		m.mesh = box
		m.material_override = _solid_material(colour)
		m.transform = Transform3D(basis, at.origin - up * 0.03)
		m.set_meta("ymin", minf(a.y, b.y) - thick)
		_solid.add_child(m)
	if collide:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		shape.transform = at
		_body.add_child(shape)


## The material of a cellar wall: bare earth looks like real dug soil (see
## BareEarth), stone is the temple's blocks and wood the town houses' stair
## boards (see HouseLooks).
func _wall_material(surface: String, demolish: bool) -> Material:
	if demolish:
		return _solid_material(DEMOLISH_COLOR)
	match surface:
		"stone":
			return HouseLooks.temple_stone()
		"wood":
			return HouseLooks.stair_wood()
		LostMine.ROCK:
			return LostMine.rock_material()
		LostMine.ORE_ROCK:
			return LostMine.ore_rock_material()
	if surface.begins_with("brick"):
		return Sewers.brick_material(Sewers.variant_of(surface))
	return BareEarth.material()


## A floor filling a box `size` big round `middle`: bare earth, the village
## square's flagstones or the cattle pen's boards (see HouseLooks). A floor
## marked for demolition is tinted red. The floor casts no shadow from the house's
## lamps (LightShadows.FLOOR); one with a room under it (`lid`: a cellar ceiling, an
## upper floor) gets a thin shadow-only board at its underside, so the light still
## stays on its own side of it. The floor is always the last node added.
func _floor_box(middle: Vector3, size: Vector3, surface: String, demolish: bool, lid := false) -> void:
	if lid:
		var under := MeshInstance3D.new()
		var board := BoxMesh.new()
		board.size = Vector3(size.x, 0.02, size.z)
		under.mesh = board
		under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		under.position = middle + Vector3(0, _lift - size.y * 0.5 + 0.01, 0)
		_into.add_child(under)
	if demolish:
		_visual_box(middle, size, _solid_material(DEMOLISH_COLOR))
	else:
		match surface:
			"stone":
				_visual_box(middle, size, HouseLooks.flagstones())
			"wood":
				var boards := HouseLooks.plank_floor(middle + Vector3(0, _lift, 0), size, _open_roof)
				boards.set_meta("ymin", middle.y + _lift - size.y * 0.5)
				_into.add_child(boards)
			_:
				if surface.begins_with("brick"):
					_visual_box(middle, size, Sewers.floor_material(Sewers.variant_of(surface)))
				else:
					_visual_box(middle, size, BareEarth.material())
	var drawn := _into.get_child(_into.get_child_count() - 1)
	drawn.set_meta(LightShadows.FLOOR, true)
	# Added to the tree before the meta was set: take it off the walls' layer again.
	(drawn as GeometryInstance3D).layers &= ~LightShadows.WALL_LAYER


## A flat tinted square over a grid cell (the blueprint of a dug cell).
func _cell_quad(parent: Node3D, cell: Vector2i, colour: Color, high := 0.0) -> void:
	var mid := plan.cell_world(cell.x, cell.y) + Vector3(0, 0.07 + high, 0)
	_box(parent, mid, Vector3(HouseSketch.CELL - 0.1, 0.04, HouseSketch.CELL - 0.1), _material(colour))
	# A dark frame, so a planned square stands out from the grass.
	var frame := _material(Color(0.1, 0.07, 0.03, 0.9))
	var edge := HouseSketch.CELL * 0.5 - 0.05
	for sign_ in [-1.0, 1.0]:
		_box(parent, mid + Vector3(edge * sign_, 0.01, 0), Vector3(0.08, 0.05, HouseSketch.CELL - 0.1), frame)
		_box(parent, mid + Vector3(0, 0.01, edge * sign_), Vector3(HouseSketch.CELL - 0.1, 0.05, 0.08), frame)


## A built piece: solid stone, a doorway (see _solid_doorway), or a window
## with a pane. A piece marked for demolition is tinted red. Walls and jambs
## stop the hero; the door in the doorway stops them only while shut.
func _solid_piece(house: HouseSketch, edge: Array, kind: String, demolish: bool) -> void:
	var a := house.node_world(edge[0], edge[1])
	var along_x: bool = edge[2] == HouseSketch.ORIENT_X
	var mid := a + (Vector3(HouseSketch.CELL * 0.5, 0, 0) if along_x else Vector3(0, 0, HouseSketch.CELL * 0.5))
	var flat := Vector3(HouseSketch.CELL + THICK, 0, THICK) if along_x else Vector3(THICK, 0, HouseSketch.CELL + THICK)
	var stone: Material = _solid_material(DEMOLISH_COLOR) if demolish else HouseLooks.temple_stone()
	# Where the wall runs on (the next piece in line, the storey above), for the
	# rounded edges of its stone (see _hidden_faces).
	var storey := roundi(_lift / HouseSketch.STOREY_HEIGHT)
	var orient: String = edge[2]
	var step := Vector2i(1, 0) if along_x else Vector2i(0, 1)
	var axis := Vector3.RIGHT if along_x else Vector3.BACK
	var lo := (a - axis * THICK * 0.5).dot(axis)
	_piece_run = {"axis": axis, "lo": lo, "hi": lo + HouseSketch.CELL + THICK,
		"before": house.has_piece(edge[0] - step.x, edge[1] - step.y, orient, storey),
		"after": house.has_piece(edge[0] + step.x, edge[1] + step.y, orient, storey),
		"above": house.has_piece(edge[0], edge[1], orient, storey + 1)}
	if HouseSketch.FENCE_KINDS.has(kind):
		_fence_run(house, edge, storey, axis, a)
	_solid_piece_parts(mid, flat, along_x, kind, demolish, stone)
	_piece_run = {}


## Where a garden wall piece on `edge` starts and ends along `axis` (from its node
## `a`), so that no two stone garden walls overlap: two boxes sharing a face's
## place flicker through each other (z-fighting). A wall that runs on into the
## next garden wall piece (or a gate) stops at the node between them; at a free
## end it reaches half its thickness past the node. Where two stone garden walls
## meet at a corner the one along x fills the corner and the one along z stops
## at its face; where one runs on past the node, the one that ends there stops
## at its face. Also fills _piece_run for the rounded edges (see _hidden_faces).
func _fence_run(house: HouseSketch, edge: Array, storey: int, axis: Vector3, a: Vector3) -> void:
	var along_x: bool = edge[2] == HouseSketch.ORIENT_X
	var half := FENCE_THICK * 0.5
	var ends := []
	var across := HouseSketch.ORIENT_Y if along_x else HouseSketch.ORIENT_X
	var step := Vector2i(1, 0) if along_x else Vector2i(0, 1)
	var side := Vector2i(0, 1) if along_x else Vector2i(1, 0)
	for end: int in [0, 1]:
		var node: Vector2i = Vector2i(edge[0], edge[1]) + step * end
		# The next piece in line past this node, and the walls across it there.
		var next: Vector2i = node if end == 1 else node - step
		var runs_on := _fence_on(house, next.x, next.y, edge[2], storey, false)
		var runs_on_stone := _fence_on(house, next.x, next.y, edge[2], storey, true)
		var cross_before := _fence_on(house, node.x - side.x, node.y - side.y, across, storey, true)
		var cross_after := _fence_on(house, node.x, node.y, across, storey, true)
		var through := cross_before and cross_after
		var reach := half
		if along_x:
			if runs_on_stone:
				reach = 0.0
			elif through:
				reach = -half
			elif runs_on:
				reach = 0.0
		elif through:
			reach = -half
		elif cross_before or cross_after:
			reach = 0.0 if runs_on_stone else -half
		elif runs_on:
			reach = 0.0
		ends.append(reach)
	_fence_ends = Vector2(ends[0], ends[1])
	var lo := a.dot(axis) - _fence_ends.x
	_piece_run = {"axis": axis, "lo": lo, "hi": a.dot(axis) + HouseSketch.CELL + _fence_ends.y,
		"before": _fence_ends.x < half, "after": _fence_ends.y < half, "above": false}


## Whether a built (or to be taken down) garden wall piece stands on the edge
## (x, y, orient) of `storey`: a stone one only with `stone_only`, else any kind,
## gates included.
func _fence_on(house: HouseSketch, x: int, y: int, orient: String, storey: int, stone_only: bool) -> bool:
	var key := HouseSketch.key_of(x, y, orient, storey)
	if not house.pieces.has(key):
		return false
	var piece: Dictionary = house.pieces[key]
	if piece.state == HouseSketch.SKETCH:
		return false
	return piece.kind == HouseSketch.STONE_FENCE if stone_only else HouseSketch.FENCE_KINDS.has(piece.kind)


func _solid_piece_parts(mid: Vector3, flat: Vector3, along_x: bool, kind: String, demolish: bool, stone: Material) -> void:
	var a := mid - (Vector3(HouseSketch.CELL * 0.5, 0, 0) if along_x else Vector3(0, 0, HouseSketch.CELL * 0.5))
	if HouseSketch.FENCE_KINDS.has(kind):
		_solid_fence(mid, along_x, kind, demolish)
		return
	match kind:
		HouseSketch.DOOR:
			_solid_doorway(mid, along_x, stone, demolish)
		HouseSketch.WINDOW:
			_solid_window(mid, flat, along_x, stone, demolish)
		_:
			_solid_box(mid + Vector3(0, WALL_HEIGHT * 0.5, 0), flat + Vector3(0, WALL_HEIGHT, 0), stone)
	if kind == HouseSketch.WALL or kind == HouseSketch.DOOR:
		# Nothing is picked up or used through it (see Level.can_reach); a window is reached through.
		var b := a + (mid - a) * 2.0
		game.level.reach_walls.append({"a": Vector2(a.x, a.z), "b": Vector2(b.x, b.z), "y": a.y + _lift,
				"door": _new_door if kind == HouseSketch.DOOR else null})
	elif kind == HouseSketch.WINDOW:
		# Seen through, but no blow or shot goes through the pane (see Level.built_between).
		var b := a + (mid - a) * 2.0
		game.level.built_windows.append({"a": Vector2(a.x, a.z), "b": Vector2(b.x, b.z), "y": a.y + _lift})


## A doorway in a house wall: stone jambs of the temple's blocks from the
## floor to the wall's top, a timber lintel of the town houses' stair boards
## resting on them, a board casing round the opening, a stone threshold and
## the door leaf itself (see BuiltDoor). The lintel is only seen, as the hero's
## reach comes up to it.
func _solid_doorway(mid: Vector3, along_x: bool, stone: Material, demolish: bool) -> void:
	var axis := Vector3.RIGHT if along_x else Vector3.BACK
	var across := Vector3.BACK if along_x else Vector3.RIGHT
	var wood: Material = _solid_material(DEMOLISH_COLOR) if demolish else HouseLooks.stair_wood()
	var opening := HouseSketch.CELL - 2.0 * DOOR_JAMB
	# The jambs reach into the corner, as a wall piece does.
	var jamb_long := DOOR_JAMB + THICK * 0.5
	var jamb_deep := THICK + 0.1
	for sign_ in [-1.0, 1.0]:
		var at: Vector3 = mid + axis * sign_ * (opening * 0.5 + jamb_long * 0.5) + Vector3(0, WALL_HEIGHT * 0.5, 0)
		_solid_box(at, _along(axis, across, jamb_long, WALL_HEIGHT, jamb_deep), stone)
	# The lintel: a beam over the opening, its ends resting on the jambs.
	# It stands a hair over the jambs, so its top never shares their top face (that flickers).
	var beam := WALL_HEIGHT - DOOR_HEIGHT + FACE_GAP
	_visual_box(mid + Vector3(0, DOOR_HEIGHT + beam * 0.5, 0), _along(axis, across, opening + 0.5, beam, jamb_deep + 0.06), wood)
	# The casing: boards lining the opening's sides.
	for sign_ in [-1.0, 1.0]:
		var at: Vector3 = mid + axis * sign_ * (opening * 0.5 - 0.03) + Vector3(0, DOOR_HEIGHT * 0.5, 0)
		_visual_box(at, _along(axis, across, 0.06, DOOR_HEIGHT, jamb_deep + 0.02), wood)
	# The threshold: a worn stone slab, too low to trip over.
	# A hair higher than a floor on the ground (FLOOR_RISE), so their tops never flicker.
	var sill_top: float = HouseSketch.FLOOR_RISE + FACE_GAP
	_visual_box(mid + Vector3(0, sill_top * 0.5, 0), _along(axis, across, opening, sill_top, jamb_deep + 0.1), stone)
	_new_door = _door_leaf(mid, along_x, Vector2(opening - 0.12, DOOR_HEIGHT - 0.02), false, demolish)


## A window in a house wall, framed like a doorway (see _solid_doorway): stone
## jambs from the floor to the wall's top, stone under the sill and over the
## lintel, a timber lintel and casing of the stair boards round the opening, a
## sill board that juts out on the outside, a pane with a cross of glazing bars,
## and a pair of shutters on the outside face (see BuiltShutters).
func _solid_window(mid: Vector3, flat: Vector3, along_x: bool, stone: Material, demolish: bool) -> void:
	var axis := Vector3.RIGHT if along_x else Vector3.BACK
	var across := Vector3.BACK if along_x else Vector3.RIGHT
	var wood: Material = _solid_material(DEMOLISH_COLOR) if demolish else HouseLooks.stair_wood()
	var opening := HouseSketch.CELL - 2.0 * JAMB
	var jamb_long := JAMB + THICK * 0.5
	var jamb_deep := THICK + 0.1
	var high := WINDOW_TOP - SILL
	for sign_ in [-1.0, 1.0]:
		var at: Vector3 = mid + axis * sign_ * (opening * 0.5 + jamb_long * 0.5) + Vector3(0, WALL_HEIGHT * 0.5, 0)
		_solid_box(at, _along(axis, across, jamb_long, WALL_HEIGHT, jamb_deep), stone)
	# The wall under the sill and over the lintel, between the jambs.
	_solid_box(mid + Vector3(0, SILL * 0.5, 0), _along(axis, across, opening, SILL, THICK), stone)
	var beam := WINDOW_LINTEL
	var over := WINDOW_TOP + beam
	_solid_box(mid + Vector3(0, (over + WALL_HEIGHT) * 0.5, 0), _along(axis, across, opening, WALL_HEIGHT - over, THICK), stone)
	# The lintel: a beam over the opening, its ends resting on the jambs.
	_visual_box(mid + Vector3(0, WINDOW_TOP + beam * 0.5, 0), _along(axis, across, opening + 0.5, beam, jamb_deep + 0.06), wood)
	# The casing: boards lining the opening's sides, and the sill board, jutting
	# out a little on the outside so rain runs off.
	for sign_ in [-1.0, 1.0]:
		var at: Vector3 = mid + axis * sign_ * (opening * 0.5 - 0.03) + Vector3(0, SILL + high * 0.5, 0)
		_visual_box(at, _along(axis, across, 0.06, high, jamb_deep + 0.02), wood)
	# Its inner face lies a hair inside the jambs' face (never in the same plane, which flickers).
	var sill_deep := jamb_deep + 0.08
	_visual_box(mid + across * _outside * 0.06 + Vector3(0, SILL + 0.03, 0), _along(axis, across, opening + 0.2, 0.06, sill_deep), wood)
	# The pane and its glazing bars: one upright and one across, on both faces.
	# One walks into this house, so its glass is clear from both sides: what lights it at night is
	# the light the hero has put up inside, shining out through it (only the houses one cannot walk
	# into have panes that glow by themselves, see WindowLights).
	if _abandoned:
		# An empty house: no light behind the panes, and most of the glass is gone. Shards are
		# left in the corners of the frame.
		var shard := _solid_material(BROKEN_GLASS)
		var pane_w := opening - 0.1
		_visual_box(mid + axis * (-pane_w * 0.34) + Vector3(0, SILL + high * 0.18, 0), _along(axis, across, pane_w * 0.32, high * 0.36, 0.03), shard)
		_visual_box(mid + axis * (-pane_w * 0.4) + Vector3(0, SILL + high * 0.5, 0), _along(axis, across, pane_w * 0.2, high * 0.28, 0.03), shard)
		_visual_box(mid + axis * (pane_w * 0.36) + Vector3(0, SILL + high * 0.84, 0), _along(axis, across, pane_w * 0.28, high * 0.3, 0.03), shard)
	else:
		_pane(mid + Vector3(0, SILL + high * 0.5, 0), across * _outside, Vector2(opening - 0.1, high))
	_visual_box(mid + Vector3(0, SILL + high * 0.5, 0), _along(axis, across, 0.05, high, 0.06), wood)
	# The bar across is a hair deeper than the upright, so their faces never share a plane.
	_visual_box(mid + Vector3(0, SILL + high * 0.55, 0), _along(axis, across, opening - 0.1, 0.05, 0.07), wood)
	# The pane itself stops the hero too: a window is no way through.
	_collide(mid + Vector3(0, (SILL + WINDOW_TOP) * 0.5, 0), flat + Vector3(0, high, 0))
	var shutters_at := mid + across * _outside * (jamb_deep * 0.5 + 0.07) + Vector3(0, SILL + 0.07, 0)
	_new_shutters = _shutter_pair(shutters_at, along_x, Vector2(opening - 0.04, high - 0.04), demolish)


## A window's glass, two clear faces back to back (see _solid_window), one turned to `out` and one
## into the room, each drawn from its own side only. Glass casts no shadow.
func _pane(at: Vector3, out: Vector3, size: Vector2) -> void:
	for face in [1.0, -1.0]:
		var m := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = size
		m.mesh = quad
		var facing: Vector3 = out * face
		# A quad shows its +z side: turned so that faces `facing`.
		m.basis = Basis(Vector3.UP.cross(facing), Vector3.UP, facing)
		m.position = at + facing * 0.012 + Vector3(0, _lift, 0)
		m.set_meta("ymin", at.y + _lift - size.y * 0.5)
		m.material_override = clear_glass()
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.name = "ClearPane"
		_into.add_child(m)


## A window's glass: clear and faintly blue, a little shiny.
static func clear_glass() -> StandardMaterial3D:
	if _clear_glass == null:
		_clear_glass = StandardMaterial3D.new()
		_clear_glass.albedo_color = Color(0.72, 0.82, 0.9, 0.12)
		_clear_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_clear_glass.roughness = 0.05
		_clear_glass.metallic_specular = 0.7
	return _clear_glass


static var _clear_glass: StandardMaterial3D


## Which way from the wall on an edge the outside lies, along +z for an edge
## along x and along +x for one along z: +1 or -1. A window's shutters and sill
## board go on that side. When both sides or neither lie inside the house
## (see _inside_now), it is +1.
func _outside_of(x: int, y: int, orient: String) -> float:
	var sides := HouseSketch.cells_beside(x, y, orient)
	if _inside_now.has(sides[1]) and not _inside_now.has(sides[0]):
		return -1.0
	return 1.0


## The pair of shutters standing at `at` on a window's outside face (see BuiltShutters).
func _shutter_pair(at: Vector3, along_x: bool, opening: Vector2, demolish: bool) -> BuiltShutters:
	var pair := BuiltShutters.new()
	if demolish:
		pair.tint = DEMOLISH_COLOR
	pair.setup(opening)
	pair.position = at + Vector3(0, _lift, 0)
	# The node's +z points out of the house.
	if along_x:
		pair.rotation.y = 0.0 if _outside > 0.0 else PI
	else:
		pair.rotation.y = PI * 0.5 if _outside > 0.0 else -PI * 0.5
	# Fades with the wall it hangs on (see _update_fade): no shutters float over a cellar.
	pair.set_meta("ymin", pair.position.y)
	_solid.add_child(pair)
	return pair


## Hands new shutters their owner and whether they are shut (kept in the plan).
func _hang_shutters(pair: BuiltShutters, house: HouseSketch, key: String, own: bool) -> void:
	pair.own = own
	if house.shut.has(key):
		pair.shut = true
		pair.closed = 1.0
		pair._pose()
	if own:
		pair.on_change = func(on: bool) -> void:
			if plan == null or not plan.pieces.has(key):
				return
			if on:
				plan.shut[key] = true
			else:
				plan.shut.erase(key)
			plan.save(game.hero_name)
	shutters["%s|%s" % [house.plot, key]] = pair


## The hero's own window shutters nearest `point` within `reach` (metres, along
## the ground and about one storey up or down), or null.
func shutters_near(point: Vector3, reach := 1.8) -> BuiltShutters:
	var best: BuiltShutters = null
	var best_d := reach
	for k in shutters:
		var pair: BuiltShutters = shutters[k]
		if not is_instance_valid(pair) or not pair.is_inside_tree() or not pair.own:
			continue
		var at := pair.global_position
		if point.y - at.y > 1.0 or at.y - point.y > 2.0:
			continue
		var dist := Vector2(point.x - at.x, point.z - at.z).length()
		if dist < best_d:
			best_d = dist
			best = pair
	return best


## A box `long` along the wall, `high` tall and `deep` through it.
static func _along(axis: Vector3, across: Vector3, long: float, high: float, deep: float) -> Vector3:
	return (axis * long + across * deep).abs() + Vector3(0, high, 0)


## A door or gate leaf standing in the opening at `mid` (see BuiltDoor).
func _door_leaf(mid: Vector3, along_x: bool, opening: Vector2, is_gate: bool, demolish: bool) -> BuiltDoor:
	var door := BuiltDoor.new()
	if demolish:
		door.tint = DEMOLISH_COLOR
	door.setup(opening, is_gate)
	door.position = mid + Vector3(0, _lift, 0)
	door.rotation.y = 0.0 if along_x else -PI * 0.5
	door.set_meta("ymin", mid.y + _lift)
	_solid.add_child(door)
	return door


## Hands a new leaf its owner, lock and the state the door had before the
## houses were drawn again.
func _hang_door(door: BuiltDoor, house: HouseSketch, key: String, own: bool, was: Dictionary) -> void:
	var id := "%s|%s" % [house.plot, key]
	door.own = own
	door.hero = game.player if game != null else null
	door.locked = house.locked.has(key)
	door._show_lock()
	if own:
		door.on_lock = func(on: bool) -> void:
			if plan == null or not plan.pieces.has(key):
				return
			if on:
				plan.locked[key] = true
			else:
				plan.locked.erase(key)
			plan.save(game.hero_name)
	if was.has(id):
		door.restore(was[id])
	doors[id] = door


## The built door or gate nearest `point` within `reach` (metres, along the
## ground and about one storey up or down), or null.
func door_near(point: Vector3, reach := 2.0) -> BuiltDoor:
	var best: BuiltDoor = null
	var best_d := reach
	for k in doors:
		var d: BuiltDoor = doors[k]
		if not is_instance_valid(d) or not d.is_inside_tree():
			continue
		var at := d.global_position
		if absf(point.y - at.y) > 1.5:
			continue
		var dist := Vector2(point.x - at.x, point.z - at.z).length()
		if dist < best_d:
			best_d = dist
			best = d
	return best


## A built garden wall: a low stone wall, a board fence between two posts, or
## a gate (two posts and an open way between them). On a roof it is a railing:
## a stone parapet or a timber railing (posts, handrail and balusters), with an
## unseen guard above it up to RAIL_GUARD, so the hero cannot jump over it.
func _solid_fence(mid: Vector3, along_x: bool, kind: String, demolish: bool) -> void:
	var high := _fence_high()
	var span := HouseSketch.CELL * 0.5
	var step := Vector3(span, 0, 0) if along_x else Vector3(0, 0, span)
	var post := Vector3(GATE_POST, high + 0.2, GATE_POST)
	var wood := _solid_material(DEMOLISH_COLOR if demolish else WOOD_COLOR)
	var rail := _lift > 0.0
	if rail and kind != HouseSketch.GATE:
		var guard := Vector3(HouseSketch.CELL, RAIL_GUARD - high, FENCE_THICK) if along_x else Vector3(FENCE_THICK, RAIL_GUARD - high, HouseSketch.CELL)
		_collide(mid + Vector3(0, (high + RAIL_GUARD) * 0.5, 0), guard)
	if rail and kind == HouseSketch.WOOD_FENCE:
		var plank := _solid_material(DEMOLISH_COLOR if demolish else PLANK_COLOR)
		var top := Vector3(HouseSketch.CELL + 0.12, 0.1, 0.14) if along_x else Vector3(0.14, 0.1, HouseSketch.CELL + 0.12)
		_solid_box(mid + Vector3(0, high - 0.05, 0), top, plank)
		_visual_box(mid + Vector3(0, 0.12, 0), top - Vector3(0, 0.02, 0), plank)
		for sign_ in [-1.0, 1.0]:
			_solid_box(mid + step * sign_ + Vector3(0, high * 0.5, 0), Vector3(0.16, high, 0.16), wood)
		# Balusters between the posts: see-through, but too close to slip between.
		for i in range(1, 6):
			var along := (i / 6.0 - 0.5) * HouseSketch.CELL
			var at := mid + (Vector3(along, 0, 0) if along_x else Vector3(0, 0, along))
			_solid_box(at + Vector3(0, high * 0.5, 0), Vector3(0.06, high - 0.1, 0.06), wood)
		return
	match kind:
		HouseSketch.STONE_FENCE:
			# Drawn with its ends as _fence_run worked them out, so it never overlaps the
			# next wall; it stops the hero over the whole cell and its corners, seamless.
			var flat := Vector3(HouseSketch.CELL + FENCE_THICK, high, FENCE_THICK) if along_x else Vector3(FENCE_THICK, high, HouseSketch.CELL + FENCE_THICK)
			_collide(mid + Vector3(0, high * 0.5, 0), flat)
			var length := HouseSketch.CELL + _fence_ends.x + _fence_ends.y
			var shift := (_fence_ends.y - _fence_ends.x) * 0.5
			var drawn := Vector3(length, high, FENCE_THICK) if along_x else Vector3(FENCE_THICK, high, length)
			var centre := mid + (Vector3(shift, 0, 0) if along_x else Vector3(0, 0, shift))
			_visual_box(centre + Vector3(0, high * 0.5, 0), drawn, _solid_material(DEMOLISH_COLOR) if demolish else HouseLooks.temple_stone())
		HouseSketch.WOOD_FENCE:
			var boards := Vector3(HouseSketch.CELL, high - 0.1, 0.1) if along_x else Vector3(0.1, high - 0.1, HouseSketch.CELL)
			_solid_box(mid + Vector3(0, (high - 0.1) * 0.5, 0), boards, _solid_material(DEMOLISH_COLOR if demolish else PLANK_COLOR))
			for sign_ in [-1.0, 1.0]:
				_solid_box(mid + step * sign_ + Vector3(0, high * 0.5, 0), Vector3(0.18, high, 0.18), wood)
		_:
			var inner := step - (Vector3(GATE_POST * 0.5, 0, 0) if along_x else Vector3(0, 0, GATE_POST * 0.5))
			for sign_ in [-1.0, 1.0]:
				_solid_box(mid + inner * sign_ + Vector3(0, post.y * 0.5, 0), post, wood)
			# A gate on the ground gets a board leaf between its posts (a gap in a
			# roof railing stays open).
			if not rail:
				_new_door = _door_leaf(mid, along_x, Vector2(HouseSketch.CELL - 2.0 * GATE_POST - 0.04, high - 0.05), true, demolish)


func _solid_box(at: Vector3, size: Vector3, mat: Material) -> void:
	_visual_box(at, size, mat)
	_collide(at, size)


## `hidden`: the faces of a stone box that lie against something (see
## _hidden_faces, which works them out when none are given).
func _visual_box(at: Vector3, size: Vector3, mat: Material, hidden: Array = []) -> void:
	var m := MeshInstance3D.new()
	if mat == HouseLooks.temple_stone() and mat is ShaderMaterial:
		# Stone walls get their outer edges rounded off (see StoneLook), but not
		# where they stand on something or butt against the next piece.
		m.mesh = StoneLook.rounded_box(size, hidden if not hidden.is_empty() else _hidden_faces(at, size))
	else:
		var box := BoxMesh.new()
		box.size = size
		m.mesh = box
	m.material_override = mat
	m.position = at + Vector3(0, _lift, 0)
	m.set_meta("ymin", at.y + _lift - size.y * 0.5)
	_into.add_child(m)


## The faces of a stone box that lie against something (see StoneLook.rounded_box):
## the bottom always; the top when the wall goes on in the storey above; and an
## end of the wall piece being built (_piece_run) when the wall runs on there.
func _hidden_faces(at: Vector3, size: Vector3) -> Array:
	var hidden: Array = [Vector3.DOWN]
	if _piece_run.is_empty():
		return hidden
	var axis: Vector3 = _piece_run["axis"]
	if _piece_run["above"] and absf(at.y + size.y * 0.5 - WALL_HEIGHT) < 0.02:
		hidden.append(Vector3.UP)
	var half := absf(size.dot(axis)) * 0.5
	var mid := at.dot(axis)
	if _piece_run["before"] and absf(mid - half - (_piece_run["lo"] as float)) < 0.02:
		hidden.append(-axis)
	if _piece_run["after"] and absf(mid + half - (_piece_run["hi"] as float)) < 0.02:
		hidden.append(axis)
	return hidden


func _collide(at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at + Vector3(0, _lift, 0)
	_body.add_child(shape)


func _solid_material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	if colour.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _draw_grid() -> void:
	var mesh := ImmediateMesh.new()
	var n := plan.nodes()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for y in range(n.y + 1):
		mesh.surface_add_vertex(plan.node_world(0, y) + Vector3(0, 0.06, 0))
		mesh.surface_add_vertex(plan.node_world(n.x, y) + Vector3(0, 0.06, 0))
	for x in range(n.x + 1):
		mesh.surface_add_vertex(plan.node_world(x, 0) + Vector3(0, 0.06, 0))
		mesh.surface_add_vertex(plan.node_world(x, n.y) + Vector3(0, 0.06, 0))
	mesh.surface_end()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GRID_COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid.mesh = mesh
	_grid.material_override = mat
	_grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A piece on an edge: a wall, a door frame or a window. `tint` of zero alpha
## means the kind's own blueprint colour.
## `grow` makes it that much thicker, to show over a built piece on the same edge.
func _segment(parent: Node3D, edge: Array, kind: String, tint: Color, grow := 0.0) -> void:
	var a := plan.node_world(edge[0], edge[1])
	var along_x: bool = edge[2] == HouseSketch.ORIENT_X
	var mid := a + (Vector3(HouseSketch.CELL * 0.5, 0, 0) if along_x else Vector3(0, 0, HouseSketch.CELL * 0.5))
	var size_flat := Vector3(HouseSketch.CELL + THICK, 0, THICK + grow) if along_x else Vector3(THICK + grow, 0, HouseSketch.CELL + THICK)
	var colour := tint
	if tint.a == 0.0:
		colour = {HouseSketch.WALL: WALL_COLOR, HouseSketch.DOOR: DOOR_COLOR, HouseSketch.WINDOW: WINDOW_COLOR,
				HouseSketch.STONE_FENCE: FENCE_COLOR, HouseSketch.WOOD_FENCE: FENCE_COLOR, HouseSketch.GATE: DOOR_COLOR}[kind]
	var mat := _material(colour)
	var low := _fence_high()
	match kind:
		HouseSketch.STONE_FENCE, HouseSketch.WOOD_FENCE:
			var thick := Vector3(HouseSketch.CELL + FENCE_THICK, 0, FENCE_THICK + grow) if along_x else Vector3(FENCE_THICK + grow, 0, HouseSketch.CELL + FENCE_THICK)
			_box(parent, mid + Vector3(0, low * 0.5, 0), thick + Vector3(0, low, 0), mat)
		HouseSketch.GATE:
			var span := HouseSketch.CELL * 0.5 - GATE_POST * 0.5
			var step := Vector3(span, 0, 0) if along_x else Vector3(0, 0, span)
			for sign_ in [-1.0, 1.0]:
				_box(parent, mid + step * sign_ + Vector3(0, (low + 0.2) * 0.5, 0), Vector3(GATE_POST + grow, low + 0.2, GATE_POST + grow), mat)
		HouseSketch.DOOR:
			# Two jambs and a lintel over the opening.
			var jamb := Vector3(0.25 + grow, DOOR_HEIGHT, 0.25 + grow)
			var span := HouseSketch.CELL * 0.5 - 0.125
			var step := Vector3(span, 0, 0) if along_x else Vector3(0, 0, span)
			_box(parent, mid - step + Vector3(0, DOOR_HEIGHT * 0.5, 0), jamb, mat)
			_box(parent, mid + step + Vector3(0, DOOR_HEIGHT * 0.5, 0), jamb, mat)
			_box(parent, mid + Vector3(0, (DOOR_HEIGHT + WALL_HEIGHT) * 0.5, 0), size_flat + Vector3(0, WALL_HEIGHT - DOOR_HEIGHT, 0), mat)
		HouseSketch.WINDOW:
			_box(parent, mid + Vector3(0, SILL * 0.5, 0), size_flat + Vector3(0, SILL, 0), mat)
			_box(parent, mid + Vector3(0, (WINDOW_TOP + WALL_HEIGHT) * 0.5, 0), size_flat + Vector3(0, WALL_HEIGHT - WINDOW_TOP, 0), mat)
		_:
			_box(parent, mid + Vector3(0, WALL_HEIGHT * 0.5, 0), size_flat + Vector3(0, WALL_HEIGHT, 0), mat)


## A small post at a node while no wall is being dragged.
func _marker(parent: Node3D, node: Vector2i) -> void:
	_box(parent, plan.node_world(node.x, node.y) + Vector3(0, 0.5, 0), Vector3(0.2, 1.0, 0.2), _material(OK_COLOR))


func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	at += Vector3(0, _lift, 0)
	var m := MeshInstance3D.new()
	if mat == HouseLooks.temple_stone() and mat is ShaderMaterial:
		# Stone walls get their outer edges rounded off (see StoneLook), but not
		# where they stand on something or butt against the next piece.
		m.mesh = StoneLook.rounded_box(size, _hidden_faces(at, size))
	else:
		var box := BoxMesh.new()
		box.size = size
		m.mesh = box
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if colour.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
