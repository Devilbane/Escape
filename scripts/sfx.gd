class_name Sfx
extends RefCounted
## Sound effects (built by tools/make_sounds.py) and the cave ambience.
## Sounds far from the camera play quieter; M or the speaker button mutes all.
## All effects play through their own "Effects" bus, so the effects volume
## slider in the pull-out menu turns them up or down without the music.

const DIR := "res://assets/sounds/"
const SETTINGS_FILE := "user://einstellungen.cfg"
## Steps, swings and hits get a slightly different pitch each time.
const PITCH_SPREAD := 0.08
const BUS := "Effects"
const DEFAULT_VOLUME := 1.0

static var muted := false
## The effects volume, from 0 (silent) to 1 (full).
static var volume := DEFAULT_VOLUME
## True while the game is in the background (alt-tabbed, other tab, minimised).
static var _in_background := false
## Kept alive so the browser can keep calling back into the game.
static var _js_focus_callback = null
static var _watching_focus := false
static var _streams := {}
static var _clicking_buttons := false
## How loud the button click is: only a hint of a sound.
const CLICK_DB := -14.0


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		muted = cfg.get_value("ton", "stumm", false)
		volume = clampf(float(cfg.get_value("ton", "lautstaerke", DEFAULT_VOLUME)), 0.0, 1.0)
	_apply_mute()
	_apply_volume()


## The bus the effects play through. It is part of the bus layout in
## res://default_bus_layout.tres and must not be added at runtime: in the
## browser build (Godot 4.5), AudioServer.add_bus() puts the new bus in
## front of Master on the web audio side, the two buses end up sending to
## each other, and the browser silences that loop, so the whole game falls
## quiet. Returns -1 if the bus is missing; players then fall back to Master.
static func bus_index() -> int:
	return AudioServer.get_bus_index(BUS)


static func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("ton", "lautstaerke", volume)
	cfg.save(SETTINGS_FILE)
	_apply_volume()


static func _apply_volume() -> void:
	var i := bus_index()
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(i, volume < 0.01)


static func toggle_mute() -> void:
	muted = not muted
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("ton", "stumm", muted)
	cfg.save(SETTINGS_FILE)
	_apply_mute()


static func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted or _in_background)


## Silences all sound while the game is not the active window or tab, and
## brings it back on return. Does not touch the player's own mute setting.
static func watch_focus(tree_node: Node) -> void:
	if _watching_focus:
		return
	_watching_focus = true
	if OS.has_feature("web"):
		# In the browser, ask the page itself: the tab can be hidden or the
		# browser window can lose focus without Godot noticing in time.
		_js_focus_callback = JavaScriptBridge.create_callback(func(_args): _check_page_focus())
		var window = JavaScriptBridge.get_interface("window")
		var document = JavaScriptBridge.get_interface("document")
		window.addEventListener("blur", _js_focus_callback)
		window.addEventListener("focus", _js_focus_callback)
		window.addEventListener("pagehide", _js_focus_callback)
		window.addEventListener("pageshow", _js_focus_callback)
		document.addEventListener("visibilitychange", _js_focus_callback)
		_check_page_focus()
	else:
		var win := tree_node.get_window()
		win.focus_exited.connect(func(): _set_background(true))
		win.focus_entered.connect(func(): _set_background(false))


## Gives every button in the game (menus, merchant windows, tabs, the HUD) a
## soft click when pressed. Hooked in once for the whole scene tree, so
## buttons made later pick it up on their own. Plays on the Effects bus, so
## the effects volume slider and M turn it down or off too.
static func click_on_buttons(tree: SceneTree) -> void:
	if _clicking_buttons:
		return
	_clicking_buttons = true
	tree.node_added.connect(_add_click)
	for node in tree.root.find_children("*", "BaseButton", true, false):
		_add_click(node)


static func _add_click(node: Node) -> void:
	# On button_down, the moment the pointer goes down: the drawer's action
	# buttons fire there too, and a click on release would trail behind.
	if node is BaseButton and not node.button_down.is_connected(_play_click):
		node.button_down.connect(_play_click)


