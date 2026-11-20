class_name HouseSketcher
extends Node3D
## The blueprint tool on the hero's plot (see Plots and HouseSketch). A signpost
## on the plot's north-west corner opens it. The hero then draws their house
## like a floor plan: drag along the grid to draw a wall, click a wall to turn
## it into a door or a window, click a piece with the eraser to take it back.
## A ghost shows what the next click does (green fits, red does not, and the
## message line says why), and undo and redo take edits back.
##
## The sketch is only a blueprint: faint, see-through pieces without collision.
## Building it solid is the character's work: the hero hands stone blocks and
## timber over at the sign, orders the build, and while they are near the plot
## the character turns one sketched piece after another solid (every BUILD_SECONDS),
## using up the material. Erasing a built piece marks it for demolition: the
## character takes it down and the material comes back. The stage banner shows
## the cycle: Plan, Build, Done, and Done leads back to Plan.
##
## The tool bar sits at the bottom of the screen with fixed sizes, so a tool or
## a stage never reshapes it.

const KIND := "bauplan"
## How far the camera looks past the plot's middle (metres), to lift the plot above the tool bar.
const VIEW_SHIFT := 4.0
const TOOL_WALL := "wall"
const TOOL_DOOR := "door"
const TOOL_WINDOW := "window"
const TOOL_ERASE := "erase"
const TOOL_DIG := "dig"
const TOOL_STAIRS := "stairs"
## The cellar ceiling, which is the ground floor's floor too (see HouseSketch.COVER).
const TOOL_COVER := "cover"
const TOOLS := [TOOL_WALL, TOOL_DOOR, TOOL_WINDOW, TOOL_ERASE]
## The cellar's tools (their own row in the tool bar).
const CELLAR_TOOLS := [TOOL_DIG, TOOL_STAIRS, TOOL_COVER]
## Floors, roofs and the stairs up: they work on the level chosen with the
## level button (0 ground floor, 1 upper floor, -1 cellar).
const TOOL_SLAB := "slab"
const TOOL_SADDLE := "saddle"
const TOOL_UP := "up"
const ROOF_TOOLS := [TOOL_SLAB, TOOL_SADDLE, TOOL_UP]
## Tools that drag a rectangle of cells.
const RECT_TOOLS := [TOOL_DIG, TOOL_COVER, TOOL_SLAB, TOOL_SADDLE]
const LEVEL_NAMES := {-1: "im Keller", 0: "im Erdgeschoss", 1: "im Obergeschoss"}
const SLAB_COLOR := Color(0.9, 0.75, 0.4, 0.7)
const ROOF_COLOR := Color(0.55, 0.22, 0.16)
const SURFACE_NAMES := {"": "roh", "stone": "aus Stein", "wood": "aus Holz"}
const COVER_COLOR := Color(0.75, 0.6, 0.35, 0.8)
const DIG_COLOR := Color(0.9, 0.55, 0.15, 0.8)
const STAIRS_COLOR := Color(1.0, 0.85, 0.3, 0.8)
const EARTH_COLOR := Color(0.28, 0.2, 0.13)
const PLANK_COLOR := Color(0.5, 0.34, 0.18)
const WALL_HEIGHT := 2.6
const THICK := 0.2
const DOOR_HEIGHT := 2.0
const SILL := 0.9
const WINDOW_TOP := 1.9
const GRID_COLOR := Color(0.7, 0.85, 1.0, 0.35)
const WALL_COLOR := Color(0.55, 0.75, 1.0, 0.4)
const DOOR_COLOR := Color(1.0, 0.8, 0.4, 0.55)
const WINDOW_COLOR := Color(0.6, 0.95, 1.0, 0.5)
const OK_COLOR := Color(0.4, 0.95, 0.4, 0.55)
const BAD_COLOR := Color(1.0, 0.4, 0.35, 0.55)
const STAGES := ["plan", "build", "done"]
const STAGE_NAMES := {"plan": "Planen", "build": "Bauen", "done": "Fertig"}
const ON_COLOR := Color(1.0, 0.82, 0.4)
const OFF_COLOR := Color(1, 1, 1, 0.4)
## Where a roof or slab sketch is drawn above the floor of its storey.
const SILL_TOP := 2.7
const STATUS_WIDTH := 880.0
## The character builds one piece this often (seconds) while the hero is near
## the plot, and works only within this many metres of its middle.
const BUILD_SECONDS := 12.0
## Digging a square of the cellar goes faster than raising a wall.
const DIG_SECONDS := 3.0
const BUILD_RANGE := 16.0
const STONE_COLOR := Color(0.5, 0.48, 0.44)
const WOOD_COLOR := Color(0.4, 0.27, 0.15)
const GLASS_COLOR := Color(0.6, 0.8, 0.9, 0.35)
const DEMOLISH_COLOR := Color(1.0, 0.45, 0.35, 0.6)

