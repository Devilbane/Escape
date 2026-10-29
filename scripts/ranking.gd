class_name Ranking
extends RefCounted
## The list of finished runs on this computer, best first: deepest level
## reached, then most gold. Fallen heroes get a skull, escaped ones a crown.

const FILE := "user://rangliste.json"
const SHOWN := 8
const RED := Color(1.0, 0.45, 0.4)


static func load_all() -> Array:
	if not FileAccess.file_exists(FILE):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return data if data is Array else []


## Adds a finished run and returns it, sorted into the list.
static func add(hero: String, level: int, level_name: String, gold: int, escaped: bool) -> Dictionary:
	var entry := {"name": hero, "level": level, "level_name": level_name, "gold": gold, "escaped": escaped,
			"date": Time.get_date_string_from_system(), "id": "%d-%d" % [Time.get_unix_time_from_system(), randi()]}
	var runs := load_all()
	runs.append(entry)
	runs.sort_custom(_better)
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(runs.slice(0, 50)))
	return entry


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if a.level != b.level:
		return a.level > b.level
	if a.gold != b.gold:
		return a.gold > b.gold
	return a.escaped and not b.escaped


## A table of the best runs; `current` is highlighted (also when it is lower down).
static func build(game: Node, current: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Menus.panel_style(Color(0.85, 0.66, 0.32, 0.7)))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading: Label = game._make_label(game.TITLE_FONT, 30, game.GOLD)
	heading.text = "Rangliste"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for title in ["Platz", "Name", "Status", "Ebene", "Gold", "Datum"]:
		_cell(game, grid, title, Color(0.65, 0.85, 1.0))
	var runs := load_all()
	var rank := 0
	for i in runs.size():
		if runs[i].get("id", "") == current.get("id", "-"):
			rank = i
	for i in runs.size():
		if i >= SHOWN and i != rank:
			continue
		var run: Dictionary = runs[i]
		var mine: bool = i == rank and not current.is_empty()
		var color := Color(1, 1, 0.6) if mine else Color.WHITE
		_cell(game, grid, "%d." % (i + 1), color)
		_cell(game, grid, run.get("name", "?"), color)
		var status := HBoxContainer.new()
		status.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = crown_texture() if run.escaped else skull_texture()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		status.add_child(icon)
		_cell(game, status, "Entkommen" if run.escaped else "Gefallen", game.GOLD if run.escaped else RED)
		grid.add_child(status)
		_cell(game, grid, "%d  %s" % [run.level, run.level_name], color)
		_cell(game, grid, str(int(run.gold)), game.GOLD)
		_cell(game, grid, run.date, color)
	return panel


static func _cell(game: Node, parent: Control, text: String, color: Color) -> void:
	var l: Label = game._make_label(game.TEXT_FONT, 20, color)
	l.text = text
	parent.add_child(l)


static var _skull: Texture2D
static var _crown: Texture2D


## A small skull drawn pixel by pixel: bone white with a dark rim, hollow eyes.
static func skull_texture() -> Texture2D:
	if _skull:
		return _skull
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bone := Color(0.95, 0.92, 0.84)
	var dark := Color(0.1, 0.05, 0.08)
	for y in S:
		for x in S:
			var p := Vector2(x, y)
			var head := p.distance_to(Vector2(32, 26)) / 22.0
			var jaw := absf(x - 32) < 13 and y > 34 and y < 54
			var inside := head < 1.0 or jaw
			var rim := head < 1.12 or (absf(x - 32) < 16 and y > 32 and y < 57)
			if inside:
				img.set_pixel(x, y, bone)
			elif rim:
				img.set_pixel(x, y, dark)
			# Eyes, nose and the gaps between the teeth.
			if p.distance_to(Vector2(23, 30)) < 6.5 or p.distance_to(Vector2(41, 30)) < 6.5:
				img.set_pixel(x, y, dark)
			if y > 37 and y < 44 and absf(x - 32) < (y - 36) * 0.6:
				img.set_pixel(x, y, dark)
			if y > 47 and y < 54 and absf(x - 32) < 12 and (x - 20) % 5 == 0:
				img.set_pixel(x, y, dark)
	_skull = ImageTexture.create_from_image(img)
	return _skull


## A small golden crown for those who escaped.
static func crown_texture() -> Texture2D:
	if _crown:
		return _crown
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var gold := Color(1.0, 0.8, 0.3)
	var dark := Color(0.3, 0.18, 0.05)
	for y in S:
		for x in S:
			# Three spikes over a band: the spikes' tips sit at x 10, 32 and 54.
			var spike := 1.0 - minf(minf(absf(x - 10), absf(x - 32)), absf(x - 54)) / 11.0
			var top := 46.0 - spike * 30.0
			if x > 6 and x < 58 and y > top and y < 52:
				img.set_pixel(x, y, gold if y > top + 3 and x > 9 and x < 55 and y < 49 else dark)
	for c in [Vector2(10, 14), Vector2(32, 14), Vector2(54, 14)]:
		for y in range(c.y - 5, c.y + 6):
			for x in range(c.x - 5, c.x + 6):
				if Vector2(x, y).distance_to(c) < 4.5:
					img.set_pixel(x, y, Color(0.95, 0.25, 0.3))
	_crown = ImageTexture.create_from_image(img)
	return _crown
