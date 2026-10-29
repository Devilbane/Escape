class_name Level
extends Node3D
## Builds a dungeon level from a text map and runs its traps and pickups.
##
## Map legend (one character per 4x4 m tile):
##   #  wall          .  floor           ,  dirt floor
##   P  player start  E  exit stairs     K  key
##   D  locked door   S  spike trap      c  coin
##   C  treasure chest
##   b  barrel        x  crates          o  pillar        t  table

signal key_collected
signal coins_collected(amount: int)
signal door_opened
signal door_locked
signal player_hurt
signal exit_reached

const TILE := 4.0
const ASSET_DIR := "res://assets/dungeon/"
const SOLID := "#bxotCD"
## Height of walls between the camera and the room, so they never hide the player.
const LOW_WALL_SCALE := 0.3
const SPIKE_PERIOD := 3.0
const SPIKE_UP_TIME := 1.1
const SPIKE_DOWN_Y := -1.95

var level_name := ""
var hint := ""
var grid: Array[String] = []
var width := 0
var height := 0
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i(-1, -1)
var astar := AStarGrid2D.new()
var player: Node3D
var finished := false
var has_key := false

var _rng := RandomNumberGenerator.new()
var _scenes := {}
var _time := 0.0
var _torches: Array = []
var _spikes: Array = []
var _pickups: Array = []
var _chests: Array = []
var _doors: Array = []
var _torch_spots: Array[Vector3] = []
var _walls_body := StaticBody3D.new()
var _door_hint_shown := false


func load_from_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n"):
		line = line.strip_edges(false, true)
		if line.begins_with("name:"):
			level_name = line.substr(5).strip_edges()
		elif line.begins_with("hint:"):
			hint = line.substr(5).strip_edges()
		elif line != "":
			grid.append(line)
			width = maxi(width, line.length())
	height = grid.size()


func build() -> void:
	_rng.seed = hash(level_name)
	add_child(_walls_body)
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var ch := cell_char(c)
			if ch == "#":
				continue
			_build_floor(c, ch)
			_build_walls(c)
			_build_content(c, ch)
	_build_corner_pillars()
	_build_wall_collision()
	_setup_astar()


# --- Grid helpers -----------------------------------------------------------

func cell_char(c: Vector2i) -> String:
	if c.y < 0 or c.y >= height or c.x < 0 or c.x >= grid[c.y].length():
		return "#"
	var ch := grid[c.y][c.x]
	return "#" if ch == " " else ch


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * TILE, 0.0, c.y * TILE)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / TILE), roundi(p.z / TILE))


## A wall tile is "low" when the room lies north of it, i.e. it stands between
## the camera and the floor.
func _is_low_wall(c: Vector2i) -> bool:
	return cell_char(c) == "#" and cell_char(c + Vector2i(0, -1)) != "#"


func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			astar.set_point_solid(c, SOLID.contains(cell_char(c)))


# --- Building ---------------------------------------------------------------

func _place(piece: String, pos: Vector3, rot_y := 0.0, parent: Node = self) -> Node3D:
	if not _scenes.has(piece):
		_scenes[piece] = load(ASSET_DIR + piece + ".glb")
	var node: Node3D = _scenes[piece].instantiate()
	node.position = pos
	node.rotation.y = rot_y
	parent.add_child(node)
	return node


func _random_quarter_turn() -> float:
	return _rng.randi_range(0, 3) * PI * 0.5


func _build_floor(c: Vector2i, ch: String) -> void:
	var pos := cell_to_world(c)
	if ch == "S":
		var tile := _place("floor_tile_big_spikes", pos)
		var spikes: Node3D = tile.find_child("spikes", true, false)
		spikes.position.y = SPIKE_DOWN_Y
		_spikes.append({"node": spikes, "cell": c, "phase": c.x * 0.45 + c.y * 0.2})
		return
	var piece := "floor_tile_large"
	var roll := _rng.randf()
	if ch == ",":
		piece = "floor_dirt_large"
	elif roll < 0.07:
		piece = "floor_tile_big_grate"
	elif roll < 0.14:
		piece = "floor_dirt_large"
	_place(piece, pos, _random_quarter_turn())


func _build_walls(c: Vector2i) -> void:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = c + d
		if cell_char(n) != "#":
			continue
		if d == Vector2i(0, -1) and cell_char(c) == "E":
			continue # The stairs lead out through the north wall.
		var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * TILE * 0.5
		# Each wall piece faces into the room.
		var rot := atan2(-float(d.x), -float(d.y))
		var low := _is_low_wall(n)
		var piece := "wall"
		var roll := _rng.randf()
		if not low and d == Vector2i(0, -1):
			if roll < 0.12:
				piece = "wall_shelves"
			elif roll < 0.22:
				piece = "wall_archedwindow_gated"
			elif roll < 0.32:
				piece = "wall_cracked"
		elif not low and roll < 0.2:
			piece = "wall_cracked"
		var wall := _place(piece, pos, rot)
		if low:
			wall.scale.y = LOW_WALL_SCALE
		else:
			_maybe_add_torch(pos, rot)