var game: Node
var active := false
var tool := TOOL_WALL
var plan: HouseSketch
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
var _sign: Node3D
var _sign_body: StaticBody3D
var _station := {}
var _bar: PanelContainer
var _stage_labels := {}
var _tool_buttons := {}
var _undo_button: Button
var _floor_button: Button
var _level_button: Button
## The level the wall, door, window, eraser and roof tools work on.
var storey := 0
## Added to the height of everything drawn for the storey being drawn.
var _lift := 0.0
## Built roof cells by ground cell on the 2 m lattice: the highest storey whose ceiling is there.
var _covered := {}
var _fade_state := ""
var _wall_button: Button
var _ceiling_button: Button
var _redo_button: Button
var _status: Label
var _hover_key := ""
var _refresh_in := 0.0


func _ready() -> void:
	add_child(_built)
	add_child(_solid)
	add_child(_body)
	add_child(_ghost)
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
	if active:
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
			game.show_message(Lang.t("Dein Held wartet auf Material für den Bau: Gib Steinblöcke und Bauholz am Bauplan-Schild ab."), 5.0)
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


# --- The plot and its sign ----------------------------------------------------

## Draws the hero's sign and plan again (after a plot is registered or the
## plan changed).
func refresh() -> void:
	if game == null or not game.level is Outdoor:
		return
	if _sign != null:
		_sign.queue_free()
		_sign_body.queue_free()
		_sign = null
		_sign_body = null
		game.level.stations.erase(_station)
		_station = {}
	_plot = Plots.plot_of(game.hero_name)
	if _plot.size == Vector2i.ZERO:
		plan = null
		_redraw()
		return
	if plan == null or plan.plot != _plot:
		plan = HouseSketch.of(game.hero_name, _plot)
	_build_sign()
	_redraw()


func _build_sign() -> void:
	var c := _plot.position
	var pos: Vector3 = game.level.cell_to_world(c) + Vector3(-1.4, 0, -1.4)
	_sign = Node3D.new()
	_sign.position = pos
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.3, 0.17)
	var board := StandardMaterial3D.new()
	board.albedo_color = Color(0.78, 0.68, 0.45)
	_box(_sign, Vector3(0, 0.7, 0), Vector3(0.14, 1.4, 0.14), wood)
	_box(_sign, Vector3(0, 1.25, 0), Vector3(0.9, 0.5, 0.08), board)
	var label := Label3D.new()
	label.text = Lang.t("Bauplan")
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = Color(0.25, 0.15, 0.05)
	label.position = Vector3(0, 1.25, 0.05)
	label.no_depth_test = false
	_sign.add_child(label)
	add_child(_sign)
	_sign_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.4, 0.4)
	shape.shape = box
	shape.position = Vector3(0, 0.7, 0)
	_sign_body.add_child(shape)
	_sign_body.position = pos
	add_child(_sign_body)
	_station = {"kind": KIND, "cell": c, "pos": pos, "used": false, "owner": game.hero_name}
	game.level.stations.append(_station)


# --- Entering and leaving -----------------------------------------------------

## The hero runs into their sign.
func enter() -> void:
	if plan == null:
		game.show_message(Lang.t("Du hast noch kein Grundstück. Das Amt der Krone trägt es dir ein."), 3.0)
		return
	active = true
	drag_from = Vector2i(-1, -1)
	if game.plot_marker != null:
		game.plot_marker.cancel()
	_grid.visible = true
	_bar.visible = true
	_draw_grid()
	select_tool(TOOL_WALL)
	game.show_message(Lang.t("Bauplan: Ziehe Wände auf dem Raster. Das Haus darf kleiner sein als das Grundstück."), 4.0)
	_update_bar()


