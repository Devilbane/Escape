class_name DrinkingSongs
extends RefCounted
## Zecher Fritz sings drinking songs at the tavern. In the evening and at
## night he strikes up a verse every minute or so, by day only now and then.
## A verse is four lines, sung one after another like any other line
## (Villager.sing, so they go into the event log with his name), each to its
## own phrase of one little tune (hum_0 to hum_3, built by tools/make_hum.py),
## which he sings himself: "la la la" in a deep, old, crackling bass, one
## syllable for every syllable of the line.
##
## He only sings when the hero is near enough to hear him, when he is free
## (not in a chat, not listening to the herald, not saying something else)
## and nobody next to him is talking. Anything else he says (the hero talks
## to him, a fright) ends the song; while he sings, nobody pulls him into a
## chat.
##
## The words also show in a bubble over his head (SongSheet), the whole
## verse with the line he sings now filling with colour, so the player can
## sing along.
##
## Every verse is German and has an English entry in
## scripts/lang/drinking_songs.gd.

## Who sings (see Villager.ROLES).
const SINGER := "5"
## Seconds between two songs in the evening and at night, and by day
## (picked at random between the two), and before the first one.
const EVENING_EVERY := Vector2(45.0, 90.0)
const DAY_EVERY := Vector2(160.0, 300.0)
const FIRST_SONG := Vector2(12.0, 25.0)
## A song that is due but cannot start (the hero is away, Fritz is busy)
## is tried again this soon.
const RETRY := 4.0
## The evening begins at this hour (the night is DayNight.NIGHT_FROM).
const EVENING_FROM := 18.0
## The hero hears him from this far (metres, as Game.HEAR_RANGE): no song
## for an empty street.
const HEAR_RANGE := 14.0
## Seconds each line is sung: one phrase of the tune.
const LINE_TIME := 3.2
## How loud the tune plays (dB): his deep, rough voice needs a little more than a hum.
const VOLUME := -4.0
## The phrases of the tune, one per line of a verse.
const TUNE := ["hum_0", "hum_1", "hum_2", "hum_3"]
## How a sung line is marked, so it reads as a song and not as talk.
const MARK := "~ %s ~"

## The songs, each one verse of four lines (German). "night": only after
## dark (it sings of the moon).
const SONGS := [
	{"lines": ["Der Krug ist leer, der Wirt ist taub,",
		"mein Beutel voller Staub und Laub!",
		"Doch schenkt mir einer noch was ein,",
		"dann soll's die schönste Nacht hier sein!"]},
	{"lines": ["Wer aus der Gruft ans Licht entkam,",
		"der trinkt mit mir und ohne Scham!",
		"Ein Prost aufs Licht, ein Prost aufs Bier,",
		"die Toten unten, wir sind hier!"]},
	{"lines": ["Unter der Linde steht ein Fass,",
		"und wer nicht singt, der wird nicht nass!",
		"Hoch die Krüge, hoch die Hand,",
		"das beste Bier im ganzen Land!"]},
	{"lines": ["Die Zeche zahl ich morgen, Wirt,",
		"wenn sich das Glück zu mir verirrt!",
		"Und kommt es nicht, so sing ich eben,",
		"ein Lied ist auch ein Stück vom Leben!"]},
	{"night": true, "lines": ["Der Mond ist voll, und ich bin's auch,",
		"ein Lied im Herz, ein Bier im Bauch!",
		"Ihr Wölfe heult, ich heule mit,",
		"doch keiner hält mit Fritz hier Schritt!"]},
]

var game: Node
## The bubble with the words over his head (null where there is none, as in
## a bare test).
var sheet: SongSheet
## The song going on: the singer, the lines still to sing (translated) and
## the seconds until the next one ({} for none).
var _song := {}
var _timer := 0.0
## How many songs have been sung, to take turns with them.
var _sung := 0
var _rng := RandomNumberGenerator.new()


func _init(owner_game: Node = null) -> void:
	game = owner_game
	_rng.randomize()
	clear()


func clear() -> void:
	stop()
	_sung = 0
	_timer = _rng.randf_range(FIRST_SONG.x, FIRST_SONG.y)


## Whether it is evening or night in the village: the time for songs.
static func is_evening(village: Outdoor) -> bool:
	return village.night or village.hour >= EVENING_FROM


func is_singing() -> bool:
	return not _song.is_empty()


## The songs that fit right now (indices into SONGS).
func fitting(village: Outdoor) -> Array:
	var out := []
	var dark: bool = village.night
	for i in SONGS.size():
		if dark or not SONGS[i].get("night", false):
			out.append(i)
	return out


## Every frame in the village while the world runs (next to VillageTalk.update).
func update(delta: float, village: Outdoor) -> void:
	if village == null or game == null:
		return
	if not _song.is_empty():
		_run_song(delta)
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if start_song(village):
		var every := EVENING_EVERY if is_evening(village) else DAY_EVERY
		_timer = _rng.randf_range(every.x, every.y)
	else:
		_timer = RETRY


## Fritz strikes up the next song, if he is free and the hero can hear him.
## Returns whether he did.
func start_song(village: Outdoor) -> bool:
	if not _song.is_empty() or village == null or game == null:
		return false
	var singer := singer_in(village)
	if singer == null or not singer.can_chat() or singer.talker_near() != null:
		return false
	if VillageTalk._flat(singer.global_position, game.player.global_position) > HEAR_RANGE:
		return false
	var songs := fitting(village)
	var song: Dictionary = SONGS[songs[_sung % songs.size()]]
	_sung += 1
	var lines := []
	var words := []
	for line in song.lines:
		words.append(Lang.t(line))
		lines.append(MARK % words.back())
	_song = {"singer": singer, "lines": lines, "words": words, "line": 0, "wait": 0.0,
		"pitch": _rng.randf_range(0.95, 1.05), "sound": null}
	return true


func singer_in(village: Outdoor) -> Villager:
	for v in village.villagers:
		if is_instance_valid(v) and v.role == SINGER:
			return v
	return null


func _run_song(delta: float) -> void:
	# The village is gone, or he said something else in between: the song
	# is over.
	if not is_instance_valid(_song.singer):
		stop()
		return
	var singer: Villager = _song.singer
	if _song.line > 0 and not singer.singing:
		stop()
		return
	_song.wait -= delta
	if _song.wait > 0.0:
		return
	var lines: Array = _song.lines
	if lines.is_empty():
		stop(false)
		return
	# Someone next to him is talking: the next line waits for them.
	if singer.talker_near() != null:
		return
	var text: String = lines.pop_front()
	singer.sing(text, LINE_TIME)
	if sheet:
		sheet.sing(singer, _song.words, _song.line, LINE_TIME)
	# One pitch for the whole verse, so the phrases make one tune; heard
	# from his side of the screen.
	_song.sound = Sfx.play_3d(singer, TUNE[_song.line % TUNE.size()], VOLUME, singer.global_position, _song.pitch)
	_song.line += 1
	_song.wait = LINE_TIME


## Ends the song going on. `cut`: broken off, so a phrase still playing
## falls silent too (at the end of a verse the last one rings out).
func stop(cut := true) -> void:
	var sound = _song.get("sound")
	if cut and sound != null and is_instance_valid(sound):
		sound.queue_free()
	var singer = _song.get("singer")
	if singer != null and is_instance_valid(singer):
		singer.singing = false
	if sheet and not _song.is_empty():
		sheet.finish(cut)
	_song = {}
