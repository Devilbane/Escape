extends SceneTree
## Headless test for the deed book of the own mines (see MineClaims): one mine per own mining plot, over a prospecting
## mark on it, offline mining, and the property register line.
## Run with: godot --headless -s tests/mine_claims.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _mark(cell: Vector2i, ore_main := "basalt") -> Dictionary:
	var s := {"cell": [cell.x, cell.y], "source": "berg", "main": ore_main, "main_pct": 70, "second": "", "second_pct": 0,
			"trace_pct": 8, "traces": [{"id": "malachit", "pct": 8}], "noise": "basalt", "noise_pct": 2, "anomaly": "", "anomaly_pct": 0}
	return Prospecting.mark_from(s)


func _initialize() -> void:
	Storage.use(Storage.Memory.new())
	Plots.reload()
	MineClaims.reload()
	var level := Outdoor.new()
	level.load_from_file("res://levels/11_die_freiheit.txt")
	var rect := Rect2i()
	for y in range(level.height - 2):
		for x in range(level.grid[y].length() - 2):
			var r := Rect2i(x, y, 2, 2)
			if rect.size == Vector2i.ZERO and Plots.problem(level, r, Plots.MINING) == "":
				rect = r
	check(rect.size != Vector2i.ZERO, "found a scree plot")
	var marks := [_mark(rect.position)]
	check(MineClaims.problem("Ann", rect, marks) == "plot", "no mine without an own mining plot")
	check(Plots.register(level, "Ann", rect, Plots.MINING) == "", "plot registered")
	check(MineClaims.problem("Bob", rect, marks) == "plot", "not another hero's plot")
	check(MineClaims.problem("Ann", rect, []) == "mark", "needs a mark on the plot")
	check(MineClaims.problem("Ann", rect, [_mark(rect.position + Vector2i(20, 20))]) == "mark", "mark must lie on the plot")
	var empty := _mark(rect.position)
	empty.report = {"ore": "", "chance": "spur", "richness": "arm", "also": "", "warn": "", "deeper": false}
	check(MineClaims.problem("Ann", rect, [empty]) == "barren", "barren rock gives no mine")
	check(MineClaims.open("Ann", rect, marks, 0.0) == "", "mine opened")
	check(MineClaims.has_mine(rect), "mine is kept")
	check(MineClaims.open("Ann", rect, marks, 0.0) == "have", "only one mine per plot")
	MineClaims.reload()
	check(MineClaims.has_mine(rect), "mine is read back from storage")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mine := MineClaims.on_plot(rect)
	var hard := MineWork.is_hard(mine)
	var made := MineClaims.catch_up(rect, 8.0 * 3600.0, rng)
	check(made == (0 if hard else 2) or made == 1 or made == 2, "offline mining made advances")
	check(PropertyRegister.rows(Plots.MINING, "Ann", level)[0].detail.contains("Stollen"), "register line")
	MineClaims.release("Ann")
	check(not MineClaims.has_mine(rect), "mines released")
	print("mine_claims: ", "ok" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
