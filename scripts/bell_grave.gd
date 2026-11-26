class_name BellGrave
extends Node3D
## The safety coffin of the valley's graveyard: in the old days people feared being buried alive and put a bell on
## a post over the grave, with a cord running down into the coffin to the hand of the one below. This grave's bell
## rings once a night, when the hero comes near the middle of the graveyard: a tiny, shrill bell, rung in a hurry.
## Whoever reaches the grave within WINDOW seconds of the ring hears a scream, "You're too late, I'm already dead!"
## (and has solved the riddle, see GraveyardRiddles); whoever comes later hears only a faint whimper and has to wait
## for the next night's ring. The only condition is the night (see DayNight.is_night).
##
## The bell is built here, from a lathe profile with textures made from noise (bronze with a green patina, grained
## wood, twisted hemp). The sounds are made by tools/make_bell_grave_sounds.py.

## The graves of a town's map (the cell of the safety coffin and the middle of the graveyard).
const GRAVES := {"Apfeltal": {"grave": Vector2i(8, 7), "centre": Vector2i(12, 7)}}
const INSCRIPTION := {"name": "Ottilie Wachsam", "text": "Sicher ist sicher: Die Schnur führt zu ihrer Hand."}
const SCREAM := "Du kommst zu spät, ich bin schon tot!"
const WHIMPER := "Du hörst nur ein leises Wimmern..."
## How near (metres) the hero must come to the middle of the graveyard for the bell to ring.
const TRIGGER := 7.0
## The seconds after the ring in which the grave must be reached, and how near (metres) is "at the grave".
const WINDOW := 5.0
const REACH := 2.6
## How loud the ring is (dB): a tiny bell must still be heard from across the graveyard.
const RING_DB := 7.0
## Seconds the bell swings after the ring.
const SWING_TIME := 5.5
## Where the post and the bell stand, from the grave's middle.
const POST_AT := Vector3(-0.95, 0.0, 0.95)
const BELL_HEIGHT := 1.9

var level: Level
var _grave := Vector3.ZERO
var _centre := Vector3.ZERO
var _bell_pivot: Node3D
var _clapper: Node3D
## The night's ring has sounded.
var _rang := false
## Seconds since the ring (-1 before it).
var _since := -1.0
var _answered := false
var _whimpered := false
var _swing := SWING_TIME


## The two cells of a town's safety coffin, empty when it has none.
static func graves_of(town: String) -> Dictionary:
	return GRAVES.get(town, {})


## The inscription of the grave, empty for any other.
static func inscription(c: Vector2i, town: String) -> Dictionary:
	var g := graves_of(town)
	return INSCRIPTION if not g.is_empty() and c == g.grave else {}


func setup(lvl: Level, town: String) -> void:
	level = lvl
	name = "BellGrave"
	var g := graves_of(town)
	_grave = lvl.cell_to_world(g.grave)
	_centre = lvl.cell_to_world(g.centre)
	position = _grave
	_build()


## Whether the bell has rung tonight, and how long ago.
func rang() -> bool:
	return _rang


func since_ring() -> float:
	return _since


## Called every frame from the map with the clock (see Outdoor._process).
func tick(delta: float, hero: Vector3, hour: float) -> void:
	if not DayNight.is_night(hour):
		_rang = false
		_since = -1.0
		_answered = false
		_whimpered = false
		return
	if not _rang:
		if _flat(hero, _centre) <= TRIGGER:
			_ring()
		return
	_since += delta
	if _answered or _whimpered or _flat(hero, _grave) > REACH:
		return
	if _since <= WINDOW:
		_answered = true
		Sfx.play_3d(self, "grave_scream", 3.0, _grave + Vector3(0, 0.3, 0))
		Effects.float_text(level, _grave + Vector3(0, 2.4, 0), Lang.t(SCREAM), Color(1.0, 0.6, 0.6))
		Events.tell(Lang.t(SCREAM), Color(1.0, 0.65, 0.65), 5.0)
		Events.bus().graveyard_riddle.emit(GraveyardRiddles.BELL)
	else:
		_whimpered = true
		Sfx.play_3d(self, "grave_whimper", -2.0, _grave + Vector3(0, 0.3, 0))
		Events.tell(Lang.t(WHIMPER), Color(0.75, 0.78, 0.85), 4.0)


func _ring() -> void:
	_rang = true
	_since = 0.0
	_swing = 0.0
	Sfx.play_3d(self, "bell_tiny", RING_DB, _bell_pivot.global_position if _bell_pivot != null else _grave)


