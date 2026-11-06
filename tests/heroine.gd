extends SceneTree
## Headless test for the hero's body: a new game asks for a hero or a
## heroine, the heroine has a body and a face of her own, hair styles, hats,
## armour and sleep work on both, the choice comes back from a saved game,
## older saved games have a hero, and the village women share the look.
## Run with: godot --headless -s tests/heroine.gd

var failures := 0
var game: Node
var frames := 0
const HERO := "Heroine test"


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


## The game needs a few frames to set itself up first.
func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	_test()
	game.delete_save(game.save_path())
	if failures == 0:
		print("PASS: heroine")
	else:
		print("FAILED: ", failures)
	quit(1 if failures > 0 else 0)
	return true


func _mesh(part: String) -> Mesh:
	return (game.player.find_child(part, true, false) as MeshInstance3D).mesh


func _source(part: String) -> Mesh:
	return (game.player.find_child(part, true, false) as MeshInstance3D).get_meta("body_source")


func _shown(part: String) -> bool:
	var node := game.player.find_child(part, true, false) as Node3D
	return node != null and node.visible


func _model_scale() -> float:
	return (game.player.find_child("Rig", true, false).get_parent() as Node3D).scale.y


func _test() -> void:
	var p: Player = game.player
	check(p.sex == "male", "a hero starts as a man")
	check(_mesh("Rogue_Body") == _source("Rogue_Body") or _mesh("Rogue_Body") == GearLook.with_rest_positions(_source("Rogue_Body")), "the man wears the model's own body")
	check(not _shown("Lashes") and not _shown("Lips"), "the man has no lashes and no painted mouth")
	var male_head := _mesh("Rogue_Head")

	# A new game asks for a hero or a heroine.
	game.new_game()
	check(game._name_box.visible, "the name box opens for a new game")
	check(game._new_sex == "male", "the hero is offered first")
	game._choose_sex("female")
	check(game._new_sex == "female", "the heroine can be chosen")
	check(game._name_ask.text == Lang.t("Wie heißt deine Heldin?"), "the question asks for the heroine's name")
	game._choose_sex("male")
	check(game._name_ask.text == Lang.t("Wie heißt dein Held?"), "and for the hero's name again")
	game._choose_sex("female")
	game._name_edit.text = HERO
	game._start_new_game()
	check(game.hero_name == HERO and p.sex == "female", "the new game starts with a heroine")
	game.load_level(0, false)

	# Her own body and face.
	check(_mesh("Rogue_Body") != _source("Rogue_Body"), "the heroine has her own body")
	check(_mesh("Rogue_Head") != male_head, "the heroine has her own head")
	check(_mesh("Rogue_ArmLeft") != _source("Rogue_ArmLeft") and _mesh("Rogue_LegLeft") != _source("Rogue_LegLeft"), "her arms and legs are her own")
	_check_bust()
	check(_shown("Lashes") and _shown("Lips"), "the heroine has lashes and a mouth")
	check(is_equal_approx(_model_scale(), BodyLook.FEMALE_SCALE), "the heroine is a little shorter")
	var female_head := _mesh("Rogue_Head")
	var female_body := _mesh("Rogue_Body")
	var skin := (game.player.find_child("Rogue_Head", true, false) as MeshInstance3D).material_override
	check(HairLook.is_hair(skin), "her head is drawn with the hair shader")

	# Hair, mohawk, bald head and tattoo work on her head too.
	p.set_hair({"style": "mohawk", "color": "pink", "tattoo": ""})
	check(_shown("Crest"), "a heroine can wear a mohawk")
	check(_mesh("Rogue_Head") != female_head, "the mohawk shaves her head")
	p.equip("knochenhelm")
	check(not _shown("Crest"), "a helmet hides her mohawk")
	check(game.player.find_child("Headgear", true, false) != null, "the helmet sits on her head")
	p.unequip("kopf")
	check(_shown("Crest"), "the mohawk is back without the helmet")
	p.set_hair({"style": "bald", "color": "natural", "tattoo": "Rose"})
	check(game.player.find_child("TattooInk", true, false) != null, "a tattoo is inked on her head")
	p.set_hair(HairLook.DEFAULT)
	check(_mesh("Rogue_Head") == female_head, "her hair grows back on her own head")

	# Armour and shoes colour her body and legs.
	p.bag.append("kettenhemd")
	p.equip("kettenhemd")
	var body := game.player.find_child("Rogue_Body", true, false) as MeshInstance3D
	check(body.material_override is ShaderMaterial and body.material_override.get_shader_parameter("recolor") == true, "chain mail is drawn on her body")
	p.unequip("ruestung")
	check(body.material_override is ShaderMaterial and body.material_override.get_shader_parameter("recolor") == false, "without it her tunic keeps its colours")
	check(body.mesh == female_body or body.mesh == GearLook.with_rest_positions(female_body), "her body stays hers under the armour")

	# Asleep her eyes close and the lashes go with them.
	p.set_asleep(true)
	check(_shown("Eyelids"), "asleep, her eyes are closed")
	check(not _shown("Lashes"), "closed eyes hide the lashes")
	p.set_asleep(false)
	check(_shown("Lashes"), "awake, the lashes are back")

	# The choice is saved and loaded, one saved game per hero.
	check(game.save_game(), "the heroine's game is saved")
	var data: Dictionary = game._read_save()
	check(data.get("sex", "") == "female", "the saved game knows she is a heroine")
	p.set_sex("male")
	check(p.sex == "male" and not _shown("Lashes") and is_equal_approx(_model_scale(), 1.0), "a man again, at full height, without lashes")
	check(_mesh("Rogue_Head") == male_head, "the man's head is back")
	game._apply_save(data)
	check(p.sex == "female" and _shown("Lashes") and _mesh("Rogue_Head") == female_head, "the heroine comes back from the saved game")
	data.erase("sex")
	game._apply_save(data)
	check(p.sex == "male", "a game saved before there were heroines has a hero")
	p.set_sex("other")
	check(p.sex == "male", "an unknown body is a man")

	# The village women built on the same model have the woman's body.
	game.load_level(game._outdoor_index(), false)
	var women := 0
	var men := 0
	for v in game.level.villagers:
		if v._info.model != "Rogue":
			continue
		var vbody := v.find_child("Rogue_Body", true, false) as MeshInstance3D
		if v._info.get("sex", "") == "female":
			women += 1
			var own: Mesh = vbody.get_meta("body_source")
			check(vbody.mesh != own and vbody.mesh != GearLook.with_rest_positions(own), "%s has a woman's body" % v._info.name)
			check(v.find_child("Lashes", true, false).visible, "%s has lashes" % v._info.name)
			check(vbody.material_override != null, "%s keeps her dyed clothes" % v._info.name)
		else:
			men += 1
			var source: Mesh = vbody.get_meta("body_source")
			check(vbody.mesh == source or vbody.mesh == GearLook.with_rest_positions(source), "%s has a man's body" % v._info.name)
	check(women >= 2 and men >= 1, "the village has women and men built on the Rogue")


