extends SceneTree
## Headless test: the townsfolk can put up a real fight against a Blob of
## level 20 and more (see Villager.LIFE_PER_LEVEL). Worked out on the numbers
## alone: one fighter alone loses but hurts it, a handful of them win.
## Run with: godot --headless -s tests/townsfolk_strength.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


## A slime of `lv`, as the world makes it: [life, damage, seconds between blows].
func _blob(lv: int) -> Array:
	var stats: Dictionary = Enemy.KINDS.schleim.duplicate(true)
	Enemy.fit_level("schleim", stats, 0, lv, SlimeGrowth.MAX_LEVEL)
	if not SlimeGrowth.is_blob_level(lv):
		return [int(stats.hp), int(stats.damage), float(stats.cooldown)]
	var damage := int(stats.damage)
	damage = maxi(damage + 1, roundi(damage * SlimeGrowth.BLOB_DAMAGE))
	return [int(int(stats.hp) * SlimeGrowth.BLOB_LIFE), damage, float(stats.cooldown) * SlimeGrowth.BLOB_PACE]


func _fighter(role: String) -> Array:
	var lv: int = Villager.LEVELS[role]
	return [lv * Villager.LIFE_PER_LEVEL, 1 + lv / Villager.BLOW_DIVISOR]


## Plays the fight second by second: every fighter strikes every BLOW_TIME,
## the slime hits the first one still standing every `gap`. Returns
## [slime life left, fighters left].
func _fight(blob: Array, roles: Array) -> Array:
	var slime_hp: int = blob[0]
	var lives := []
	var blows := []
	for r in roles:
		var f := _fighter(r)
		lives.append(f[0])
		blows.append(f[1])
	var t := 0.0
	var next_hit := 0.0
	var next_blow := 0.0
	while t < 300.0 and slime_hp > 0 and lives.any(func(l): return l > 0):
		if t >= next_blow:
			next_blow += Villager.BLOW_TIME
			for i in lives.size():
				if lives[i] > 0:
					slime_hp -= blows[i]
		if t >= next_hit:
			next_hit += blob[2]
			for i in lives.size():
				if lives[i] > 0:
					lives[i] -= blob[1]
					break
		t += 0.1
	return [maxi(slime_hp, 0), lives.filter(func(l): return l > 0).size()]


func _initialize() -> void:
	for lv in [20, 22, 25]:
		var blob := _blob(lv)
		var alone := _fight(blob, ["4"])
		var share: float = 1.0 - float(alone[0]) / float(blob[0])
		check(alone[1] == 0, "level %d: the guard alone is beaten" % lv)
		check(share >= 0.15, "level %d: but he takes %d%% of its life" % [lv, roundi(share * 100.0)])
		var three := _fight(blob, ["4", "G", "1"])
		check(three[0] == 0 and three[1] < 3, "level %d: three of them win, at a cost (%d left)" % [lv, three[1]])
		var band := _fight(blob, ["4", "G", "1", "O", "0", "K"])
		check(band[0] == 0 and band[1] >= 4, "level %d: a band of six wins with little loss (%d left)" % [lv, band[1]])
	# The weakest fighter does not die in one blow of a level 20 slime.
	var weak := _fighter("7")
	check(weak[0] > _blob(20)[1], "even the weakest takes more than one blow")
	# Small slimes are still no match for them.
	var small := _fight(_blob(5), ["7"])
	check(small[0] == 0 and small[1] == 1, "a lone villager fells a level 5 slime unharmed")
	print("townsfolk_strength: %s" % ("OK" if failures == 0 else "%d failures" % failures))
	quit(1 if failures > 0 else 0)
