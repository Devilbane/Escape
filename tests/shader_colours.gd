extends SceneTree
## Headless test: every shader of the game's own takes its colours the same way on both renderers
## (see shaders/gl_colour.gdshaderinc). That is, for every spatial shader in shaders/ and every one
## written into a script:
## - no colour input carries a source_color hint, and
## - every fragment() ends with ALBEDO = gl_colour(ALBEDO); (and EMISSION = gl_colour(EMISSION);
##   where it sets EMISSION), with gl_colour.gdshaderinc included.
## A shader that misses this looks right on OpenGL but pale and flat on the modern renderer.
## The fog of war and the fog banks read the finished picture and are left out (KEPT).
## Godot's own materials that take their colour from vertex colours set vertex_color_is_srgb from
## Graphics.vertex_colours_srgb(), for the same reason.
## Run with: godot --headless -s tests/shader_colours.gd

## Shaders that keep Godot's own colour handling, and why.
const KEPT := {
	"res://shaders/fog.gdshader": "darkens the finished picture (screen texture)",
	"res://shaders/fog_clouds.gdshader": "its haze colour is the same on both; its see-through blend goes through gl_alpha",
	"res://shaders/gl_colour.gdshaderinc": "the helper itself",
}
const INCLUDE := "res://shaders/gl_colour.gdshaderinc"

var failures := 0
var checked := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	for file in _files("res://shaders", [".gdshader", ".gdshaderinc"]):
		if KEPT.has(file):
			continue
		_check_shader(file, FileAccess.get_file_as_string(file))
	for file in _files("res://scripts", [".gd"]):
		_check_script(file, FileAccess.get_file_as_string(file))
		_check_vertex_colours(file, FileAccess.get_file_as_string(file))
	check(checked >= 40, "only %d shaders found" % checked)
	print("checked %d shaders" % checked)
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _files(dir_path: String, endings: Array) -> Array[String]:
	var out: Array[String] = []
	for name in DirAccess.get_files_at(dir_path):
		for ending: String in endings:
			if name.ends_with(ending):
				out.append(dir_path.path_join(name))
	return out


## A script's shaders: from each "shader_type spatial" on to the end of the fragment() that follows
## it (a shader may be put together from several strings, as WindowLife's is).
func _check_script(file: String, text: String) -> void:
	var at := text.find("shader_type spatial")
	while at >= 0:
		var next := text.find("shader_type spatial", at + 1)
		var frag := text.find("void fragment()", at)
		var end := next if next >= 0 else text.length()
		if frag >= 0 and (next < 0 or frag < next):
			end = frag + _fragment_body(text.substr(frag)).length() + 20
		_check_shader("%s (shader at line %d)" % [file, text.substr(0, at).count("\n") + 1], text.substr(at, end - at))
		at = next


func _check_shader(where: String, code: String) -> void:
	if code.contains("shader_type canvas_item"):
		return
	var has_fragment := code.contains("void fragment()")
	if not has_fragment and not code.contains("source_color") and not where.ends_with(".gdshaderinc"):
		return
	checked += 1
	check(not code.contains("source_color"), "%s: a colour input still has source_color" % where)
	if not has_fragment:
		return
	check(code.contains('#include "%s"' % INCLUDE), "%s: does not include %s" % [where, INCLUDE])
	var body := _fragment_body(code)
	var tail := body.strip_edges().split("\n")
	var sets_emission := RegEx.create_from_string("\\bEMISSION\\s*[+\\-*]?=\\s*(?!gl_colour)").search(body) != null
	var wanted := ["ALBEDO = gl_colour(ALBEDO);"]
	if sets_emission:
		wanted.append("EMISSION = gl_colour(EMISSION);")
	var last: Array = Array(tail).slice(-wanted.size()).map(func(l: String) -> String: return l.strip_edges())
	for line: String in wanted:
		check(line in last, "%s: fragment() does not end with %s" % [where, line])


func _fragment_body(code: String) -> String:
	var start := code.find("void fragment()")
	var open := code.find("{", start)
	var depth := 0
	for i in range(open, code.length()):
		var c := code[i]
		if c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				return code.substr(open + 1, i - open - 1)
	return code.substr(open + 1)


## Every "<material>.vertex_color_use_as_albedo = true" is followed by
## "<material>.vertex_color_is_srgb = Graphics.vertex_colours_srgb()".
func _check_vertex_colours(file: String, text: String) -> void:
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if not line.ends_with(".vertex_color_use_as_albedo = true"):
			continue
		var material := line.trim_suffix(".vertex_color_use_as_albedo = true")
		var next := lines[i + 1].strip_edges() if i + 1 < lines.size() else ""
		check(next == material + ".vertex_color_is_srgb = Graphics.vertex_colours_srgb()",
				"%s:%d: %s takes vertex colours without vertex_color_is_srgb" % [file, i + 1, material])
