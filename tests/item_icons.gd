extends SceneTree
## Headless test for the painted item and HUD pictures (ItemIcon, made by
## tools/make_icons.py into assets/ui/icons): every item of the game gets a
## painted picture or a drawn one, the pictures in the item's own colour have
## their grey part to tint, the pictures are large enough to stay sharp and
## have mipmaps, and the tiles sit in a bronze slot.
## Run with: godot --headless -s tests/item_icons.gd

var failures := 0
var frames := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_test()
	return false


## Kinds still drawn with shapes: symbols and swatches, not things.
const DRAWN := ["up", "down", "plus", "chev_up", "chev_down", "hair", "paw"]
## Kinds whose picture takes the item's colour.
const TINTED := ["helmet", "cloak", "armour", "gloves", "boots", "bracelet", "bag", "ore", "ring", "heal_potion", "coin", "bar"]


func _test() -> void:
	# Every item is painted (or a known drawn symbol).
	var unpainted := []
	for id in Items.ALL:
		var kind := ItemIcon.art_kind(ItemIcon.kind_of(id))
		if ItemIcon.art(kind)[0] == null and not kind in DRAWN:
			unpainted.append("%s (%s)" % [id, kind])
	check(unpainted.is_empty(), "every item has a painted picture: %s" % [unpainted])
	for kind in TINTED:
		var art: Array = ItemIcon.art(kind)
		check(art[0] != null and art[1] != null, "%s has a picture and a part to tint" % kind)
	for kind in ["map", "book", "bag", "hero", "scroll", "house", "torch", "torch_out", "coin", "sword", "shield", "boots", "hammer_anvil", "stone", "flame"]:
		var art: Array = ItemIcon.art(kind)
		check(art[0] != null, "the HUD's %s picture is painted" % kind)
		if art[0] != null:
			var tex: Texture2D = art[0]
			check(tex.get_width() >= 128, "the %s picture is made large enough: %d" % [kind, tex.get_width()])
			check(tex.get_image().has_mipmaps(), "the %s picture has mipmaps" % kind)
	# A picture is loaded once.
	check(ItemIcon.art("sword")[0] == ItemIcon.art("sword")[0], "a picture is loaded once")
	# Tints: a ruby ring is red, a coin takes its metal.
	var ring := ItemIcon.make("rubinring")
	check(ring.tint_of("ring").r > 0.8 and ring.tint_of("ring").g < 0.4, "a ruby ring's stone is red")
	var copper := ItemIcon.make("kupfermuenze")
	check(copper.tint_of("coin") == Loot.COIN_COLORS["kupfermuenze"], "a copper coin takes its metal")
	ring.free()
	copper.free()
	# The tile sits in a bronze slot.
	check(ItemIcon._slot(3) is BronzeStyle, "an item's tile is a bronze slot")
	if failures == 0:
		print("PASS: item icons")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
