class_name Sfx
extends RefCounted
## Sound effects (built by tools/make_sounds.py) and the cave ambience.
## Sounds far from the camera play quieter; M or the speaker button mutes all.

const DIR := "res://assets/sounds/"
const SETTINGS_FILE := "user://einstellungen.cfg"
## Steps, swings and hits get a slightly different pitch each time.
const PITCH_SPREAD := 0.08

static var muted := false
static var _streams := {}


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		muted = cfg.get_value("ton", "stumm", false)
	_apply_mute()


static func toggle_mute() -> void:
	muted = not muted
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("ton", "stumm", muted)
	cfg.save(SETTINGS_FILE)
	_apply_mute()


static func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


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
			# The camera hovers about 27 m away; beyond that, sounds fade out.
			var far := maxf(0.0, cam.global_position.distance_to(at) - 28.0)
			volume_db -= far * 0.9
			if volume_db < -40.0:
				return
	var p := AudioStreamPlayer.new()
	p.stream = _stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch + randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## The endless wind and dripping water in the background.
static func start_ambience(owner_node: Node) -> AudioStreamPlayer:
	var stream: AudioStreamOggVorbis = _stream("ambience")
	stream.loop = true
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -8.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	owner_node.add_child(p)
	p.play()
	return p