func _build_corner_pillars() -> void:
	for vy in range(0, height + 1):
		for vx in range(0, width + 1):
			var cells := [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]
			var walls := 0
			var low := false
			for cc in cells:
				if cell_char(cc) == "#":
					walls += 1
					low = low or _is_low_wall(cc)
			var diagonal := walls == 2 and (cell_char(cells[0]) == "#") == (cell_char(cells[3]) == "#")
			if walls == 1 or diagonal:
				var pillar := _place("pillar", Vector3(vx * TILE - TILE * 0.5, 0, vy * TILE - TILE * 0.5))
				if low:
					pillar.scale.y = LOW_WALL_SCALE


func _build_wall_collision() -> void:
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if cell_char(c) != "#":
				continue
			var near_floor := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if cell_char(c + Vector2i(dx, dy)) != "#":
						near_floor = true
			if near_floor:
				_add_box(_walls_body, cell_to_world(c) + Vector3(0, 2, 0), Vector3(TILE, 4, TILE))


func _add_box(body: StaticBody3D, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	body.add_child(shape)
	return shape


func _add_solid(pos: Vector3, size: Vector3) -> void:
	_add_box(_walls_body, pos + Vector3(0, size.y * 0.5, 0), size)


func _build_content(c: Vector2i, ch: String) -> void:
	var pos := cell_to_world(c)
	match ch:
		"P":
			start_cell = c
		"E":
			exit_cell = c
			_build_exit(c)
		"K":
			_build_key(pos)
		"c":
			_build_coin(pos)
		"C":
			_build_chest(c)
		"D":
			_build_door(c)
		"b":
			_place("barrel_large", pos + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4)), _rng.randf() * TAU)
			_place("barrel_small", pos + Vector3(1.2, 0, 1.1), _rng.randf() * TAU)
			_add_solid(pos, Vector3(2.4, 2, 2.4))
		"x":
			_place("crates_stacked", pos, _random_quarter_turn())
			_add_solid(pos, Vector3(3.0, 2, 3.0))
		"o":
			_place("pillar_decorated", pos)
			_add_solid(pos, Vector3(1.6, 4, 1.6))
		"t":
			_place("table_medium_decorated_A", pos, _random_quarter_turn())
			_add_solid(pos, Vector3(3.0, 2, 2.2))


func _maybe_add_torch(wall_pos: Vector3, rot: float) -> void:
	for spot in _torch_spots:
		if spot.distance_to(wall_pos) < TILE * 2.2:
			return
	_torch_spots.append(wall_pos)
	var facing := Vector3(sin(rot), 0, cos(rot))
	var holder := Node3D.new()
	holder.position = wall_pos + facing * 0.5 + Vector3(0, 2.3, 0)
	holder.rotation.y = rot
	add_child(holder)
	_place("torch_mounted", Vector3.ZERO, 0.0, holder)
	var flame := Effects.make_flame()
	flame.position = Vector3(0, 0.78, 0.45)
	holder.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.56, 0.24)
	light.light_energy = 3.4
	light.omni_range = 12.0
	light.omni_attenuation = 1.3
	light.position = Vector3(0, 1.0, 1.0)
	holder.add_child(light)
	_torches.append({"light": light, "seed": _rng.randf() * 100.0})


func _build_key(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 1.3, 0)
	add_child(holder)
	var key := _place("key", Vector3(-0.25, 0, 0), 0.0, holder)
	key.scale = Vector3.ONE * 2.2
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.35)
	light.light_energy = 1.8
	light.omni_range = 4.0
	holder.add_child(light)
	holder.add_child(Effects.make_sparkles(Color(1.0, 0.85, 0.4)))
	_pickups.append({"node": holder, "kind": "key", "radius": 1.8})