func _process(delta: float) -> void:
	if _bell_pivot == null or _swing >= SWING_TIME:
		return
	_swing += delta
	var fade := exp(-_swing / 1.9)
	_bell_pivot.rotation.z = sin(_swing * 17.0) * 0.55 * fade + sin(_swing * 6.3) * 0.15 * fade
	_bell_pivot.rotation.x = cos(_swing * 11.0) * 0.12 * fade
	if _clapper != null:
		_clapper.rotation.z = -sin(_swing * 17.0 + 0.9) * 0.8 * fade
	if _swing >= SWING_TIME:
		_bell_pivot.rotation = Vector3.ZERO


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- The look ---------------------------------------------------------------------------------

func _build() -> void:
	var wood := _wood_material()
	var post := Node3D.new()
	post.position = POST_AT
	post.rotation.z = 0.025
	add_child(post)
	# The post: a squared timber, its foot sunk in a little earth heap, with a cap.
	post.add_child(_box(Vector3(0.14, 2.15, 0.14), Vector3(0, 1.075, 0), wood))
	post.add_child(_box(Vector3(0.19, 0.05, 0.19), Vector3(0, 2.17, 0), wood))
	post.add_child(_box(Vector3(0.22, 0.09, 0.22), Vector3(0, 0.05, 0), wood))
	# The arm, with a brace under it, holding the bell over the grave.
	var arm_len := absf(POST_AT.x) + 0.05
	post.add_child(_box(Vector3(arm_len + 0.1, 0.09, 0.1), Vector3((arm_len + 0.1) * 0.5 - 0.05, BELL_HEIGHT + 0.12, 0), wood))
	var brace := _box(Vector3(0.65, 0.07, 0.08), Vector3(0.28, BELL_HEIGHT - 0.2, 0), wood)
	brace.rotation.z = 0.78
	post.add_child(brace)
	var iron := _iron_material()
	for y in [0.6, 1.3, 1.95]:
		post.add_child(_box(Vector3(0.16, 0.025, 0.16), Vector3(0, y, 0), iron))
	# The bell hangs from the arm's end on a small hanger, and swings (see _process).
	_bell_pivot = Node3D.new()
	_bell_pivot.position = POST_AT + Vector3(arm_len, BELL_HEIGHT + 0.07, 0)
	add_child(_bell_pivot)
	var hanger := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.012
	tor.outer_radius = 0.032
	hanger.mesh = tor
	hanger.material_override = iron
	hanger.rotation.x = PI / 2.0
	_bell_pivot.add_child(hanger)
	var bell := MeshInstance3D.new()
	bell.mesh = _bell_mesh()
	bell.material_override = _bronze_material()
	bell.position = Vector3(0, -0.27, 0)
	_bell_pivot.add_child(bell)
	_clapper = Node3D.new()
	_clapper.position = Vector3(0, -0.07, 0)
	_bell_pivot.add_child(_clapper)
	var rod := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.004
	rc.bottom_radius = 0.004
	rc.height = 0.15
	rod.mesh = rc
	rod.material_override = iron
	rod.position = Vector3(0, -0.075, 0)
	_clapper.add_child(rod)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.019
	sm.height = 0.038
	ball.mesh = sm
	ball.material_override = iron
	ball.position = Vector3(0, -0.16, 0)
	_clapper.add_child(ball)
	# The cord: from the bell down, a little slack, into an iron pipe in the earth over the coffin.
	var cord := _cord_material()
	var top := Vector3(0, -0.04, 0)
	var pipe_at := _bell_pivot.position + Vector3(0.0, -BELL_HEIGHT - 0.07 + 0.2, 0.0)
	_add_cord(top + _bell_pivot.position, pipe_at, cord)
	var pipe := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.04
	pc.bottom_radius = 0.05
	pc.height = 0.28
	pipe.mesh = pc
	pipe.material_override = iron
	pipe.position = pipe_at + Vector3(0, -0.06, 0)
	add_child(pipe)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.028
	hm.bottom_radius = 0.028
	hm.height = 0.01
	hole.mesh = hm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.01, 0.015)
	hole.material_override = dark
	hole.position = pipe_at + Vector3(0, 0.081, 0)
	add_child(hole)


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = at
	return m


## A slack cord from `from` down to `to` (world-near positions in this node's space): short straight pieces along a
## gentle sag, each a thin tube.
func _add_cord(from: Vector3, to: Vector3, mat: Material) -> void:
	var steps := 12
	var prev := from
	for i in range(1, steps + 1):
		var u := float(i) / steps
		var p := from.lerp(to, u) + Vector3(sin(u * PI) * 0.045, 0.0, sin(u * PI * 2.0) * 0.015)
		var seg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0075
		cm.bottom_radius = 0.0075
		cm.height = prev.distance_to(p)
		cm.radial_segments = 6
		seg.mesh = cm
		seg.material_override = mat
		seg.position = (prev + p) * 0.5
		var dir := (p - prev).normalized()
		seg.basis = Basis(Quaternion(Vector3.UP, dir))
		add_child(seg)
		prev = p


