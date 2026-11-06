extends SceneTree
## Renders the hero, the smith and a skeleton warrior in one style.
## Mock-up only (not used by the game). Run with a display:
## godot --path . --resolution 2560x1440 -s tools/mockups/character_styles.gd -- <today|hd|cel|paint|grit|detail> (fplus/both need --rendering-method forward_plus)
var game: Node
var frames := 0
var v: Node3D
var e: Node3D
var style := "today"
var OUT := "user://character_styles/"

const LIGHT_CEL := """
void light() {
	float nl = dot(NORMAL, LIGHT);
	float l = clamp(nl, 0.0, 1.0) * ATTENUATION;
	float band = l > 0.45 ? 1.0 : (l > 0.06 ? 0.55 : 0.12);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float s = pow(max(dot(NORMAL, h), 0.0), 60.0) * ATTENUATION;
	SPECULAR_LIGHT += step(0.5, s) * LIGHT_COLOR * 0.12;
	float rim = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	DIFFUSE_LIGHT += step(0.68, rim) * step(0.0, nl) * LIGHT_COLOR / PI * 0.45;
}
"""

const LIGHT_PAINT := """
void light() {
	float nl = dot(NORMAL, LIGHT);
	float w = clamp((nl + 0.35) / 1.35, 0.0, 1.0) * mix(0.35, 1.0, ATTENUATION);
	float band = smoothstep(0.30, 0.52, w) * 0.65 + smoothstep(0.7, 0.9, w) * 0.35;
	vec3 shade = mix(vec3(0.20, 0.13, 0.24), vec3(0.78, 0.68, 0.55), band);
	DIFFUSE_LIGHT += shade * LIGHT_COLOR / PI;
	float rim = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	DIFFUSE_LIGHT += vec3(1.0, 0.68, 0.30) * smoothstep(0.6, 0.9, rim) * 0.4 * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += vec3(1.0, 0.85, 0.6) * pow(max(dot(NORMAL, h), 0.0), 24.0) * ATTENUATION * LIGHT_COLOR * 0.06;
}
"""

const LIGHT_GRIT := """
void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float l = pow(nl, 1.5) * ATTENUATION;
	DIFFUSE_LIGHT += l * LIGHT_COLOR / PI * 1.15;
	float rim = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	DIFFUSE_LIGHT += vec3(0.55, 0.7, 1.0) * pow(rim, 3.0) * 0.9 * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), 40.0) * ATTENUATION * LIGHT_COLOR * 0.10;
}
"""

const LIGHT_HD := """
void light() {
	float nl = dot(NORMAL, LIGHT);
	float w = clamp((nl + 0.25) / 1.25, 0.0, 1.0) * ATTENUATION;
	DIFFUSE_LIGHT += w * LIGHT_COLOR / PI;
	float rim = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	DIFFUSE_LIGHT += vec3(1.0, 0.9, 0.75) * pow(rim, 4.0) * 0.35 * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	SPECULAR_LIGHT += pow(max(dot(NORMAL, h), 0.0), 32.0) * ATTENUATION * LIGHT_COLOR * 0.05;
}
"""

const STD := """
shader_type spatial;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float metallic = 0.0;
uniform float roughness = 1.0;
void fragment() {
	ALBEDO = (texture(tex, UV) * albedo).rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
"""

const DETAIL_CALL := """
	{
		vec3 d_wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 d_wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 d_alb = ALBEDO;
		float d_rough = ROUGHNESS;
		vec3 d_g = vec3(0.0);
		d_detail(d_wp, d_wn, d_alb, d_rough, d_g);
		ALBEDO = d_alb;
		ROUGHNESS = d_rough;
		NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(d_g, 0.0)).xyz);
	}
"""

