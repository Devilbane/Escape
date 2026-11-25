class_name BankHall
extends RefCounted
## The banking hall of the Bank of the Crown, the room inside the bank's stone walls over the vault
## cellar (see BankVault): a place that looks like it keeps riches safe. Banker Goldwin works by day
## at his desk on the west side, facing the stairs down to the vault (see VillagePosts, which walks
## him in through the door and out again at nightfall); the hero stands on the red carpet before it.
## A heavy iron vault door stands open against the east wall by a stone gateway over the stairs, with
## an iron railing round the stairwell; stone pillars stand in the corners, iron-bound chests in a row
## across its south half, the Crown's green banners on the walls, ledgers in a bookcase, and candle
## sconces on the walls light it all; every window has iron bars against robbers and lets the light
## of the hour in (WindowSun). Looked into from above, the stairwell shows the lamplit stone of the
## vault below instead of the empty light the hidden cellar left (the shade, see _shade).
##
## Everything stands under one node on the level ("BankHall"), so it hides with the rest of the
## surface while the hero is down in the vault (see CellarView). Built by HouseSketcher next to the
## vault, with BankVault's switch on.
##
## The hall's own frame: x runs east and z south from the bank's inner north-west corner, on its floor.

## Who keeps the bank (a villager role, see Villager.INFO).
const KEEPER := "Y"
## The desk: its middle (hall frame), size, and where Goldwin stands behind it. Its front faces east.
const DESK_AT := Vector2(2.4, 3.0)
const DESK_WIDE := 2.4
const DESK_DEEP := 0.8
const DESK_HIGH := 0.9
const BANKER_AT := Vector2(1.4, 3.0)
## Where he goes round the desk's north end on his way in and out (hall frame).
const BANKER_VIA := Vector2(1.4, 1.0)
## The stairwell (hall frame): the stairs down take the east column of cells (the frame starts
## INSET inside the walls, so the cells' edges lie at 1.9, 3.9, 5.9 and 7.9).
const WELL := Rect2(5.9, 1.9, 2.0, 4.0)
## The gateway over the top of the stairs: its posts' inner faces, how high its lintel is.
const GATE_LEFT := 6.2
const GATE_RIGHT := 7.5
const GATE_HIGH := 2.35
## The railing round the stairwell.
const RAIL_HIGH := 1.0
## The bars over the windows: how many uprights, how far out from the middle of the wall.
const BARS := 7
const BARS_OUT := 0.09
## Where the cross bands hold them, as parts of the window's height from the sill.
const BANDS := [0.22, 0.75]
## The light through the windows: how far in from the middle of the wall the bright inner pane
## hangs, and how deep into the hall the patch of light on the floor reaches.
const PANE_IN := 0.12
const PATCH_DEEP := 1.3
## The row of chests (hall frame, their middle): far enough from the south wall that it does not
## hide them from the camera, which looks over it.
const CHESTS_Z := 5.6
## The open vault door, flat against the east wall north of the gateway.
const VAULT_DOOR := Vector3(0.22, 2.2, 1.55)
## Walls and roof: how far in from the bank's walls the inner faces stand, how high the ceiling is.
const INSET := 0.1
const CEILING := 3.1
## How high the candle sconces sit on the walls.
const SCONCE_HIGH := 1.9

const STONE := Color(0.74, 0.71, 0.66)
const IRON := Color(0.17, 0.17, 0.19)
const BRASS := Color(0.86, 0.66, 0.28)
const GOLD := Color(1.0, 0.8, 0.3)
const GREEN := Color(0.13, 0.33, 0.22)
const CARPET := Color(0.5, 0.1, 0.1)
const LIGHT := Color(1.0, 0.8, 0.55)

static var _mats := {}


## The node of the hall on the level, or null.
static func of(level: Node) -> Node3D:
	if level == null or not BankVault.on:
		return null
	return level.get_node_or_null("BankHall") as Node3D


## The world point of a spot in the hall's frame, on its floor.
static func world(at: Vector2) -> Vector3:
	return origin() + Vector3(at.x, 0, at.y)


## The hall frame's origin: the bank's inner north-west corner, on its floor.
static func origin() -> Vector3:
	var s := BankVault.sketch()
	return s.node_world(BankVault.BANK.position.x, BankVault.BANK.position.y) + Vector3(INSET, HouseSketch.FLOOR_RISE, INSET)


