class_name Bleeding
extends RefCounted
## Bleeding: a cutting hit (a blade, an axe, a dagger, a bolt, claws or
## fangs; not a club, a hammer, a fist, magic or fire) opens a wound with
## CHANCE. The wound bleeds away as much life as the hit cost, one life per
## second, and twice as fast (MOVING_RATE) while the bleeder moves: the
## same life, lost in half the time.
##
## Wounds add up: a new one adds its life to what the old one still has to
## bleed, and the flow stays the same, so it lasts longer. A vital hit
## (see MonsterLore.BLEED_CHANCE) opens a wound with any weapon.
##
## The hero and the monsters each keep one Bleeding (see Player.bleed and
## Enemy.bleed). The hero's bleeding is an ailment with an icon under the
## life bar ("blut", see StatusIcon) and, like poison and burning, never
## takes the last life; a ghost has no blood; a monster can bleed to death,
## which counts as the hero's kill.

## How often a cutting hit that costs life opens a wound.
const CHANCE := 0.2
## Life lost per second while standing, and while moving.
const RATE := 1.0
const MOVING_RATE := 2.0
## Faster than this (metres a second, along the ground) counts as moving.
const MOVING_SPEED := 0.5
## The red of the words and numbers of bleeding.
const COLOR := Color(0.9, 0.15, 0.15)
## The hero's weapons that strike blunt: maces and hammers. Every other
## weapon (and the hero's own dagger) cuts, and so do thrown knives.
const BLUNT_WEAPONS := ["streitkolben", "kriegshammer", "donnerhammer", "runenhammer"]
## The weapons monsters hold that cut (Enemy.KINDS "weapon"): blades, axes,
## daggers, swords and crossbows. A staff does not.
const CUTTING_WEAPONS := ["Skeleton_Blade", "Skeleton_Axe", "Skeleton_Crossbow", "dagger", "sword_1handed", "axe_1handed"]
## The beasts whose claws or fangs cut. Orcs, yetis and trolls punch, slimes
## smother, dragons burn.
const CLAWED := ["wolf", "eiswolf", "spinne", "spinnenkoenigin", "hohle_mutter", "fledermaus", "ghul"]

## Life still to bleed away, and the share of the next life already lost.
var left := 0
var _flow := 0.0
var _drip := 0.0
## Seconds between two drops of blood that fall to the floor (see
## BloodDrops), standing and moving.
const DRIP_STANDING := 0.8
const DRIP_MOVING := 0.3


## Whether the hero's weapon `id` cuts ("" is the hero's own dagger).
static func weapon_cuts(id: String) -> bool:
	return not id in BLUNT_WEAPONS


## Whether a monster of kind `kind` with KINDS entry `stats` cuts with its
## blows and shots. Ghosts' blows are a cold touch, magic and fire burn.
static func monster_cuts(kind: String, stats: Dictionary) -> bool:
	if stats.has("ghost") or stats.get("magic", false) or stats.get("fire", false):
		return false
	return str(stats.get("weapon", "")) in CUTTING_WEAPONS or kind in CLAWED


## A hit that cost `lost` life rolls for a wound: with `chance` (CHANCE for a
## cutting hit) it opens one. `roll` is for the tests.
static func rolls_wound(lost: int, chance := CHANCE, roll := -1.0) -> bool:
	return lost > 0 and (randf() if roll < 0.0 else roll) < chance


## Opens a wound that bleeds `amount` life, on top of what is still left.
## Returns whether it is a fresh wound (nothing was bleeding before).
func open(amount: int) -> bool:
	if amount <= 0:
		return false
	var fresh := left <= 0
	if fresh:
		_flow = 0.0
	left += amount
	return fresh


func active() -> bool:
	return left > 0


## The wound stops (cured, or the bleeder died).
func stop() -> void:
	left = 0
	_flow = 0.0
	_drip = 0.0


## Whether a drop of blood falls in this `delta`: one at once, then one every
## DRIP_STANDING seconds, or DRIP_MOVING while the bleeder moves.
func drips(delta: float, moving: bool) -> bool:
	if left <= 0:
		return false
	_drip -= delta
	if _drip > 0.0:
		return false
	_drip = DRIP_MOVING if moving else DRIP_STANDING
	return true


## Lets `delta` seconds of blood run, faster while `moving`; returns the
## whole lives lost in that time (never more than are left).
func run(delta: float, moving: bool) -> int:
	if left <= 0:
		return 0
	_flow += delta * (MOVING_RATE if moving else RATE)
	var lost := mini(floori(_flow), left)
	_flow -= lost
	left -= lost
	if left <= 0:
		_flow = 0.0
	return lost


## Seconds until the wound has bled out, standing still.
func seconds_left() -> float:
	return maxf(0.0, (left - _flow) / RATE)