## Where the camera looks while the tool is open: the middle of the plot, moved
## so that the plot clears the tool bar (see Game._process).
func view_centre() -> Vector3:
	var mid := plan.node_world(plan.nodes().x / 2, plan.nodes().y / 2)
	return Vector3(mid.x, 0.0, mid.z + VIEW_SHIFT)


func leave() -> void:
	if not active:
		return
	active = false
	drag_from = Vector2i(-1, -1)
	_grid.visible = false
	_bar.visible = false
	_clear(_ghost)
	if plan != null:
		plan.save(game.hero_name)


## Gives up the drag in progress (the mouse was let go off the ground).
func cancel_drag() -> void:
	drag_from = Vector2i(-1, -1)
	_clear(_ghost)


func select_tool(next: String) -> void:
	tool = next
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
				var why := "no dig"
				for c in cells:
					if plan.problem_cover(c[0], c[1]) == "stairs":
						why = "stairs"
				_say(reason(why))
			elif done == 0:
				_say(Lang.t("Dort ist schon gegraben oder gebaut."))
			else:
				_say(Lang.t("%d Felder vorgemerkt. Beauftrage den Bau: Dein Held baut es dann.") % done)
		return
	if tool == TOOL_UP:
		if pressed:
			var c := plan.cell_at(point)
			var dir := plan.upstairs_dir(c.x, c.y)
			if dir == "":
				_say(reason("no slab"))
			else:
				plan.sketch_upstairs(c.x, c.y, dir)
				_changed()
				_say(Lang.t("Treppe vorgemerkt. Beauftrage den Bau: Dein Held baut sie dann."))
		return
	if tool == TOOL_STAIRS:
		if pressed:
			var c := plan.cell_at(point)
			var dir := plan.stairs_dir(c.x, c.y)
			if dir == "":
				var why := "no cellar"
				for d in HouseSketch.DOWN:
					if plan.problem_stairs(c.x, c.y, d) == "covered":
						why = "covered"
				_say(reason(why))
			else:
				plan.sketch_stairs(c.x, c.y, dir)
				_changed()
				_say(Lang.t("Treppe vorgemerkt. Beauftrage den Bau: Dein Held baut sie dann."))
		return
	if tool == TOOL_WALL:
		if pressed:
			drag_from = plan.node_at(point)
			hover(point)
		elif drag_from.x >= 0:
			var run := plan.run_between(drag_from, plan.node_at(point))
			drag_from = Vector2i(-1, -1)
			_clear(_ghost)
			if run.is_empty():
				return
			var n := plan.sketch(run, HouseSketch.WALL, storey)
			_changed()
			if n == 0:
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
		elif why_not == "" and was_built:
			_say(Lang.t("Zum Abriss vorgemerkt: Dein Held reißt es ab und bekommt das Material zurück."))
		_changed()
		return
	if edge.is_empty():
		return
	if tool == TOOL_ERASE:
		var had := plan.piece(edge[0], edge[1], edge[2], storey)
		if plan.erase([edge], storey) > 0 and had.get("state", "") == HouseSketch.BUILT:
			_say(Lang.t("Zum Abriss vorgemerkt: Dein Held reißt es ab und bekommt das Material zurück."))
		_changed()
		return
	var why := plan.problem(edge[0], edge[1], edge[2], tool, storey)
	if why != "":
		_say(reason(why))
		return
	plan.sketch([edge], tool, storey)
	_changed()