## The bell: a lathe of a profile (radius, height) with a flared lip, two raised bands round the waist and a thick
## crown, outside and inside, with smooth shading.
static func _bell_mesh() -> ArrayMesh:
	var outer := [Vector2(0.112, 0.0), Vector2(0.116, 0.008), Vector2(0.104, 0.022), Vector2(0.096, 0.04), Vector2(0.098, 0.05),
			Vector2(0.092, 0.058), Vector2(0.094, 0.068), Vector2(0.082, 0.09), Vector2(0.066, 0.125), Vector2(0.05, 0.158),
			Vector2(0.036, 0.18), Vector2(0.022, 0.195), Vector2(0.008, 0.2)]
	var inner := [Vector2(0.0, 0.186), Vector2(0.014, 0.18), Vector2(0.03, 0.166), Vector2(0.044, 0.142), Vector2(0.058, 0.11),
			Vector2(0.074, 0.075), Vector2(0.086, 0.04), Vector2(0.092, 0.014), Vector2(0.098, 0.0)]
	var profile: Array = outer + inner
	var seg := 28
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var rings := profile.size()
	for i in rings - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		for k in seg:
			var u0 := float(k) / seg
			var u1 := float(k + 1) / seg
			var a0 := u0 * TAU
			var a1 := u1 * TAU
			var v0 := float(i) / (rings - 1)
			var v1 := float(i + 1) / (rings - 1)
			var p00 := Vector3(cos(a0) * a.x, a.y, sin(a0) * a.x)
			var p10 := Vector3(cos(a1) * a.x, a.y, sin(a1) * a.x)
			var p01 := Vector3(cos(a0) * b.x, b.y, sin(a0) * b.x)
			var p11 := Vector3(cos(a1) * b.x, b.y, sin(a1) * b.x)
			# Both sides are drawn: the bell is a thin shell.
			for tri in [[p00, p10, p01, Vector2(u0, v0), Vector2(u1, v0), Vector2(u0, v1)],
					[p10, p11, p01, Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]]:
				for j in 3:
					st.set_uv(tri[3 + j])
					st.add_vertex(tri[j])
	st.generate_normals()
	return st.commit()


static func _noise_image(w: int, h: int, freq: float, seed_value: int, stretch := Vector2.ONE) -> Array:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 4
	var out := []
	for y in h:
		var row := []
		for x in w:
			row.append(n.get_noise_2d(x * stretch.x, y * stretch.y) * 0.5 + 0.5)
		out.append(row)
	return out


static func _bronze_material() -> StandardMaterial3D:
	var w := 96
	var h := 96
	var a := _noise_image(w, h, 0.07, 31)
	var b := _noise_image(w, h, 0.25, 47)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var patina: float = clampf((a[y][x] - 0.5) * 3.2 + 0.35 + (1.0 - float(y) / h) * 0.15, 0.0, 1.0)
			var metal: Color = Color(0.62, 0.4, 0.17).lerp(Color(0.8, 0.58, 0.28), b[y][x])
			var green: Color = Color(0.2, 0.46, 0.38).lerp(Color(0.38, 0.62, 0.5), b[y][x])
			var streak: float = 0.82 + 0.18 * sin(x * 0.9 + a[y][x] * 6.0)
			img.set_pixel(x, y, metal.lerp(green, patina) * streak)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.metallic = 0.7
	mat.roughness = 0.42
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _wood_material() -> StandardMaterial3D:
	var w := 48
	var h := 160
	var g := _noise_image(w, h, 0.06, 5, Vector2(5.0, 0.35))
	var k := _noise_image(w, h, 0.2, 9, Vector2(1.0, 0.6))
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var grain: float = g[y][x]
			var col: Color = Color(0.2, 0.15, 0.1).lerp(Color(0.46, 0.35, 0.24), grain)
			col = col.lerp(Color(0.5, 0.5, 0.42), clampf((k[y][x] - 0.6) * 1.8, 0.0, 0.5))
			img.set_pixel(x, y, col)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 0.95
	return mat


static func _iron_material() -> StandardMaterial3D:
	var w := 32
	var h := 32
	var a := _noise_image(w, h, 0.18, 77)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var rust: float = clampf((a[y][x] - 0.4) * 2.4, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.16, 0.16, 0.18).lerp(Color(0.42, 0.2, 0.1), rust))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.metallic = 0.5
	mat.roughness = 0.7
	return mat


static func _cord_material() -> StandardMaterial3D:
	var w := 8
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var twist := 0.5 + 0.5 * sin((y + x * 2.0) * 1.1)
			img.set_pixel(x, y, Color(0.3, 0.24, 0.15).lerp(Color(0.62, 0.52, 0.34), twist))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = 1.0
	return mat
