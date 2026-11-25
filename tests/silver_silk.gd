extends SceneTree
## Headless test for silver spider silk (SilverSilk): about one web in ONE_IN is silver, the same
## ones every visit; and the silk is an ingredient with a picture and English texts.
## Run with: godot --headless -s tests/silver_silk.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var silver := 0
	var total := 0
	for x in 60:
		for z in 60:
			var at := Vector3(x * 0.7, 2.0, z * 0.7)
			var s := SilverSilk.is_silver("test_level", at)
			check(s == SilverSilk.is_silver("test_level", at), "the same web is silver on every visit")
			total += 1
			if s:
				silver += 1
	var share := float(silver) / total
	check(share > 0.04 and share < 0.15, "about one web in %d is silver (%.3f)" % [SilverSilk.ONE_IN, share])
	check(Crafting.INGREDIENTS.has(SilverSilk.ID), "silver silk is an ingredient")
	for key in ["name", "where", "region", "source"]:
		check(Lang.EN.has(Crafting.INGREDIENTS[SilverSilk.ID][key]), "silver silk: the %s has an English text" % key)
	check(Lang.EN.has(SilverSilk.LEARN), "the compendium text has an English text")
	check(ItemIcon.kind_of(SilverSilk.ID) == "spider_silk", "silver silk has its own picture")
	check(ResourceLoader.exists("res://assets/ui/icons/spider_silk.svg"), "the silk picture exists")
	if failures == 0:
		print("PASS: silver silk (%d of %d webs silver)" % [silver, total])
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
