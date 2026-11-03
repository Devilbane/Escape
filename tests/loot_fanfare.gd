extends SceneTree
## Headless test for the fanfares of loot finer than rare (Sfx.RARITY_SOUNDS):
## epic and god-born gear each ring out a sound of their own, the god-born
## one longer than the epic one, common to rare gear stays plain, and of a
## heap of drops only the finest piece sings.
## Run with: godot --headless -s tests/loot_fanfare.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var by_tier := {}
	for id in Items.ALL:
		var tier := Level.tier_of(id)
		if not by_tier.has(tier):
			by_tier[tier] = id
	for tier in Level.TIERS:
		check(by_tier.has(tier), "some gear is %s" % tier)
	var order: Array = Level.TIERS.keys()
	var rare_at := order.find("selten")
	for tier in by_tier:
		var sound := Sfx.rarity_sound(by_tier[tier])
		if order.find(tier) > rare_at:
			check(sound != "", "%s gear has a fanfare" % tier)
			check(ResourceLoader.exists(Sfx.DIR + sound + ".wav"), "%s.wav exists" % sound)
		else:
			check(sound == "", "%s gear has no fanfare" % tier)
	# Each tier above rare sounds bigger than the one below it.
	var epic: AudioStream = load(Sfx.DIR + "loot_epic.wav")
	var god: AudioStream = load(Sfx.DIR + "loot_godborn.wav")
	check(epic != null and god != null, "fanfares load")
	if epic and god:
		check(god.get_length() > epic.get_length() + 0.5, "the god-born fanfare is the longer one")
	check(Sfx.RARITY_SOUNDS["episch"] != Sfx.RARITY_SOUNDS["gottgeboren"], "each tier has its own sound")
	# Of a heap, the finest piece sings; a heap of plain gear stays quiet.
	if by_tier.has("episch") and by_tier.has("gottgeboren"):
		var heap := [by_tier.get("normal", ""), by_tier["episch"], by_tier["gottgeboren"], by_tier.get("selten", "")]
		check(Sfx.finest(heap) == by_tier["gottgeboren"], "the god-born piece outshines the epic one")
	check(Sfx.finest([by_tier.get("normal", ""), by_tier.get("selten", "")]) == "", "plain gear stays quiet")
	check(Sfx.finest([]) == "", "no drops, no fanfare")
	if failures == 0:
		print("PASS: loot fanfare")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
