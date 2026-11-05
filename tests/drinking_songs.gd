extends SceneTree
## Headless test for Zecher Fritz's drinking songs (see DrinkingSongs): every
## verse has four lines with English texts and the tune has its sounds; in the
## evening near the hero, Fritz sings a whole verse, line after line, in the
## event log; far from the hero he does not; the moon song waits for the
## night; while he sings, nobody pulls him into a chat; and the hero talking
## to him ends the song. The words show in the song sheet over his head
## (SongSheet): the whole verse, the line he sings now in step with him and
## filling as he sings it, in a bubble of one fixed size that holds every
## line of every song in both languages; it fades when the song is over or
## broken off and while a window is open.
## Run with: godot --headless -s tests/drinking_songs.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Testheld Lieder"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: drinking songs")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


func _free_everyone() -> void:
	for v in game.level.villagers:
		v._start("idle", 60.0)
		v.hush()
	var fritz := _villager(DrinkingSongs.SINGER)
	if fritz:
		fritz._start("sit", 60.0)


## The lines Fritz sings while the songs run for `seconds`.
func _run(seconds: float, sung := [], step := 0.1) -> Array:
	var songs: DrinkingSongs = game.drinking_songs
	var fritz := _villager(DrinkingSongs.SINGER)
	var t := 0.0
	while t < seconds:
		songs.update(step, game.level)
		if fritz._bubble_time > 0.0:
			var line: String = fritz._bubble.text.get_slice("\n", 1)
			if not sung.has(line):
				sung.append(line)
		for v in game.level.villagers:
			v._update_bubble(step)
		game.drinking_songs.sheet.step(step)
		_sheet_seen(fritz)
		t += step
	return sung


## What the song sheet showed while the songs ran: the line it marked each
## time Fritz sang one (it must be the one he sings), and its sizes.
var sheet_lines := []
var sheet_sizes := {}
var sheet_in_step := true


func _sheet_seen(fritz: Villager) -> void:
	var sheet: SongSheet = game.drinking_songs.sheet
	if not sheet.shows():
		return
	sheet_sizes[sheet.size] = true
	if fritz._bubble_time > 0.0 and fritz.singing:
		var said: String = fritz._bubble.text.get_slice("\n", 1)
		var shown: String = DrinkingSongs.MARK % sheet.lines()[sheet.line()]
		if said != shown:
			sheet_in_step = false
		if not sheet_lines.has(shown):
			sheet_lines.append(shown)


func _verse(index: int) -> Array:
	var out := []
	for line in DrinkingSongs.SONGS[index].lines:
		out.append(DrinkingSongs.MARK % Lang.t(line))
	return out


