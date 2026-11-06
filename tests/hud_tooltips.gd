extends SceneTree
## Headless test for the HUD's hover tooltips: with the pointer resting on
## the life bar, the throwing knives, a trouble icon under the bar, the run
## meter, the experience bar, the gold or the key, that is the control the
## pointer is over (nothing on the HUD covers it), it has a tooltip in the
## house style, and the text follows the values.
## Run with: godot --headless --fixed-fps 60 -s tests/hud_tooltips.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	if failures == 0:
		print("PASS: hud tooltips")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


## The control the pointer would be over at `at` (screen pixels), picked the
## way Godot's GUI picks it: the highest canvas layer first, within one the
## last drawn first, children before their parent, skipping hidden controls
## and those that ignore the pointer (their children still count). (A
## headless run has no real pointer to move.)
func _hovered(at: Vector2) -> Control:
	var layers: Array = []
	_collect_layers(root, layers)
	layers.sort_custom(func(a, b): return _layer_of(a) > _layer_of(b))
	for holder in layers:
		var hit := _pick(holder, at)
		if hit != null:
			return hit
	return null


func _layer_of(n: Node) -> int:
	return (n as CanvasLayer).layer if n is CanvasLayer else 0


func _collect_layers(n: Node, into: Array) -> void:
	if n == root or n is CanvasLayer:
		if n is CanvasLayer and not (n as CanvasLayer).visible:
			return
		into.append(n)
	for c in n.get_children():
		if not (c is Window):
			_collect_layers(c, into)


func _pick(n: Node, at: Vector2) -> Control:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return null
	var children := n.get_children()
	children.reverse()
	for c in children:
		if c is CanvasLayer or c is Window:
			continue
		var hit := _pick(c, at)
		if hit != null:
			return hit
	if n is Control and n != root:
		var c := n as Control
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(at):
			return c
	return null


## Whether `c` or a control above it carries the house tooltip theme.
func _house_style(c: Control) -> bool:
	var n: Node = c
	while n is Control:
		var t: Theme = (n as Control).theme
		if t != null and t.has_stylebox("panel", "TooltipPanel"):
			return true
		n = n.get_parent()
	return false


## Hovers the middle of `target` and checks a tooltip shows there.
func _check_hover(target: Control, name: String) -> Control:
	var under := _hovered(target.get_global_rect().get_center())
	check(under != null, "%s: something is under the pointer" % name)
	if under == null:
		return null
	check(under.tooltip_text != "", "%s has a tooltip (under the pointer: %s)" % [name, under])
	check(_house_style(under), "%s's tooltip has the house style" % name)
	return under


