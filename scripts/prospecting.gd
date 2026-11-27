class_name Prospecting
extends RefCounted
## Prospecting: the way to the hero's own mine. The Crown Prospector (see Prospector) sells a probe bucket
## (BUCKET). With it in hand (key 4, HOLD_KEY) the hero takes a sample of the ground under their feet (key 5,
## DIG_KEY), or runs into a mountain and is asked whether to take a sample of the rock there (see
## Game._on_player_bumped, ask_window). The bucket then holds the sample (FULL, one at a time) and must be
## handed to the prospector, who analyses it (see ProspectGeology.analyse) and puts a mark on the hero's map
## at the exact spot with what he found (see MapView), and a stake with a ribbon in the ore's colour in the
## world.
##
## The marks are what the hero keeps: later they lead to the Crown's land register, where a mining plot over
## a good mark can be claimed. Saved as "prospecting": {held, sample, marks}.

## The probe bucket, empty and full (items, see Items.ALL).
const BUCKET := "probeneimer"
const FULL := "probeneimer_voll"
const ITEMS := [BUCKET, FULL]
const PRICE := 30
## The keys: bucket in hand or away, and the ground sample.
const HOLD_KEY := "4"
const DIG_KEY := "5"
## Seconds the hero digs for a sample, and how long a mountain's refusal to be asked again lasts.
const DIG_TIME := 1.3
const ASK_QUIET := 1.2
## The most marks the map keeps, one letter each, A to Z (the oldest go first).
const MAX_MARKS := 26
## The window asking whether to take a mountain sample.
const ASK_KIND := "probe_frage"

const STAKE_COLORS := ProspectGeology.ORE_COLORS

## Explained in the compendium the first time the bucket is taken in hand.
const LEARN := "Prospektieren: Kauf beim Kronprospektor einen Probeneimer und nimm ihn in die Hand (Taste 4). Mit Taste 5 schöpfst du eine Bodenprobe, und wer mit dem Eimer in der Hand gegen einen Berg läuft, wird gefragt, ob er dort eine Probe nehmen will. Den vollen Eimer bringst du zum Kronprospektor: Er untersucht die Probe und trägt das Ergebnis mit dem genauen Ort in deine Karte ein. Rostflecken, Grünspan, Bleiglanz, Glimmer und Olivin verraten das Erz, Pyrit ist nur Katzengold, und Leuchtstaub oder Sternenstaub deuten auf Seltenes."

var game: Node
## Whether the bucket is in the hero's hand.
var held := false
## The sample in the bucket ({} when it is empty).
var sample := {}
## The marks on the map, oldest first (see mark_from).
var marks: Array = []
## True while the hero is digging, and the time a refusal of the question lasts out.
var digging := false
var _quiet_until := 0
var _bucket_model: Node3D


func _init(owner_game: Node = null) -> void:
	game = owner_game


func clear() -> void:
	held = false
	sample = {}
	marks = []
	digging = false
	_drop_model()


# --- The bucket ----------------------------------------------------------------------------------

## Which bucket the hero carries: FULL, BUCKET or "".
func bucket_id() -> String:
	if game == null or game.player == null:
		return ""
	if game.player.bag.has(FULL):
		return FULL
	return BUCKET if game.player.bag.has(BUCKET) else ""


func has_bucket() -> bool:
	return bucket_id() != ""


func is_full() -> bool:
	return bucket_id() == FULL and not sample.is_empty()


## Whether the hero holds an empty bucket, ready to take a sample.
func ready() -> bool:
	return held and has_bucket() and not is_full()


## Key 4: the bucket in the hand or away again. Returns why not ("" when it worked).
func toggle() -> String:
	if game == null or game.player == null or not game.player.can_act():
		return ""
	if held:
		held = false
		_drop_model()
		return Lang.t("Du steckst den Probeneimer weg.")
	if not has_bucket():
		return Lang.t("Du hast keinen Probeneimer. (Der Kronprospektor verkauft ihn.)")
	held = true
	_make_model()
	Events.teach(LEARN)
	if is_full():
		return Lang.t("Du nimmst den vollen Probeneimer in die Hand. Bring ihn zum Kronprospektor.")
	return Lang.t("Du nimmst den Probeneimer in die Hand. Taste 5: Bodenprobe hier, oder gegen einen Berg laufen.")


