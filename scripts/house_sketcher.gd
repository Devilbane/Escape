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
const TOOL_WALL := "wall"
const TOOL_DOOR := "door"
const TOOL_WINDOW := "window"
const TOOL_ERASE := "erase"
const TOOL_DIG := "dig"
const TOOL_STAIRS := "stairs"
const TOOLS := [TOOL_WALL, TOOL_DOOR, TOOL_WINDOW, TOOL_ERASE]
## The cellar's tools (their own row in the tool bar).
const CELLAR_TOOLS := [TOOL_DIG, TOOL_STAIRS]
const SURFACE_NAMES := {"": "roh", "stone": "aus Stein", "wood": "aus Holz"}
const DIG_COLOR := Color(0.62, 0.45, 0.25, 0.5)
const STAIRS_COLOR := Color(1.0, 0.8, 0.4, 0.55)
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
const STATUS_WIDTH := 640.0
## The character builds one piece this often (seconds) while the hero is near
## the plot, and works only within this many metres of its middle.
const BUILD_SECONDS := 12.0
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
var _wall_button: Button
var _redo_button: Button
var _status: Label
var _hover_key := ""


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
	if plan == null or not plan.ordered or game.state != game.State.PLAYING or not game.player.can_act():
		return
	var middle := plan.node_world(plan.nodes().x / 2, plan.nodes().y / 2)
	if Vector2(game.player.global_position.x - middle.x, game.player.global_position.z - middle.z).length() > BUILD_RANGE + plan.nodes().length() * HouseSketch.CELL * 0.25:
		return
	_work += delta
	if _work < BUILD_SECONDS:
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
	if tool == TOOL_DIG:
		if pressed:
			drag_from = plan.cell_at(point)
			hover(point)
		elif drag_from.x >= 0:
			var cells := plan.cells_between(drag_from, plan.cell_at(point))
			drag_from = Vector2i(-1, -1)
			_clear(_ghost)
			if plan.sketch_dig(cells) == 0:
				_say(Lang.t("Dort ist schon gegraben oder gebaut."))
			_changed()
		return
	if tool == TOOL_STAIRS:
		if pressed:
			var c := plan.cell_at(point)
			var dir := plan.stairs_dir(c.x, c.y)
			if dir == "":
				_say(reason("no cellar"))
			else:
				plan.sketch_stairs(c.x, c.y, dir)
				_changed()
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
			var n := plan.sketch(run, HouseSketch.WALL)
			_changed()
			if n == 0:
				_say(Lang.t("Dort steht schon eine Wand."))
		return
	if not pressed:
		return
	var edge := plan.edge_near(point, HouseSketch.CELL * 0.3) if tool == TOOL_ERASE else plan.edge_near(point)
	if tool == TOOL_ERASE and edge.is_empty():
		var c := plan.cell_at(point)
		var was_built: bool = plan.hole_key(c.x, c.y) != "" and plan.pieces[plan.hole_key(c.x, c.y)].state == HouseSketch.BUILT
		var why_not := plan.erase_cell(c.x, c.y)
		if why_not == "needed":
			_say(Lang.t("Die Treppe führt hierher: Nimm zuerst die Treppe zurück."))
		elif why_not == "" and was_built:
			_say(Lang.t("Zum Zuschütten vorgemerkt: Dein Held füllt es auf und bekommt das Material zurück."))
		_changed()
		return
	if edge.is_empty():
		return
	if tool == TOOL_ERASE:
		var had := plan.piece(edge[0], edge[1], edge[2])
		if plan.erase([edge]) > 0 and had.get("state", "") == HouseSketch.BUILT:
			_say(Lang.t("Zum Abriss vorgemerkt: Dein Held reißt es ab und bekommt das Material zurück."))
		_changed()
		return
	var why := plan.problem(edge[0], edge[1], edge[2], tool)
	if why != "":
		_say(reason(why))
		return
	plan.sketch([edge], tool)
	_changed()


