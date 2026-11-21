extends SceneTree
## Headless test for the looks of the townsfolk (see TownsfolkLook): every person of the village has
## a look of their own (no two share a skin tone, a haircut with a hair colour, or a hat colour), the
## look is fixed, some wear glasses, and Pip and Pippi keep their hand-made looks.
## Run with: godot --headless -s tests/townsfolk_look.gd

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var skins := {}
	var cuts := {}
	var hats := {}
	var glasses := 0
	var roles: Array = Villager.ROLES.keys()
	for role: String in roles:
		var info: Dictionary = Villager.ROLES[role]
		var look := TownsfolkLook.look_for(role, info)
		check(look == TownsfolkLook.look_for(role, info), "%s looks the same every time" % role)
		if role in ["7", "pippi"]:
			check(look.is_empty(), "%s keeps the hand-made look" % info.name)
		else:
			check(not look.is_empty(), "%s has a look of their own" % info.name)
			var key := str(look.skin)
			check(not skins.has(key), "%s shares a skin tone with %s" % [info.name, skins.get(key, "")])
			skins[key] = info.name
			if look.hat != null:
				check(not hats.has(str(look.hat)), "%s shares a hat colour" % info.name)
				hats[str(look.hat)] = info.name
			if look.glasses != "":
				glasses += 1
				check(look.glasses in TownsfolkLook.GLASSES, "%s wears glasses of a known kind" % info.name)
				for kind in TownsfolkLook.GLASSES:
					var mesh := TownsfolkLook.glasses_mesh(kind, AABB(Vector3(-0.54, 1.17, -0.5), Vector3(1.08, 1.02, 1.0)), look.frame)
					check(mesh.get_surface_count() == 1, "%s glasses have a surface" % kind)
		if info.model == "Rogue":
			var hair := TownsfolkLook.hair_of(info, look)
			var cut := "%s/%s" % [hair.style, hair.color]
			check(not cuts.has(cut), "%s has the same haircut and colour (%s) as %s" % [info.name, cut, cuts.get(cut, "")])
			cuts[cut] = info.name
	# Knights with bare heads (the herald and the clerk) wear hair dyed apart, not the model's own blond.
	var dyes := {}
	for role: String in roles:
		var info: Dictionary = Villager.ROLES[role]
		if info.model == "Knight" and not "Knight_Helmet" in info.show:
			var dye = TownsfolkLook.look_for(role, info).dye
			check((dye is Array and dye.size() == 3) or HairLook.COLORS.has(dye), "%s has dyed hair" % info.name)
			dye = str(dye)
			check(not dyes.has(dye), "%s has the same hair colour as %s" % [info.name, dyes.get(dye, "")])
			dyes[dye] = info.name
	check(dyes.size() >= 2, "both bare-headed knights are checked")
	var dyed: Image = TownsfolkLook.dye_texture("black").get_image()
	var patch := HairLook.HAIR_UV.get_center() * dyed.get_width()
	check(dyed.get_pixelv(Vector2i(patch)).a == 1.0 and dyed.get_pixel(0, dyed.get_height() - 1).a == 0.0, "the dye covers only the hair")
	check(glasses >= 3, "some townsfolk wear glasses")
	check(Villager.ROLES["7"].hair == {"style": "spiky", "color": "blond"}, "Pip keeps his hair")
	# The glasses sit on the eyes whatever the model's head box is (the Knight's is taller).
	for box in [AABB(Vector3(-0.54, 1.17, -0.5), Vector3(1.08, 1.02, 1.0)), AABB(Vector3(-0.54, 1.22, -0.49), Vector3(1.09, 1.1, 1.02)), AABB(Vector3(-0.54, 1.07, -0.75), Vector3(1.09, 1.14, 1.27))]:
		var rim := TownsfolkLook.glasses_mesh("round", box, Color.BLACK).get_aabb()
		check(absf(rim.get_center().y - TownsfolkLook.EYE_Y) < 0.05, "glasses sit on the eyes, not on the head box %s" % box)
	# Someone who is not in the table still gets a fixed look of their own.
	var stranger := {"name": "x", "model": "Mage", "show": [], "colors": [Color.WHITE, Color.WHITE, Color.WHITE]}
	check(TownsfolkLook.look_for("~", stranger) == TownsfolkLook.look_for("~", stranger), "a stranger's look is fixed")
	# On a model: the glasses hang from the head, the skin is tinted.
	for role in ["8", "6"]:
		var info: Dictionary = Villager.ROLES[role]
		var model: Node3D = load("res://assets/characters/%s.glb" % info.model).instantiate()
		root.add_child(model)
		Villager.dress_model(model, info)
		TownsfolkLook.apply(model, info, TownsfolkLook.look_for(role, info))
		check(model.find_child(TownsfolkLook.TAG, true, false) != null, "%s wears glasses" % info.name)
	print("townsfolk look test: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures else 0)
