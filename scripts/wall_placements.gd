class_name WallPlacements
extends RefCounted
## Where climbing walls stand in the world. A placement says: a wall (a file made in the wall workshop, see
## WallWorkshop), the map and the rock tile it is climbed from. The hero pushes against that rock tile like
## against any mountain face (see Player._try_climb_rock) and, after the usual moment, the wall screen opens
## (see WallScreens): the mountaineer's climb, with the hero's own Klettern, the weather of the day and the
## hero's life points. At the top, the wall's `summit` takes the hero where it says (another map, a place).
##
## The list is a text file, one placement per line, `wall file | map name | column row`; lines starting with #
## are ignored. There are two lists: walls/placements.txt that ships with the game and
## user://waende/placements.txt, which is yours (the workshop saves your walls into the same folder, so the
## wall file is just the name of what you saved, for example `my_wall.txt`). Your list wins.
##
## Example:   sample_three_paths.txt | Apfeltal | 120 30

const SHIPPED := "res://walls/placements.txt"
const USER := "user://waende/placements.txt"


## All placements: [{"wall": file, "map": map name, "cell": Vector2i}], yours first.
static func all() -> Array:
	var out := []
	for path in [USER, SHIPPED]:
		out.append_array(parse(_read(path)))
	return out


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


static func parse(text: String) -> Array:
	var out := []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts := line.split("|")
		if parts.size() < 3:
			continue
		var xy := parts[2].strip_edges().split(" ", false)
		if xy.size() != 2 or not xy[0].is_valid_int() or not xy[1].is_valid_int():
			continue
		out.append({"wall": parts[0].strip_edges(), "map": parts[1].strip_edges(), "cell": Vector2i(int(xy[0]), int(xy[1]))})
	return out


## The placement on rock tile `cell` of the map called `level_name`, or an empty Dictionary.
static func at(level_name: String, cell: Vector2i) -> Dictionary:
	for p: Dictionary in all():
		if p.map == level_name and p.cell == cell:
			return p
	return {}


## The wall a placement names: from your folder first, then from the game's.
static func load_wall(file: String) -> WallMap:
	for dir in [WallWorkshop.SAVE_DIR, WallWorkshop.SHIPPED_DIR]:
		var m := WallMap.load_file(dir + file)
		if m != null:
			return m
	return null


## `summit` ("level file:place") as [level file, place]; an empty Array without one.
static func summit_of(wall: WallMap) -> Array:
	if wall.summit == "":
		return []
	var parts := wall.summit.split(":", true, 1)
	return [parts[0].strip_edges(), parts[1].strip_edges() if parts.size() > 1 else ""]