## The ghost follows the mouse.
func hover(point: Vector3) -> void:
	if not active or plan == null:
		return
	var key := ""
	if tool in RECT_TOOLS or tool == TOOL_STAIRS or tool == TOOL_UP:
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
			var dir := plan.stairs_dir(c.x, c.y) if tool == TOOL_STAIRS else plan.upstairs_dir(c.x, c.y)
			if dir == "":
				_cell_quad(_ghost, c, BAD_COLOR)
			else:
				for cell in HouseSketch.stairs_cells(c.x, c.y, dir).slice(0, 2):
					_cell_quad(_ghost, cell, OK_COLOR)
			_say("")
		return
	if tool == TOOL_WALL:
		var to := plan.node_at(point)
		var from := drag_from if drag_from.x >= 0 else to
		key = "w:%s:%s" % [from, to]
		if key == _hover_key:
			return
		_hover_key = key
		_clear(_ghost)
		if drag_from.x >= 0:
			var run := plan.run_between(from, to)
			_lift = storey * HouseSketch.STOREY_HEIGHT
			for e in run:
				_segment(_ghost, e, HouseSketch.WALL, OK_COLOR)
			_lift = 0.0
			_say(Lang.t("Wand: %d m") % int(run.size() * HouseSketch.CELL) if not run.is_empty() else "")
		else:
			_marker(_ghost, to)
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
		_segment(_ghost, edge, piece_here.get("kind", HouseSketch.WALL), DEMOLISH_COLOR if piece_here.state != HouseSketch.SKETCH else OK_COLOR)
		_lift = 0.0
		return
	var why := plan.problem(edge[0], edge[1], edge[2], tool, storey)
	_segment(_ghost, edge, tool, OK_COLOR if why == "" else BAD_COLOR)
	_lift = 0.0
	_say(reason(why) if why != "" else "")


## The key of the cell piece the eraser takes at a cell on the current level, or "":
## in the cellar the ceiling, then the dug cell or stairs; above, the slab or roof,
## on the ground floor then the stairs up, then the cellar ceiling (its floor).
func _eraser_key(c: Vector2i) -> String:
	var cover := HouseSketch.key_of(c.x, c.y, HouseSketch.COVER_ORIENT, HouseSketch.CELLAR_STOREY)
	if storey < 0:
		if plan.pieces.has(cover) and plan.pieces[cover].state != HouseSketch.DEMOLISH:
			return cover
		return plan.hole_key(c.x, c.y)
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
		"built":
			return Lang.t("Das ist schon gebaut. Reiß es mit dem Radierer ab, um es zu ändern.")
		"taken":
			return Lang.t("Dort ist schon gegraben oder gebaut.")
		"no cellar":
			return Lang.t("Eine Treppe braucht zwei freie Felder und danach einen gegrabenen Keller.")
		"no slab":
			return Lang.t("Eine Treppe nach oben braucht zwei freie Felder und danach eine Decke.")
		"no dig":
			return Lang.t("Die Kellerdecke kommt nur über gegrabene Felder. Über der Treppe bleibt sie offen.")
		"stairs":
			return Lang.t("Am Fuß der Treppe bleibt die Kellerdecke offen, damit du aufrecht hinabsteigen kannst.")
		"covered":
			return Lang.t("Über dem Fuß der Treppe liegt die Kellerdecke: Nimm sie dort erst zurück.")
		"storey":
			return Lang.t("Höher als das Obergeschoss baut dein Held nicht.")
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
	var names := {TOOL_WALL: "Wand", TOOL_DOOR: "Tür", TOOL_WINDOW: "Fenster", TOOL_ERASE: "Radierer"}
	var roof_names := {TOOL_SLAB: "Decke oder Flachdach", TOOL_SADDLE: "Satteldach", TOOL_UP: "Treppe nach oben"}
	var cellar_names := {TOOL_DIG: "Keller graben", TOOL_STAIRS: "Kellertreppe", TOOL_COVER: "Kellerdecke"}
	for t in [TOOL_WALL, TOOL_DOOR, TOOL_WINDOW, TOOL_SLAB, TOOL_SADDLE, TOOL_UP, TOOL_DIG, TOOL_STAIRS, TOOL_COVER, TOOL_ERASE]:
		var label: String = names.get(t, roof_names.get(t, cellar_names.get(t, "")))
		var b := _small_button(Lang.t(label), select_tool.bind(t))
		tools.add_child(b)
		_tool_buttons[t] = b
	# Row 2: the level the tools work on, the surfaces of the cellar, undo and redo.
	var options := _row(box)
	_level_button = _small_button("", cycle_level, 210)
	options.add_child(_level_button)
	_floor_button = _small_button("", cycle_floor, 190)
	options.add_child(_floor_button)
	_wall_button = _small_button("", cycle_wall, 190)
	options.add_child(_wall_button)
	_ceiling_button = _small_button("", cycle_ceiling, 190)
	options.add_child(_ceiling_button)
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


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
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
		_floor_button.text = Lang.t("Kellerboden: %s") % Lang.t(SURFACE_NAMES[plan.floor_surface])
		_wall_button.text = Lang.t("Kellerwände: %s") % Lang.t(SURFACE_NAMES[plan.wall_surface])
		_ceiling_button.text = Lang.t("Kellerdecke: %s") % Lang.t(SURFACE_NAMES[plan.ceiling_surface])
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