## The height of the floor under a world point: the hall's inside the bank, the ground outside it.
static func floor_y(at: Vector3) -> float:
	var p := at - origin()
	var size := Vector2(BankVault.BANK.size) * HouseSketch.CELL - Vector2(INSET, INSET) * 2.0
	return HouseSketch.FLOOR_RISE if Rect2(Vector2.ZERO, size).grow(0.15).has_point(Vector2(p.x, p.z)) else 0.0


## Goldwin's post at his desk, in the shape VillagePosts walks him by: {"rec", "post"}, or {} with
## no hall on the map. The record's "way" is the way in through the door (outside, inside), its
## "via" the way round the desk.
static func post(level: Node) -> Dictionary:
	var hall := of(level)
	if hall == null:
		return {}
	var s := BankVault.sketch()
	var door := s.cell_world(BankVault.door_cell().x, BankVault.door_cell().y)
	var wall_z := s.node_world(0, BankVault.BANK.position.y).z
	var outside := Vector3(door.x, 0.0, wall_z - 1.2)
	var inside := Vector3(door.x, HouseSketch.FLOOR_RISE, wall_z + 0.7)
	var rec := {"kind": "bank", "node": hall, "door": hall.to_local(Vector3(door.x, 0.0, wall_z)), "way": [outside, inside], "via": [world(BANKER_VIA)]}
	var at := world(BANKER_AT)
	return {"rec": rec, "post": {"pos": at, "rot": PI * 0.5, "front": world(DESK_AT + Vector2(DESK_DEEP * 0.5 + 0.6, 0))}}


## Builds the hall on the level once (again after the level was built anew).
static func build(level: Node3D) -> void:
	if level == null or level.get_node_or_null("BankHall") != null:
		return
	var hall := Node3D.new()
	hall.name = "BankHall"
	level.add_child(hall)
	hall.global_position = origin()
	var body := StaticBody3D.new()
	body.name = "BankHallSolids"
	hall.add_child(body)
	var size := Vector2(BankVault.BANK.size) * HouseSketch.CELL - Vector2(INSET, INSET) * 2.0
	_desk(hall, body)
	_carpet(hall)
	_stairwell(hall, body)
	_vault_door(hall, body, size)
	_window_bars(hall)
	_pillars(hall, body, size)
	_chests(hall, body, size)
	_banners(hall, size)
	_ledgers(hall, body, size)
	_sconces(hall, size)
	_shade(hall)


# --- The pieces ----------------------------------------------------------------

