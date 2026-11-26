extends SceneTree
## Headless test: the extra storage pieces (crates, barrel, oak chest) add room to the storage chest.
## Run with: godot --headless -s tests/home_storage_extra.gd

var failures := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)

func _initialize() -> void:
	for kind in ["kiste", "fass", "eichentruhe"]:
		var info: Dictionary = HouseFurniture.KINDS.get(kind, {})
		check(not info.is_empty() and info.station == "lager" and int(info.store) > 0, kind + " is a storage piece")
		check(Lang.EN.has(info.name) and Lang.EN.has(info.text), kind + " has English")
	var f := HouseFurniture.new()
	check(f.store_bonus() == 0, "no pieces, no bonus")
	f.placed = [{"kind": "kiste"}, {"kind": "eichentruhe"}, {"kind": "truhe"}]
	check(f.store_bonus() == 48, "crate + oak chest give 48")
	f.placed = []
	for i in 20:
		f.placed.append({"kind": "eichentruhe"})
	check(f.store_bonus() == HouseFurniture.STORE_CAP, "the bonus is capped")
	check(HomeUpgrades.storage_size({}) == 32, "base size stays 32")
	print("PASS" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)
