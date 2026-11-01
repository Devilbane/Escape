class_name Music
extends RefCounted
## The background music: one track that loops for as long as the game runs.
## Browsers only allow sound after the player has clicked or pressed a key,
## so the music waits for that first input and starts then. The volume and
## the music's own on/off switch live in the pull-out menu and are kept in
## the settings file. M (sound off) still silences everything, music included.

const TRACK := "res://assets/music/abeth.mp3"
const SETTINGS_FILE := Sfx.SETTINGS_FILE
const DEFAULT_VOLUME := 0.5
## Below this the slider counts as silent.
const SILENT := 0.01

static var volume := DEFAULT_VOLUME
static var muted := false
## Set once the player has clicked, tapped or pressed a key.
static var heard_input := false
## Whether the music must wait for the first input (always true in the
## browser; tests can switch it off or on).
static var wait_for_input := OS.has_feature("web")
static var _player: AudioStreamPlayer = null


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		volume = clampf(float(cfg.get_value("musik", "lautstaerke", DEFAULT_VOLUME)), 0.0, 1.0)
		muted = bool(cfg.get_value("musik", "stumm", false))
	_apply()


static func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("musik", "lautstaerke", volume)
	cfg.set_value("musik", "stumm", muted)
	cfg.save(SETTINGS_FILE)


## True when the music track is part of the game.
static func has_track() -> bool:
	return ResourceLoader.exists(TRACK)


## Creates the music player under `owner_node`. It starts playing right away,
## or with the first input where the browser demands one.
static func start(owner_node: Node) -> AudioStreamPlayer:
	if _player != null and is_instance_valid(_player):
		_player.queue_free()
	_player = null
	if not has_track():
		return null
	var stream: AudioStream = load(TRACK)
	if "loop" in stream:
		stream.loop = true
	var p := AudioStreamPlayer.new()
	p.name = "Music"
	p.stream = stream
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	owner_node.add_child(p)
	_player = p
	_apply()
	return p


## Called with every input event; the first click, tap or key press lets the
## music begin.
static func notice_input(event: InputEvent) -> void:
	if heard_input:
		return
	var pressed: bool = (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch) and event.is_pressed()
	if pressed:
		heard_input = true
		_apply()


static func is_playing() -> bool:
	return _player != null and is_instance_valid(_player) and _player.playing and not _player.stream_paused


static func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_save_settings()
	_apply()


static func toggle_mute() -> void:
	muted = not muted
	_save_settings()
	_apply()


## Brings the player in line with the settings: paused while off, silent or
## still waiting for the first input, otherwise playing at the chosen volume.
static func _apply() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.volume_db = linear_to_db(maxf(volume, 0.0001))
	var should_play := not muted and volume >= SILENT and (heard_input or not wait_for_input)
	if not should_play:
		if _player.playing:
			_player.stream_paused = true
		return
	if _player.stream_paused:
		_player.stream_paused = false
	elif not _player.playing:
		_player.play()
