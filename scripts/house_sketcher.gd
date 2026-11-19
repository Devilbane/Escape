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
## Building it solid is the character's work (see the construction phase). The
## stage banner shows the cycle: Plan, Build, Done, and Done leads back to Plan.
##
## The tool bar sits at the bottom of the screen with fixed sizes, so a tool or
## a stage never reshapes it.

const KIND := "bauplan"
const TOOL_WALL := "wall"
const TOOL_DOOR := "door"
const TOOL_WINDOW := "window"
const TOOL_ERASE := "erase"
const TOOLS := [TOOL_WALL, TOOL_DOOR, TOOL_WINDOW, TOOL_ERASE]
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
const STATUS_WIDTH := 520.0

var game: Node
var active := false
var tool := TOOL_WALL
var plan: HouseSketch
## The node where a wall drag started, or (-1, -1).
var drag_from := Vector2i(-1, -1)
var _plot := Rect2i()
var _built := Node3D.new()
var _ghost := Node3D.new()
var _grid := MeshInstance3D.new()
var _sign: Node3D
var _sign_body: StaticBody3D
var _station := {}
var _bar: PanelContainer
var _stage_labels := {}
var _tool_buttons := {}
var _undo_button: Button
var _redo_button: Button
var _status: Label
var _hover_key := ""


func _ready() -> void:
	add_child(_built)
	add_child(_ghost)
	_grid.visible = false
	add_child(_grid)
	_build_bar()
	refresh()


func _exit_tree() -> void:
	if is_instance_valid(_bar):
		_bar.queue_free()


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
	var edge := plan.edge_near(point)
	if edge.is_empty():
		return
	if tool == TOOL_ERASE:
		if plan.erase([edge]) == 0:
			_say(Lang.t("Das ist schon gebaut: Es lässt sich nicht wegradieren."))
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
	var edge := plan.edge_near(point)
	key = "e:%s" % [edge]
	if key == _hover_key:
		return
	_hover_key = key
	_clear(_ghost)
	if edge.is_empty():
		_say("")
		return
	if tool == TOOL_ERASE:
		var had := plan.piece(edge[0], edge[1], edge[2])
		var ok: bool = not had.is_empty() and had.state == HouseSketch.SKETCH
		_segment(_ghost, edge, had.get("kind", HouseSketch.WALL), OK_COLOR if ok else BAD_COLOR)
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
			return Lang.t("Das ist schon gebaut.")
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
	for t in TOOLS:
		var b: Button = _tool_buttons[t]
		var on: bool = t == tool
		b.add_theme_color_override("font_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
		b.add_theme_color_override("font_hover_color", ON_COLOR if on else Color(1, 1, 1, 0.75))
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed") if on else b.get_theme_stylebox("hover"))
	_undo_button.disabled = plan == null or not plan.can_undo()
	_redo_button.disabled = plan == null or not plan.can_redo()
	if plan != null:
		_status.text = _hint()


func _hint() -> String:
	match tool:
		TOOL_WALL:
			return Lang.t("Wand: Maustaste halten und auf dem Raster ziehen. Rechtsklick beendet.")
		TOOL_DOOR:
			return Lang.t("Tür: Klicke eine Wand an.")
		TOOL_WINDOW:
			return Lang.t("Fenster: Klicke eine Wand an.")
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
	if plan == null:
		return
	for key in plan.pieces:
		var p := HouseSketch.parts_of(key)
		_segment(_built, [p[1], p[2], p[3]], plan.pieces[key].kind, Color(0, 0, 0, 0))


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