## What the next cellar ceiling is made of: wood or stone, never bare earth.
func cycle_ceiling() -> void:
	if plan == null:
		return
	plan.ceiling_surface = HouseSketch.CEILINGS[(HouseSketch.CEILINGS.find(plan.ceiling_surface) + 1) % HouseSketch.CEILINGS.size()]
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
			return Lang.t("Tür: Klicke eine Wand an.")
		TOOL_WINDOW:
			return Lang.t("Fenster: Klicke eine Wand an.")
		TOOL_DIG:
			return Lang.t("Graben: Maustaste halten, Rechteck aufziehen, loslassen. Rechtsklick oder Esc beendet.")
		TOOL_STAIRS:
			return Lang.t("Treppe: Klicke ein Feld vor dem Keller an. Sie führt vier Meter nach unten.")
		TOOL_COVER:
			return Lang.t("Kellerdecke: Ziehe ein Rechteck über den Keller. Sie ist zugleich der Boden des Erdgeschosses.")
		TOOL_SLAB:
			return Lang.t("Decke: Ziehe ein Rechteck. Sie ist Boden des Stockwerks darüber oder ein begehbares Flachdach.")
		TOOL_SADDLE:
			return Lang.t("Satteldach: Ziehe ein Rechteck. Der First läuft entlang der langen Seite.")
		TOOL_UP:
			return Lang.t("Treppe nach oben: Klicke ein Feld vor einer Decke an. Sie führt vier Meter hinauf.")
	return Lang.t("Radierer: Klicke ein Stück an, um es zurückzunehmen.")


func _say(text: String) -> void:
	if _status != null:
		_status.text = text if text != "" else _hint()


# --- Drawing -------------------------------------------------------------------

func _clear(node: Node3D) -> void:
	for child in node.get_children():
		child.queue_free()
	_hover_key = ""