## Why the hero cannot take a sample here ("" when they can).
func why_not() -> String:
	if game == null or game.player == null or not game.player.can_act():
		return "-"
	if not held or not has_bucket():
		return Lang.t("Nimm erst den Probeneimer in die Hand (Taste 4).")
	if is_full():
		return Lang.t("Der Eimer ist voll. Bring ihn zum Kronprospektor.")
	if not (game.level is Outdoor) or game._indoors():
		return Lang.t("Proben nimmt man nur im Freien.")
	if digging:
		return "-"
	return ""


## Key 5: a sample of the ground under the hero's feet. Returns the message when it does not work.
func dig_here() -> String:
	var why := why_not()
	if why != "":
		return why
	var cell: Vector2i = game.level.world_to_cell(game.player.global_position)
	if Mountains.is_rock(game.level, cell):
		return Lang.t("Hier ist Fels: Lauf gegen den Berg, um eine Probe zu nehmen.")
	_take(cell, ProspectGeology.GROUND)
	return ""


## The hero ran into a point of the world: a mountain there asks whether to take a sample. True when the
## question was asked (the bump is used up).
func bumped(point: Vector3) -> bool:
	if not ready() or game.level == null or not (game.level is Outdoor) or digging:
		return false
	var cell: Vector2i = game.level.world_to_cell(point)
	if not Mountains.is_rock(game.level, cell):
		return false
	if Time.get_ticks_msec() < _quiet_until or why_not() != "":
		return true
	game.player.path.clear()
	pending_cell = cell
	game.menus.open(ASK_KIND)
	return true


## The rock tile the question is about.
var pending_cell := Vector2i.ZERO


func decline() -> void:
	_quiet_until = Time.get_ticks_msec() + int(ASK_QUIET * 1000.0)


## Takes the sample (a short dig), fills the bucket and tells the hero.
func _take(cell: Vector2i, source: String) -> void:
	digging = true
	game.player.path.clear()
	game.player.velocity = Vector3.ZERO
	var at: Vector3 = game.player.global_position
	game.player.play_once("Interact", DIG_TIME)
	Sfx.play(game, "rummage", -4.0, at)
	await game.get_tree().create_timer(DIG_TIME * 0.5).timeout
	Sfx.play(game, "word_klack", -6.0, at, 1.2)
	await game.get_tree().create_timer(DIG_TIME * 0.5).timeout
	digging = false
	if game.state != game.State.PLAYING or not has_bucket() or is_full():
		return
	sample = ProspectGeology.sample(cell, source)
	sample["at"] = [at.x, at.z]
	sample["file"] = game.journal.current_file()
	var i: int = game.player.bag.find(BUCKET)
	if i >= 0:
		game.player.bag[i] = FULL
	Effects.loot_text(game.level, at + Vector3(0, 1.8, 0), Lang.t("Probe genommen"), ProspectGeology.ROCK_COLORS[sample.main], 1.0)
	game.show_message(Lang.t("Der Eimer ist voll: %s. Bring ihn zum Kronprospektor.") % _what(sample), 3.2)
	game._update_hud()


static func _what(s: Dictionary) -> String:
	return Lang.t("Bodenprobe") if str(s.source) == ProspectGeology.GROUND else Lang.t("Bergprobe")


## The window's yes: take the mountain sample.
func accept() -> void:
	if ready():
		_take(pending_cell, ProspectGeology.MOUNTAIN)


# --- The prospector's part ---------------------------------------------------------------------------

## Buys the bucket. Returns why not ("" when bought).
func buy() -> String:
	if has_bucket():
		return Lang.t("Du hast schon einen Probeneimer.")
	if not Payment.can_pay(game, PRICE):
		return Lang.t("Dafür reicht dein Kupfer nicht.")
	if not game.player.bag_fits(BUCKET):
		return Lang.t("Deine Tasche ist voll.")
	Payment.pay(game, PRICE)
	game.player.bag.append(BUCKET)
	Events.bus().traded.emit(Prospector.ROLE)
	return ""


## Hands the full bucket over: the prospector analyses the sample and puts a mark on the map. Returns the
## mark ({} when there was nothing to hand over).
func deliver() -> Dictionary:
	if not is_full():
		return {}
	var mark := mark_from(sample)
	mark["day"] = game.day
	# One mark per spot: a second sample of the same place replaces the first.
	marks = marks.filter(func(m: Dictionary) -> bool: return not (m.file == mark.file and m.cell == mark.cell and m.source == mark.source))
	marks.append(mark)
	while marks.size() > MAX_MARKS:
		marks.pop_front()
	var i: int = game.player.bag.find(FULL)
	if i >= 0:
		game.player.bag[i] = BUCKET
	sample = {}
	if game.level is Outdoor:
		build_stake(game.level, mark)
	game.journal.write("Prospektor: %s", [report_text(mark.report)], str(mark.file))
	Events.tell(Lang.t("Brandt trägt die Stelle in deine Karte ein: %s") % report_text(mark.report), STAKE_COLORS.get(str(mark.report.ore), Color.WHITE))
	return mark


