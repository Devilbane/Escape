class_name Lang
extends RefCounted
## The game's languages. Every text is written in German in the code;
## this table gives the English for each one. Labels and buttons translate
## their text by themselves, composed texts go through Lang.t() first.

const SETTINGS_FILE := "user://einstellungen.json"

const EN := {
	# Title, name, ranking
	"Entkomme aus dem Verlies": "Escape from the dungeon",
	"Sprache wählen": "Choose your language",
	"Spielstand laden": "Load saved game",
	"Laden": "Load",
	"Abbrechen": "Cancel",
	"Beenden": "Quit",
	"Ton: an": "Sound: on",
	"Ton: aus": "Sound: off",
	"%d%% Tempo": "%d%% speed",
	"Spiel beenden": "Quit game",
	"Was seit dem letzten Schlaf im Bett geschah, geht verloren.": "Whatever happened since you last slept in the bed is lost.",
	"Es gibt noch keinen Spielstand. Gespeichert wird im Bett der Zuflucht.": "There is no saved game yet. You save in the bed of the refuge.",
	"%s auf Ebene %d mit %d Gold.": "%s on level %d with %d gold.",
	"Was du seitdem erlebt hast, geht verloren.": "Everything since then will be lost.",
	"Neues Spiel": "New game",
	"Klicken oder eine Taste: weiterspielen.  N: neues Spiel": "Click or press a key to continue.  N: new game",
	"Klicken oder eine Taste drücken": "Click or press a key",
	"Wie heißt dein Held?": "What is your hero's name?",
	"Dein Name": "Your name",
	"Los geht's": "Let's go",
	"Namenlos": "Nameless",
	"Gute Nacht": "Good night",
	"Dein Spiel ist gespeichert.": "Your game has been saved.",
	"Frei!": "Free!",
	"%s ist entkommen und hat %d Gold erbeutet.": "%s escaped with %d gold.",
	"Klicken für ein neues Spiel": "Click for a new game",
	"Gefallen": "Fallen",
	"%s fiel auf Ebene %d mit %d Gold.": "%s fell on level %d with %d gold.",
	"Rangliste": "Ranking",
	"Platz": "Rank",
	"Name": "Name",
	"Status": "Status",
	"Ebene": "Level",
	"Gold": "Gold",
	"Datum": "Date",
	"Entkommen": "Escaped",
	"Alle Rechte vorbehalten": "All rights reserved",
	# HUD and help
	"WASD: laufen   Leertaste: springen   F: Schlag   R: Messer   M: Ton\nI: Inventar   L: Laden   Rad: Zoom   Dagegenlaufen: benutzen\nMaus: Klick/halten laufen, Rechtsklick: Messer (im Lauf: Sprung)":
		"WASD: walk   Space: jump   F: strike   R: knife   M: sound\nI: inventory   L: load   Wheel: zoom   Run into things: use\nMouse: click/hold to walk, right click: knife (running: jump)",
	"Inventar": "Inventory",
	"Springen": "Jump",
	"Werfen": "Throw",
	"Schlagen": "Strike",
	"Ebene %d: %s": "Level %d: %s",
	"Ebene %d: %s\n%s": "Level %d: %s\n%s",
	"Leben: %d / %d": "Life: %d / %d",
	"Kampfkraft %d": "Strength %d",
	"Tempo %d%%": "Speed %d%%",
	"Gold: %d": "Gold: %d",
	"Messer: %d": "Knives: %d",
	"Schlüssel gefunden": "Key found",
	"Kein Schlüssel": "No key",
	"Dagegenlaufen, um %s zu untersuchen": "Run into %s to search it",
	"Dagegenlaufen, um den Schrein zu berühren": "Run into the shrine to touch it",
	"Dagegenlaufen, um dich ins Bett zu legen": "Run into the bed to lie down",
	"Dagegenlaufen, um die Lagertruhe zu öffnen": "Run into the storage chest to open it",
	"Dagegenlaufen, um mit dem Händler zu handeln": "Run into the merchant to trade",
	"Dagegenlaufen, um aus dem Brunnen zu trinken": "Run into the fountain to drink",
	"Diese Fackelhalterung sieht seltsam aus.\nDu ziehst daran und hörst in der Ferne Stein, der sich bewegt!": "This torchholder looks odd.\nYou pull it and you hear a distant sound of moving stone!",
	"Geheimraum: %s": "Secret room: %s",
	"Gewöhnlich": "Normal",
	"Ungewöhnlich": "Uncommon",
	"Selten": "Rare",
	"Episch": "Epic",
	"Gottgeboren": "Godborn",
	"KLACK!": "CLACK!",
	"KLICK!": "CLICK!",
	"RUMMS!": "RUMBLE!",
	"GRUMPEL!": "GRRRIND!",
	"Vergiftet": "Poisoned",
	"Verflucht": "Cursed",
	"Vergiftet!": "Poisoned!",
	"Verflucht!": "Cursed!",
	"Das Wasser des Brunnens heilt dich von allem Übel.": "The fountain's water cures you of every ailment.",
	"Das kühle Wasser heilt deine Wunden.": "The cool water heals your wounds.",
	"Du trinkst vom klaren Wasser.": "You drink the clear water.",
	"Dein Leiden ist geheilt.": "Your ailment is cured.",
	# Messages
	"Die Tür öffnet sich knarrend...": "The door creaks open...",
	"Verschlossen. Finde den Schlüssel!": "Locked. Find the key!",
	"Du hast den Schlüssel gefunden!": "You found the key!",
	"Das Skelett zerfällt zu Staub.": "The skeleton crumbles to dust.",
	"Schon durchsucht": "Already searched",
	"Deine Tasche ist voll. Wirf im Inventar (Taste I) etwas weg.": "Your bag is full. Drop something in the inventory (key I).",
	"%s: leer": "%s: empty",
	"+%d Gold": "+%d gold",
	"+%d Wurfmesser": "+%d throwing knives",
	"Heiltrank! +2 Leben": "Healing potion! +2 life",
	"Gefunden: %s (%s)": "Found: %s (%s)",
	"\nTaste I öffnet das Inventar.": "\nKey I opens the inventory.",
	"Du durchsuchst %s... nichts.": "You search %s... nothing.",
	"Du wurdest besiegt...": "You have been defeated...",
	"Keine Wurfmesser": "No throwing knives",
	"Phönixfeder!": "Phoenix feather!",
	# Things to search
	"Fass": "Barrel",
	"das Fass": "the barrel",
	"Regal": "Shelf",
	"das Regal": "the shelf",
	"Kiste": "Crate",
	"die Kiste": "the crate",
	"Truhe": "Trunk",
	"Schatztruhe": "Treasure chest",
	"die Truhe": "the chest",
	"Tisch": "Table",
	"den Tisch": "the table",
	# Shrine
	"Schrein der Ahnen": "Shrine of the Ancestors",
	"Wähle eine Gabe": "Choose a gift",
	"+1 Leben": "+1 life",
	"+1 Kampfkraft": "+1 strength",
	"+7% Tempo": "+7% speed",
	"%s\n(Taste %d)": "%s\n(key %d)",
	"Du fühlst dich zäher: +1 Leben": "You feel tougher: +1 life",
	"Deine Hiebe werden härter: +1 Kampfkraft": "Your blows grow harder: +1 strength",
	"Deine Schritte werden leichter: +7% Tempo": "Your steps grow lighter: +7% speed",
	# Windows
	"Schließen": "Close",
	"Leben %d / %d    Kampfkraft %d    Tempo %d%%    Messer %d    Gold %d": "Life %d / %d    Strength %d    Speed %d%%    Knives %d    Gold %d",
	"Angelegt (anklicken zum Ablegen)": "Worn (click to take off)",
	"Tasche (%d / %d)": "Bag (%d / %d)",
	"Anlegen": "Wear",
	"Wegwerfen": "Drop",
	"%s weggeworfen.": "%s dropped.",
	"Deine Tasche ist voll.": "Your bag is full.",
	"Lagertruhe": "Storage chest",
	"Klicke einen Gegenstand an, um ihn zu verschieben.": "Click an item to move it.",
	"Truhe (%d / %d)": "Chest (%d / %d)",
	"Die Truhe ist voll.": "The chest is full.",
	"Händler": "Merchant",
	"Dein Gold: %d": "Your gold: %d",
	"Kaufen": "Buy",
	"%s\n%d Gold": "%s\n%d gold",
	"Verkaufen": "Sell",
	"Dafür reicht dein Gold nicht.": "You don't have enough gold for that.",
	"Gekauft: %s (%s)": "Bought: %s (%s)",
	"Verkauft: %s für %d Gold": "Sold: %s for %d gold",
	"Ein weiches Bett": "A soft bed",
	"Hier kannst du dich ausruhen. Dein Spiel wird gespeichert\nund du loggst dich aus. Später geht es genau hier weiter.":
		"You can rest here. Your game is saved\nand you log out. Later you carry on right here.",
	"Schlafen und ausloggen": "Sleep and log out",
	"Weiter wach bleiben": "Stay awake",
	# Item slots and items
	"Kopf": "Head",
	"Knochenhelm": "Bone helmet",
	"Zauberhut": "Wizard hat",
	"Ritterhelm": "Knight's helmet",
	"Bärenkappe": "Bear cap",
	"Waffe": "Weapon",
	"Schild": "Shield",
	"Umhang": "Cloak",
	"Rüstung": "Armour",
	"Schuhe": "Shoes",
	"Amulett": "Amulet",
	"Ring": "Ring",
	"Armreif": "Bracelet",
	"Spezial 1": "Special 1",
	"Spezial 2": "Special 2",
	"Schwert": "Sword",
	"Axt": "Axe",
	"Rundschild": "Round shield",
	"Wappenschild": "Crest shield",
	"Stachelschild": "Spiked shield",
	"Wollumhang": "Wool cloak",
	"Schattenumhang": "Shadow cloak",
	"Königsumhang": "Royal cloak",
	"Lederwams": "Leather jerkin",
	"Kettenhemd": "Chain mail",
	"Plattenpanzer": "Plate armour",
	"Lederstiefel": "Leather boots",
	"Eilstiefel": "Swift boots",
	"Amulett der Eile": "Amulet of Haste",
	"Amulett der Stärke": "Amulet of Strength",
	"Amulett des Lebens": "Amulet of Life",
	"Kupferring": "Copper ring",
	"Rubinring": "Ruby ring",
	"Bronzearmreif": "Bronze bracelet",
	"Silberarmreif": "Silver bracelet",
	"Vampirzahn": "Vampire fang",
	"Jeder besiegte Gegner gibt dir 1 Leben": "Every defeated enemy gives you 1 life",
	"Glücksklee": "Lucky clover",
	"Doppeltes Gold": "Double gold",
	"Dornenrune": "Thorn rune",
	"Wer dich im Nahkampf trifft, erleidet 1 Schaden": "Whoever hits you up close takes 1 damage",
	"Phönixfeder": "Phoenix feather",
	"Rettet dich einmal vor dem Tod, dann verbrennt sie": "Saves you from death once, then burns up",
	"+%d Kampfkraft": "+%d strength",
	"+%d Leben": "+%d life",
	"+%d%% Tempo": "+%d%% speed",
	# Levels
	"Die Zelle": "The Cell",
	"Durchsuche alles, finde den Schlüssel und öffne die Tür.": "Search everything, find the key and open the door.",
	"Die Stachelhalle": "The Spike Hall",
	"Spring über die Stacheln! (Leertaste)": "Jump over the spikes! (Space)",
	"Das Labyrinth": "The Labyrinth",
	"Vorsicht, Skelett-Schützen! Halte Abstand oder wirf Messer.": "Beware, skeleton archers! Keep your distance or throw knives.",
	"Die Gruft": "The Crypt",
	"Hier ruhen die alten Wächter. Weck sie nicht alle auf.": "The old guardians rest here. Don't wake them all.",
	"Die Zuflucht": "The Refuge",
	"Ein sicherer Ort. Der Brunnen heilt deine Wunden und jedes Gift, und du kannst Dinge lagern, handeln und im Bett speichern.": "A safe place. The fountain heals your wounds and any poison, and you can store things, trade and save in the bed.",
	"Die Katakomben": "The Catacombs",
	"Kleine Wichte kommen in Scharen. Bleib in Bewegung!": "Little minions come in swarms. Keep moving!",
	"Die Bibliothek": "The Library",
	"Skelett-Magier! Ihre Kugeln folgen dir. Lauf hinter eine Säule.": "Skeleton mages! Their orbs follow you. Duck behind a pillar.",
	"Die Knochengrube": "The Bone Pit",
	"Ein Koloss! Er ist langsam, aber er schlägt doppelt hart.": "A brute! It is slow, but it hits twice as hard.",
	"Die Klingenhalle": "The Hall of Blades",
	"Stacheln, Klingen und Zauber. Alles, was du gelernt hast, zählt jetzt.": "Spikes, blades and spells. Everything you have learned counts now.",
	"Das Tor": "The Gate",
	"Dahinter liegt die Freiheit. Zwei Kolosse bewachen den letzten Weg.": "Freedom lies beyond. Two brutes guard the last way out.",
	# Comic words
	"ZACK!": "WHACK!",
	"KLONK!": "CLONK!",
	"WUMM!": "WHUMP!",
	"KRACH!": "CRASH!",
	"WAMM!": "WHAM!",
	"TSCHAK!": "THWACK!",
	"AUA!": "OUCH!",
	"UFF!": "OOF!",
	"AUTSCH!": "OW!",
	"KNACK!": "CRACK!",
	"KLAPPER!": "RATTLE!",
	"WUSCH!": "WHOOSH!",
}

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
