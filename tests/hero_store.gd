extends SceneTree
## Headless test for HeroStore (scripts/sim/hero_store.gd): a server keeps one
## record per hero, reads it back at the current version, refuses records from
## newer builds and never lets a name reach outside its folder.
## Run with: godot --headless -s tests/hero_store.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var memory := Storage.Memory.new()
	Storage.use(memory)
	check(HeroStore.key("Alrik") == "hero_alrik", "a plain name stays readable")
	check(HeroStore.key("Alrik") == HeroStore.key(" ALRIK "), "case and spaces around do not matter")
	for name in ["../evil", "a/b", "c:\\x", "Jörg", "x.json"]:
		var key := HeroStore.key(name)
		check(not key.contains("/") and not key.contains("\\") and not key.contains(".") and not key.contains(":"), "%s gives a safe record name" % name)
	check(HeroStore.key("Jörg") != HeroStore.key("Jorg"), "letters outside a-z stay apart")

	check(HeroStore.load_hero("Niemand").is_empty(), "an unknown hero has no record")
	check(not HeroStore.has("Niemand"), "an unknown hero is not kept")
	check(HeroStore.save_hero({"version": SaveFormat.VERSION, "name": "Alrik", "coins": 12}), "a record is kept")
	var back := HeroStore.load_hero("alrik")
	check(int(back.get("coins", 0)) == 12 and int(back.version) == SaveFormat.VERSION, "the record comes back")
	memory.write(HeroStore.key("Alt"), {"version": 1, "name": "Alt"})
	check(int(HeroStore.load_hero("Alt").version) == SaveFormat.VERSION, "an old record comes back up to date")
	check(not HeroStore.save_hero({"version": SaveFormat.VERSION + 1, "name": "Neu"}), "a record from a newer build is refused")
	check(not HeroStore.save_hero({"version": SaveFormat.VERSION}), "a record without a name is refused")
	Storage.use(null)

	if failures == 0:
		print("PASS: hero store")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
