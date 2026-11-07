class_name Ignition
extends RefCounted
## Fire and monsters. Creatures with webs, fur or hide catch fire from a
## fireball (a spider, a wolf, the yeti); bone, stone, slime and dragons do
## not. A burning monster shows flames, loses BURN_DAMAGE life every
## BURN_TICK seconds for BURN_TIME seconds and shows "Burning!" over its head.
## Casters (a skeleton mage, the hero's arcane bolt) hurl a fireball instead
## of their usual bolt at a target that can ignite.

const FLAMMABLE := ["spinne", "spinnenkoenigin", "hohle_mutter", "wolf", "eiswolf", "yeti", "bleicher_waechter", "felstroll", "bergkoenig", "bergork", "ork"]
const BURN_TIME := 4.0
const BURN_TICK := 1.0
const BURN_DAMAGE := 1
const COLOR := Color(1.0, 0.5, 0.15)


## Whether `e` is alive, flammable and not burning already.
static func can_ignite(e: Enemy) -> bool:
	return e != null and is_instance_valid(e) and not e.dead and e.burning <= 0.0 and FLAMMABLE.has(e.kind)


## Whether a caster should cast a fireball at `target` (any Node3D).
static func wants_fireball(target: Node) -> bool:
	return target is Enemy and can_ignite(target as Enemy)


## Flames on a monster, for as long as it burns.
static func make_flames(size: float) -> Node3D:
	var flame := Effects.make_flame()
	flame.position = Vector3(0, 0.8 * size, 0)
	flame.scale = Vector3.ONE * 2.0 * size
	flame.name = "BurnFlames"
	return flame


## The village's mages and how hard their fireballs hit (Villager roles):
## Aldo the elder is far stronger than Odo the scholar.
const VILLAGE_MAGES := {"0": 6, "8": 2}
## How far they see a target, and the pause between two fireballs.
const VILLAGE_RANGE := 14.0
const VILLAGE_COOL := 3.0
