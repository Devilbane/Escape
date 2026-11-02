class_name Lang
extends RefCounted
## The game's languages. Every text is written in German in the code;
## the English for each one lives in scripts/lang/, one file per feature,
## and is merged into EN when the game starts. Labels and buttons translate
## their text by themselves, composed texts go through Lang.t() first.
##
## To add texts for a new feature, write scripts/lang/<feature>.gd with a
## `const EN := {...}` and list it in PARTS. tests/lang_keys.gd fails when a
## German text is in two files or a file in scripts/lang/ is not listed.

const SETTINGS_FILE := "user://einstellungen.json"

## The English texts, one script per feature, each with its own `EN` table.
const PARTS := [
	preload("res://scripts/lang/title.gd"),
	preload("res://scripts/lang/hud.gd"),
	preload("res://scripts/lang/compendium.gd"),
	preload("res://scripts/lang/crafting_square.gd"),
	preload("res://scripts/lang/messages.gd"),
	preload("res://scripts/lang/search.gd"),
	preload("res://scripts/lang/shrine.gd"),
	preload("res://scripts/lang/windows.gd"),
	preload("res://scripts/lang/trade_window.gd"),
	preload("res://scripts/lang/items.gd"),
	preload("res://scripts/lang/training.gd"),
	preload("res://scripts/lang/character_page.gd"),
	preload("res://scripts/lang/levels.gd"),
	preload("res://scripts/lang/village.gd"),
	preload("res://scripts/lang/homes.gd"),
	preload("res://scripts/lang/barber.gd"),
	preload("res://scripts/lang/offline.gd"),
	preload("res://scripts/lang/comic.gd"),
	preload("res://scripts/lang/crates.gd"),
	preload("res://scripts/lang/stones.gd"),
	preload("res://scripts/lang/forge.gd"),
	preload("res://scripts/lang/puzzles.gd"),
	preload("res://scripts/lang/quests.gd"),
	preload("res://scripts/lang/crafting.gd"),
	preload("res://scripts/lang/fishing.gd"),
	preload("res://scripts/lang/bounties.gd"),
	preload("res://scripts/lang/day_night.gd"),
	preload("res://scripts/lang/journal.gd"),
	preload("res://scripts/lang/wandering_merchant.gd"),
	preload("res://scripts/lang/fox.gd"),
	preload("res://scripts/lang/companions.gd"),
	preload("res://scripts/lang/pouch.gd"),
	preload("res://scripts/lang/weather.gd"),
	preload("res://scripts/lang/moon.gd"),
	preload("res://scripts/lang/reputation.gd"),
	preload("res://scripts/lang/horrors.gd"),
	preload("res://scripts/lang/home_upgrades.gd"),
	preload("res://scripts/lang/factions.gd"),
	preload("res://scripts/lang/village_talk.gd"),
	preload("res://scripts/lang/wishes.gd"),
	preload("res://scripts/lang/quick_bar.gd"),
	preload("res://scripts/lang/exploration.gd"),
	preload("res://scripts/lang/save_slots.gd"),
]

## German text -> English text, all features together. Read it, never write it.
static var EN := _merge_parts()

## "de" or "en"; empty until the player has chosen.
static var language := ""


static var _english: Translation


## Loads the chosen language.
static func setup() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_FILE))
		if data is Dictionary and data.get("language", "") in ["de", "en"]:
			language = data.language
	_apply()


static func choose(code: String) -> void:
	language = code
	_apply()
	var file := FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"language": code}))


## The English table is only registered while English is chosen: Godot
## falls back to English for any locale it has no table for.
static func _apply() -> void:
	if _english == null:
		_english = Translation.new()
		_english.locale = "en"
		for key in EN:
			_english.add_message(key, EN[key])
	TranslationServer.remove_translation(_english)
	if language == "en":
		TranslationServer.add_translation(_english)
	TranslationServer.set_locale("en" if language == "en" else "de")


## The text in the chosen language.
static func t(text: String) -> String:
	return String(TranslationServer.translate(text))


## All PARTS in one table. A text in two parts keeps its first English;
## tests/lang_keys.gd catches that case.
static func _merge_parts() -> Dictionary:
	var all := {}
	for part in PARTS:
		all.merge(part.EN)
	return all