func _test() -> void:
	# The tables.
	check(DrinkingSongs.SONGS.size() >= 4, "Fritz knows a few songs")
	for song in DrinkingSongs.SONGS:
		check(song.lines.size() == DrinkingSongs.TUNE.size(), "a verse has one line per phrase of the tune: %s" % [song.lines])
		for line in song.lines:
			check(Lang.EN.has(line), "\"%s\" has an English text" % line)
	for sound in DrinkingSongs.TUNE:
		check(ResourceLoader.exists(Sfx.DIR + sound + ".wav"), "the tune has its sound %s" % sound)
	check(Villager.ROLES.has(DrinkingSongs.SINGER), "the singer lives in the village")

	# A fresh hero in the village in the evening.
	game.hero_name = HERO
	game.met.clear()
	game.quests.clear()
	game.reputation.clear()
	game.village_talk.clear()
	game.load_level(game._outdoor_index(), false)
	var village: Outdoor = game.level
	check(village is Outdoor, "the village is loaded")
	if not village is Outdoor:
		return
	game.village_talk._timer = 1e9
	game.village_worries._remark_timer = 1e9
	village.set_weather(Weather.CLEAR)
	var songs: DrinkingSongs = game.drinking_songs
	songs.clear()
	var fritz := _villager(DrinkingSongs.SINGER)
	check(fritz != null, "Fritz lives in the village")
	if fritz == null:
		return
	village.set_hour(12.0)
	check(not DrinkingSongs.is_evening(village), "noon is not the evening")
	check(not songs.fitting(village).has(4), "the moon song is not sung by day")
	village.set_hour(19.0)
	check(DrinkingSongs.is_evening(village), "seven o'clock is the evening")
	_free_everyone()

	# Far from the hero, Fritz does not sing.
	game.player.global_position = fritz.global_position + Vector3(60, 0, 60)
	songs._timer = 0.0
	var sung := _run(2.0, [])
	check(sung.is_empty(), "no song for an empty street: %s" % [sung])
	check(songs._timer <= DrinkingSongs.RETRY, "a song that is due is tried again soon")

	# Near the hero, he sings a whole verse, line after line, in order.
	game.player.global_position = fritz.global_position + Vector3(3, 0, 2)
	game._snap_camera()
	_free_everyone()
	songs._timer = 0.0
	sung = _run(0.2, [])
	check(songs.is_singing() and fritz.singing, "Fritz strikes up a song")
	check(not fritz.can_chat(), "while he sings, nobody pulls him into a chat")
	_run(DrinkingSongs.LINE_TIME * DrinkingSongs.TUNE.size() + 1.0, sung)
	check(sung == _verse(0), "he sings the first verse in order: %s" % [sung])
	check(not songs.is_singing() and not fritz.singing, "and then the song is over")
	check(songs._timer >= DrinkingSongs.EVENING_EVERY.x - 1.0, "the next one comes in a while (%.1f s)" % songs._timer)

	# The song sheet showed every line as he sang it, then went.
	var sheet: SongSheet = songs.sheet
	check(sheet != null, "the game has a song sheet")
	check(sheet_lines == _verse(0), "the sheet showed each line as he sang it: %s" % [sheet_lines])
	check(sheet_in_step, "the sheet marks the line he is singing, never another")
	check(sheet_sizes.size() == 1, "the sheet keeps one size for the whole verse: %s" % [sheet_sizes.keys()])
	_run(SongSheet.LINGER + SongSheet.FADE_OUT + 0.3, [])
	check(not sheet.shows() and not sheet.visible, "after the verse the sheet goes")

	# The sheet is big enough for every line in both languages, and its size
	# is the same for every song and language.
	var box := SongSheet.box_size()
	var room := box.x - SongSheet.PAD.x * 2 - SongSheet.MARKER
	for song in DrinkingSongs.SONGS:
		for line in song.lines:
			for text in [line, Lang.EN.get(line, line)]:
				var w := SongSheet.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SongSheet._font_size()).x
				check(w <= room, "\"%s\" fits in the sheet" % text)
	check(box.x <= 640.0, "the sheet is not wider than half the screen (%d)" % box.x)

	# The next song is another one.
	_free_everyone()
	songs._timer = 0.0
	sung = _run(DrinkingSongs.LINE_TIME * DrinkingSongs.TUNE.size() + 1.0, [])
	check(sung == _verse(1), "the next time he sings another song: %s" % [sung])
	check(sheet_sizes.size() == 1, "another song keeps the sheet's size")

	# Mid-line, the line he sings fills with colour as he sings it.
	_free_everyone()
	songs._timer = 0.0
	_run(0.2, [])
	var early := sheet.progress()
	_run(DrinkingSongs.LINE_TIME * 0.5, [])
	check(sheet.line() == 0 and sheet.progress() > early and sheet.progress() < 1.0,
		"the line fills as he sings it (%.2f to %.2f)" % [early, sheet.progress()])
	_run(DrinkingSongs.LINE_TIME * 0.5, [])
	check(sheet.line() == 1, "then the sheet moves on to the next line")
	check(sheet.visible and sheet.modulate.a > 0.9, "the sheet shows over Fritz (%.2f)" % sheet.modulate.a)
	var screen := sheet.get_viewport_rect()
	check(screen.encloses(sheet.get_rect()), "the sheet stays on screen: %s" % sheet.get_rect())
	check(SongSheet._overlap(sheet.get_rect(), sheet._blocked()) == 0.0, "the sheet does not cover the hero")
	var tail_at := sheet.position + sheet._tip
	var fritz_at: Vector2 = game.camera.unproject_position(fritz.global_position)
	check(absf(tail_at.x - fritz_at.x) < 60.0, "its tail points at Fritz (%d px beside him)" % absf(tail_at.x - fritz_at.x))
	# With the hero standing right where the sheet hangs, it moves aside.
	game.player.global_position = fritz.global_position + Vector3(0, 0, -2.5)
	game._snap_camera()
	for i in 3:
		sheet.step(0.05)
	var ends: Array = sheet._anchors()
	var least := INF
	for i in SongSheet.SPOTS.size():
		least = minf(least, SongSheet._overlap(sheet._spot_rect(i, ends[0], ends[1]), sheet._blocked()))
	check(SongSheet._overlap(sheet.get_rect(), sheet._blocked()) <= least + 1.0,
		"the sheet takes the spot that covers the hero least (%s)" % sheet.where())
	check(sheet.where() != "above", "with the hero above Fritz, the sheet moves away from him (%s)" % sheet.where())
	game.player.global_position = fritz.global_position + Vector3(3, 0, 2)
	game._snap_camera()
	# A window opens: the sheet fades out, and comes back after.
	game.menus.open("inventory")
	for i in 10:
		sheet.step(0.05)
	check(sheet.modulate.a == 0.0, "the sheet fades out while a window is open")
	game.menus.close()
	for i in 10:
		sheet.step(0.05)
	check(sheet.modulate.a > 0.9 or not sheet.shows(), "and comes back when it closes (%.2f)" % sheet.modulate.a)
	songs.stop()
	for i in 10:
		sheet.step(0.05)
	check(not sheet.shows(), "a broken-off song takes the sheet away")

	# The hero talks to him mid-song: the song is over.
	_free_everyone()
	songs._timer = 0.0
	_run(DrinkingSongs.LINE_TIME + 0.2, [])
	check(songs.is_singing(), "a third song has begun")
	fritz.hush()
	fritz.talk(game.player)
	_run(0.2, [])
	check(not songs.is_singing() and not fritz.singing, "talking to him ends the song")
	_run(SongSheet.FADE_OUT + 0.2, [])
	check(not sheet.shows(), "and takes the sheet away")

	# By night he sings of the moon too.
	village.set_hour(22.0)
	check(songs.fitting(village).has(4), "the moon song is sung at night")
	village.set_hour(12.0)
	songs.clear()
