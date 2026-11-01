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