static func _play_click() -> void:
	# Played from the tree's root, not the button: many buttons close their
	# own window on press and may already be out of the tree by now.
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		play(tree.root, "ui_click", CLICK_DB)


static func _check_page_focus() -> void:
	_set_background(bool(JavaScriptBridge.eval("document.hidden || !document.hasFocus()", true)))


static func _set_background(value: bool) -> void:
	if value == _in_background:
		return
	_in_background = value
	_apply_mute()


static func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := DIR + sound + (".ogg" if ResourceLoader.exists(DIR + sound + ".ogg") else ".wav")
		_streams[sound] = load(path)
	return _streams[sound]


## Plays a sound once. With `at`, it fades with the distance from the camera.
## `pitch` shifts the sound up or down around the usual small random spread.
static func play(tree_node: Node, sound: String, volume_db := 0.0, at = null, pitch := 1.0) -> void:
	if tree_node == null or not tree_node.is_inside_tree():
		return
	var tree := tree_node.get_tree()
	if at is Vector3:
		var cam := tree_node.get_viewport().get_camera_3d()
		if cam:
			# The camera hovers about 27 m away, up to 32 m fully zoomed out;
			# beyond that, sounds fade out.
			var far := maxf(0.0, cam.global_position.distance_to(at) - 33.0)
			volume_db -= far * 0.9
			if volume_db < -40.0:
				return
	var p := AudioStreamPlayer.new()
	p.stream = _stream(sound)
	p.bus = BUS
	p.volume_db = volume_db
	p.pitch_scale = pitch + randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Plays a sound once from a spot in the world, so it is heard from that
## side (left or right of the screen). It does not fade with the distance on
## its own: the caller picks the volume. Lives under `parent`, so it falls
## silent when that (say, the level) goes away.
static func play_3d(parent: Node, sound: String, volume_db: float, at: Vector3, pitch := 1.0) -> AudioStreamPlayer3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(sound)
	p.bus = BUS
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.panning_strength = 1.5
	parent.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Like play, but only after `seconds` (say, once a chest lid is up).
static func play_after(tree_node: Node, seconds: float, sound: String, volume_db := 0.0, at = null) -> void:
	if seconds <= 0.0:
		play(tree_node, sound, volume_db, at)
		return
	if tree_node == null or not tree_node.is_inside_tree():
		return
	var timer := tree_node.get_tree().create_timer(seconds, true)
	timer.timeout.connect(func():
		if is_instance_valid(tree_node):
			play(tree_node, sound, volume_db, at))


## The hero's weapon sounds (built by tools/make_weapon_sounds.py), by kind
## of blow, with how many takes each has. "swing" and "sweep" are the rush of
## air as the hero strikes one enemy or sweeps a crowd; the rest is the blow
## landing: "hit" plain, "heavy" a heavy hit, "vital" a vital point found,
## "sneak" a sneak attack and "glance" the weapon glancing off armour.
const WEAPON_TAKES := {"swing": 3, "sweep": 2, "hit": 3, "heavy": 2, "vital": 2, "sneak": 2, "glance": 2}
## How loud each kind sits, so the telling blows stand out of a fight.
const WEAPON_DB := {"swing": -3.0, "sweep": -2.0, "hit": 0.0, "heavy": 1.0, "vital": 2.0, "sneak": 2.0, "glance": -1.0}
## The two weapon families that sound apart.
const WEAPON_FAMILIES := ["sword", "axe"]


## Which family a weapon skill sounds like: axes, maces and hammers
## (Aexte) chop as an "axe", blades as a "sword".
static func weapon_family(skill_id: String) -> String:
	return "axe" if skill_id == "aexte" else "sword"


## The file of one take of a weapon sound, e.g. "sword_hit_2".
static func weapon_sound(family: String, blow: String, take: int) -> String:
	return "%s_%s_%d" % [family, blow, take]


## Plays a random take of a weapon sound: `family` from weapon_family,
## `blow` a key of WEAPON_TAKES. With `at`, it fades with the distance.
static func play_weapon(tree_node: Node, family: String, blow: String, at = null) -> void:
	var take := randi() % int(WEAPON_TAKES.get(blow, 1))
	play(tree_node, weapon_sound(family, blow, take), float(WEAPON_DB.get(blow, 0.0)), at)


