extends SceneTree
## Headless test for Zecher Fritz's drinking songs (see DrinkingSongs): every
## verse has four lines with English texts and the tune has its sounds; in the
## evening near the hero, Fritz sings a whole verse, line after line, in the
## event log; far from the hero he does not; the moon song waits for the
## night; while he sings, nobody pulls him into a chat; and the hero talking
## to him ends the song.
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
		t += step
	return sung


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
	_free_everyone()
	songs._timer = 0.0
	sung = _run(0.2, [])
	check(songs.is_singing() and fritz.singing, "Fritz strikes up a song")
	check(not fritz.can_chat(), "while he sings, nobody pulls him into a chat")
	_run(DrinkingSongs.LINE_TIME * DrinkingSongs.TUNE.size() + 1.0, sung)
	check(sung == _verse(0), "he sings the first verse in order: %s" % [sung])
	check(not songs.is_singing() and not fritz.singing, "and then the song is over")
	check(songs._timer >= DrinkingSongs.EVENING_EVERY.x - 1.0, "the next one comes in a while (%.1f s)" % songs._timer)

	# The next song is another one.
	_free_everyone()
	songs._timer = 0.0
	sung = _run(DrinkingSongs.LINE_TIME * DrinkingSongs.TUNE.size() + 1.0, [])
	check(sung == _verse(1), "the next time he sings another song: %s" % [sung])

	# The hero talks to him mid-song: the song is over.
	_free_everyone()
	songs._timer = 0.0
	_run(DrinkingSongs.LINE_TIME + 0.2, [])
	check(songs.is_singing(), "a third song has begun")
	fritz.hush()
	fritz.talk(game.player)
	_run(0.2, [])
	check(not songs.is_singing() and not fritz.singing, "talking to him ends the song")

	# By night he sings of the moon too.
	village.set_hour(22.0)
	check(songs.fitting(village).has(4), "the moon song is sung at night")
	village.set_hour(12.0)
	songs.clear()
