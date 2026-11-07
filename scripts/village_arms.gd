class_name VillageArms
extends RefCounted
## What each villager fights a slime with (see Villager._fight): the men take
## up the blade that suits their trade (the guard and the herald a sword,
## the smith his hammer, the woodcutter, the stonemason and the guild master
## an axe, the mages a dagger), Pip throws knives from a distance, and the
## priestess does not strike at all but mends the hurt (see Villager.HEAL).
## Blows hit as hard as ever (Villager.blow); only the look and the pace of
## the fight change.

const SWORD := "res://assets/weapons/sword_1handed.gltf"
const AXE := "res://assets/weapons/axe_1handed.gltf"
const DAGGER := "res://assets/weapons/dagger.gltf"
## The smith keeps the hammer already in his hand (see Villager._draw_blade).
const HAMMER := "hammer"

## Roles with their own weapon; everyone else takes a sword.
const WEAPONS := {"4": SWORD, "K": SWORD, "1": HAMMER, "3": AXE, "S": AXE, "G": AXE, "0": DAGGER, "8": DAGGER, "7": DAGGER}
## Roles that do not stand toe to toe: Pip throws knives, the priestess heals.
const THROWERS := ["7"]
const HEALERS := ["O"]

## How far a knife is thrown from, how often, and what it costs the slime
## on top of the thrower's own blow (a little shot, see SlimeCoat.absorb).
const THROW_RANGE := 8.0
const THROW_TIME := 1.6
const KNIFE_BONUS := 1
## The priestess keeps this far from the slime, near enough to reach the
## fighters around it.
const SUPPORT_DISTANCE := 7.0


## How `role` fights: "melee", "throw" or "heal".
static func style(role: String) -> String:
	if role in HEALERS:
		return "heal"
	if role in THROWERS:
		return "throw"
	return "melee"


## The weapon `role` carries into a fight (a scene path, or HAMMER).
static func weapon(role: String) -> String:
	return str(WEAPONS.get(role, SWORD))


## Puts `role`'s weapon in `hand`, named "SlimeBlade".
static func arm(hand: Node3D, role: String) -> Node3D:
	var path := weapon(role)
	var blade: Node3D = (load(path) as PackedScene).instantiate()
	blade.name = "SlimeBlade"
	hand.add_child(blade)
	return blade