## Goldwin's desk, its front to the east: the ledger, ink and papers of a writing desk, with coin
## scales, stacks of coins, a small strongbox and a candle on it, and a chair behind it.
static func _desk(hall: Node3D, body: StaticBody3D) -> void:
	var desk := WalkInFurniture.desk(DESK_WIDE, DESK_HIGH, DESK_DEEP)
	desk.position = Vector3(DESK_AT.x, 0, DESK_AT.y)
	desk.rotation.y = PI * 0.5
	hall.add_child(desk)
	_solid(body, Vector3(DESK_AT.x, DESK_HIGH * 0.5, DESK_AT.y), Vector3(DESK_DEEP, DESK_HIGH, DESK_WIDE))
	# In the desk's own frame: x along it (+x to the north), +z its front (east), on its top.
	var top := DESK_HIGH
	var brass := _mat("brass", BRASS, 0.7)
	var gold := _mat("gold", GOLD, 0.8, 0.15)
	# Coin scales at its south end: a foot, a post, a beam and two pans, one weighed down with coins.
	var sx := -DESK_WIDE * 0.5 + 0.3
	_cylinder(desk, 0.1, 0.03, Vector3(sx, top + 0.015, 0.05), brass)
	_box(desk, Vector3(0.03, 0.36, 0.03), Vector3(sx, top + 0.2, 0.05), brass)
	_box(desk, Vector3(0.42, 0.02, 0.02), Vector3(sx, top + 0.37, 0.05), brass, Basis(Vector3.FORWARD, 0.12))
	for side: float in [-1.0, 1.0]:
		var drop := 0.17 + side * 0.025
		var px := sx + side * 0.2
		_box(desk, Vector3(0.006, drop, 0.006), Vector3(px, top + 0.37 - side * 0.025 - drop * 0.5, 0.05), brass)
		_cylinder(desk, 0.08, 0.015, Vector3(px, top + 0.37 - side * 0.025 - drop, 0.05), brass)
	_cylinder(desk, 0.035, 0.03, Vector3(sx + 0.2, top + 0.2, 0.05), gold)
	# Stacks of coins counted out before him, and a little iron-bound strongbox.
	for k in 4:
		_cylinder(desk, 0.035, 0.02 + k * 0.015, Vector3(-0.25 + k * 0.09, top + 0.01 + k * 0.0075, 0.22), gold)
	_box(desk, Vector3(0.3, 0.18, 0.22), Vector3(0.25, top + 0.09, -0.2), _mat("chest_wood", Color(0.42, 0.26, 0.16)))
	for bx: float in [0.14, 0.36]:
		_box(desk, Vector3(0.03, 0.19, 0.23), Vector3(bx, top + 0.095, -0.2), _mat("iron", IRON, 0.6))
	_box(desk, Vector3(0.06, 0.07, 0.01), Vector3(0.25, top + 0.1, -0.085), brass)
	# A candle in a brass stick on the north corner, and its glow.
	var cx := DESK_WIDE * 0.5 - 0.18
	_cylinder(desk, 0.06, 0.02, Vector3(cx, top + 0.01, -0.2), brass)
	_cylinder(desk, 0.025, 0.18, Vector3(cx, top + 0.11, -0.2), _mat("wax", Color(0.96, 0.92, 0.8)))
	_box(desk, Vector3(0.03, 0.05, 0.03), Vector3(cx, top + 0.23, -0.2), _mat("flame", LIGHT, 0.0, 3.0))
	var glow := OmniLight3D.new()
	glow.light_color = LIGHT
	glow.light_energy = 0.9
	glow.omni_range = 3.5
	glow.position = Vector3(cx, top + 0.4, -0.2)
	# Walls all round it (see LightShadows.INDOOR), or it lit the ivy and the snow outside through the wall.
	glow.set_meta(LightShadows.INDOOR, true)
	desk.add_child(glow)
	# His high-backed chair, behind him against the west wall's window.
	var wood := _mat("chair_wood", Color(0.36, 0.22, 0.14))
	var chair := Node3D.new()
	chair.position = Vector3(0.55, 0, DESK_AT.y)
	hall.add_child(chair)
	_box(chair, Vector3(0.5, 0.08, 0.5), Vector3(0, 0.48, 0), wood)
	_box(chair, Vector3(0.08, 1.3, 0.5), Vector3(-0.22, 0.65, 0), wood)
	_box(chair, Vector3(0.03, 0.5, 0.36), Vector3(-0.17, 0.85, 0), _mat("green", GREEN))
	for leg: Vector2 in [Vector2(0.2, 0.2), Vector2(0.2, -0.2)]:
		_box(chair, Vector3(0.06, 0.48, 0.06), Vector3(leg.x, 0.24, leg.y), wood)


## A long red carpet with a gold border from the door to the desk, where the hero stands to deal.
static func _carpet(hall: Node3D) -> void:
	var at := Vector3(4.1, 0.012, 2.6)
	_box(hall, Vector3(2.0, 0.02, 4.4), at, _mat("gold_trim", Color(0.8, 0.62, 0.25)))
	_box(hall, Vector3(1.8, 0.024, 4.2), at, _mat("carpet", CARPET))
	_box(hall, Vector3(1.3, 0.028, 3.7), at, _mat("carpet_dark", Color(0.36, 0.06, 0.07)))


