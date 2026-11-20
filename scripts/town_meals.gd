class_name TownMeals
extends RefCounted
## Shared meals on the village square. Long tables with benches and plates of
## food stand on the square (map letter LETTER), and the townsfolk eat there
## together twice a day: lunch around noon and dinner around seven in the
## evening (MEALS). A canopy of striped cloth on posts keeps the rain and the
## snow off each table, and a lantern hangs under it, with two candles on the
## table: they light up at dusk and burn through the night (set_glow).
##
## Nobody comes all at once. When a meal draws near, every villager who goes
## (see goes) is given an hour of their own to arrive, spread round the meal's
## hour (ARRIVE_EARLY, ARRIVE_LATE, averaged from two rolls so most come close
## to the middle). Each one walks over at their hour, takes a free seat, sits
## down and eats for about an hour (SEATED: an hour, give or take a quarter,
## counted from sitting down); they get up one by one and go back to their day. Dinner always ends before the
## village goes to bed (LAST_CALL).
##
## At the table they talk: now and then two who sit at the same table trade a
## short exchange (TABLE_TALK), small talk about the food and the latest
## gossip, one line at a time so the bubbles never cover each other.
##
## Shopkeepers, the elder and the others who keep to a spot stay at their posts
## so the hero can always trade (see Villager.keeps_spot); the children keep
## playing; the woodcutter eats out in the woods.
##
## Seats are handed out by TownMeals, never taken by two: a seat belongs to
## whoever walks to it until they leave or something else (an alarm, the
## herald, nightfall) takes them away (see tick).

## The map letter of a dining table (see Tiles.OUTDOOR).
const LETTER := "π"

## The hours of the meals (see DayNight).
const MEALS := [12.0, 19.0]
## How long before and after a meal's hour the townsfolk set off for the table
## (game hours; an hour is 50 seconds, see DayNight.DAY_LENGTH). They set off a
## little ahead (WALK_AHEAD), so most sit down close to the meal's hour.
const ARRIVE_EARLY := 0.7
const ARRIVE_LATE := 0.5
const WALK_AHEAD := 0.3
## How long each one stays seated and eats (game hours, picked at random
## between the two: an hour, give or take a quarter).
const SEATED := Vector2(0.75, 1.25)
## One who finds no seat or never gets there gives up this long after setting off (game hours).
const GIVE_UP := 1.5
## When the meal is over for everyone, counted from its hour (game hours).
const MEAL_END := 2.2
## Everyone has left the dinner table by then: the village goes to bed at DayNight.NIGHT_FROM.
const LAST_CALL := DayNight.NIGHT_FROM - 0.15
## Who never comes to the table: the woodcutter (out in the woods) and the wandering merchant.
const STAY_AWAY := ["3", "%"]
## The day plans of those who come (see Villager.ROLES): everyone who does not keep a stall or a post.
const PLANS := ["work", "sit", "patrol", "stroll", "carry"]

## The table: the kit's wooden table, a little longer and narrower than in the
## dungeon, with its top at a sitting villager's chest.
const TABLE_SCALE := Vector3(1.6, 1.6, 1.2)
## How far the benches stand from the table's middle line, and how long they are stretched.
const BENCH_OFF := 1.18
const BENCH_STRETCH := 1.7
## Where the seats are along a bench (metres from the table's middle), three to a side.
const SEAT_XS := [-1.1, 0.0, 1.1]
## The table top's height and half its depth (metres), where the plates go.
const TOP := 1.0
const TOP_HALF := 0.78
## How long sitting down and getting up take (seconds; the chair animations).
const SIT_TIME := 0.8