## A mark from a sample: where it was taken, the sample and the prospector's report.
static func mark_from(s: Dictionary) -> Dictionary:
	return {
		"file": str(s.get("file", "")), "cell": [int(s.cell[0]), int(s.cell[1])], "source": str(s.source),
		"at": s.get("at", [float(s.cell[0]) * Level.TILE, float(s.cell[1]) * Level.TILE]),
		"sample": s, "report": ProspectGeology.analyse(s), "day": 0,
	}


## What the prospector says about a report, in one line.
static func report_text(r: Dictionary) -> String:
	var ore := str(r.ore)
	if ore == "":
		return Lang.t("Taubes Gestein: hier lohnt kein Stollen.")
	var out := "%s: %s, %s" % [Lang.t(ProspectGeology.ORES[ore]), Lang.t(CHANCE_TEXT[str(r.chance)]), Lang.t(RICH_TEXT[str(r.richness)])]
	if str(r.also) != "":
		out += ". " + Lang.t("Dazu vielleicht %s") % Lang.t(ProspectGeology.ORES[str(r.also)])
	if str(r.warn) == ProspectGeology.DECOY:
		out += ". " + Lang.t("Vorsicht: Pyrit ist Katzengold.")
	if bool(r.deeper):
		out += ". " + Lang.t("Das Erz liegt tiefer, unter Verwitterungsschutt.")
	return out


const CHANCE_TEXT := {"sicher": "sehr wahrscheinlich", "vielleicht": "möglich", "spur": "nur eine Spur"}
const RICH_TEXT := {"arm": "arme Ader", "mittel": "gute Ader", "reich": "reiche Ader"}


## The composition of a sample as one line: "Basalt 68 %, Grünspan 8 %, ...".
static func composition_text(s: Dictionary) -> String:
	var parts: Array[String] = []
	for entry in ProspectGeology.composition(s):
		parts.append("%s %d %%" % [Lang.t(str(entry[0])), int(entry[1])])
	return ", ".join(parts)


## The letter of the i-th mark on a map (A, B, C ...).
static func letter(i: int) -> String:
	return char(65 + i % 26)


## One short line for the map's legend: "Gold, reiche Ader (Bodenprobe)".
static func legend_text(m: Dictionary) -> String:
	var r: Dictionary = m.report
	var what := _what(m.sample)
	if str(r.ore) == "":
		return "%s (%s)" % [Lang.t("Taubes Gestein"), what]
	return "%s: %s, %s (%s)" % [Lang.t(ProspectGeology.ORES[str(r.ore)]), Lang.t(CHANCE_TEXT[str(r.chance)]), Lang.t(RICH_TEXT[str(r.richness)]), what]


## The marks on a level file, for the map.
func marks_on(file: String) -> Array:
	return marks.filter(func(m: Dictionary) -> bool: return m.file == file)


# --- In the world ---------------------------------------------------------------------------------------

## A stake with a ribbon in the ore's colour, where the sample was taken.
static func build_stake(level: Level, mark: Dictionary) -> void:
	var at: Array = mark.at
	var key := "stake_%d_%d_%s" % [int(mark.cell[0]), int(mark.cell[1]), mark.source]
	var old := level.get_node_or_null(key)
	if old != null:
		old.queue_free()
	var root := Node3D.new()
	root.name = key
	root.add_to_group("prospect_stakes")
	level.add_child(root)
	root.position = Vector3(float(at[0]), 0.0, float(at[1]))
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.28, 0.16)
	wood.roughness = 0.95
	var pole := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.035
	rod.bottom_radius = 0.05
	rod.height = 1.2
	rod.radial_segments = 8
	pole.mesh = rod
	pole.material_override = wood
	pole.position = Vector3(0, 0.6, 0)
	root.add_child(pole)
	var ribbon := MeshInstance3D.new()
	var cloth := BoxMesh.new()
	cloth.size = Vector3(0.38, 0.22, 0.02)
	ribbon.mesh = cloth
	var colour := StandardMaterial3D.new()
	colour.albedo_color = STAKE_COLORS.get(str(mark.report.ore), Color(0.6, 0.6, 0.6))
	colour.roughness = 0.8
	colour.cull_mode = BaseMaterial3D.CULL_DISABLED
	ribbon.material_override = colour
	ribbon.position = Vector3(0.21, 1.05, 0)
	ribbon.rotation_degrees = Vector3(0, 0, -8)
	root.add_child(ribbon)
	var cairn := MeshInstance3D.new()
	var stones := CylinderMesh.new()
	stones.top_radius = 0.1
	stones.bottom_radius = 0.2
	stones.height = 0.14
	stones.radial_segments = 7
	cairn.mesh = stones
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.5, 0.48, 0.45)
	grey.roughness = 1.0
	cairn.material_override = grey
	cairn.position = Vector3(0, 0.07, 0)
	root.add_child(cairn)