func _run() -> void:
	var hero: Player = game.player
	game.state = game.State.PLAYING
	hero.hp = maxi(1, hero.max_hp / 2)
	hero.knives = 2
	hero.ailments["gift"] = 5.0
	game._update_hud()
	game._update_run_meter()
	game._place_hp_bar()
	await _wait(3)

	# The life bar: a strip a little taller than the slim bar takes the
	# pointer, and names the life in numbers.
	var bar: Rect2 = game._hp_bar.get_global_rect()
	var life := _check_hover(game._hp_bar, "the life bar")
	check(life == game._hp_hover, "the pointer on the life bar is over its hover strip")
	if life != null:
		check(str(hero.hp) in life.tooltip_text and str(hero.max_hp) in life.tooltip_text,
				"the life tooltip names the life: %s" % life.tooltip_text)
	var above := _hovered(Vector2(bar.get_center().x, bar.position.y - 3))
	check(above == game._hp_hover, "just above the slim bar still shows its tooltip")
	var strip: Rect2 = game._hp_hover.get_global_rect()
	check(strip.end.y <= game._ammo_row.get_global_rect().position.y,
			"the hover strip stops above the ammunition row")
	hero.hp -= 1
	hero._regen_pause = Player.REGEN_PAUSE_AFTER_HIT
	game._update_hud()
	check(hero.regen_paused() and game._hp_hover.tooltip_text != Lang.t("Leben: %d von %d") % [hero.hp, hero.max_hp],
			"freshly hit, the life tooltip says the healing waits: %s" % game._hp_hover.tooltip_text)
	hero.hp = hero.max_hp
	game._update_hud()
	check(game._hp_hover.tooltip_text == Lang.t("Leben: %d von %d") % [hero.max_hp, hero.max_hp],
			"at full life only the numbers: %s" % game._hp_hover.tooltip_text)

	# The throwing knives under the bar.
	var knives := _check_hover(game._ammo_counts["knives"], "the throwing knives")
	if knives != null:
		check("2" in knives.tooltip_text, "the knives tooltip names the count: %s" % knives.tooltip_text)
		check(str(hero.throw_power()) in knives.tooltip_text and "%d%%" % roundi(Projectile.KNIFE_BREAK_CHANCE * 100.0) in knives.tooltip_text,
				"the knives tooltip names the damage and the break chance: %s" % knives.tooltip_text)
		check(" R " in knives.tooltip_text, "the knives tooltip names the key to throw: %s" % knives.tooltip_text)

	# A trouble icon under the bar.
	check(game._status_row.get_child_count() > 0, "poison shows an icon under the bar")
	if game._status_row.get_child_count() > 0:
		var icon := _check_hover(game._status_row.get_child(0), "the poison icon")
		check(icon is StatusIcon, "the pointer is over the poison icon itself")

	# The status block at the top left.
	var run := _check_hover(game._run_bar, "the run meter")
	check(run == game._run_row, "the run meter's row takes the pointer")
	var xp := _check_hover(game._xp_bar, "the experience bar")
	check(xp == game._xp_row, "the experience row takes the pointer")
	if xp != null:
		var step := HeroLevel.progress(hero.hero_xp)
		check(str(step.y) in xp.tooltip_text, "the experience tooltip names what the level takes: %s" % xp.tooltip_text)
	var gold := _check_hover(game._coin_label, "the gold")
	check(gold == game._coin_label, "the pointer on the gold is over the gold")
	# Copper, silver and gold coins each show a picture and their count.
	game.crafting.set_count("silbermuenze", 3)
	game.crafting.set_count("goldmuenze", 0)
	game._update_hud()
	check(game._coin_label.text == str(game.coins), "the copper count is a plain number: %s" % game._coin_label.text)
	check(game._silver_label.text == "3", "three silver coins are counted: %s" % game._silver_label.text)
	check(game._gold_label.text == "0" and game._gold_label.modulate.a < 1.0, "no gold coins: a dimmed 0")
	for id in game.PURSE_COINS:
		check(game._coin_icons[id].what == id, "the %s coin has its own picture" % id)
	check(_check_hover(game._silver_label, "the silver") == game._silver_label, "the silver count takes the pointer")
	game.crafting.set_count("silbermuenze", 0)
	if game._key_label.visible:
		_check_hover(game._key_label, "the key")

	# Carrying on from the title fades it out: its language buttons must not
	# stay behind, unseen, over the life bar and take the pointer from it.
	game._show_start_title("Escape!", "")
	check(game._lang_row.visible, "the title offers the languages")
	game._leave_title(func(): pass)
	await _wait(40)
	game.state = game.State.PLAYING
	game._place_hp_bar()
	check(not game._lang_row.visible, "the language buttons are gone once the game goes on")
	_check_hover(game._hp_bar, "the life bar after leaving the title")
	_check_hover(game._ammo_counts["knives"], "the knives after leaving the title")

	# Every tooltip has English.
	var was := Lang.language
	Lang.language = "en"
	Lang._apply()
	game._update_hud()
	game._update_run_meter()
	for c in [game._hp_hover, game._xp_row, game._run_row, game._coin_label, game._ammo_counts["knives"].get_parent()]:
		check(not ("ä" in c.tooltip_text or "ü" in c.tooltip_text or " von " in c.tooltip_text),
				"in English: %s" % c.tooltip_text)
	Lang.language = was
	Lang._apply()
	hero.ailments.erase("gift")
	_finish()