## The canopy over each table: its posts stand just past the ends of the
## benches (x) and beside their backs (z); the cloth runs from the eaves up to a
## ridge along the table and hangs a little past the posts.
const POST_X := 2.35
const POST_Z := 1.8
const EAVE := 2.55
const RIDGE := 3.25
const OVERHANG := 0.25
## The cloth's stripes, how wide each is, and the scalloped edge hanging from the eaves.
const CLOTH := [Color(0.88, 0.82, 0.68), Color(0.68, 0.2, 0.16)]
const STRIPE := 0.55
const VALANCE := 0.28
## How see-through the cloth is: from afar, and with the hero close by, so the
## diners under it stay in view (see _fade_cloth).
const CLOTH_ALPHA := 0.82
const CLOTH_NEAR_ALPHA := 0.35
const CLOTH_NEAR := 9.0
## The lantern under the ridge (its glass, metres above the ground) and how
## brightly it and the candles burn at night (see set_glow).
const LANTERN_Y := 2.15
const LAMP_ENERGY := 2.6
const LAMP_RANGE := 7.5
const FLAME_GLOW := 4.0
## Where the two candles stand on the table (x from its middle).
const CANDLE_XS := [-1.4, 1.4]

## Seconds between two table talks (picked at random), and the pause between two lines.
const TALK_EVERY := Vector2(3.0, 7.0)
const LINE_GAP := 0.5

## Exchanges at the table, said in turn by two who sit at the same table. A
## Dictionary entry names the roles who never take part ("not"), so nobody
## gossips about themselves.
const TABLE_TALK := [
	["Reich mir mal das Brot rüber.", "Nur wenn du mir die Butter lässt."],
	["Noch ein Stück Käse?", "Ich hab schon drei. Na gut, noch eins."],
	["Wer hat eigentlich gekocht?", "Frag lieber nicht. Iss einfach."],
	["Das Brot ist hart wie ein Stein.", "Dann gib es dem Steinmetz. Der freut sich."],
	["Mmh, die Wurst ist frisch.", "Vom Hof hinter dem Teich. Die beste weit und breit."],
	["Iss nicht so schnell, du verschluckst dich noch.", "Die Arbeit wartet nicht.", "Die Arbeit läuft dir auch nicht weg."],
	["Ein Prost auf das Essen!", "Und auf die, die es gekocht hat!"],
	["Finger weg vom Kuchen, der ist für später!", "Ich hab doch nur geschaut."],
	["Die Suppe ist heute richtig gut.", "Endlich hat jemand Salz gefunden."],
	["Gibt's noch Äpfel?", "Nur die Schrumpeligen. Die Guten hat Pip schon stibitzt."],
	["Schon wieder ein Tag vorbei.", "Und morgen fängt alles von vorne an.", "Hauptsache, es gibt wieder Essen."],
	{"not": ["Y"], "lines": ["Hast du gehört? Der Bankier zählt sogar beim Essen seine Münzen.", "Ich hab gesehen, wie er die Erbsen gezählt hat."]},
	["Man sagt, Gorm und Hagen haben sich wieder gestritten.", "Wegen eines Wetzsteins? Schon wieder?", "Die zwei streiten wie ein altes Ehepaar."],
	{"not": ["O", "5"], "lines": ["Die Priesterin war gestern bis spät in der Nacht im Tempel.", "Sie betet für uns alle. Vor allem für Fritz."]},
	{"not": ["M"], "lines": ["Stimmt es, dass Anselm heimlich die Briefe liest?", "Nur die langweiligen, sagt er. Die schreibt er dann spannender."]},
	{"not": ["4"], "lines": ["Die Wache hat letzte Nacht wieder Lichter auf dem Friedhof gesehen.", "Dann iss lieber schnell auf. Bevor es dunkel wird."]},
	["Der Fremde aus der Gruft war wieder unten im Verlies.", "Und kommt jedes Mal hungriger zurück, wette ich."],
	{"not": ["M"], "lines": ["Mira hat einen neuen Verehrer, heißt es.", "Den Postmeister? Der bringt ihr jeden Tag einen Brief.", "Und keiner davon hat eine Marke."]},
	{"not": ["5"], "lines": ["Fritz hat gestern wieder im Wirtshaus gesungen.", "Gesungen? So nennt er das also."]},
]

