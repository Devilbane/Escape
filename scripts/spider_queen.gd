class_name SpiderQueen
extends Enemy
## The Spider Queen, the boss at the bottom of the spider hole (the floor
## "building: loch2b", below "loch2"): a pale spider as big as a cart. A plain
## fight, kept readable: she bites hard up close and throws her web far more
## often than her brood (see Enemy._throw_web), so the hero is slowed while
## she closes in. At half her life she calls her young: BROOD spiders drop
## from the walls beside her, and her webs come quicker. Her health bar shows
## at the top (see BossBar). A stab in the back does not end her: she is big
## (see Enemy "big").

const TITLE := "Die Spinnenkönigin"
## Where she calls her brood, as a share of her life.
const PHASE_AT := [0.5]
## How many spiders she calls, and how much quicker her webs come after.
const BROOD := 2
const RAGE_WEB := 0.6

var phase := 1


func _init() -> void:
	kind = "spinnenkoenigin"


func boss_title() -> String:
	# One made in the map workshop goes by the name it was given there.
	return str(custom.get("title", TITLE))


func phase_marks() -> Array:
	return PHASE_AT


func is_dazed() -> bool:
	return false


func take_hit(damage: int, from: Vector3, hit_kind := "hit", wakes := true) -> void:
	super.take_hit(damage, from, hit_kind, wakes)
	if not dead and phase == 1 and hp <= max_hp() * PHASE_AT[0]:
		phase = 2
		_stats.web = float(_stats.get("web", 4.0)) * RAGE_WEB
		Effects.float_text(level, global_position + Vector3(0, 2.4 * _stats.size, 0), Lang.t("Die Spinnenkönigin ruft ihre Brut!"), Color(0.8, 0.55, 1.0))
		Comic.pop(global_position, "big")
		# Not in the middle of handling the blow: the level's list of
		# monsters may be walked over right now.
		_call_brood.call_deferred()


## Her young come out of the walls on the free tiles around her.
func _call_brood() -> void:
	if dead or not is_inside_tree() or level == null:
		return
	var home := level.world_to_cell(global_position)
	var spots: Array[Vector2i] = []
	for r in [1, 2]:
		for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r), Vector2i(r, r), Vector2i(-r, -r), Vector2i(r, -r), Vector2i(-r, r)]:
			var c: Vector2i = home + d
			if level.cell_char(c) in ".," and not spots.has(c):
				spots.append(c)
	spots.shuffle()
	for i in mini(BROOD, spots.size()):
		var young: Enemy = level._spawn_enemy("spinne", spots[i])
		young.reset_physics_interpolation()


## A boss shrugs off a thunder weapon's crack (see Enemy.shock).
func can_be_stunned() -> bool:
	return false