## The ghost follows the mouse.
func hover(point: Vector3) -> void:
	if not active or plan == null:
		return
	var key := ""
	if tool == TOOL_DIG or tool == TOOL_STAIRS:
		var c := plan.cell_at(point)
		var from_cell := drag_from if drag_from.x >= 0 and tool == TOOL_DIG else c
		key = "c:%s:%s" % [from_cell, c]
		if key == _hover_key:
			return
		_hover_key = key
		_clear(_ghost)
		if tool == TOOL_DIG:
			var cells := plan.cells_between(from_cell, c)
			for cell in cells:
				_cell_quad(_ghost, Vector2i(cell[0], cell[1]), OK_COLOR if plan.problem_dig(cell[0], cell[1]) == "" else BAD_COLOR)
			_say(Lang.t("Keller: %d Felder") % cells.size() if drag_from.x >= 0 else "")
		else:
			var dir := plan.stairs_dir(c.x, c.y)
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
			for e in run:
				_segment(_ghost, e, HouseSketch.WALL, OK_COLOR)
			_say(Lang.t("Wand: %d m") % int(run.size() * HouseSketch.CELL) if not run.is_empty() else "")
		else:
			_marker(_ghost, to)
		return
	var edge := plan.edge_near(point, HouseSketch.CELL * 0.3) if tool == TOOL_ERASE else plan.edge_near(point)
	key = "e:%s" % [edge]
	if key == _hover_key:
		return
	_hover_key = key
	_clear(_ghost)
	if edge.is_empty():
		if tool == TOOL_ERASE:
			var cell := plan.cell_at(point)
			if plan.hole_key(cell.x, cell.y) != "":
				_cell_quad(_ghost, cell, DEMOLISH_COLOR)
		_say("")
		return
	if tool == TOOL_ERASE:
		var had := plan.piece(edge[0], edge[1], edge[2])
		_segment(_ghost, edge, had.get("kind", HouseSketch.WALL), BAD_COLOR if had.is_empty() else (DEMOLISH_COLOR if had.state != HouseSketch.SKETCH else OK_COLOR))
		return
	var why := plan.problem(edge[0], edge[1], edge[2], tool)
	_segment(_ghost, edge, tool, OK_COLOR if why == "" else BAD_COLOR)
	_say(reason(why) if why != "" else "")


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