## Every seat: {"table", "sit" (where the sitter's feet go), "stand" (where they
## step up to it, behind the bench), "front" (the way they face), "taker" (a
## Villager or null)}.
var seats: Array = []
## The middles of the tables (world positions).
var tables: Array = []
## Who comes to the meal now: Villager -> {"arrive", "leave", "last", "sat", "stay" (game hours), "seated"}.
var _plan := {}
## Which meal _plan is for (day * 10 + meal), -1 for none.
var _meal_key := -1
var _rng := RandomNumberGenerator.new()
## The table talk running: {"lines": [[Villager, text], ...], "wait": seconds} or {}.
var _talk := {}
var _talk_in := 0.0
var _turn := 0
## The lanterns' lights, one under every canopy (see set_glow).
var lights: Array[OmniLight3D] = []
var _flames: Array[MeshInstance3D] = []
var _flame_mat: StandardMaterial3D
var _cloth_mat: StandardMaterial3D
## The tiles under the canopies, where no snow settles (see Outdoor's sky mask).
var roofed: Array[Vector2i] = []


func _init() -> void:
	_rng.randomize()
	_talk_in = _rng.randf_range(TALK_EVERY.x, TALK_EVERY.y)


# --- Building -------------------------------------------------------------------

## Builds a table on tile `c` of `level`: the table along the tile's x, a bench
## on each long side turned to it, plates of food, mugs and a bread board on the
## top, and six seats.
func build_table(level: Outdoor, c: Vector2i) -> void:
	var pos := level.cell_to_world(c)
	var node := Node3D.new()
	node.name = "MealTable"
	node.position = pos
	level.add_child(node)
	level._add_kit_part(["SM_WoodenTable", "props", Vector3.ZERO, TABLE_SCALE, 0.0], node)
	for side in [-1.0, 1.0]:
		# The seat of the bench faces its +z: the north bench (side -1) faces south to the table.
		var rot := 0.0 if side < 0.0 else PI
		var bench := level._put("bench", pos + Vector3(0, 0, side * BENCH_OFF), rot, Seats.BENCH_SCALE)
		bench.scale.x = Seats.BENCH_SCALE * BENCH_STRETCH
		var front := Vector3(0, 0, -side)
		var out := Seats.BENCH_SIZE.z * 0.5 + Villager.PASSING_SPACE * 0.6 + Seats.STAND_GAP
		for x: float in SEAT_XS:
			var middle := pos + Vector3(x, 0, side * BENCH_OFF)
			seats.append({"table": tables.size(), "sit": middle + front * Seats.SIT_FORWARD,
					"stand": middle - front * out, "front": front, "taker": null})
	node.add_child(_food_mesh(c))
	# Blocked where the table and its benches stand, so the hero walks round them.
	var depth := (BENCH_OFF + Seats.BENCH_SIZE.z * 0.5) * 2.0
	level._add_box(level._walls_body, pos + Vector3(0, 0.5, 0), Vector3(TABLE_SCALE.x * 2.27, 1.0, depth))
	_build_canopy(level, node, c)
	tables.append(pos)


