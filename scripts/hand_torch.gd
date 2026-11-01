class_name HandTorch
extends Node
## The hero's hand torch, for the pitch-black places (levels with the line
## "dark: yes", such as the creepy holes in the wild). Torches ("fackel")
## are bought from the shopkeeper and carried in the bag. In the dark one is
## lit by itself and burns for BURN seconds, then the next one is lit, until
## the bag holds none. Without a burning torch the hero sees hardly more
## than the tile they stand on (DARK_REACH, see Fog), and even with one only
## a few steps around (TORCH_REACH). A burning torch cannot be hooded: every
## monster down there sees the hero coming.
## Back in the light the torch is put out, and what is left of it burns on
## the next time it gets dark.

## A word for the message line (see Game.show_message).
signal notice(text: String, duration: float)

const ITEM := "fackel"
## How long one torch burns (seconds), and when it starts to gutter.
const BURN := 180.0
const LOW := 30.0
## How far the hero sees in the dark (metres): without a torch the own tile
## and barely the next, with one the tiles around and not much more.
const DARK_REACH := 2.6
const TORCH_REACH := 6.2
## The hero's lantern in the dark: a glimmer that only shows the feet.
const DARK_LANTERN_ENERGY := 0.12
const DARK_LANTERN_RANGE := 3.0
const LIGHT_COLOR := Color(1.0, 0.58, 0.26)
const LIGHT_ENERGY := 2.0
const LIGHT_RANGE := 7.5

var player: Player
## Seconds left on the torch in hand; 0 when there is none.
var left := 0.0
## Whether it burns right now.
var lit := false
var _was_dark := false
var _warned := false
var _holder: Node3D
var _light: OmniLight3D
var _time := 0.0


func _init(hero: Player) -> void:
	player = hero


## Whether the hero is somewhere pitch black right now.
func in_dark() -> bool:
	return is_instance_valid(player.level) and player.level.pitch_dark


## How far the hero sees in the dark (see Fog).
func light_reach() -> float:
	return TORCH_REACH if lit else DARK_REACH


## Torches in the bag, not counting the one in hand.
func spare() -> int:
	return player.bag.count(ITEM)


func _process(delta: float) -> void:
	var dark: bool = in_dark() and not player.dead
	if dark and not lit:
		if left <= 0.0 and player.bag.has(ITEM):
			player.bag.erase(ITEM)
			left = BURN
			_warned = false
			notice.emit(Lang.t("Du zündest eine Fackel an. Noch %d im Beutel.") % spare(), 2.4)
		if left > 0.0:
			_set_lit(true)
	elif not dark and lit:
		_set_lit(false)
	if dark != _was_dark:
		_was_dark = dark
		if not dark:
			# Out of the dark: the lantern shines as before.
			player.set_sneaking(player.sneaking)
	if dark:
		# Whatever the sneaking did to it, the lantern is all but useless here.
		player._lantern.light_energy = DARK_LANTERN_ENERGY
		player._lantern.omni_range = DARK_LANTERN_RANGE
	if not lit:
		return
	if not is_instance_valid(_holder):
		_make_holder()
	_time += delta
	# The flame flickers, and gutters when it is nearly burnt down.
	var low := clampf(left / LOW, 0.35, 1.0)
	_light.light_energy = LIGHT_ENERGY * low * (0.85 + 0.15 * sin(_time * 13.0) * sin(_time * 7.3))
	_light.omni_range = LIGHT_RANGE * lerpf(0.75, 1.0, low)
	if player.frozen:
		return # A window is open or the hero is on the way: time stands still.
	left -= delta
	if left <= LOW and not _warned:
		_warned = true
		notice.emit(Lang.t("Deine Fackel flackert. Sie brennt bald aus."), 2.4)
	if left <= 0.0:
		left = 0.0
		_set_lit(false)
		if player.bag.has(ITEM):
			player.bag.erase(ITEM)
			left = BURN
			_warned = false
			_set_lit(true)
			notice.emit(Lang.t("Die Fackel ist heruntergebrannt. Du zündest die nächste an."), 2.4)
		else:
			Sfx.play(player, "drip", -4.0)
			notice.emit(Lang.t("Deine Fackel ist erloschen! Finsternis umgibt dich."), 3.0)


func _set_lit(on: bool) -> void:
	lit = on
	if on:
		_make_holder()
		Sfx.play(player, "magic", -14.0, null, 0.6)
	elif is_instance_valid(_holder):
		_holder.queue_free()
		_holder = null
	if is_instance_valid(_light):
		_light.visible = on


## The torch in the hero's left hand, a flame on its tip, and the light it
## throws (hung on the hero, not the hand, so it does not swing about).
func _make_holder() -> void:
	if is_instance_valid(_holder):
		return
	var hand: Node3D = player.find_child("handslot_l", true, false)
	_holder = Node3D.new()
	_holder.name = "Torch"
	if hand:
		hand.add_child(_holder)
	else:
		_holder.position = Vector3(0.45, 1.4, 0.3)
		player.add_child(_holder)
	var stick := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.045
	rod.bottom_radius = 0.03
	rod.height = 0.6
	stick.mesh = rod
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.11)
	stick.material_override = wood
	stick.position = Vector3(0, 0.15, 0)
	_holder.add_child(stick)
	var flame := Effects.make_flame()
	flame.scale = Vector3.ONE * 0.55
	flame.position = Vector3(0, 0.5, 0)
	_holder.add_child(flame)
	if not is_instance_valid(_light):
		_light = OmniLight3D.new()
		_light.light_color = LIGHT_COLOR
		_light.light_energy = LIGHT_ENERGY
		_light.omni_range = LIGHT_RANGE
		_light.omni_attenuation = 1.4
		_light.position = Vector3(0.4, 2.4, 0.5)
		player.add_child(_light)
	_light.visible = true