func _redraw() -> void:
	_clear(_built)
	_clear(_solid)
	for child in _body.get_children():
		child.queue_free()
	if game == null or not game.level is Outdoor:
		return
	# Everyone's built pieces stand on the map for all to see.
	var holes := []
	var floored := []
	var ceilinged := []
	_covered.clear()
	_fade_state = ""
	for deed in Plots.all():
		var house := plan if plan != null and deed.rect == _plot else HouseSketch.of(deed.owner, deed.rect)
		if _has_floors(house):
			floored.append(house)
		for key in house.pieces:
			var p := HouseSketch.parts_of(key)
			var piece: Dictionary = house.pieces[key]
			if piece.state != HouseSketch.SKETCH and not HouseSketch.CELL_KINDS.has(piece.kind):
				_lift = p[0] * HouseSketch.STOREY_HEIGHT
				_solid_piece(house, [p[1], p[2], p[3]], piece.kind, piece.state == HouseSketch.DEMOLISH)
				_lift = 0.0
		_solid_cellar(house, holes, ceilinged)
		_solid_above(house)
	game.level.set_floor_holes(holes, ceilinged)
	game.level.house_floors = HouseFloors.new(floored) if not floored.is_empty() else null
	_raise_roofs()
	if plan == null:
		return
	for key in plan.pieces:
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
			else:
				_lift = p[0] * HouseSketch.STOREY_HEIGHT
				_segment(_built, [p[1], p[2], p[3]], kind, Color(0, 0, 0, 0))
				_lift = 0.0


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
## them a cellar ceiling closes again.
func _solid_cellar(house: HouseSketch, holes: Array, ceilinged: Array = []) -> void:
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
	for c: Vector2i in open:
		var piece: Dictionary = open[c]
		var demolish: bool = piece.state == HouseSketch.DEMOLISH
		var corner := house.node_world(c.x, c.y)
		holes.append(Rect2(corner.x, corner.z, HouseSketch.CELL, HouseSketch.CELL))
		var middle := house.cell_world(c.x, c.y)
		var is_dig: bool = piece.kind == HouseSketch.DIG
		if is_dig:
			var floor_mat := _solid_material(DEMOLISH_COLOR if demolish else _surface_color(piece.get("floor", "")))
			_visual_box(middle + Vector3(0, -HouseSketch.DEPTH - 0.04, 0), Vector3(HouseSketch.CELL, 0.08, HouseSketch.CELL), floor_mat)
			_collide(middle + Vector3(0, -HouseSketch.DEPTH - 0.25, 0), Vector3(HouseSketch.CELL, 0.5, HouseSketch.CELL))
		var wall_mat := _solid_material(DEMOLISH_COLOR if demolish else _surface_color(piece.get("wall", "") if is_dig else ""))
		for dir in HouseSketch.DOWN:
			var step: Vector2i = HouseSketch.DOWN[dir]
			if open.has(c + step):
				continue
			var side := Vector3(step.x, 0, step.y) * (HouseSketch.CELL * 0.5 - 0.05)
			var size := Vector3(0.1, HouseSketch.DEPTH, HouseSketch.CELL) if step.x != 0 else Vector3(HouseSketch.CELL, HouseSketch.DEPTH, 0.1)
			_visual_box(middle + side + Vector3(0, -HouseSketch.DEPTH * 0.5, 0), size, wall_mat)
	for key in house.pieces:
		var piece: Dictionary = house.pieces[key]
		if piece.state == HouseSketch.SKETCH:
			continue
		var p := HouseSketch.parts_of(key)
		if piece.kind == HouseSketch.STAIRS:
			_ramp(house, p[1], p[2], p[3], piece.state == HouseSketch.DEMOLISH)
		elif piece.kind == HouseSketch.COVER and open.has(Vector2i(p[1], p[2])):
			_cellar_ceiling(house, p[1], p[2], piece)
			var corner := house.node_world(p[1], p[2])
			ceilinged.append(Rect2(corner.x, corner.z, HouseSketch.CELL, HouseSketch.CELL))


## The cellar ceiling over a dug cell: a floor of planks or stone whose top is
## the ground, so the hero walks over the cellar on the ground floor. The ground
## stays cut open under it (the cellar is still there). While the hero is down in
## the cellar under it, it fades like a roof (see _update_fade).
func _cellar_ceiling(house: HouseSketch, x: int, y: int, piece: Dictionary) -> void:
	var colour := DEMOLISH_COLOR if piece.state == HouseSketch.DEMOLISH else _surface_color(piece.get("surface", "wood"))
	var thick := HouseSketch.COVER_THICK
	_solid_box(house.cell_world(x, y) + Vector3(0, -thick * 0.5, 0), Vector3(HouseSketch.CELL, thick, HouseSketch.CELL), _solid_material(colour))
	# The mesh: fades away while the hero is in the cellar below it.
	var mesh: Node = _solid.get_child(_solid.get_child_count() - 1)
	mesh.set_meta("ymin", 0.0)
	_cover(house, x, y, HouseSketch.CELLAR_STOREY)


## The floors, roofs and stairs up of a house. Everything is solid: a slab
## carries the hero (a flat roof too), a saddle roof only keeps the rain out.
func _solid_above(house: HouseSketch) -> void:
	for key in house.pieces:
		var piece: Dictionary = house.pieces[key]
		if piece.state == HouseSketch.SKETCH:
			continue
		var p := HouseSketch.parts_of(key)
		var demolish: bool = piece.state == HouseSketch.DEMOLISH
		var base: float = p[0] * HouseSketch.STOREY_HEIGHT + WALL_HEIGHT
		var mid := house.cell_world(p[1], p[2])
		match piece.kind:
			HouseSketch.SLAB:
				_solid_box(mid + Vector3(0, base + HouseSketch.SLAB_THICK * 0.5, 0), Vector3(HouseSketch.CELL, HouseSketch.SLAB_THICK, HouseSketch.CELL),
						_solid_material(DEMOLISH_COLOR if demolish else PLANK_COLOR))
				_cover(house, p[1], p[2], p[0])
			HouseSketch.SADDLE:
				_saddle(mid, base + HouseSketch.SLAB_THICK, p[3] == "rx", demolish)
				_cover(house, p[1], p[2], p[0])
			HouseSketch.UPSTAIRS:
				_ramp(house, p[1], p[2], p[3], demolish, HouseSketch.STOREY_HEIGHT)