## The canopy over the table at `c`: four posts, rafters at both ends, a ridge
## pole and eave beams, the striped cloth with its scalloped edge, the lantern
## hanging from the ridge and two candles on the table.
func _build_canopy(level: Outdoor, node: Node3D, c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("canopy|%s" % c)
	var b := WeatheredProps.Builder.new()
	var dark := WeatheredProps.DARK_TIMBER
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(sx * POST_X, 0, sz * POST_Z), Vector3(0.14, EAVE, 0.14), WeatheredProps.vary(WeatheredProps.TIMBER[1], rng),
					WeatheredProps.WOOD, Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)))
			# A rafter from the top of the post up to the ridge.
			b.bar(Vector3(sx * POST_X, EAVE - 0.05, sz * POST_Z), Vector3(sx * POST_X, RIDGE, 0), 0.05, dark, WeatheredProps.WOOD)
		# The eave beam along the posts' tops on this side.
		b.bar(Vector3(-POST_X - 0.1, EAVE - 0.06, sx * POST_Z), Vector3(POST_X + 0.1, EAVE - 0.06, sx * POST_Z), 0.05, dark, WeatheredProps.WOOD)
	b.bar(Vector3(-POST_X - 0.15, RIDGE, 0), Vector3(POST_X + 0.15, RIDGE, 0), 0.06, dark, WeatheredProps.WOOD)
	# The lantern: a short chain from the ridge, then the iron frame round the glass (as VillageProps.build_lamp).
	var lantern := Vector3(0, LANTERN_Y, 0)
	var iron := WeatheredProps.IRON_COLOUR * 0.8
	b.bar(Vector3(0, RIDGE - 0.05, 0), lantern + Vector3(0, 0.36, 0), 0.015, WeatheredProps.IRON_COLOUR, WeatheredProps.IRON, 4)
	b.frustum(lantern + Vector3(0, -0.26, 0), Vector2(0.18, 0.18), Vector2(0.3, 0.3), 0.06, iron, WeatheredProps.IRON)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		b.box(lantern + Vector3(corner.x * 0.13, -0.2, corner.y * 0.13), Vector3(0.03, 0.36, 0.03), iron, WeatheredProps.IRON)
	b.frustum(lantern + Vector3(0, 0.16, 0), Vector2(0.34, 0.34), Vector2(0.06, 0.06), 0.18, iron, WeatheredProps.IRON)
	b.cylinder(lantern + Vector3(0, 0.34, 0), 0.04, 0.04, 0.05, iron, WeatheredProps.IRON, 6)
	# Two candles in iron holders on the table.
	for x: float in CANDLE_XS:
		b.cylinder(Vector3(x, TOP, 0), 0.07, 0.05, 0.03, iron, WeatheredProps.IRON, 8)
		b.cylinder(Vector3(x, TOP + 0.03, 0), 0.025, 0.025, 0.16, Color(0.95, 0.92, 0.82), WeatheredProps.FRESH, 8)
	var frame := b.finish(node)
	frame.name = "Canopy"
	var glass := MeshInstance3D.new()
	var pane := BoxMesh.new()
	pane.size = Vector3(0.24, 0.34, 0.24)
	glass.mesh = pane
	glass.material_override = level._lantern_panes()
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.position = lantern - Vector3(0, 0.03, 0)
	node.add_child(glass)
	node.add_child(_cloth_mesh())
	var light := OmniLight3D.new()
	light.name = "TableLight"
	light.light_color = Color(1.0, 0.74, 0.48)
	light.light_energy = 0.0
	light.omni_range = LAMP_RANGE
	light.omni_attenuation = 1.6
	light.position = lantern - Vector3(0, 0.1, 0)
	light.visible = false
	node.add_child(light)
	lights.append(light)
	if _flame_mat == null:
		_flame_mat = StandardMaterial3D.new()
		_flame_mat.albedo_color = Color(1.0, 0.8, 0.5)
		_flame_mat.emission_enabled = true
		_flame_mat.emission = Color(1.0, 0.7, 0.35)
		_flame_mat.emission_energy_multiplier = 0.0
	var spots: Array[Vector3] = [lantern - Vector3(0, 0.05, 0)]
	for x: float in CANDLE_XS:
		spots.append(Vector3(x, TOP + 0.23, 0))
	for at in spots:
		var flame := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.03
		ball.height = 0.1
		flame.mesh = ball
		flame.material_override = _flame_mat
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = at
		flame.visible = false
		node.add_child(flame)
		_flames.append(flame)
	# The posts are solid, thin as they are drawn.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			level._add_solid(node.position + Vector3(sx * POST_X, 0, sz * POST_Z), Vector3(0.22, EAVE, 0.22))
	# No snow settles on the ground under the cloth (see SnowCover.set_sky_mask).
	roofed.append(c)