## Puts the stakes of the marks of this level into the world (after the level is built).
func build_stakes(level: Level) -> void:
	if not (level is Outdoor):
		return
	for m: Dictionary in marks_on(game.journal.current_file()):
		build_stake(level, m)


# --- The bucket in the hand ------------------------------------------------------------------------------

func _make_model() -> void:
	_drop_model()
	if game == null or game.player == null:
		return
	var hand: Node3D = game.player.find_child("handslot_l", true, false)
	if hand == null:
		return
	var scene: PackedScene = load("res://assets/village/bucket_water.gltf")
	if scene == null:
		return
	_bucket_model = Node3D.new()
	_bucket_model.name = "ProbeBucket"
	var body: Node3D = scene.instantiate()
	body.scale = Vector3.ONE * 0.9
	body.position = Vector3(0, -0.28, 0)
	_bucket_model.add_child(body)
	hand.add_child(_bucket_model)


func _drop_model() -> void:
	if is_instance_valid(_bucket_model):
		_bucket_model.queue_free()
	_bucket_model = null


## Keeps the model true to the state: gone when the bucket is away or lost.
func tick() -> void:
	if held and not has_bucket():
		held = false
		_drop_model()


# --- The window of the question ------------------------------------------------------------------------------

## "Take a sample of the mountain here?" with Yes and No.
static func build_ask(menus: Menus) -> void:
	var game: Node = menus.game
	menus._add_label(Lang.t("Bergprobe"), 38, game.GOLD, game.TITLE_FONT)
	var text: Label = menus._add_label(Lang.t("Möchtest du hier am Berg eine Probe nehmen? Der Eimer wird mit Gestein gefüllt."), 20, Color.WHITE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(ASK_SIZE.x - 80.0, 80.0)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	menus._box.add_child(row)
	var yes: Button = menus._item_button(Lang.t("Probe nehmen"), func():
		menus.close()
		game.prospecting.accept())
	yes.custom_minimum_size = Vector2(240, 54)
	row.add_child(yes)
	var no: Button = menus._item_button(Lang.t("Lieber nicht"), func():
		game.prospecting.decline()
		menus.close())
	no.custom_minimum_size = Vector2(240, 54)
	row.add_child(no)


const ASK_SIZE := Vector2(620, 250)


# --- Saved game ---------------------------------------------------------------------------------------------------

func for_save() -> Dictionary:
	return {"held": held, "sample": sample.duplicate(true), "marks": marks.duplicate(true)}


func load_from(data) -> void:
	clear()
	if not (data is Dictionary):
		return
	held = bool(data.get("held", false))
	var s = data.get("sample", {})
	if s is Dictionary and s.has("main") and s.has("cell"):
		sample = _clean(s)
	var list = data.get("marks", [])
	if list is Array:
		for m in list:
			if m is Dictionary and m.has("sample") and m.sample is Dictionary and m.sample.has("main"):
				var one := mark_from(_clean(m.sample))
				one["day"] = int(m.get("day", 0))
				marks.append(one)
	if held:
		call_deferred("_make_model")


## A sample read back from a save: whole numbers whole again.
static func _clean(s: Dictionary) -> Dictionary:
	var out := s.duplicate(true)
	for key in ["main_pct", "second_pct", "trace_pct", "noise_pct", "anomaly_pct"]:
		out[key] = int(out.get(key, 0))
	out["cell"] = [int(s.cell[0]), int(s.cell[1])]
	out["second"] = str(out.get("second", ""))
	out["anomaly"] = str(out.get("anomaly", ""))
	var traces: Array = []
	for t in out.get("traces", []):
		traces.append({"id": str(t.id), "pct": int(t.pct)})
	out["traces"] = traces
	var at = s.get("at", null)
	if at is Array and at.size() == 2:
		out["at"] = [float(at[0]), float(at[1])]
	return out