## Coins clinking: a coin or two, or a whole handful of gold.
static func play_coins(tree_node: Node, amount: int, delay := 0.0, at = null) -> void:
	var sound := "coins_big_%d" % (randi() % 3) if amount >= 5 else "coins_small_%d" % (randi() % 3)
	play_after(tree_node, delay, sound, 0.0, at)


## A chest lid opening: latch, creaking hinges, the lid falling back.
static func play_chest(tree_node: Node, at = null) -> void:
	play(tree_node, "chest_open_%d" % (randi() % 3), -2.0, at)


## A piece of gear clattering onto the floor, by what it is made of.
static func play_gear(tree_node: Node, id: String, delay := 0.0, at = null) -> void:
	var item: Dictionary = Items.ALL.get(id, {})
	var sound := "gear_trinket"
	match item.get("material", ""):
		"metal", "mixed":
			sound = "gear_metal_%d" % (randi() % 3)
		"chain":
			sound = "gear_chain_%d" % (randi() % 2)
		"leather", "cloth", "fur":
			sound = "gear_soft_%d" % (randi() % 2)
		"bone":
			sound = "gear_bone"
		_:
			if item.get("slot", "") == "buch":
				sound = "gear_book"
	# Plate armour lands with mail's rattle and weight.
	if id == "plattenpanzer":
		sound = "gear_chain_%d" % (randi() % 2)
	play_after(tree_node, delay, sound, -2.0, at)


## The fanfare for loot finer than rare, by its tier (see Level.TIERS and
## tools/make_rarity_sounds.py). Each one is bigger than the one below, so
## the ear knows the tier before the eye reads it. Common to rare gear has
## none: there the clatter alone tells of the find.
const RARITY_SOUNDS := {"episch": "loot_epic", "gottgeboren": "loot_godborn"}
## How long after the clatter the fanfare sets in.
const RARITY_AFTER := 0.15


## The fanfare a piece of gear earns when it turns up, or "" for none.
static func rarity_sound(id: String) -> String:
	return str(RARITY_SOUNDS.get(Level.tier_of(id), ""))


## Of several pieces, the one whose fanfare is the grandest ("" when none of
## them earns one): when a monster drops a heap, only the best of it sings.
static func finest(ids: Array) -> String:
	var order: Array = Level.TIERS.keys()
	var best := ""
	for id in ids:
		if rarity_sound(id) != "" and (best == "" or order.find(Level.tier_of(id)) > order.find(Level.tier_of(best))):
			best = id
	return best


## Rings out the fanfare of a piece finer than rare, just after its
## clatter (`delay` is the clatter's own delay). Does nothing for others.
static func play_rarity(tree_node: Node, id: String, delay := 0.0, at = null) -> void:
	var sound := rarity_sound(id)
	if sound != "":
		play_after(tree_node, delay + RARITY_AFTER, sound, 0.0, at)


## A piece of loot turning up: its clatter, and its fanfare if it is finer
## than rare. For gear the hero finds or a monster drops, not for gear the
## hero merely puts down.
static func play_find(tree_node: Node, id: String, delay := 0.0, at = null) -> void:
	play_gear(tree_node, id, delay, at)
	play_rarity(tree_node, id, delay, at)


## A sound that loops for as long as it plays (an .ogg file), e.g. the
## rain. It starts silent and stopped: the caller sets the volume and
## plays it when the time comes.
static func start_loop(owner_node: Node, sound: String) -> AudioStreamPlayer:
	var stream: AudioStreamOggVorbis = _stream(sound)
	stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = BUS
	p.volume_db = -80.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	owner_node.add_child(p)
	return p


## The endless wind and dripping water in the background.
static func start_ambience(owner_node: Node) -> AudioStreamPlayer:
	var stream: AudioStreamOggVorbis = _stream("ambience")
	stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = BUS
	p.volume_db = -8.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	owner_node.add_child(p)
	p.play()
	return p
