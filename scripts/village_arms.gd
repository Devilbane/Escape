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
## Zarek's staff: a level 50 mage who fights from a distance (see CASTERS).
const STAFF := "res://assets/weapons/Skeleton_Staff.gltf"

## Roles with their own weapon; everyone else takes a sword.
const WEAPONS := {"4": SWORD, "K": SWORD, "1": HAMMER, "3": AXE, "S": AXE, "G": AXE, "0": DAGGER, "8": DAGGER, "7": DAGGER, "%": STAFF}
## Roles that do not stand toe to toe: Pip throws knives, the priestess heals.
const THROWERS := ["7"]
const HEALERS := ["O"]
## Zarek the wandering merchant is a level 50 mage: he hurls spells at every
## slime he sees (see Villager._cast_spell) and keeps his distance.
const CASTERS := ["%"]
## How far he sees a slime to attack, how far he casts from, how close a
## slime may come before he steps back, and the pause between two spells.
const CAST_HUNT := 13.0
const CAST_RANGE := 10.0
const CAST_KEEP_AWAY := 4.0
const CAST_TIME := 2.0
## Zarek stays near his wagon: he steps at most this far from his pitch to
## cast, and only goes for slimes within CAST_HUNT of it.
const CAST_LEASH := 5.0
## An arcane bolt costs a slime this many times his blow (Villager.blow);
## every CAST_FIRE_EVERY-th spell is a fireball worth FIRE_FACTOR blows.
const BOLT_FACTOR := 2
const FIRE_FACTOR := 3
const CAST_FIRE_EVERY := 3

## How far a knife is thrown from, how often, and what it costs the slime
## on top of the thrower's own blow (a little shot, see SlimeCoat.absorb).
const THROW_RANGE := 8.0
const THROW_TIME := 1.6
const KNIFE_BONUS := 0
## Every fighter who stands toe to toe carries this many throwing knives, thrown
## at a slime from afar before he closes in; they are back in his belt every night. Pip throws without end, Zarek casts and the priestess heals.
const KNIVES := 3
## The priestess keeps this far from the slime, near enough to reach the
## fighters around it.
const SUPPORT_DISTANCE := 7.0


## How `role` fights: "melee", "throw", "cast" or "heal".
static func style(role: String) -> String:
	if role in HEALERS:
		return "heal"
	if role in THROWERS:
		return "throw"
	if role in CASTERS:
		return "cast"
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