## The way down: a stone gateway over the top of the stairs (posts and lintel, a brass plate on it)
## and an iron railing along the stairwell's open sides.
static func _stairwell(hall: Node3D, body: StaticBody3D) -> void:
	var stone := _mat("stone", STONE)
	var iron := _mat("iron", IRON, 0.6)
	var z := WELL.position.y - 0.1
	var post_w := 0.3
	for x: float in [GATE_LEFT - post_w * 0.5, GATE_RIGHT + post_w * 0.5]:
		_box(hall, Vector3(post_w, GATE_HIGH, 0.4), Vector3(x, GATE_HIGH * 0.5, z), stone)
		_box(hall, Vector3(post_w + 0.1, 0.15, 0.5), Vector3(x, 0.075, z), stone)
		_solid(body, Vector3(x, GATE_HIGH * 0.5, z), Vector3(post_w, GATE_HIGH, 0.4))
	var span := GATE_RIGHT - GATE_LEFT + post_w * 2.0
	var mid := (GATE_LEFT + GATE_RIGHT) * 0.5
	_box(hall, Vector3(span + 0.1, 0.3, 0.5), Vector3(mid, GATE_HIGH + 0.15, z), stone)
	_box(hall, Vector3(0.7, 0.16, 0.02), Vector3(mid, GATE_HIGH + 0.15, z - 0.26), _mat("brass", BRASS, 0.7))
	# The iron grille of the gate, drawn up under the lintel.
	var bars := int((GATE_RIGHT - GATE_LEFT) / 0.16)
	for i in bars + 1:
		var x := GATE_LEFT + i * (GATE_RIGHT - GATE_LEFT) / bars
		_box(hall, Vector3(0.035, 0.4, 0.035), Vector3(x, GATE_HIGH - 0.2, z), iron)
		_box(hall, Vector3(0.05, 0.08, 0.05), Vector3(x, GATE_HIGH - 0.43, z), iron)
	_box(hall, Vector3(GATE_RIGHT - GATE_LEFT, 0.05, 0.05), Vector3(mid, GATE_HIGH - 0.3, z), iron)
	# The railing: along the west side of the stairwell, and its south end.
	var west := WELL.position.x + 0.05
	var south := WELL.end.y
	var east := WELL.end.x - INSET
	var n := 6
	for i in n + 1:
		var pz := z + 0.3 + i * (south - z - 0.3) / n
		_box(hall, Vector3(0.05, RAIL_HIGH, 0.05), Vector3(west, RAIL_HIGH * 0.5, pz), iron)
	for i in 4:
		var px := west + i * (east - west) / 3.0
		_box(hall, Vector3(0.05, RAIL_HIGH, 0.05), Vector3(px, RAIL_HIGH * 0.5, south), iron)
	_box(hall, Vector3(0.08, 0.06, south - z - 0.3), Vector3(west, RAIL_HIGH, (z + 0.3 + south) * 0.5), _mat("brass", BRASS, 0.7))
	_box(hall, Vector3(east - west, 0.06, 0.08), Vector3((west + east) * 0.5, RAIL_HIGH, south), _mat("brass", BRASS, 0.7))
	for y: float in [0.12, RAIL_HIGH * 0.55]:
		_box(hall, Vector3(0.04, 0.04, south - z - 0.3), Vector3(west, y, (z + 0.3 + south) * 0.5), iron)
		_box(hall, Vector3(east - west, 0.04, 0.04), Vector3((west + east) * 0.5, y, south), iron)
	# Its solids start a little over the floor: whoever walks down the stairs passes under its south end.
	var low := 0.4
	_solid(body, Vector3(west, (low + RAIL_HIGH) * 0.5, (z + 0.3 + south) * 0.5), Vector3(0.15, RAIL_HIGH - low, south - z - 0.3))
	_solid(body, Vector3((west + east) * 0.5, (low + RAIL_HIGH) * 0.5, south), Vector3(east - west, RAIL_HIGH - low, 0.15))


## The vault's great door, swung open flat against the east wall: an iron slab on three hinges,
## riveted all over, with its bolts out of its edge and a wheel to turn them.
static func _vault_door(hall: Node3D, body: StaticBody3D, size: Vector2) -> void:
	var iron := _mat("vault_iron", Color(0.3, 0.31, 0.34), 0.7)
	var dark := _mat("iron", IRON, 0.6)
	var steel := _mat("steel", Color(0.62, 0.64, 0.68), 0.8)
	var brass := _mat("brass", BRASS, 0.7)
	var d := VAULT_DOOR
	var at := Vector3(size.x - d.x * 0.5 - 0.02, d.y * 0.5, WELL.position.y - 0.3 - d.z * 0.5)
	_box(hall, d, at, iron)
	_solid(body, at, d)
	var face := at.x - d.x * 0.5
	# A raised rim round its face, and rivets along it.
	for y: float in [0.1, d.y - 0.1]:
		_box(hall, Vector3(0.03, 0.08, d.z - 0.1), Vector3(face - 0.015, y, at.z), dark)
	for zs: float in [-1.0, 1.0]:
		_box(hall, Vector3(0.03, d.y - 0.1, 0.08), Vector3(face - 0.015, d.y * 0.5, at.z + zs * (d.z * 0.5 - 0.05)), dark)
	for i in 8:
		for zs: float in [-1.0, 1.0]:
			_box(hall, Vector3(0.03, 0.04, 0.04), Vector3(face - 0.035, 0.25 + i * (d.y - 0.5) / 7.0, at.z + zs * (d.z * 0.5 - 0.05)), steel)
	# Three hinges on its north edge (the wall side as it hangs open), three bolts out of its south edge.
	for k in 3:
		var y := 0.35 + k * (d.y - 0.7) / 2.0
		_cylinder(hall, 0.06, 0.25, Vector3(at.x, y, at.z - d.z * 0.5 - 0.03), dark)
		_cylinder(hall, 0.045, 0.22, Vector3(at.x, y, at.z + d.z * 0.5 + 0.08), steel, Basis(Vector3.RIGHT, PI * 0.5))
	# The wheel in its middle, and the brass crown plate above it.
	var wheel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.32
	wheel.mesh = torus
	wheel.material_override = steel
	wheel.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(face - 0.12, d.y * 0.48, at.z))
	hall.add_child(wheel)
	_cylinder(hall, 0.07, 0.12, Vector3(face - 0.08, d.y * 0.48, at.z), steel, Basis(Vector3.FORWARD, PI * 0.5))
	for k in 3:
		_box(hall, Vector3(0.025, 0.56, 0.03), Vector3(face - 0.12, d.y * 0.48, at.z), steel, Basis(Vector3.RIGHT, k * PI / 3.0))
	_box(hall, Vector3(0.02, 0.18, 0.4), Vector3(face - 0.02, d.y * 0.8, at.z), brass)