## The canopy's cloth: two slopes from the eaves up to the ridge in stripes
## running down the slope, and a scalloped edge hanging from both eaves. All
## the tables share one material, which fades while the hero is near (see _fade_cloth).
func _cloth_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := POST_X + OVERHANG
	var count := int(ceil(half * 2.0 / STRIPE))
	var width := half * 2.0 / count
	# Past the eave beams the cloth runs on down the same slope.
	var drop := (RIDGE - EAVE) / POST_Z * OVERHANG
	var eave_y := EAVE + 0.02 - drop
	var top := RIDGE + 0.07
	for side in [-1.0, 1.0]:
		var eave_z: float = side * (POST_Z + OVERHANG)
		var n := Vector3(0, POST_Z, side * (RIDGE - EAVE)).normalized()
		var out := Vector3(0, 0, side)
		for i in count:
			var x0 := -half + i * width
			var x1 := x0 + width
			var mid := (x0 + x1) * 0.5
			st.set_color(CLOTH[i % 2])
			st.set_normal(n)
			for v in [Vector3(x0, eave_y, eave_z), Vector3(x1, eave_y, eave_z), Vector3(x1, top, 0),
					Vector3(x0, eave_y, eave_z), Vector3(x1, top, 0), Vector3(x0, top, 0)]:
				st.add_vertex(v)
			# The scalloped edge: a flap hanging from the eave, its lower edge in a point.
			st.set_color(CLOTH[(i + 1) % 2])
			st.set_normal(out)
			var low := eave_y - VALANCE * 0.6
			for v in [Vector3(x0, eave_y, eave_z), Vector3(x1, eave_y, eave_z), Vector3(x1, low, eave_z),
					Vector3(x0, eave_y, eave_z), Vector3(x1, low, eave_z), Vector3(mid, eave_y - VALANCE, eave_z),
					Vector3(x0, eave_y, eave_z), Vector3(mid, eave_y - VALANCE, eave_z), Vector3(x0, low, eave_z)]:
				st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "Cloth"
	mi.mesh = st.commit()
	if _cloth_mat == null:
		_cloth_mat = StandardMaterial3D.new()
		_cloth_mat.vertex_color_use_as_albedo = true
		_cloth_mat.roughness = 0.95
		_cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cloth_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		_cloth_mat.albedo_color = Color(1, 1, 1, CLOTH_ALPHA)
	mi.material_override = _cloth_mat
	# Snow lies on the ground round it, not as the overlay's flat white on the cloth.
	mi.set_meta("no_snow", true)
	return mi


## Lights the lanterns and candles for the glow of the hour (0 by day, 1 at
## night, see DayNight.glow_at): they light up as dusk falls (see Outdoor.set_hour).
func set_glow(glow: float) -> void:
	var lit := smoothstep(0.05, 0.4, glow)
	for light in lights:
		light.light_energy = LAMP_ENERGY * lit
		light.visible = lit > 0.01
	if _flame_mat:
		_flame_mat.emission_energy_multiplier = FLAME_GLOW * lit
	for flame in _flames:
		flame.visible = lit > 0.01


## Whether a table's burning lantern lights `pos` within `reach` metres (see Outdoor.is_lit).
func lights_up(pos: Vector3, reach: float) -> bool:
	for light in lights:
		if light.visible and Vector2(pos.x - light.global_position.x, pos.z - light.global_position.z).length() < reach:
			return true
	return false


## Fades the cloth while the hero is near a table, so the diners under it stay in view.
func _fade_cloth(level: Outdoor, delta: float) -> void:
	if _cloth_mat == null or level.player == null:
		return
	var near := false
	var hero: Vector3 = level.player.global_position
	for t: Vector3 in tables:
		if Vector2(hero.x - t.x, hero.z - t.z).length() < CLOTH_NEAR:
			near = true
			break
	_cloth_mat.albedo_color.a = move_toward(_cloth_mat.albedo_color.a, CLOTH_NEAR_ALPHA if near else CLOTH_ALPHA, delta * 1.5)