func _build_coin(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos + Vector3(0, 0.9, 0)
	add_child(holder)
	var coin := _place("coin", Vector3.ZERO, 0.0, holder)
	coin.scale = Vector3.ONE * 3.0
	coin.rotation.x = PI * 0.5
	_pickups.append({"node": holder, "kind": "coin", "radius": 1.5})


func _build_chest(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	# Face the chest towards the open side of the room.
	var rot := 0.0
	if cell_char(c + Vector2i(0, 1)) == "#":
		rot = PI
	var chest := _place("chest_gold", pos, rot)
	_add_solid(pos, Vector3(2.0, 1.5, 2.0))
	_chests.append({"node": chest, "lid": chest.find_child("chest_gold_lid", true, false), "pos": pos, "open": false})


func _build_door(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	var blocks_north_south := cell_char(c + Vector2i(-1, 0)) == "#" and cell_char(c + Vector2i(1, 0)) == "#"
	var rot := 0.0 if blocks_north_south else PI * 0.5
	var door := _place("wall_doorway", pos, rot)
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot
	add_child(body)
	_add_box(body, Vector3(-1.45, 2, 0), Vector3(1.1, 4, 1))
	_add_box(body, Vector3(1.45, 2, 0), Vector3(1.1, 4, 1))
	var leaf := _add_box(body, Vector3(0, 2, 0), Vector3(1.8, 4, 1))
	_doors.append({"door": door.find_child("wall_doorway_door", true, false), "leaf": leaf, "cell": c, "pos": pos, "open": false})


func _build_exit(c: Vector2i) -> void:
	var pos := cell_to_world(c)
	_place("stairs", pos + Vector3(0, 0, -TILE * 0.5))
	# Pale light falling down the stairs: the way out.
	var light := OmniLight3D.new()
	light.light_color = Color(0.62, 0.78, 1.0)
	light.light_energy = 3.0
	light.omni_range = 10.0
	light.position = pos + Vector3(0, 6.0, -2.5)
	add_child(light)
	var motes := Effects.make_sparkles(Color(0.7, 0.85, 1.0))
	motes.position = pos + Vector3(0, 2.5, -1.0)
	add_child(motes)


# --- Runtime ----------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	for t in _torches:
		var s: float = t.seed + _time * 9.0
		t.light.light_energy = 3.4 + sin(s) * 0.25 + sin(s * 2.3) * 0.15
	for p in _pickups:
		if is_instance_valid(p.node):
			p.node.rotation.y += delta * 2.0
			p.node.position.y += sin(_time * 3.0) * delta * 0.25
	_update_spikes(delta)
	if player == null or finished:
		return
	_check_pickups()
	_check_doors()
	_check_chests()
	if exit_cell.x >= 0:
		var exit_pos := cell_to_world(exit_cell)
		if Vector2(player.global_position.x - exit_pos.x, player.global_position.z - exit_pos.z).length() < 1.4:
			finished = true
			exit_reached.emit()


func _spike_is_up(s: Dictionary) -> bool:
	return fposmod(_time + s.phase, SPIKE_PERIOD) < SPIKE_UP_TIME


func _update_spikes(delta: float) -> void:
	for s in _spikes:
		var t := fposmod(_time + s.phase, SPIKE_PERIOD)
		var target := SPIKE_DOWN_Y
		var speed := 4.0
		if t < SPIKE_UP_TIME:
			target = 0.0
			speed = 30.0
		elif t > SPIKE_PERIOD - 0.45:
			target = SPIKE_DOWN_Y + 0.35 # A small twitch warns before they shoot up.
			speed = 10.0
		s.node.position.y = move_toward(s.node.position.y, target, delta * speed * 2.0)
		if player and not finished and _spike_is_up(s):
			var sp := cell_to_world(s.cell)
			if absf(player.global_position.x - sp.x) < 1.6 and absf(player.global_position.z - sp.z) < 1.6:
				player_hurt.emit()


func _check_pickups() -> void:
	for p in _pickups.duplicate():
		var n: Node3D = p.node
		var d := Vector2(player.global_position.x - n.global_position.x, player.global_position.z - n.global_position.z)
		if d.length() > p.radius:
			continue
		_pickups.erase(p)
		var tween := create_tween()
		tween.tween_property(n, "position:y", n.position.y + 1.5, 0.35).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(n, "scale", Vector3.ONE * 0.01, 0.35).set_ease(Tween.EASE_IN)
		tween.tween_callback(n.queue_free)
		if p.kind == "key":
			key_collected.emit()
		else:
			coins_collected.emit(1)


func _check_doors() -> void:
	for d in _doors:
		if d.open:
			continue
		var dist := Vector2(player.global_position.x - d.pos.x, player.global_position.z - d.pos.z).length()
		if dist > 4.2:
			continue
		if not has_key:
			if not _door_hint_shown:
				_door_hint_shown = true
				door_locked.emit()
			continue
		d.open = true
		has_key = false
		d.leaf.queue_free()
		astar.set_point_solid(d.cell, false)
		var tween := create_tween()
		tween.tween_property(d.door, "rotation:y", d.door.rotation.y - deg_to_rad(105), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		door_opened.emit()
	if not has_key and _door_hint_shown:
		# Allow the hint again once the player walked away.
		var far := true
		for d in _doors:
			if not d.open and Vector2(player.global_position.x - d.pos.x, player.global_position.z - d.pos.z).length() < 5.0:
				far = false
		if far:
			_door_hint_shown = false


func _check_chests() -> void:
	for ch in _chests:
		if ch.open:
			continue
		if Vector2(player.global_position.x - ch.pos.x, player.global_position.z - ch.pos.z).length() > 4.3:
			continue
		ch.open = true
		if ch.lid:
			create_tween().tween_property(ch.lid, "rotation:x", ch.lid.rotation.x - deg_to_rad(70), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var burst := Effects.make_sparkles(Color(1.0, 0.85, 0.3), true)
		burst.position = ch.pos + Vector3(0, 1.2, 0)
		add_child(burst)
		coins_collected.emit(5)