## Her chest has a small bust: finer triangles there, rounded forward, and
## every new vertex is skinned like its neighbours so it follows the run.
func _check_bust() -> void:
	var source := _source("Rogue_Body").surface_get_arrays(0)
	var body := _mesh("Rogue_Body").surface_get_arrays(0)
	var verts: PackedVector3Array = body[Mesh.ARRAY_VERTEX]
	var weights: PackedFloat32Array = body[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array = body[Mesh.ARRAY_BONES]
	check(verts.size() > (source[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "her chest is cut into finer triangles")
	check(bones.size() == verts.size() * 4 and weights.size() == verts.size() * 4, "every vertex of her body is skinned")
	var front := func(vs: PackedVector3Array) -> float:
		var most := -INF
		for p in vs:
			if absf(absf(p.x) - BodyLook.BUST_SIDE) < 0.04 and absf(p.y - BodyLook.BUST_HEIGHT) < 0.04:
				most = maxf(most, p.z)
		return most
	var rise: float = front.call(verts) - front.call(source[Mesh.ARRAY_VERTEX])
	check(rise > BodyLook.BUST_OUT * 0.5 and rise < BodyLook.BUST_OUT * 1.5, "her bust comes forward a little (%.3f)" % rise)
	var loose := 0
	for v in verts.size():
		var total := 0.0
		for j in 4:
			total += weights[v * 4 + j]
		if absf(total - 1.0) > 0.01:
			loose += 1
	check(loose == 0, "every vertex's skin weights add up (%d do not)" % loose)