## Plates of food in front of every seat, mugs beside them and a bread board
## and a fruit bowl down the middle: one mesh with vertex colours.
func _food_mesh(c: Vector2i) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("meal|%s" % c)
	var parts := []
	for side in [-1.0, 1.0]:
		for x: float in SEAT_XS:
			var at := Vector3(x + rng.randf_range(-0.08, 0.08), TOP, side * (TOP_HALF - 0.28))
			_plate(parts, at, rng)
			# A mug to the right of the plate.
			var mug_at := at + Vector3(0.32 * -side, 0, side * -0.12)
			parts.append([_cylinder(0.075, 0.07, 0.18), Transform3D(Basis(), mug_at + Vector3(0, 0.09, 0)), Color(0.45, 0.3, 0.18)])
			parts.append([_cylinder(0.062, 0.062, 0.01), Transform3D(Basis(), mug_at + Vector3(0, 0.175, 0)), Color(0.85, 0.7, 0.35)])
	# Down the middle: a bread board with a loaf, a bowl of apples and a round cheese.
	parts.append([_box(Vector3(0.6, 0.04, 0.3)), Transform3D(Basis(Vector3.UP, 0.1), Vector3(-0.6, TOP + 0.02, 0)), Color(0.62, 0.45, 0.28)])
	parts.append([_ball(0.13, 0.09), Transform3D(Basis().scaled(Vector3(1.8, 1, 1)), Vector3(-0.62, TOP + 0.1, 0)), Color(0.72, 0.48, 0.22)])
	parts.append([_cylinder(0.22, 0.14, 0.12), Transform3D(Basis(), Vector3(0.55, TOP + 0.06, 0)), Color(0.55, 0.38, 0.22)])
	for i in 5:
		var a := TAU * i / 5.0
		parts.append([_ball(0.06, 0.06), Transform3D(Basis(), Vector3(0.55 + cos(a) * 0.1, TOP + 0.15, sin(a) * 0.1)),
				Color(0.75, 0.12, 0.1) if i % 2 == 0 else Color(0.55, 0.7, 0.2)])
	parts.append([_cylinder(0.16, 0.16, 0.1), Transform3D(Basis(), Vector3(0.0, TOP + 0.05, 0.05)), Color(0.93, 0.78, 0.35)])
	var mi := MeshInstance3D.new()
	mi.name = "Food"
	mi.mesh = _merge(parts)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.75
	mi.material_override = mat
	return mi


## A plate at `at` with one dish on it: a stew, a sausage with bread, a roast leg or cheese and apple.
func _plate(parts: Array, at: Vector3, rng: RandomNumberGenerator) -> void:
	parts.append([_cylinder(0.17, 0.14, 0.025), Transform3D(Basis(), at + Vector3(0, 0.0125, 0)), Color(0.9, 0.87, 0.78)])
	var top := at + Vector3(0, 0.025, 0)
	match rng.randi() % 4:
		0:
			# A bowl of stew.
			parts.append([_cylinder(0.11, 0.07, 0.07), Transform3D(Basis(), top + Vector3(0, 0.035, 0)), Color(0.5, 0.33, 0.2)])
			parts.append([_cylinder(0.095, 0.095, 0.01), Transform3D(Basis(), top + Vector3(0, 0.068, 0)), Color(0.6, 0.32, 0.12)])
		1:
			# A sausage and a slice of bread.
			parts.append([_capsule(0.035, 0.2), Transform3D(Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, rng.randf() * TAU), top + Vector3(0, 0.035, 0)), Color(0.55, 0.25, 0.15)])
			parts.append([_box(Vector3(0.11, 0.03, 0.09)), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), top + Vector3(0.06, 0.015, 0.05)), Color(0.82, 0.62, 0.38)])
		2:
			# A roast leg.
			parts.append([_ball(0.07, 0.05), Transform3D(Basis().scaled(Vector3(1.4, 1, 1)), top + Vector3(0, 0.04, 0)), Color(0.6, 0.35, 0.16)])
			parts.append([_cylinder(0.015, 0.015, 0.12), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), top + Vector3(0.12, 0.04, 0)), Color(0.93, 0.9, 0.82)])
		_:
			# A wedge of cheese and an apple.
			parts.append([_box(Vector3(0.1, 0.06, 0.07)), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), top + Vector3(-0.03, 0.03, 0)), Color(0.95, 0.8, 0.3)])
			parts.append([_ball(0.045, 0.045), Transform3D(Basis(), top + Vector3(0.07, 0.045, 0.03)), Color(0.75, 0.12, 0.1)])