## Iron bars over every window of the bank, on the outside of the glass, against robbers: stout
## uprights set into the sill and the lintel, held by two flat cross bands with a riveted knuckle
## where each upright crosses them. The shutters still swing in front of them.
static func _window_bars(hall: Node3D) -> void:
	var s := BankVault.sketch()
	var iron := _mat("iron", IRON, 0.6)
	var centre := (s.node_world(BankVault.BANK.position.x, BankVault.BANK.position.y) + s.node_world(BankVault.BANK.end.x, BankVault.BANK.end.y)) * 0.5
	var opening := HouseSketch.CELL - 2.0 * HouseSketcher.JAMB
	var low := HouseSketcher.SILL
	var high := HouseSketcher.WINDOW_TOP - low
	var bars := Node3D.new()
	bars.name = "WindowBars"
	hall.add_child(bars)
	var sun := WindowSun.new()
	sun.name = "WindowSun"
	sun.level = hall.get_parent()
	hall.add_child(sun)
	for key: String in s.pieces:
		if s.pieces[key].kind != HouseSketch.WINDOW:
			continue
		var p := HouseSketch.parts_of(key)
		var along_x: bool = p[3] == HouseSketch.ORIENT_X
		var axis := Vector3.RIGHT if along_x else Vector3.BACK
		var across := Vector3.BACK if along_x else Vector3.RIGHT
		var mid := s.node_world(p[1], p[2]) + axis * HouseSketch.CELL * 0.5
		var out := signf((mid - centre).dot(across))
		var turn := Basis() if along_x else Basis(Vector3.UP, PI * 0.5)
		# Just outside the glass and its glazing bars, inside the shutters; and seen from the hall,
		# the same grille again in front of the bright inner pane (see _daylight), which hides the glass.
		for side: float in [out * BARS_OUT, -out * (PANE_IN + 0.04)]:
			var face := hall.to_local(mid + across * side)
			face.y = 0.0
			_grille(bars, face, turn, signf(side), opening, low, high, iron)
		_daylight(hall, sun, mid, axis, across * -out, opening, low, high)


## One grille of window bars on the face at `face` (hall frame), its bands on the `out` side.
static func _grille(parent: Node3D, face: Vector3, turn: Basis, out: float, opening: float, low: float, high: float, iron: Material) -> void:
	var y0 := low - HouseSketch.FLOOR_RISE
	for i in BARS:
		var t := -opening * 0.5 + (i + 0.5) * opening / BARS
		_box(parent, Vector3(0.045, high + 0.1, 0.045), face + turn * Vector3(t, 0, 0) + Vector3(0, y0 + high * 0.5, 0), iron, turn)
		for y: float in BANDS:
			_box(parent, Vector3(0.07, 0.08, 0.07), face + turn * Vector3(t, 0, out * 0.02) + Vector3(0, y0 + high * y, 0), iron, turn)
	for y: float in BANDS:
		_box(parent, Vector3(opening, 0.06, 0.025), face + turn * Vector3(0, 0, out * 0.03) + Vector3(0, y0 + high * y, 0), iron, turn)