const DETAIL_FUNCS := """
float d_hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float d_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(d_hash(i), d_hash(i + vec2(1, 0)), f.x), mix(d_hash(i + vec2(0, 1)), d_hash(i + vec2(1, 1)), f.x), f.y);
}
float d_fbm(vec2 p) { float a = 0.5; float r = 0.0; for (int i = 0; i < 4; i++) { r += a * d_noise(p); p *= 2.03; a *= 0.5; } return r; }
float d_cells(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); float d = 1.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 r = o + vec2(d_hash(i + o), d_hash(i + o + 7.1)) - f;
		d = min(d, dot(r, r));
	}
	return sqrt(d);
}
// Height of the painted surface: cloth weave, leather grain, metal scratches, bone cracks, skin.
float d_height(vec2 uv, vec4 w) {
	float weave = 0.5 + 0.5 * sin(uv.x * 420.0) * sin(uv.y * 420.0);
	weave = mix(weave, d_noise(uv * 140.0), 0.35);
	float leather = smoothstep(0.0, 0.45, d_cells(uv * 70.0)) * 0.7 + d_fbm(uv * 30.0) * 0.3;
	float scratch = 1.0 - smoothstep(0.0, 0.06, abs(d_noise(vec2(uv.x * 9.0, uv.y * 240.0)) - 0.5)) * 0.8;
	scratch = scratch * 0.7 + d_noise(uv * 160.0) * 0.3;
	float cracks = smoothstep(0.0, 0.05, abs(d_fbm(uv * 14.0) - 0.5)) * 0.75 + d_noise(uv * 90.0) * 0.25;
	float skin = d_noise(uv * 220.0) * 0.4 + 0.6;
	return weave * w.x + leather * w.y + scratch * w.z + mix(skin, cracks, step(0.5, 1.0 - w.w)) * w.w;
}
void d_detail(vec3 p, vec3 n, inout vec3 alb, inout float rough, out vec3 g) {
	vec3 an = abs(n);
	vec2 uv = an.x > an.y && an.x > an.z ? p.zy : (an.y > an.z ? p.xz : p.xy);
	float mx = max(alb.r, max(alb.g, alb.b));
	float mn = min(alb.r, min(alb.g, alb.b));
	float sat = mx > 0.001 ? (mx - mn) / mx : 0.0;
	float warm = step(alb.b, alb.g) * step(alb.g, alb.r);
	float skinw = warm * smoothstep(0.65, 0.8, mx) * smoothstep(0.12, 0.22, sat) * (1.0 - smoothstep(0.4, 0.5, sat));
	float leatherw = warm * max(1.0 - smoothstep(0.45, 0.6, mx), smoothstep(0.45, 0.55, sat)) * smoothstep(0.2, 0.35, sat) * (1.0 - skinw);
	float greyw = 1.0 - smoothstep(0.1, 0.22, sat);
	float bonew = greyw * smoothstep(0.6, 0.8, mx);
	float metalw = greyw - bonew;
	float clothw = max(0.0, 1.0 - skinw - leatherw - greyw);
	vec4 w = vec4(clothw, leatherw, metalw, skinw + bonew);
	if (bonew > skinw) { w.w = -w.w; }
	vec4 wa = vec4(w.xyz, abs(w.w));
	// sign of w.w picks cracks (bone) or pores (skin)
	vec4 ww = vec4(wa.xyz, abs(w.w));
	float e = 0.0015;
	float h0 = d_height(uv, ww);
	float hx = d_height(uv + vec2(e, 0.0), ww);
	float hy = d_height(uv + vec2(0.0, e), ww);
	float amount = 0.9 - 0.75 * skinw;
	alb *= 0.86 + 0.28 * h0 * amount + (1.0 - amount) * 0.14;
	alb *= 1.0 - 0.25 * metalw * (1.0 - h0);
	rough = clamp(rough + (0.5 - h0) * 0.35 * metalw - 0.25 * metalw, 0.05, 1.0);
	vec3 t1 = an.x > an.y && an.x > an.z ? vec3(0, 0, 1) : (an.y > an.z ? vec3(1, 0, 0) : vec3(1, 0, 0));
	vec3 t2 = an.x > an.y && an.x > an.z ? vec3(0, 1, 0) : (an.y > an.z ? vec3(0, 0, 1) : vec3(0, 1, 0));
	g = -((hx - h0) / e * t1 + (hy - h0) / e * t2) * 0.0014 * amount;
	g -= n * dot(g, n);
}
"""

const OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always;
uniform vec4 ink : source_color = vec4(0.08, 0.05, 0.04, 1.0);
uniform float width = 0.012;
void vertex() { VERTEX += normalize(NORMAL) * width; }
void fragment() { ALBEDO = ink.rgb; }
"""

## Painted strokes: a Kuwahara filter on the character's own pixels.
const PAINT_OVERLAY := """
shader_type spatial;
render_mode unshaded, depth_draw_never, blend_mix;
uniform sampler2D screen : hint_screen_texture, filter_linear;
const int R = 7;
void fragment() {
	vec2 px = 1.0 / vec2(textureSize(screen, 0));
	vec3 m[4]; vec3 s[4];
	for (int k = 0; k < 4; k++) { m[k] = vec3(0.0); s[k] = vec3(0.0); }
	for (int j = -R; j <= R; j++) {
		for (int i = -R; i <= R; i++) {
			vec3 c = texture(screen, SCREEN_UV + vec2(float(i), float(j)) * px).rgb;
			if (i <= 0 && j <= 0) { m[0] += c; s[0] += c * c; }
			if (i >= 0 && j <= 0) { m[1] += c; s[1] += c * c; }
			if (i <= 0 && j >= 0) { m[2] += c; s[2] += c * c; }
			if (i >= 0 && j >= 0) { m[3] += c; s[3] += c * c; }
		}
	}
	float n = float((R + 1) * (R + 1));
	float best = 1e9; vec3 col = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec3 mean = m[k] / n;
		vec3 var = abs(s[k] / n - mean * mean);
		float sv = var.r + var.g + var.b;
		if (sv < best) { best = sv; col = mean; }
	}
	// warm varnish and a faint canvas weave
	float weave = 0.97 + 0.03 * sin(FRAGCOORD.x * 1.3) * sin(FRAGCOORD.y * 1.3);
	col = mix(col, col * vec3(1.02, 0.95, 0.85), 0.7) * weave * 0.92;
	ALBEDO = col;
}
"""

## Dark and worn: desaturated, harder contrast, grime from the feet up.
const GRIT_OVERLAY := """
shader_type spatial;
render_mode unshaded, depth_draw_never, blend_mix;
uniform sampler2D screen : hint_screen_texture, filter_linear;
varying vec3 wpos;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, 0.45);
	c = (c - 0.5) * 1.18 + 0.47;
	float n = noise(wpos * 9.0) * 0.6 + noise(wpos * 31.0) * 0.4;
	float grime = smoothstep(0.35, 0.8, n) * 0.35 + (1.0 - smoothstep(0.0, 0.9, wpos.y - floor(wpos.y / 100.0) * 100.0)) * 0.0;
	float feet = 1.0 - smoothstep(0.0, 0.7, fract(wpos.y));
	c *= 1.0 - grime;
	c = mix(c, c * vec3(0.55, 0.45, 0.35), feet * 0.6);
	ALBEDO = clamp(c, 0.0, 1.0);
}
"""

## Crisp: a hint of sharpening on the character's pixels.
const HD_OVERLAY := """
shader_type spatial;
render_mode unshaded, depth_draw_never, blend_mix;
uniform sampler2D screen : hint_screen_texture, filter_linear;
void fragment() {
	vec2 px = 1.0 / vec2(textureSize(screen, 0));
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec3 b = (texture(screen, SCREEN_UV + vec2(px.x, 0)).rgb + texture(screen, SCREEN_UV - vec2(px.x, 0)).rgb
		+ texture(screen, SCREEN_UV + vec2(0, px.y)).rgb + texture(screen, SCREEN_UV - vec2(0, px.y)).rgb) * 0.25;
	ALBEDO = clamp(c + (c - b) * 0.6, 0.0, 1.0);
}
"""

var WHITE: Texture2D

func _initialize() -> void:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	WHITE = ImageTexture.create_from_image(img)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		style = args[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	WorldPreload.done = true
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _chars() -> Array:
	return [e, v, game.player]


func _restyle(light_code: String, overlay: Material, outline: Material = null, detail := false) -> void:
	for c in _chars():
		for m: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
			if m.mesh == null:
				continue
			var count := 1 if m.material_override != null else m.mesh.get_surface_count()
			for i in count:
				var mat: Material = m.get_active_material(i)
				if mat == null:
					continue
				var code := ""
				var params := {}
				if mat is ShaderMaterial:
					code = mat.shader.code
					for u in mat.shader.get_shader_uniform_list():
						params[u.name] = mat.get_shader_parameter(u.name)
				elif mat is BaseMaterial3D:
					if mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.emission_enabled:
						continue
					code = STD
					params = {"albedo": mat.albedo_color, "tex": mat.albedo_texture if mat.albedo_texture else WHITE, "metallic": mat.metallic, "roughness": mat.roughness}
				if code == "" or code.contains("void light()"):
					continue
				if light_code != "" or detail:
					var sh := Shader.new()
					sh.code = (_add_detail(code) if detail else code) + "\n" + light_code
					var nm := ShaderMaterial.new()
					nm.shader = sh
					nm.next_pass = outline
					for k in params:
						nm.set_shader_parameter(k, params[k])
					if m.material_override != null:
						m.material_override = nm
					else:
						m.set_surface_override_material(i, nm)
			if overlay:
				m.material_overlay = overlay


## Puts the painted surface detail at the end of the shader's fragment().
func _inline(code: String) -> String:
	var out := PackedStringArray()
	for line in code.split("\n"):
		if line.strip_edges().begins_with("#include"):
			var path := line.get_slice("\"", 1)
			out.append(_inline(FileAccess.get_file_as_string(path)))
		else:
			out.append(line)
	return "\n".join(out)


func _add_detail(code: String) -> String:
	code = _inline(code)
	if code.contains("hair_color"):
		return code  # the hair has its own strands
	var at := code.find("void fragment()")
	if at < 0:
		return code
	var open := code.find("{", at)
	var depth := 0
	var close := -1
	for k in range(open, code.length()):
		var ch := code[k]
		if ch == "{":
			depth += 1
		elif ch == "}":
			depth -= 1
			if depth == 0:
				close = k
				break
	if close < 0:
		return code
	return code.substr(0, at) + DETAIL_FUNCS + "\n" + code.substr(at, close - at) + DETAIL_CALL + code.substr(close)


func _mat(code: String, next: Material = null) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	m.next_pass = next
	return m


func _outline(w: float, ink: Color) -> ShaderMaterial:
	var m := _mat(OUTLINE)
	m.set_shader_parameter("width", w)
	m.set_shader_parameter("ink", ink)
	return m


func _apply_style() -> void:
	match style:
		"today":
			pass
		"hd":
			root.msaa_3d = Viewport.MSAA_8X
			_restyle(LIGHT_HD, _mat(HD_OVERLAY))
		"cel":
			root.msaa_3d = Viewport.MSAA_4X
			_restyle(LIGHT_CEL, null, _outline(0.035, Color(0.07, 0.04, 0.03)))
		"paint":
			root.msaa_3d = Viewport.MSAA_4X
			_restyle(LIGHT_PAINT, _mat(PAINT_OVERLAY), _outline(0.03, Color(0.22, 0.12, 0.06)))
		"fplus":
			_full_renderer()
		"detail":
			root.msaa_3d = Viewport.MSAA_4X
			_restyle("", null, null, true)
		"both":
			_full_renderer()
			_restyle("", null, null, true)
		"grit":
			root.msaa_3d = Viewport.MSAA_4X
			_restyle(LIGHT_GRIT, _mat(GRIT_OVERLAY), _outline(0.022, Color(0.03, 0.03, 0.04)))


## What the Forward+ renderer adds: contact shadows (SSAO), bounced light
## (SSIL), glow and softer, finer shadows.
func _full_renderer() -> void:
	root.msaa_3d = Viewport.MSAA_4X
	var env: Environment = game._env
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.8
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	game._moon.light_angular_distance = 0.6
	game._moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func _hide_ui() -> void:
	for n in game.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	for n in game.find_children("*", "Label3D", true, false):
		n.visible = false
	for n in game.find_children("*", "Sprite3D", true, false):
		n.visible = false


func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		game.load_level(game._outdoor_index(), false)
		game.state = 1
		game.day_hour = 11.0
	if frames == 60:
		var p: Node3D = game.player
		for x in game.level.find_children("*", "Villager", true, false):
			if x.role == "1":
				v = x
		v.set_physics_process(false)
		v.set_process(false)
		v.global_position = p.global_position + Vector3(1.75, 0, 0.25)
		e = Enemy.new()
		e.kind = "krieger"
		e.gear = [] as Array[String]
		e.level = game.level
		game.level.add_child(e)
		e.global_position = p.global_position + Vector3(-1.75, 0, 0.25)
		e.set_physics_process(false)
	if frames == 64:
		e.set_physics_process(false)
		game.player.set_physics_process(false)
		game.player.set_process(false)
	if frames == 96:
		for c in _chars():
			c.rotation = Vector3.ZERO
			c._model.global_rotation = Vector3.ZERO
		e._model.global_rotation.y = 0.25
		v._model.global_rotation.y = -0.2
		_hide_ui()
		_apply_style()
	if frames == 104:
		root.get_texture().get_image().save_png(OUT + style + "_game.png")
		var cam := Camera3D.new()
		cam.fov = 30
		game.add_child(cam)
		var c: Vector3 = game.player.global_position + Vector3(0, 0.95, 0)
		cam.global_position = c + Vector3(0, 1.5, 7.6)
		cam.look_at(c)
		cam.make_current()
	if frames == 110:
		root.get_texture().get_image().save_png(OUT + style + "_close.png")
		quit()
	return false