static func _cylinder(top: float, bottom: float, height: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 12
	m.rings = 1
	return m


static func _ball(radius: float, height: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m


static func _capsule(radius: float, height: float) -> Mesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 8
	m.rings = 2
	return m


static func _box(size: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## All `parts` ([mesh, transform, colour]) in one mesh, coloured by vertex.
static func _merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part in parts:
		var arrays: Array = (part[0] as Mesh).surface_get_arrays(0)
		var xf: Transform3D = part[1]
		var base := verts.size()
		var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in pv.size():
			verts.append(xf * pv[i])
			normals.append((xf.basis * pn[i]).normalized())
			colors.append(part[2])
		for i: int in arrays[Mesh.ARRAY_INDEX]:
			indices.append(base + i)
	var all := []
	all.resize(Mesh.ARRAY_MAX)
	all[Mesh.ARRAY_VERTEX] = verts
	all[Mesh.ARRAY_NORMAL] = normals
	all[Mesh.ARRAY_COLOR] = colors
	all[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, all)
	return mesh


# --- Meal times -----------------------------------------------------------------

## Whether `v` comes to the shared meals at all.
static func goes(v: Villager) -> bool:
	return v.meal_plan() in PLANS and not v.role in STAY_AWAY and v.radius >= 0.45


## The meal whose time it is at `hour` (its index in MEALS), or -1: from the
## first arrival until the last one has left.
static func meal_at(hour: float) -> int:
	for i in MEALS.size():
		var m: float = MEALS[i]
		if hour >= m - WALK_AHEAD - ARRIVE_EARLY and hour < minf(m + MEAL_END, LAST_CALL if m >= 18.0 else 24.0):
			return i
	return -1


## An arrival and a leaving hour for one villager at the meal at `centre`, never
## before `now` (a village entered in the middle of a meal still fills slowly).
func plan_for(centre: float, now: float) -> Dictionary:
	# The mean of two rolls: most come close to the meal's hour, a few early or late.
	var arrive := centre - WALK_AHEAD + (_rng.randf_range(-ARRIVE_EARLY, ARRIVE_LATE) + _rng.randf_range(-ARRIVE_EARLY, ARRIVE_LATE)) * 0.5
	if arrive < now:
		arrive = now + _rng.randf_range(0.0, 0.35)
	var last := minf(LAST_CALL - _rng.randf_range(0.0, 0.1) if centre >= 18.0 else 24.0, centre + MEAL_END - 0.05)
	return {"arrive": arrive, "leave": minf(arrive + GIVE_UP, last), "last": last, "seated": false, "sat": -1.0,
			"stay": _rng.randf_range(SEATED.x, SEATED.y)}


## Runs the meals on `level`: plans who comes when a meal draws near, sends
## them to their seats at their hour, sends them off at theirs, and keeps the
## table talk going.
func tick(level: Outdoor, delta: float) -> void:
	if seats.is_empty() or level.hour < 0.0:
		return
	_fade_cloth(level, delta)
	_check_seats()
	var meal := meal_at(level.hour)
	if meal < 0:
		if not _plan.is_empty():
			for v in _plan.keys():
				if is_instance_valid(v) and v.dines():
					v.leave_meal()
			_plan.clear()
		_meal_key = -1
		return
	var key: int = level.day * 10 + meal
	if key != _meal_key:
		_meal_key = key
		_plan.clear()
		for v: Villager in level.villagers:
			if goes(v):
				_plan[v] = plan_for(MEALS[meal], level.hour)
	var alarm: bool = level.village_alarm.raised
	for v in _plan.keys():
		if not is_instance_valid(v):
			_plan.erase(v)
			continue
		var p: Dictionary = _plan[v]
		if p.seated and not v.dines():
			# Called away on the way or from the table (a fright, the herald): back again later.
			p.seated = false
			p.sat = -1.0
		if p.sat < 0.0 and v.seated_at_meal():
			# The hour at the table counts from sitting down: a long walk over does not cut it short.
			p.sat = level.hour
			p.leave = minf(p.sat + p.stay, p.last)
		if level.hour >= p.leave:
			if v.dines():
				v.leave_meal()
			_plan.erase(v)
		elif not p.seated and level.hour >= p.arrive and not alarm and v.can_go_to_meal():
			var seat := free_seat(level.player.global_position if level.player else Vector3.INF)
			if seat.is_empty():
				continue
			seat.taker = v
			p.seated = true
			v.go_to_meal(seat)
	_table_talk(delta)


## A seat nobody has, by preference next to someone already eating, so the
## tables fill up in company. {} when the tables are full.
func free_seat(_near := Vector3.INF) -> Dictionary:
	var free := []
	var social := []
	for i in seats.size():
		var s: Dictionary = seats[i]
		if s.taker != null:
			continue
		free.append(s)
		for j in [i - 1, i + 1, i - 3, i + 3]:
			if j >= 0 and j < seats.size() and seats[j].table == s.table and seats[j].taker != null:
				social.append(s)
				break
	if free.is_empty():
		return {}
	var pick: Array = social if not social.is_empty() and _rng.randf() < 0.7 else free
	return pick[_rng.randi() % pick.size()]


## Seats whose taker was called away (an alarm, the herald, nightfall) or is gone are free again.
func _check_seats() -> void:
	for s: Dictionary in seats:
		var v = s.taker
		if v == null:
			continue
		if not is_instance_valid(v) or not v.dines() or v.meal_seat != s:
			if is_instance_valid(v) and v.meal_seat == s:
				v.forget_meal()
			s.taker = null


## Everyone sitting at the table right now.
func seated() -> Array:
	var out := []
	for s: Dictionary in seats:
		if s.taker != null and is_instance_valid(s.taker) and s.taker.seated_at_meal():
			out.append(s.taker)
	return out


## Two at the same table now and then trade a few lines (TABLE_TALK), one at a time.
func _table_talk(delta: float) -> void:
	if not _talk.is_empty():
		_run_talk(delta)
		return
	_talk_in -= delta
	if _talk_in > 0.0:
		return
	_talk_in = _rng.randf_range(TALK_EVERY.x, TALK_EVERY.y)
	var pairs := []
	for a: Dictionary in seats:
		for b: Dictionary in seats:
			if a == b or a.table != b.table or a.taker == null or b.taker == null:
				continue
			if is_instance_valid(a.taker) and is_instance_valid(b.taker) and a.taker.seated_at_meal() and b.taker.seated_at_meal():
				pairs.append([a.taker, b.taker])
	if pairs.is_empty():
		return
	var pair: Array = pairs[_rng.randi() % pairs.size()]
	var lines := exchange_for(pair[0].role, pair[1].role)
	if lines.is_empty():
		return
	var said := []
	for i in lines.size():
		said.append([pair[i % 2], lines[i]])
	_talk = {"lines": said, "wait": 0.0}


## The next exchange for two at the table (roles `a` and `b`): German lines, said in turn.
func exchange_for(a: String, b: String) -> Array:
	var options := []
	for entry in TABLE_TALK:
		var lines: Array = entry.lines if entry is Dictionary else entry
		var left_out: Array = entry.get("not", []) if entry is Dictionary else []
		if not (a in left_out or b in left_out):
			options.append(lines)
	if options.is_empty():
		return []
	_turn += 1 + _rng.randi() % 3
	return options[_turn % options.size()]


func _run_talk(delta: float) -> void:
	_talk.wait -= delta
	if _talk.wait > 0.0:
		return
	var lines: Array = _talk.lines
	if lines.is_empty():
		_talk = {}
		return
	var speaker = lines[0][0]
	if not is_instance_valid(speaker) or not speaker.seated_at_meal():
		_talk = {}
		return
	# A line still being read nearby (the partner's, or someone talking to the hero) is not cut short.
	if speaker.is_talking() or speaker.talker_near() != null:
		return
	var text: String = lines.pop_front()[1]
	var time := VillageTalk.line_time(text)
	speaker.say(Lang.t(text), Vector3.INF, time)
	_talk.wait = time + LINE_GAP