## The light through one window (`inward` points into the hall): its inner pane shines with the sky,
## a spotlight falls in through it, and on the floor before it lies a patch of light striped by the
## shadows of the bars (none over the stairwell). WindowSun keeps them to the hour.
static func _daylight(hall: Node3D, sun: WindowSun, mid: Vector3, axis: Vector3, inward: Vector3, opening: float, low: float, high: float) -> void:
	var turn := Basis(Vector3.UP.cross(inward), Vector3.UP, inward)
	var lift := Vector3(0, low + high * 0.5 - HouseSketch.FLOOR_RISE, 0)
	var pane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(opening - 0.1, high)
	pane.mesh = quad
	pane.material_override = sun.pane
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pane.transform = Transform3D(turn, hall.to_local(mid + inward * PANE_IN) * Vector3(1, 0, 1) + lift)
	hall.add_child(pane)
	var spot := SpotLight3D.new()
	spot.spot_range = 5.0
	spot.spot_angle = 50.0
	spot.shadow_enabled = false
	var from := hall.to_local(mid + inward * 0.3) * Vector3(1, 0, 1) + Vector3(0, low + high - HouseSketch.FLOOR_RISE, 0)
	spot.transform = Transform3D(Basis.looking_at(inward * 1.0 + Vector3(0, -1.1, 0), Vector3.UP), from)
	hall.add_child(spot)
	sun.lights.append(spot)
	# The patch on the floor: a stripe between each two bars, from the wall into the hall.
	var start := hall.to_local(mid + inward * 0.15) * Vector3(1, 0, 1)
	var foot := Rect2(Vector2(start.x, start.z), Vector2.ZERO).expand(Vector2(start.x, start.z) + Vector2(inward.x, inward.z) * PATCH_DEEP)
	foot = foot.grow_individual(absf(axis.x) * opening * 0.5, absf(axis.z) * opening * 0.5, absf(axis.x) * opening * 0.5, absf(axis.z) * opening * 0.5)
	if foot.intersects(WELL):
		return
	var gap := 0.07
	var stripe := (opening - BARS * gap) / (BARS + 1)
	for i in BARS + 1:
		var t := -opening * 0.5 + stripe * 0.5 + i * (stripe + gap)
		var strip := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(stripe, PATCH_DEEP)
		strip.mesh = plane
		strip.material_override = sun.patch
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.transform = Transform3D(turn, start + turn * Vector3(t, 0, PATCH_DEEP * 0.5) + Vector3(0, 0.03, 0))
		hall.add_child(strip)


## Keeps the windows' light to the hour of the day: warm daylight, the reds of dusk, pale blue
## moonlight at night, as the open air outside (see DayNight.sky_at). Looks again every TICK seconds.
class WindowSun extends Node3D:
	const TICK := 0.5
	var level: Node
	var lights: Array[SpotLight3D] = []
	var pane := StandardMaterial3D.new()
	var patch := StandardMaterial3D.new()
	var _hour := -99.0
	var _wait := 0.0

	func _init() -> void:
		pane.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		patch.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		patch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		patch.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	func _ready() -> void:
		show_hour()

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait > 0.0:
			return
		_wait = TICK
		show_hour()

	## Lights the panes, the patches and the spotlights for the level's hour.
	func show_hour() -> void:
		var hour = level.get("hour") if level != null else null
		if hour == null or float(hour) < 0.0 or absf(float(hour) - _hour) < 0.05:
			return
		_hour = float(hour)
		var sky := DayNight.sky_at(_hour)
		var c: Color = sky.sun
		var e := clampf(float(sky.sun_e), 0.0, 1.2)
		# The sky through the glass: blue by day, warm at dusk, deep blue at night.
		var sky_col: Color = sky.bg if sky.has("bg") else c
		pane.albedo_color = sky_col.lerp(c, 0.35) * (0.3 + 0.55 * minf(e, 1.0))
		patch.albedo_color = Color(c.r, c.g, c.b, 1.0) * (0.15 + 0.3 * minf(e, 1.0))
		for l in lights:
			l.light_color = c
			l.light_energy = 0.4 + 1.4 * e


## Stone pillars in the corners (the north-east one is the vault door's), on plinths under capitals.
static func _pillars(hall: Node3D, body: StaticBody3D, size: Vector2) -> void:
	var stone := _mat("stone", STONE)
	var pale := _mat("pale_stone", Color(0.84, 0.81, 0.76))
	var r := 0.24
	for c: Vector2 in [Vector2(r + 0.06, r + 0.06), Vector2(r + 0.06, size.y - r - 0.06), Vector2(size.x - r - 0.06, size.y - r - 0.06)]:
		_box(hall, Vector3(r * 2.4, 0.22, r * 2.4), Vector3(c.x, 0.11, c.y), stone)
		_cylinder(hall, r, CEILING - 0.5, Vector3(c.x, 0.22 + (CEILING - 0.5) * 0.5, c.y), pale)
		_box(hall, Vector3(r * 2.5, 0.28, r * 2.5), Vector3(c.x, CEILING - 0.14, c.y), stone)
		_box(hall, Vector3(r * 2.2, 0.06, r * 2.2), Vector3(c.x, CEILING - 0.31, c.y), pale)
		_solid(body, Vector3(c.x, CEILING * 0.5, c.y), Vector3(r * 2.2, CEILING, r * 2.2))


