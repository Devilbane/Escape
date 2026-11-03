class_name MountainKing
extends Enemy
## The Mountain King, the boss deep in the third mine (see Mines): a rock
## troll grown huge on the mountain's heat. A plain fight, kept readable:
## big, slow blows to step away from, and at half his life he rages, his
## blows coming quicker and his glow turning bright. His health bar shows at
## the top (see BossBar).

const TITLE := "Der Bergkönig"
## Where his rage begins, as a share of his life.
const PHASE_AT := [0.5]
const RAGE_COOLDOWN := 0.75
const RAGE_SPEED := 1.15

var phase := 1


func _init() -> void:
	kind = "bergkoenig"


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
		_stats.cooldown *= RAGE_COOLDOWN
		_stats.speed *= RAGE_SPEED
		Effects.float_text(level, global_position + Vector3(0, 2.4 * _stats.size, 0), Lang.t("Der Bergkönig tobt!"), Color(1.0, 0.45, 0.2))
		for light in find_children("*", "OmniLight3D", false, false):
			light.light_energy *= 2.5


## A boss shrugs off a thunder weapon's crack (see Enemy.shock).
func can_be_stunned() -> bool:
	return false
