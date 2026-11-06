class_name EditorCreations
extends RefCounted
## The "Creations" page of the map workshop (see LevelEditor): ten slots, one
## per digit, each a monster, a person or a piece of gear of the map's own
## (see Creations), with a form for its name, numbers, look and lines.
##
## Typing in a field changes the creation at once; the form is only built
## anew when its shape changes (a new type, base or body), so the field being
## typed in keeps the focus.

## The height kept for the note under the base kind (three lines).
const HINT_HEIGHT := 72.0

var editor: Node
var slot := "1"
var _box: VBoxContainer
var _slot_buttons := {}
var _ask_delete := false


func _init(owner_editor: Node) -> void:
	editor = owner_editor


func build(box: VBoxContainer) -> void:
	_box = box
	rebuild()


func rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	_slot_buttons.clear()
	if editor.map.is_outdoor():
		var none := EditorUi.label(Lang.t("Eigene Geschöpfe gibt es nur in Verliesen. Im Freien sind die Ziffern Dorfbewohner."), 16, EditorUi.DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(none)
		return
	var made: Dictionary = editor.map.creations()
	var intro := EditorUi.label(Lang.t("Jede Ziffer auf der Karte setzt ein eigenes Geschöpf: ein Monster, eine Person oder Ausrüstung."), 16, EditorUi.DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(intro)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_box.add_child(grid)
	for letter in Creations.LETTERS:
		var b := EditorUi.toggle(letter, pick.bind(letter), Vector2(52, 52))
		b.button_pressed = letter == slot
		b.tooltip_text = EditorPalette.name_of(letter, made)
		if made.has(letter):
			b.add_theme_color_override("font_color", Color(0.75, 0.65, 1.0))
		grid.add_child(b)
		_slot_buttons[letter] = b
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, EditorUi.GROUP_GAP - EditorUi.ROW_GAP)
	_box.add_child(spacer)
	if not made.has(slot):
		_build_empty()
		return
	var spec: Dictionary = made[slot]
	var head := EditorUi.hbox()
	var title := EditorUi.label("%s  %s" % [slot, Creations.label_of(spec)], 20, EditorUi.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	_box.add_child(head)
	var actions := EditorUi.hbox()
	actions.add_child(EditorUi.button(Lang.t("Als Pinsel"), func(): editor.pick_letter(slot), Vector2(140, 44)))
	var del := EditorUi.button(Lang.t("Wirklich löschen?") if _ask_delete else Lang.t("Löschen"), _delete, Vector2(150, 44))
	actions.add_child(del)
	_box.add_child(actions)
	match spec.type:
		"monster":
			_build_monster(spec)
		"npc":
			_build_npc(spec)
		"item":
			_build_item(spec)


func pick(letter: String) -> void:
	slot = letter
	_ask_delete = false
	rebuild()


func _build_empty() -> void:
	_box.add_child(EditorUi.label(Lang.t("Die %s ist frei. Was soll sie werden?") % slot, 16))
	for entry in [["monster", "Neues Monster"], ["npc", "Neue Person"], ["item", "Neue Ausrüstung"]]:
		_box.add_child(EditorUi.button(Lang.t(entry[1]), _create.bind(entry[0]), Vector2(0, 52)))


func _create(type: String) -> void:
	var spec := Creations.blank(type)
	if type == "monster":
		_fill_monster_stats(spec)
	elif type == "item":
		_fill_item_stats(spec)
		spec.id = Creations.item_id(spec.name)
	_store(spec)
	editor.pick_letter(slot)
	rebuild()


func _delete() -> void:
	if not _ask_delete:
		_ask_delete = true
		rebuild()
		return
	_ask_delete = false
	editor.set_creation(slot, {})
	rebuild()


func _store(spec: Dictionary) -> void:
	editor.set_creation(slot, Creations.checked(spec))
	var made: Dictionary = editor.map.creations()
	if _slot_buttons.has(slot):
		_slot_buttons[slot].tooltip_text = EditorPalette.name_of(slot, made)


## Changes one value of the creation in this slot (without a new form).
func _change(key: String, value) -> void:
	var spec: Dictionary = editor.map.creations().get(slot, {})
	if spec.is_empty():
		return
	spec[key] = value
	_store(spec)


func _name_field(spec: Dictionary) -> void:
	_box.add_child(EditorUi.row(Lang.t("Name"), EditorUi.line_edit(spec.name, func(t): _change("name", t), 40)))


# --- Monsters ---------------------------------------------------------------

func _build_monster(spec: Dictionary) -> void:
	_name_field(spec)
	var bases := []
	for family in Creations.MONSTER_FAMILIES:
		bases.append(["", Lang.t(family[0])])
		for b in family[1]:
			bases.append([b, Lang.t(Creations.MONSTER_NAMES[b])])
	_box.add_child(EditorUi.row(Lang.t("Grundart"), EditorUi.choice(bases, spec.base, func(b):
		var s: Dictionary = editor.map.creations()[slot]
		s.base = b
		_fill_monster_stats(s)
		_store(s)
		rebuild())))
	var boss: bool = spec.base in Creations.MONSTER_BOSSES
	var hint := EditorUi.label(Lang.t("Ein Endgegner: kämpft mit allen Angriffen seiner Grundart und zeigt oben seine Lebensleiste mit diesem Namen.") if boss
			else Lang.t("Kämpft wie seine Grundart. Eine neue Grundart setzt deren Werte."), 16, EditorUi.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Room for the longer boss note either way, so the numbers below stay
	# put when the base changes.
	hint.custom_minimum_size.y = HINT_HEIGHT
	_box.add_child(hint)
	for s in Creations.MONSTER_STATS:
		_box.add_child(EditorUi.row(Lang.t(s[1]), EditorUi.spin(float(spec.get(s[0], s[2])), s[2], s[3], s[4], func(v): _change(s[0], v))))
	_box.add_child(EditorUi.check(Lang.t("Streift umher"), bool(spec.get("roam", false)), func(on): _change("roam", on)))
	_tint_row(spec, true)


## The base kind's own numbers, as the first values of the form.
func _fill_monster_stats(spec: Dictionary) -> void:
	var kind: Dictionary = Enemy.KINDS[spec.base]
	for s in Creations.MONSTER_STATS:
		if s[0] == "gold":
			spec.gold = int(kind.get("purse", [0, 0])[1])
		elif s[0] == "armor":
			spec.armor = int(kind.get("armor", 0))
		else:
			spec[s[0]] = kind.get(s[0], s[2])


func _tint_row(spec: Dictionary, enabled: bool) -> void:
	var row := EditorUi.hbox()
	var picker := EditorUi.color_button(Color.html(spec.tint) if spec.has("tint") else Color(0.8, 0.8, 0.8), func(c): _change("tint", "#" + c.to_html(false)))
	picker.disabled = not spec.has("tint") or not enabled
	var tick := EditorUi.check(Lang.t("Eigene Farbe"), spec.has("tint"), func(on):
		picker.disabled = not on
		var s: Dictionary = editor.map.creations()[slot]
		if on:
			s.tint = "#" + picker.color.to_html(false)
		else:
			s.erase("tint")
		_store(s))
	tick.disabled = not enabled
	tick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tick)
	row.add_child(picker)
	_box.add_child(row)


# --- People -----------------------------------------------------------------

func _build_npc(spec: Dictionary) -> void:
	_name_field(spec)
	var models := Creations.NPC_MODELS.map(func(m): return [m, Lang.t(Creations.NPC_MODEL_NAMES[m])])
	_box.add_child(EditorUi.row(Lang.t("Körper"), EditorUi.choice(models, spec.model, func(m):
		var s: Dictionary = editor.map.creations()[slot]
		s.model = m
		_store(s)
		rebuild())))
	var woman := EditorUi.check(Lang.t("Frau (nur beim Schurken)"), spec.sex == "female", func(on): _change("sex", "female" if on else "male"))
	woman.disabled = spec.model != "Rogue"
	_box.add_child(woman)
	_box.add_child(EditorUi.label(Lang.t("Trägt"), 16, EditorUi.GOLD))
	# Five rows for every body, so the form keeps its height when the body changes.
	var parts: Array = Creations.NPC_PARTS[spec.model]
	for i in 5:
		if i < parts.size():
			var part: String = parts[i]
			_box.add_child(EditorUi.check(Lang.t(Creations.PART_NAMES[part]), part in spec.show, func(on):
				var s: Dictionary = editor.map.creations()[slot]
				var show: Array = s.show
				if on and not part in show:
					show.append(part)
				elif not on:
					show.erase(part)
				_store(s)))
		else:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 44)
			_box.add_child(gap)
	for i in 3:
		_box.add_child(EditorUi.row(Lang.t(["Kleidung", "Hose", "Hut, Umhang"][i]), EditorUi.color_button(Color.html(spec.colors[i]), func(c):
			var s: Dictionary = editor.map.creations()[slot]
			s.colors[i] = "#" + c.to_html(false)
			_store(s))))
	var poses := Creations.NPC_POSES.map(func(p): return [p[0], Lang.t(p[1])])
	_box.add_child(EditorUi.row(Lang.t("Haltung"), EditorUi.choice(poses, spec.pose, func(p): _change("pose", p))))
	var says := EditorUi.label(Lang.t("Was die Person sagt, eins nach dem anderen"), 16, EditorUi.GOLD)
	says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(says)
	var lines: Array = spec.lines
	for i in Creations.NPC_MAX_LINES:
		var e := EditorUi.line_edit(lines[i] if i < lines.size() else "", func(_t): _store_lines(), 120)
		e.placeholder_text = Lang.t("Zeile %d") % (i + 1)
		e.set_meta("line", true)
		_box.add_child(e)


func _store_lines() -> void:
	var s: Dictionary = editor.map.creations()[slot]
	var lines: Array = []
	for child in _box.get_children():
		if child is LineEdit and child.has_meta("line"):
			lines.append(child.text)
	s.lines = lines
	_store(s)


# --- Gear -------------------------------------------------------------------

func _build_item(spec: Dictionary) -> void:
	_name_field(spec)
	var bases: Array = []
	for slot_id in Creations.ITEM_SLOTS:
		for id in Items.ALL:
			var item: Dictionary = Items.ALL[id]
			if item.slot == slot_id and not item.get("custom", false):
				bases.append([id, "%s: %s" % [Lang.t(Items.SLOT_NAMES.get(slot_id, slot_id)), Lang.t(item.name)]])
	_box.add_child(EditorUi.row(Lang.t("Sieht aus wie"), EditorUi.choice(bases, spec.base, func(b):
		var s: Dictionary = editor.map.creations()[slot]
		s.base = b
		_fill_item_stats(s)
		_store(s)
		rebuild())))
	var hint := EditorUi.label(Lang.t("Trägt sich wie das gewählte Stück, mit deinen Werten. Wird nie verkauft oder als Beute gefunden."), 16, EditorUi.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(hint)
	for s in Creations.ITEM_STATS:
		_box.add_child(EditorUi.row(Lang.t(s[1]), EditorUi.spin(float(spec.get(s[0], 0)), s[2], s[3], s[4], func(v): _change(s[0], v))))
	_tint_row(spec, Items.ALL[spec.base].slot in Creations.TINTED_SLOTS)
	var id := EditorUi.label(Lang.t("Kennung: %s") % spec.id, 16, EditorUi.DIM)
	id.clip_text = true
	_box.add_child(id)


func _fill_item_stats(spec: Dictionary) -> void:
	var item: Dictionary = Items.ALL[spec.base]
	for s in Creations.ITEM_STATS:
		spec[s[0]] = item.get(s[0], 0 if s[4] is int else 0.0)
	spec.price = maxi(1, int(spec.price))
	spec.erase("tint")