func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.visible = false
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.offset_bottom = -16
	_bar.add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.BRONZE))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_bar.add_child(box)
	var stages := HBoxContainer.new()
	stages.alignment = BoxContainer.ALIGNMENT_CENTER
	stages.add_theme_constant_override("separation", 10)
	box.add_child(stages)
	for i in STAGES.size():
		if i > 0:
			var arrow: Label = UiKit.label(UiKit.TEXT_FONT, 18, OFF_COLOR)
			arrow.text = "▸"
			stages.add_child(arrow)
		var l: Label = UiKit.label(UiKit.TEXT_FONT, 20, OFF_COLOR)
		l.text = Lang.t(STAGE_NAMES[STAGES[i]])
		l.custom_minimum_size = Vector2(110, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stages.add_child(l)
		_stage_labels[STAGES[i]] = l
	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 8)
	box.add_child(tools)
	var names := {TOOL_WALL: "Wand", TOOL_DOOR: "Tür", TOOL_WINDOW: "Fenster", TOOL_ERASE: "Radierer"}
	for t in TOOLS:
		var b: Button = UiKit.button(Lang.t(names[t]), select_tool.bind(t))
		b.custom_minimum_size = Vector2(120, 48)
		tools.add_child(b)
		_tool_buttons[t] = b
	_undo_button = UiKit.button(Lang.t("Rückgängig"), undo)
	_undo_button.custom_minimum_size = Vector2(110, 48)
	tools.add_child(_undo_button)
	_redo_button = UiKit.button(Lang.t("Wiederholen"), redo)
	_redo_button.custom_minimum_size = Vector2(90, 48)
	tools.add_child(_redo_button)
	var done: Button = UiKit.button(Lang.t("Schließen"), leave)
	done.custom_minimum_size = Vector2(110, 48)
	tools.add_child(done)
	var cellar := HBoxContainer.new()
	cellar.alignment = BoxContainer.ALIGNMENT_CENTER
	cellar.add_theme_constant_override("separation", 8)
	box.add_child(cellar)
	var cellar_names := {TOOL_DIG: "Keller graben", TOOL_STAIRS: "Kellertreppe"}
	for t in CELLAR_TOOLS:
		var b: Button = UiKit.button(Lang.t(cellar_names[t]), select_tool.bind(t))
		b.custom_minimum_size = Vector2(170, 48)
		cellar.add_child(b)
		_tool_buttons[t] = b
	_floor_button = UiKit.button("", cycle_floor)
	_floor_button.custom_minimum_size = Vector2(190, 48)
	cellar.add_child(_floor_button)
	_wall_button = UiKit.button("", cycle_wall)
	_wall_button.custom_minimum_size = Vector2(230, 48)
	cellar.add_child(_wall_button)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_deposit_button = UiKit.button(Lang.t("Material abgeben"), deposit_materials)
	_deposit_button.custom_minimum_size = Vector2(250, 48)
	actions.add_child(_deposit_button)
	_order_button = UiKit.button(Lang.t("Bau beauftragen"), toggle_order)
	_order_button.custom_minimum_size = Vector2(250, 48)
	actions.add_child(_order_button)
	_stock_label = UiKit.label(UiKit.TEXT_FONT, 16, Color(0.8, 0.9, 1.0))
	_stock_label.custom_minimum_size = Vector2(STATUS_WIDTH, 26)
	_stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stock_label.clip_text = true
	_stock_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_stock_label)
	_status = UiKit.label(UiKit.TEXT_FONT, 16, Color(1.0, 0.75, 0.5))
	_status.custom_minimum_size = Vector2(STATUS_WIDTH, 26)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_status)
	if game != null and game._hud != null:
		game._hud.add_child(_bar)
	else:
		add_child(_bar)


func _update_bar() -> void:
	if _bar == null:
		return
	var stage := plan.stage() if plan != null else "plan"
	for s in STAGES:
		_stage_labels[s].add_theme_color_override("font_color", ON_COLOR if s == stage else OFF_COLOR)
	for t in TOOLS + CELLAR_TOOLS:
		var b: Button = _tool_buttons[t]
		var on: bool = t == tool
		b.add_theme_color_override("font_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
		b.add_theme_color_override("font_hover_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed") if on else b.get_theme_stylebox("hover"))
	_undo_button.disabled = plan == null or not plan.can_undo()
	_redo_button.disabled = plan == null or not plan.can_redo()
	if plan != null:
		_floor_button.text = Lang.t("Kellerboden: %s") % Lang.t(SURFACE_NAMES[plan.floor_surface])
		_wall_button.text = Lang.t("Kellerwände: %s") % Lang.t(SURFACE_NAMES[plan.wall_surface])
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
			return Lang.t("Wand: Maustaste halten und auf dem Raster ziehen. Rechtsklick beendet.")
		TOOL_DOOR:
			return Lang.t("Tür: Klicke eine Wand an.")
		TOOL_WINDOW:
			return Lang.t("Fenster: Klicke eine Wand an.")
		TOOL_DIG:
			return Lang.t("Graben: Maustaste halten und ein Rechteck aufziehen. Boden und Wand wählst du vorher.")
		TOOL_STAIRS:
			return Lang.t("Treppe: Klicke ein Feld vor dem Keller an. Sie führt vier Meter nach unten.")
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
	for deed in Plots.all():
		var house := plan if plan != null and deed.rect == _plot else HouseSketch.of(deed.owner, deed.rect)
		for key in house.pieces:
			var p := HouseSketch.parts_of(key)
			var piece: Dictionary = house.pieces[key]
			if piece.state != HouseSketch.SKETCH and not HouseSketch.CELLAR_KINDS.has(piece.kind):
				_solid_piece(house, [p[1], p[2], p[3]], piece.kind, piece.state == HouseSketch.DEMOLISH)
		_solid_cellar(house, holes)
	game.level.set_floor_holes(holes)
	if plan == null:
		return
	for key in plan.pieces:
		if plan.pieces[key].state == HouseSketch.SKETCH:
			var p := HouseSketch.parts_of(key)
			if HouseSketch.CELLAR_KINDS.has(plan.pieces[key].kind):
				if plan.pieces[key].kind == HouseSketch.DIG:
					_cell_quad(_built, Vector2i(p[1], p[2]), DIG_COLOR)
				else:
					for c in HouseSketch.stairs_cells(p[1], p[2], p[3]).slice(0, 2):
						_cell_quad(_built, c, STAIRS_COLOR)
			else:
				_segment(_built, [p[1], p[2], p[3]], plan.pieces[key].kind, Color(0, 0, 0, 0))