## One cell of pitched roof: two boards up to the ridge and a triangle at each end.
func _saddle(mid: Vector3, eave: float, ridge_x: bool, demolish: bool) -> void:
	var half := HouseSketch.CELL * 0.5
	var rise := HouseSketch.ROOF_RISE
	var colour := DEMOLISH_COLOR if demolish else ROOF_COLOR
	var across := Vector3(0, 0, half) if ridge_x else Vector3(half, 0, 0)
	var peak := mid + Vector3(0, eave + rise, 0)
	for sign_ in [-1.0, 1.0]:
		_slanted(mid + across * sign_ + Vector3(0, eave, 0), peak, HouseSketch.CELL, 0.15, colour, true)
	var along := Vector3(half - 0.05, 0, 0) if ridge_x else Vector3(0, 0, half - 0.05)
	for sign_ in [-1.0, 1.0]:
		var prism := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(HouseSketch.CELL, rise, 0.1)
		prism.mesh = mesh
		prism.material_override = _solid_material(colour)
		prism.position = mid + along * sign_ + Vector3(0, eave + rise * 0.5, 0)
		if ridge_x:
			prism.rotation.y = PI * 0.5
		prism.set_meta("ymin", eave)
		_solid.add_child(prism)


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
	if game == null or game.player == null or (_covered.is_empty() and _fade_state == ""):
		return
	var pos: Vector3 = game.player.global_position
	var level := -1 if pos.y < -0.5 else clampi(floori((pos.y + 0.2) / HouseSketch.STOREY_HEIGHT), 0, HouseSketch.MAX_STOREY + 1)
	var at := Vector2i(floori((pos.x + Level.TILE * 0.5) / HouseSketch.CELL), floori((pos.z + Level.TILE * 0.5) / HouseSketch.CELL))
	var inside := false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if int(_covered.get(at + Vector2i(dx, dy), -2)) >= level:
				inside = true
	var state := "%d:%s" % [level, inside]
	if state == _fade_state:
		return
	_fade_state = state
	var limit := (level * HouseSketch.STOREY_HEIGHT + WALL_HEIGHT - 0.05) if level >= 0 else -0.05
	for node in _solid.get_children():
		if node.has_meta("ymin"):
			node.visible = not (inside and float(node.get_meta("ymin")) >= limit)


## The ramp of a stairs piece: from the ground at the top of its first cell
## down to the cellar floor (or up to the next storey) at the end of its second.
func _ramp(house: HouseSketch, x: int, y: int, dir: String, demolish: bool, rise := -HouseSketch.DEPTH) -> void:
	var step: Vector2i = HouseSketch.DOWN[dir]
	var flat := Vector3(step.x, 0, step.y)
	var start := house.cell_world(x, y) - flat * (HouseSketch.CELL * 0.5)
	_slanted(start, start + flat * HouseSketch.CELL * 2.0 + Vector3(0, rise, 0), HouseSketch.CELL, 0.3,
			DEMOLISH_COLOR if demolish else PLANK_COLOR, true)


## A thick slanted board from point `a` to point `b` (its upper face runs
## through both), `width` wide across the slope. It stops the hero.
func _slanted(a: Vector3, b: Vector3, width: float, thick: float, colour: Color, collide: bool) -> void:
	var slope := b - a
	var length := slope.length()
	var along := slope / length
	var up := (Vector3.UP - along * along.dot(Vector3.UP)).normalized()
	var basis := Basis(along, up, along.cross(up))
	var at := Transform3D(basis, a + slope * 0.5 - up * thick * 0.5)
	var size := Vector3(length, thick, width)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = _solid_material(colour)
	m.transform = at
	m.set_meta("ymin", minf(a.y, b.y) - thick)
	_solid.add_child(m)
	if collide:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		shape.transform = at
		_body.add_child(shape)


func _surface_color(surface: String) -> Color:
	match surface:
		"stone":
			return STONE_COLOR
		"wood":
			return PLANK_COLOR
	return EARTH_COLOR


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