## Iron-bound chests in a row across the south half of the hall, where they show over the south
## wall from the street side, a strongbox between them, and sacks of coin by the railing.
static func _chests(hall: Node3D, body: StaticBody3D, size: Vector2) -> void:
	var z := CHESTS_Z
	for x: float in [2.4, 4.9]:
		_chest(hall, Vector3(x, 0, z), Vector3(1.1, 0.62, 0.62))
		_solid(body, Vector3(x, 0.4, z), Vector3(1.1, 0.8, 0.62))
	_chest(hall, Vector3(3.65, 0, z), Vector3(0.6, 0.4, 0.45))
	_solid(body, Vector3(3.65, 0.25, z), Vector3(0.6, 0.5, 0.45))
	for at: Vector2 in [Vector2(6.3, WELL.end.y + 0.45), Vector2(6.9, WELL.end.y + 0.55), Vector2(1.4, z + 0.1)]:
		var sack := WalkInFurniture.sack()
		sack.position = Vector3(at.x, 0, at.y)
		sack.rotation.y = at.x
		hall.add_child(sack)
		# A coin or two spilled out at its foot.
		_cylinder(hall, 0.04, 0.01, Vector3(at.x - 0.3, 0.005, at.y - 0.1), _mat("gold", GOLD, 0.8, 0.15))


## One chest: a wooden box under a rounded lid, iron bands round both, iron corners and a brass lock.
static func _chest(hall: Node3D, at: Vector3, size: Vector3) -> void:
	var wood := _mat("chest_wood", Color(0.42, 0.26, 0.16))
	var iron := _mat("iron", IRON, 0.6)
	var low := size.y * 0.7
	_box(hall, Vector3(size.x, low, size.z), at + Vector3(0, low * 0.5, 0), wood)
	var lid := _cylinder(hall, size.z * 0.5, size.x, at + Vector3(0, low, 0), wood, Basis(Vector3.FORWARD, PI * 0.5))
	lid.scale = Vector3(1, 1, 0.6)
	for k in 3:
		var x := -size.x * 0.5 + 0.08 + k * (size.x - 0.16) / 2.0
		_box(hall, Vector3(0.06, low + 0.01, size.z + 0.02), at + Vector3(x, low * 0.5, 0), iron)
		var band := _cylinder(hall, size.z * 0.5 + 0.012, 0.06, at + Vector3(x, low, 0), iron, Basis(Vector3.FORWARD, PI * 0.5))
		band.scale = Vector3(1, 1, 0.62)
	for cx: float in [-1.0, 1.0]:
		_box(hall, Vector3(0.1, low + 0.02, 0.1), at + Vector3(cx * (size.x * 0.5 - 0.03), low * 0.5, -size.z * 0.5 + 0.03), iron)
	_box(hall, Vector3(0.12, 0.14, 0.03), at + Vector3(0, low - 0.02, -size.z * 0.5 - 0.01), _mat("brass", BRASS, 0.7))


## The Crown's green banners with a gold coin on them: on the north wall beside the door, on the
## west wall over the banker's shoulder, and on the east wall south of the stairs.
static func _banners(hall: Node3D, size: Vector2) -> void:
	var gold := _mat("gold", GOLD, 0.8, 0.15)
	var high := 1.6
	for spot: Array in [[Vector3(3.0, CEILING - 0.35, 0.02), 0.0], [Vector3(0.02, CEILING - 0.35, 0.95), PI * 0.5],
			[Vector3(size.x - 0.02, CEILING - 0.35, 6.85), -PI * 0.5]]:
		var banner := WalkInFurniture.banner(GREEN, high)
		banner.position = spot[0]
		banner.rotation.y = spot[1]
		hall.add_child(banner)
		_cylinder(banner, 0.2, 0.02, Vector3(0, -high * 0.6, 0.04), gold, Basis(Vector3.RIGHT, PI * 0.5))
		_cylinder(banner, 0.13, 0.025, Vector3(0, -high * 0.6, 0.045), _mat("brass", BRASS, 0.7), Basis(Vector3.RIGHT, PI * 0.5))
		# A gold fringe along its foot.
		_box(banner, Vector3(0.7, 0.06, 0.03), Vector3(0, -high + 0.03, 0.02), gold)


