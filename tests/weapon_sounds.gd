extends SceneTree
## Headless test for the hero's sword and axe sounds (tools/make_weapon_sounds.py,
## Sfx.play_weapon): every take of every blow of both families is part of the
## game and short; blades sound as a sword and axes, maces and hammers as an
## axe; a strike with a sword swishes and lands with a sword impact, one with
## an axe whooms and chops, and the comic word of that blow plays quietly
## under the weapon's own impact.
## Run with: godot --headless --fixed-fps 60 -s tests/weapon_sounds.gd

var failures := 0
var game: Node
var frames := 0
var stage := 0
var wait := 0
var enemy: Enemy
var heard: Array = []
var words_heard := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _finish() -> void:
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: weapon sounds")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _check_files() -> void:
	for family in Sfx.WEAPON_FAMILIES:
		for blow in Sfx.WEAPON_TAKES:
			check(Sfx.WEAPON_DB.has(blow), "%s has a loudness" % blow)
			check(int(Sfx.WEAPON_TAKES[blow]) >= 2, "%s has a few takes" % blow)
			for take in Sfx.WEAPON_TAKES[blow]:
				var path: String = Sfx.DIR + Sfx.weapon_sound(family, blow, take) + ".wav"
				var stream := load(path) as AudioStreamWAV
				check(stream != null, "%s is part of the game" % path)
				if stream:
					check(stream.get_length() > 0.1 and stream.get_length() < 1.0, "%s is short (%.2fs)" % [path, stream.get_length()])
	for blow in Player.BLOWS:
		check(Sfx.WEAPON_TAKES.has(blow), "the blow %s has a sound" % blow)
	for id in Items.ALL:
		var item: Dictionary = Items.ALL[id]
		if item.get("slot", "") != "waffe":
			continue
		var want := "axe" if item.get("uses", "") == "aexte" else "sword"
		check(Sfx.weapon_family(item.get("uses", "klingen")) == want, "%s sounds as a %s" % [id, want])


## Sound players already counted, so a strike only hears its own sounds.
var _known := {}


## The sound players started since the last look, as [file, volume].
func _new_sounds() -> Array:
	var out := []
	for p in root.get_children():
		if p is AudioStreamPlayer and p.stream and not _known.has(p.get_instance_id()):
			_known[p.get_instance_id()] = true
			out.append([p.stream.resource_path.get_file().get_basename(), p.volume_db])
	return out


func _strike(weapon: String) -> void:
	var hero: Player = game.player
	hero.equipped["waffe"] = weapon
	hero.refresh_stats()
	hero._attack_cooldown = 0.0
	enemy.hp = 100000
	enemy.global_position = hero.global_position + hero.facing() * 1.2
	enemy._wake(hero.global_position)
	heard.clear()
	_new_sounds()
	hero.melee()


## Notes the weapon sounds started since the last look, and checks that the
## blow words among them play quietly under the weapon.
func _listen() -> void:
	for s in _new_sounds():
		var file: String = s[0]
		if file.begins_with("sword_") or file.begins_with("axe_"):
			heard.append(file)
		elif file.begins_with("word_"):
			words_heard += 1
			check(s[1] <= Comic.UNDER_WEAPON_DB + 0.01, "the blow's word %s plays under the weapon (%.1f dB)" % s)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	if frames > 1500:
		check(false, "the test finished in time (stage %d)" % stage)
		_finish()
		return true
	game.player.hp = game.player.max_hp
	match stage:
		0:
			_check_files()
			for e in game.level.enemies:
				if is_instance_valid(e) and not e.dead and not e.is_armored() and not e.is_friend():
					enemy = e
					break
			check(enemy != null, "the level has a foe to strike")
			if enemy == null:
				_finish()
				return true
			stage = 1
		1:
			if game.player.can_act():
				_strike("schwert")
				wait = 0
				stage = 2
		2:
			_listen()
			wait += 1
			if wait > 40:
				check(heard.any(func(f): return f.begins_with("sword_swing_")), "a sword strike swishes (heard %s)" % [heard])
				check(heard.any(func(f): return f.begins_with("sword_") and not f.begins_with("sword_swing") and not f.begins_with("sword_sweep")),
						"a sword blow lands with a sword impact (heard %s)" % [heard])
				check(not heard.any(func(f): return f.begins_with("axe_")), "a sword never sounds as an axe (heard %s)" % [heard])
				check(words_heard > 0, "the blow's comic word sounds too")
				stage = 3
		3:
			if game.player.can_act():
				_strike("streitaxt")
				wait = 0
				stage = 4
		4:
			_listen()
			wait += 1
			if wait > 40:
				check(heard.any(func(f): return f.begins_with("axe_swing_")), "an axe strike whooms (heard %s)" % [heard])
				check(heard.any(func(f): return f.begins_with("axe_") and not f.begins_with("axe_swing") and not f.begins_with("axe_sweep")),
						"an axe blow lands with an axe impact (heard %s)" % [heard])
				check(not heard.any(func(f): return f.begins_with("sword_")), "an axe never sounds as a sword (heard %s)" % [heard])
				_finish()
				return true
	return false
