class_name PlotMarker
extends Node3D
## Shows building plots on the open map (see Plots) and lets the hero mark out a
## new one: the clerk's cord is picked up, a click sets one corner and a second
## click the opposite one. While the second corner is chosen the rectangle
## follows the mouse, green where it could be registered and red where not (the
## message line says why). A marked plot stays pending until it is registered
## at the Crown Office, or until the hero marks another.
##
## Registered plots are drawn for everyone: a post on every tile of the edge and a cord between.

enum Stage { OFF, FIRST, SECOND }

const POST_SIZE := Vector3(0.14, 1.0, 0.14)
const CORD := 0.04
const CORD_HEIGHT := 0.8
const OK_COLOR := Color(0.4, 0.9, 0.4)
const BAD_COLOR := Color(1.0, 0.4, 0.35)
const PENDING_COLOR := Color(1.0, 0.8, 0.3)
const DEED_COLOR := Color(0.85, 0.82, 0.7)

var game: Node
var stage := Stage.OFF
## The first corner picked, and the plot marked out and waiting to be registered.
var corner := Vector2i.ZERO
var pending := Rect2i()
var _ghost: Node3D
var _deeds := Node3D.new()
var _last_hover := Rect2i()


func _ready() -> void:
	add_child(_deeds)
	refresh()


func marking() -> bool:
	return stage != Stage.OFF


## Starts marking: the next click sets the first corner.
func begin() -> void:
	stage = Stage.FIRST
	_clear_ghost()
	pending = Rect2i()


func cancel() -> void:
	stage = Stage.OFF
	_clear_ghost()


## The tile under a point on the ground.
func tile_at(point: Vector3) -> Vector2i:
	return game.level.world_to_cell(point)


## A click on the ground while marking. Returns whether it was used.
func click(point: Vector3) -> bool:
	if stage == Stage.OFF:
		return false
	var c := tile_at(point)
	if stage == Stage.FIRST:
		corner = c
		stage = Stage.SECOND
		_show(Plots.rect_between(corner, c))
		game.show_message(Lang.t("Erste Ecke gesetzt. Klicke die gegenüberliegende Ecke. Esc bricht ab."), 3.0)
		return true
	var rect := Plots.rect_between(corner, c)
	var why := Plots.problem(game.level, rect)
	if why != "":
		game.show_message(reason(why), 2.4)
		return true
	stage = Stage.OFF
	pending = rect
	_show(rect, true)
	game.show_message(Lang.t("Grundstück abgesteckt: %d x %d Felder. Lass es beim Amt der Krone eintragen (%d Kupfer).") % [rect.size.x, rect.size.y, Plots.fee(rect)], 5.0)
	return true


## While the second corner is chosen, the rectangle follows the mouse.
func hover(point: Vector3) -> void:
	if stage != Stage.SECOND:
		return
	var rect := Plots.rect_between(corner, tile_at(point))
	if rect == _last_hover:
		return
	_show(rect)


static func reason(why: String) -> String:
	match why:
		"small":
			return Lang.t("Zu klein: mindestens %d x %d Felder.") % [Plots.MIN_SIDE, Plots.MIN_SIDE]
		"big":
			return Lang.t("Zu groß: höchstens %d x %d Felder.") % [Plots.MAX_SIDE, Plots.MAX_SIDE]
		"ground":
			return Lang.t("Hier ist der Boden nicht eben und frei: nur blanke Wiese.")
		"village":
			return Lang.t("Zu nah am Dorf: Das Land gehört der Gemeinde.")
		"taken":
			return Lang.t("Dieses Land gehört schon jemandem.")
		"have":
			return Lang.t("Du besitzt schon ein Grundstück.")
	return ""


## Draws the registered plots again.
func refresh() -> void:
	for child in _deeds.get_children():
		child.queue_free()
	if game == null or not game.level is Outdoor:
		return
	for deed in Plots.all():
		_deeds.add_child(_fence(deed.rect, DEED_COLOR, false))
	if pending.size != Vector2i.ZERO and not Plots.has_plot(game.hero_name):
		_show(pending, true)
	if game.house_sketcher != null:
		game.house_sketcher.refresh()


func _clear_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_last_hover = Rect2i()


func _show(rect: Rect2i, settled := false) -> void:
	_clear_ghost()
	_last_hover = rect
	var colour := PENDING_COLOR
	if not settled:
		colour = OK_COLOR if Plots.problem(game.level, rect) == "" else BAD_COLOR
	_ghost = _fence(rect, colour, true)
	add_child(_ghost)


## The posts, the cord and (for a marked plot) a faint tint of the ground.
func _fence(rect: Rect2i, colour: Color, tint: bool) -> Node3D:
	var root := Node3D.new()
	var lo := Vector2(rect.position.x - 0.5, rect.position.y - 0.5) * Level.TILE
	var hi := Vector2(rect.end.x - 0.5, rect.end.y - 0.5) * Level.TILE
	var post_mat := _material(colour.darkened(0.25))
	var cord_mat := _material(colour)
	for i in range(rect.size.x + 1):
		var x := lo.x + i * Level.TILE
		_post(root, Vector3(x, 0, lo.y), post_mat)
		_post(root, Vector3(x, 0, hi.y), post_mat)
	for j in range(1, rect.size.y):
		var z := lo.y + j * Level.TILE
		_post(root, Vector3(lo.x, 0, z), post_mat)
		_post(root, Vector3(hi.x, 0, z), post_mat)
	_bar(root, Vector3((lo.x + hi.x) * 0.5, CORD_HEIGHT, lo.y), Vector3(hi.x - lo.x, CORD, CORD), cord_mat)
	_bar(root, Vector3((lo.x + hi.x) * 0.5, CORD_HEIGHT, hi.y), Vector3(hi.x - lo.x, CORD, CORD), cord_mat)
	_bar(root, Vector3(lo.x, CORD_HEIGHT, (lo.y + hi.y) * 0.5), Vector3(CORD, CORD, hi.y - lo.y), cord_mat)
	_bar(root, Vector3(hi.x, CORD_HEIGHT, (lo.y + hi.y) * 0.5), Vector3(CORD, CORD, hi.y - lo.y), cord_mat)
	if tint:
		var tint_mat := _material(Color(colour, 0.18))
		_bar(root, Vector3((lo.x + hi.x) * 0.5, 0.03, (lo.y + hi.y) * 0.5), Vector3(hi.x - lo.x, 0.02, hi.y - lo.y), tint_mat)
	return root


func _post(parent: Node3D, at: Vector3, mat: Material) -> void:
	_bar(parent, at + Vector3(0, POST_SIZE.y * 0.5, 0), POST_SIZE, mat)


func _bar(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> void:
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