## The bank's ledgers in a tall bookcase against the west wall, south of the desk.
static func _ledgers(hall: Node3D, body: StaticBody3D, size: Vector2) -> void:
	var books := WalkInFurniture.bookcase(1.6, 2.2, 0.4)
	books.position = Vector3(0.22, 0, size.y - 1.95)
	books.rotation.y = PI * 0.5
	hall.add_child(books)
	_solid(body, Vector3(0.22, 1.1, size.y - 1.95), Vector3(0.4, 2.2, 1.6))


## Candle sconces on the walls (nothing hangs from the ceiling): an iron plate and bracket with a
## brass drip pan and a candle, and its light. Each spot is a point on a wall (hall frame) and the
## way from that wall into the hall.
static func _sconces(hall: Node3D, size: Vector2) -> void:
	var iron := _mat("iron", IRON, 0.6)
	for spot: Array in [[Vector2(2.2, 0.0), Vector2(0, 1)], [Vector2(0.0, 4.5), Vector2(1, 0)],
			[Vector2(1.0, size.y), Vector2(0, -1)], [Vector2(6.9, size.y), Vector2(0, -1)], [Vector2(size.x, 4.6), Vector2(-1, 0)]]:
		var wall := Vector3(spot[0].x, SCONCE_HIGH, spot[0].y)
		var out := Vector3(spot[1].x, 0, spot[1].y)
		var side := Vector3(absf(out.z), 0, absf(out.x))
		_box(hall, side * 0.14 + out.abs() * 0.03 + Vector3(0, 0.36, 0), wall + out * 0.02 + Vector3(0, 0.05, 0), iron)
		_box(hall, out.abs() * 0.22 + Vector3(0.03, 0.03, 0.03), wall + out * 0.13, iron)
		var cup := wall + out * 0.25
		_cylinder(hall, 0.07, 0.02, cup, _mat("brass", BRASS, 0.7))
		_cylinder(hall, 0.025, 0.16, cup + Vector3(0, 0.09, 0), _mat("wax", Color(0.96, 0.92, 0.8)))
		_box(hall, Vector3(0.03, 0.05, 0.03), cup + Vector3(0, 0.2, 0), _mat("flame", LIGHT, 0.0, 3.0))
		var light := OmniLight3D.new()
		light.light_color = LIGHT
		light.light_energy = 0.9
		light.omni_range = 4.5
		light.position = cup + out * 0.15 + Vector3(0, 0.3, 0)
		light.set_meta(LightShadows.INDOOR, true) # Walls all round it: it must not light the outside.
		hall.add_child(light)


## Looked down into from the hall, the stairwell shows the vault's lamplit stone floor below: a dark
## warm floor under the stairs and the hall at their foot, where the hidden cellar otherwise left
## a bright empty hole (it hides with the hall while the hero is down there and the vault is drawn).
static func _shade(hall: Node3D) -> void:
	var floor := MeshInstance3D.new()
	floor.name = "StairShade"
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 11.0)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.16, 0.12, 0.09)
	floor.material_override = mat
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	floor.position = Vector3(WELL.position.x - 2.0, -HouseSketch.DEPTH - HouseSketch.FLOOR_RISE + 0.02, WELL.position.y + 3.6)
	hall.add_child(floor)
	# The lamp light falling on the floor at the stairs' foot.
	var pool := MeshInstance3D.new()
	var disc := PlaneMesh.new()
	disc.size = Vector2(1.8, 2.4)
	pool.mesh = disc
	var warm := StandardMaterial3D.new()
	warm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warm.albedo_color = Color(0.42, 0.3, 0.18)
	pool.material_override = warm
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = Vector3(WELL.get_center().x, floor.position.y + 0.005, WELL.end.y + 0.8)
	hall.add_child(pool)


# --- Helpers -----------------------------------------------------------------

static func _mat(key: String, colour: Color, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 0.9 if metal == 0.0 else 0.4
		m.metallic = metal
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = colour
			m.emission_energy_multiplier = glow
		_mats[key] = m
	return _mats[key]


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, turn := Basis()) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.material_override = mat
	m.transform = Transform3D(turn, at)
	parent.add_child(m)
	return m


static func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, turn := Basis()) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	m.mesh = mesh
	m.material_override = mat
	m.transform = Transform3D(turn, at)
	parent.add_child(m)
	return m


static func _solid(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