## The cellar of a house: the ground opens over every built cell, the pit gets
## a floor, walls and stairs, and `holes` collects the open cells (Rect2 in
## world x/z) so the map can cut its ground there.
func _solid_cellar(house: HouseSketch, holes: Array) -> void:
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
		if piece.kind == HouseSketch.STAIRS and piece.state != HouseSketch.SKETCH:
			var p := HouseSketch.parts_of(key)
			_ramp(house, p[1], p[2], p[3], piece.state == HouseSketch.DEMOLISH)


## The ramp of a stairs piece: it runs from the ground at the top of its first
## cell down to the cellar floor at the end of its second.
func _ramp(house: HouseSketch, x: int, y: int, dir: String, demolish: bool) -> void:
	var step: Vector2i = HouseSketch.DOWN[dir]
	var flat := Vector3(step.x, 0, step.y)
	var start := house.cell_world(x, y) - flat * (HouseSketch.CELL * 0.5)
	var run := HouseSketch.CELL * 2.0
	var slope := Vector3(0, -HouseSketch.DEPTH, 0) + flat * run
	var length := slope.length()
	var along := slope / length
	var up := (Vector3.UP - along * along.dot(Vector3.UP)).normalized()
	var basis := Basis(along, up, along.cross(up))
	var thick := 0.3
	var at := Transform3D(basis, start + slope * 0.5 - up * thick * 0.5)
	var size := Vector3(length, thick, HouseSketch.CELL) if step.x != 0 else Vector3(HouseSketch.CELL, thick, length)
	if step.x == 0:
		# The box's long side must run along the slope: turn it for north and south.
		basis = Basis(up.cross(along), up, along)
		at = Transform3D(basis, start + slope * 0.5 - up * thick * 0.5)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = _solid_material(DEMOLISH_COLOR if demolish else PLANK_COLOR)
	m.transform = at
	_solid.add_child(m)
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
func _cell_quad(parent: Node3D, cell: Vector2i, colour: Color) -> void:
	_box(parent, plan.cell_world(cell.x, cell.y) + Vector3(0, 0.07, 0), Vector3(HouseSketch.CELL - 0.1, 0.04, HouseSketch.CELL - 0.1), _material(colour))


## A built piece: solid stone, a doorway with a wooden lintel, or a window
## with a pane. A piece marked for demolition is tinted red. Walls, jambs and
## lintels stop the hero; the doorway stays open.
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
			_solid_box(mid + Vector3(0, (DOOR_HEIGHT + WALL_HEIGHT) * 0.5, 0), lintel, wood)
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
	m.position = at
	_solid.add_child(m)


func _collide(at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
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
