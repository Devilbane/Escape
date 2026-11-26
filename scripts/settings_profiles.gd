class_name SettingsProfiles
extends RefCounted
## Named sets of picture settings the player can save, load, overwrite and delete in the settings window
## (SettingsWindow, tab "Profile"). A profile holds what the Graphics and Colour tabs and V-Sync and the frame
## limit set: the preset and the options on top of it, brightness, contrast and saturation. The window mode,
## the monitor and the sound stay as they are, as they belong to the computer, not to a look.
##
## There are SLOTS places. The profiles live in the settings file (section "profile", one key per place).

const SETTINGS_FILE := Graphics.SETTINGS_FILE
const SLOTS := 8
const NAME_LENGTH := 24


## The profile in a place (1 to SLOTS): a Dictionary with "name", "preset", "custom", "tone", "vsync" and
## "fps", or an empty one when the place is free.
static func get_slot(slot: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if slot < 1 or slot > SLOTS or cfg.load(SETTINGS_FILE) != OK:
		return {}
	var data: Variant = cfg.get_value("profile", str(slot), {})
	return data if data is Dictionary and data.has("name") else {}


## What the settings are right now, as a profile called `profile_name`.
static func snapshot(profile_name: String) -> Dictionary:
	return {"name": clean_name(profile_name), "preset": Graphics.preset, "custom": Graphics.custom.duplicate(),
		"tone": Graphics.tone.duplicate(), "vsync": Graphics.vsync, "fps": Graphics.fps_cap}


## A name as it is kept: trimmed and not too long ("" stays empty).
static func clean_name(text: String) -> String:
	return text.strip_edges().left(NAME_LENGTH)


## Keeps the current settings in a place under `profile_name` (an empty name becomes "Profile N").
static func save_slot(slot: int, profile_name: String) -> void:
	if slot < 1 or slot > SLOTS:
		return
	var label := clean_name(profile_name)
	if label == "":
		label = Lang.t("Profil %d") % slot
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE)
	cfg.set_value("profile", str(slot), snapshot(label))
	cfg.save(SETTINGS_FILE)


## Empties a place.
static func delete_slot(slot: int) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) != OK:
		return
	cfg.set_value("profile", str(slot), null)
	cfg.save(SETTINGS_FILE)


## Uses the profile of a place (and remembers it as the settings). Returns whether the place held one.
static func load_slot(slot: int, view: Viewport) -> bool:
	var profile := get_slot(slot)
	if profile.is_empty():
		return false
	Graphics.adopt(profile, view)
	return true


## Whether the settings are right now exactly those of the profile in a place (its name aside).
static func is_current(slot: int) -> bool:
	var profile := get_slot(slot)
	if profile.is_empty():
		return false
	var now := snapshot("")
	now["name"] = profile.name
	return var_to_str(_plain(now)) == var_to_str(_plain(profile))


## The same profile with the values brought to their types (a file may hold 1 where 1.0 was saved).
static func _plain(profile: Dictionary) -> Dictionary:
	var custom := {}
	for key: String in Graphics.OPTIONS:
		var options: Variant = profile.get("custom", {})
		if options is Dictionary and options.has(key):
			var v: Variant = options[key]
			custom[key] = snappedf(float(v), 0.001) if (v is float or v is int) and not v is bool else v
	var tone := {}
	for key: String in Graphics.TONES:
		var tones: Variant = profile.get("tone", {})
		tone[key] = snappedf(float(tones.get(key, 0.0)), 0.001) if tones is Dictionary else 0.0
	return {"name": profile.get("name", ""), "preset": profile.get("preset", ""), "custom": custom, "tone": tone,
		"vsync": profile.get("vsync", ""), "fps": int(profile.get("fps", 0))}
