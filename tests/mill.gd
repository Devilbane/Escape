extends SceneTree
## Headless test for the mill one walks into and its miller (see MillTower, Mill, VillageHalls):
## - the windmill is a hall of stone with the kit's tower, cap and sails on it, the sails turn and
##   so does the runner stone in the mill room;
## - Korbinian the miller lives in the village and keeps the mill;
## - he sells grain for the chicks, and Mira's shop no longer does;
## - he hands out a sack of flour for Fritz at the tavern, who pays for it.
## Run with: godot --headless --fixed-fps 60 -s tests/mill.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _villager(role: String) -> Villager:
	for v in game.level.villagers:
		if v.role == role:
			return v
	return null


func _bump(v: Villager) -> void:
	v._update_bubble(Villager.MIN_SAY_TIME)
	game._use_station(v.station)


func _run() -> void:
	if game.state == game.State.TITLE:
		game._start_playing()
	game.hero_name = "Mill test"
	game.quests.clear()
	game.coins = 40
	game.player.bag.clear()
	game.day_hour = 10.0
	game.load_level(game._outdoor_index(), false)
	game.state = game.State.PLAYING
	await _wait(10)
	var lvl: Outdoor = game.level

	# --- The mill -------------------------------------------------------------------------
	var mills: Array = lvl.walk_in.buildings.filter(func(r): return r.kind == "mill")
	check(mills.size() == 1, "the windmill is a hall one walks into")
	if mills.is_empty():
		_end()
		return
	var rec: Dictionary = mills[0]
	var tower: Node3D = null
	for part in rec.up:
		if part is Node3D and (part as Node3D).has_meta("mill_tower"):
			tower = part
	check(tower != null, "the kit's tower stands on the mill's stone storey and hides with its floor above")
	var turning: Windmill = null
	for w: Windmill in lvl.windmills:
		if w.hall == rec.node:
			turning = w
	check(turning != null, "its sails turn (see Windmill)")
	var runner := (rec.node as Node3D).find_child("Runner", true, false) as Node3D
	check(runner != null, "the mill room has its millstones")
	if runner != null and turning != null:
		var before := runner.rotation.y
		await _wait(30)
		check(not is_equal_approx(runner.rotation.y, before), "the runner stone turns with the sails")
	check(lvl.walk_in.is_on("u"), "the mill can be switched off on its own (WalkIn.halls)")

	# --- The miller -----------------------------------------------------------------------
	var miller := _villager(VillageHalls.KEEPERS.mill)
	check(miller != null and miller.station.kind == Mill.KIND, "Korbinian the miller lives in the village and trades grain")
	check(Lang.EN.has(Villager.ROLES[VillageHalls.KEEPERS.mill].name), "the miller's name has an English entry")
	if miller == null:
		_end()
		return
	# Mira's shop no longer keeps grain: the miller sells it.
	game.shop_stock.clear()
	game.menus._build_shop()
	game.menus.close()
	check(not game.shop_stock.has(VillageBirds.SEEDS), "Mira's shop no longer sells grain")

	# The flour for the tavern: a task first, outside the mill too.
	_bump(miller)
	check(game.quests.is_active("mehl") and game.player.bag.has(Mill.FLOUR), "the miller hands over a sack of flour for the tavern")
	check(Lang.EN.has(Items.ALL[Mill.FLOUR].name) and Lang.EN.has(Quests.ALL.mehl.title), "the flour and its task have English")
	game.menus.close()
	game.state = game.State.PLAYING
	var coins: int = game.coins
	_bump(_villager("5"))
	check(game.quests.is_done("mehl") and not game.player.bag.has(Mill.FLOUR), "Fritz at the tavern takes the flour")
	check(game.coins == coins + int(Quests.ALL.mehl.gold), "and pays for it")
	game.menus.close()
	game.state = game.State.PLAYING

	# Grain from his counter in the mill, once he is at his place.
	for i in 60 * 50:
		await physics_frame
		if VillagePosts.at_post(miller):
			break
	check(VillagePosts.at_post(miller), "by day the miller works behind his counter in the mill (%s, %s)" % [miller._task, miller.post_trip.get("step", "-")])
	_bump(miller)
	await _wait(2)
	check(game.menus.current == Mill.KIND, "at his counter his window opens")
	var had: int = game.coins
	game.menus._buy_grain(3)
	check(game.player.bag.count(VillageBirds.SEEDS) == 3 and game.coins < had, "the hero buys grain for the chicks")
	game.menus.close()
	_end()


func _end() -> void:
	if failures == 0:
		print("PASS: mill")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