## A built piece: solid stone, a doorway with a wooden lintel, or a window
## with a pane. A piece marked for demolition is tinted red. Walls and jambs
## stop the hero; the doorway (lintel included) stays open.
func _solid_piece(house: HouseSketch, edge: Array, kind: String, demolish: bool) -> void:
	var a := house.node_world(edge[0], edge[1])
	var along_x: bool = edge[2] == HouseSketch.ORIENT_X
	var mid := a + (Vector3(HouseSketch.CELL * 0.5, 0, 0) if along_x else Vector3(0, 0, HouseSketch.CELL * 0.5))
	var flat := Vector3(HouseSketch.CELL + THICK, 0, THICK) if along_x else Vector3(THICK, 0, HouseSketch.CELL + THICK)
	var stone := _solid_material(DEMOLISH_COLOR if demolish else STONE_COLOR)
	var wood := _solid_material(DEMOLISH_COLOR if demolish else WOOD_COLOR)
	match kind:
		HouseSketch.DOOR:
			var jamb := Vector3(0.3, DOOR_HEIGHT, 0.3)
			var span := HouseSketch.CELL * 0.5 - 0.15
			var step := Vector3(span, 0, 0) if along_x else Vector3(0, 0, span)
			var lintel := flat + Vector3(0, WALL_HEIGHT - DOOR_HEIGHT, 0)
			for sign_ in [-1.0, 1.0]:
				_solid_box(mid + step * sign_ + Vector3(0, DOOR_HEIGHT * 0.5, 0), jamb, stone)
			# The lintel is only seen: the hero (2.4 m with their reach, see Player.tall) must fit
			# through the doorway, so only the jambs stop them.
			_visual_box(mid + Vector3(0, (DOOR_HEIGHT + WALL_HEIGHT) * 0.5, 0), lintel, wood)
		HouseSketch.WINDOW:
			_solid_box(mid + Vector3(0, SILL * 0.5, 0), flat + Vector3(0, SILL, 0), stone)
			_solid_box(mid + Vector3(0, (WINDOW_TOP + WALL_HEIGHT) * 0.5, 0), flat + Vector3(0, WALL_HEIGHT - WINDOW_TOP, 0), stone)
			_visual_box(mid + Vector3(0, (SILL + WINDOW_TOP) * 0.5, 0), flat * 0.5 + Vector3(0, WINDOW_TOP - SILL, 0), _solid_material(GLASS_COLOR))
			# The pane itself stops the hero too: a window is no way through.
			_collide(mid + Vector3(0, (SILL + WINDOW_TOP) * 0.5, 0), flat + Vector3(0, WINDOW_TOP - SILL, 0))
		_:
			_solid_box(mid + Vector3(0, WALL_HEIGHT * 0.5, 0), flat + Vector3(0, WALL_HEIGHT, 0), stone)


func _solid_box(at: Vector3, size: Vector3, mat: Material) -> void:
	_visual_box(at, size, mat)
	_collide(at, size)


func _visual_box(at: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = at + Vector3(0, _lift, 0)
	m.set_meta("ymin", at.y + _lift - size.y * 0.5)
	_solid.add_child(m)


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
func _segment(parent: Node3D, edge: Array, kind: String, tint: Color) -> void:
	var a := plan.node_world(edge[0], edge[1])
	var along_x: bool = edge[2] == HouseSketch.ORIENT_X
	var mid := a + (Vector3(HouseSketch.CELL * 0.5, 0, 0) if along_x else Vector3(0, 0, HouseSketch.CELL * 0.5))
	var size_flat := Vector3(HouseSketch.CELL + THICK, 0, THICK) if along_x else Vector3(THICK, 0, HouseSketch.CELL + THICK)
	var colour := tint
	if tint.a == 0.0:
		colour = {HouseSketch.WALL: WALL_COLOR, HouseSketch.DOOR: DOOR_COLOR, HouseSketch.WINDOW: WINDOW_COLOR}[kind]
	var mat := _material(colour)
	match kind:
		HouseSketch.DOOR:
			# Two jambs and a lintel over the opening.
			var jamb := Vector3(0.25, DOOR_HEIGHT, 0.25)
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


func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
	at += Vector3(0, _lift, 0)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)


func _material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if colour.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
