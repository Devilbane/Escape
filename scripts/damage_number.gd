class_name DamageNumber
extends Label3D
## A number (or a short word) that pops up above a creature's head, rises and
## slowly fades. Numbers over the same head never cover each other: a new one
## always starts at the head, and the older ones are pushed up out of its way,
## so a hero striking one foe again and again can read every blow.
## News floating up at a spot (Effects.float_text: a level-up, experience, a
## find) share the same stacks, so they never cover a number or each other.

## Seconds a number lives, from pop to gone.
const LIFE := 1.7
## How far a number drifts up on its own over its life.
const RISE := 1.0
## When the fade starts, and how long it takes.
const FADE_AT := 0.9
const FADE_TIME := LIFE - FADE_AT
## The smallest gap between two numbers over the same head, in world units
## along the screen's up.
## The glyphs are about 0.5 high, so this leaves a clear gap between lines.
const STEP := 0.8
## Seen from above, the head point sits low on the picture: a new number
## starts this far (along the screen's up) above it, off the hair or helmet.
const HEAD_GAP := 0.45
## More numbers than this over one head (and, apart, more news than this) and
## the oldest one hurries its fade.
const MOST := 4
## The pop: a new number starts this much bigger and settles in POP_TIME.
const POP := 1.4
const POP_TIME := 0.14
## The letters of numbers and news, before UiKit.sized.
const FONT_SIZE := 64
## Finds and experience (see Effects.loot_text) are sized by their worth: a
## copper coin or a few points of experience in small letters, a godborn
## piece or a boss's experience in big ones (see worth_size).
const WORTH_MIN_SIZE := 34
const WORTH_MAX_SIZE := 68
## How much each rarity tier is worth on that scale (0 to 1).
const TIER_WORTH := {"normal": 0.15, "ungewoehnlich": 0.35, "selten": 0.55, "episch": 0.8, "gottgeboren": 1.0, "gefertigt": 0.55}
## As many copper coins as this are worth the most (two gold coins).
const COPPER_MOST := 500.0

## The numbers alive over each head, oldest first, keyed by the target's id.
static var _stacks := {}

var _key := 0
var _target: Node3D
var _offset := Vector3.ZERO
var _anchor := Vector3.ZERO
var _age := 0.0
## The extra height this number was pushed up by newer ones.
var _lift := 0.0
## The height above the head it is drawn at now (it slides toward its goal).
var _shown := 0.0
var _alpha := 1.0
var _outline_alpha := 1.0


## Words that tell news rather than a blow (Effects.float_text: a level-up,
## experience, a find) live longer and rise further.
const NEWS_LIFE := 2.6
const NEWS_RISE := 1.6
const NEWS_FADE_AT := 1.8
## A text dropped at a spot joins the stack of a creature standing there, or
## of other texts there, when it is this close on the floor plan...
const JOIN := 1.0
## ...and no further above the creature's feet than this.
const JOIN_HEIGHT := 5.0
## The letters (Cinzel capitals) are about this share of the font size high;
## the rest of a line is empty room above and below them.
const INK_HEIGHT := 0.7

## This number's own life, rise and fade start (news live longer, see NEWS_LIFE).
var life := LIFE
var rise := RISE
var fade_at := FADE_AT


## Shows `text` above `target`'s head (`offset` from its origin). The label
## lives under `parent`, so it stays on when the target dies.
static func show_over(parent: Node, target: Node3D, offset: Vector3, text: String, color: Color) -> DamageNumber:
	var label := _make(text, color)
	label._target = target
	label._offset = offset
	label._anchor = target.global_position + offset
	label._key = target.get_instance_id()
	_join(parent, label)
	return label


## Shows news at a spot in the world (see Effects.float_text). Over a
## creature (the hero, a foe) it joins the words over that head, so a
## level-up, the experience and a "Blocked!" stack instead of covering each
## other; elsewhere it joins the texts already floating at that spot, or
## those it would otherwise start on (loot right beside the hero's head).
## With `above_fog` it is drawn over walls and the fog of war.
## `size` is the font size before UiKit.sized (finds and experience go by
## their worth, see worth_size).
static func show_at(parent: Node, pos: Vector3, text: String, color: Color, above_fog := false, size := FONT_SIZE) -> DamageNumber:
	var label := _make(text, color, size)
	label.life = NEWS_LIFE
	label.rise = NEWS_RISE
	label.fade_at = NEWS_FADE_AT
	if above_fog:
		# The fog of war draws at priority 100 and covers anything below it.
		label.render_priority = 110
		label.outline_render_priority = 109
	var host := _creature_at(parent, pos)
	if host:
		label._target = host
		label._offset = pos - host.global_position
		label._key = host.get_instance_id()
	else:
		label._key = _stack_near(pos)
		if label._key == 0:
			label._key = label.get_instance_id()
	label._anchor = pos if host == null else host.global_position + label._offset
	# A new stack that would start on the words of another one beside it (the
	# loot over a chest right next to the hero's head) joins that one instead.
	if _newest(_stacks.get(label._key, [])) == null and parent.is_inside_tree():
		var cam := parent.get_viewport().get_camera_3d()
		if cam:
			var start := label._anchor + cam.global_basis.y * HEAD_GAP
			var rect := label.screen_rect(cam, start, 1.0).grow(4)
			for column in columns(cam):
				if column.rect.intersects(rect):
					label._key = column.key
					break
	_join(parent, label)
	return label


## The font size for a find or experience of `worth` (0 to 1).
static func worth_size(worth: float) -> int:
	return roundi(lerpf(WORTH_MIN_SIZE, WORTH_MAX_SIZE, clampf(worth, 0.0, 1.0)))


## The worth of an item or ingredient, by its rarity tier (see Rarity.tier).
static func item_worth(id: String) -> float:
	return TIER_WORTH.get(Rarity.tier(id), 0.15)


## The worth of `copper` coins: one is next to nothing, COPPER_MOST the most.
static func copper_worth(copper: float) -> float:
	return clampf(log(maxf(copper, 1.0)) / log(COPPER_MOST), 0.0, 1.0)


## The worth of `amount` experience for a hero of `hero_level`, measured by a
## kill at the hero's own level: a quarter of one is small, one is middling,
## eight (a boss, a big task) the most.
static func xp_worth(amount: int, hero_level: int) -> float:
	var kill := float(HeroLevel.kill_xp(hero_level, hero_level))
	return clampf(0.4 + 0.2 * log(maxf(amount, 1) / kill) / log(2.0), 0.0, 1.0)


static func _make(text: String, color: Color, size := FONT_SIZE) -> DamageNumber:
	var label := DamageNumber.new()
	label.text = text
	label.font = preload("res://assets/fonts/Cinzel-Bold.woff2")
	label.font_size = UiKit.sized(size)
	label.pixel_size = 0.012
	# The dark outline keeps its share of the letters, so small loot stays as readable.
	label.outline_size = roundi(14.0 * size / FONT_SIZE)
	label.outline_modulate = Color(0.05, 0.02, 0.06)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.outline_render_priority = 19
	label._alpha = color.a
	label._outline_alpha = label.outline_modulate.a
	return label


## Puts a new label into its stack. A stack that is already there keeps its
## anchor: the newcomer starts where the others started, so nothing jumps.
static func _join(parent: Node, label: DamageNumber) -> void:
	var stack: Array = _stacks.get(label._key, [])
	var newest := _newest(stack)
	if newest:
		label._target = newest._target
		label._offset = newest._offset
		label._anchor = newest._anchor
	label.scale = Vector3.ONE * POP
	parent.add_child(label)
	label.global_position = label._anchor
	stack.append(label)
	_stacks[label._key] = stack
	# Too many at once: the oldest ones skip ahead to their fade. Blows and
	# news are counted apart, so the numbers of a fight never sweep away a
	# level-up, and a pile of news never hides a "Blocked!".
	var is_news := label.life > LIFE
	var extra := -MOST
	for n in stack:
		if is_instance_valid(n) and (n.life > LIFE) == is_news and n._age < n.life - 0.25:
			extra += 1
	for old in stack:
		if extra <= 0:
			break
		if old == label or not is_instance_valid(old) or (old.life > LIFE) != is_news or old._age >= old.life - 0.25:
			continue
		old._age = old.life - 0.25
		extra -= 1


static func _newest(stack: Array) -> DamageNumber:
	for j in range(stack.size() - 1, -1, -1):
		if is_instance_valid(stack[j]):
			return stack[j]
	return null


## The creature (hero or foe) standing right below `pos`, if any.
static func _creature_at(parent: Node, pos: Vector3) -> Node3D:
	if not parent.is_inside_tree():
		return null
	var best: Node3D = null
	var best_d := JOIN
	for node in parent.get_tree().get_nodes_in_group("combatant"):
		var body := node as Node3D
		if body == null or not body.is_inside_tree():
			continue
		var feet := body.global_position
		var d := Vector2(pos.x - feet.x, pos.z - feet.z).length()
		if d < best_d and pos.y >= feet.y - 0.5 and pos.y <= feet.y + JOIN_HEIGHT:
			best = body
			best_d = d
	return best


## The key of a stack of texts floating near `pos`, or 0.
static func _stack_near(pos: Vector3) -> int:
	for key in _stacks:
		var newest := _newest(_stacks[key])
		if newest == null:
			continue
		var d := Vector2(pos.x - newest._anchor.x, pos.z - newest._anchor.z).length()
		if d < JOIN and absf(pos.y - newest._anchor.y) < JOIN_HEIGHT:
			return key
	return 0


## Every number and word alive (for keeping comic bubbles off them, and tests).
static func all() -> Array:
	var out := []
	for key in _stacks:
		for n in _stacks[key]:
			if is_instance_valid(n) and n.is_inside_tree():
				out.append(n)
	return out


## The stacks alive, each an Array of its labels, oldest first.
static func stacks() -> Array:
	var out := []
	for key in _stacks:
		var alive: Array = _stacks[key].filter(func(n): return is_instance_valid(n) and n.is_inside_tree())
		if not alive.is_empty():
			out.append(alive)
	return out


## Where the letters of this label are on screen, seen through `camera`:
## the width of the text and the height of its capitals. `at` and `size`
## give where it would be and how big (now: its place and scale).
func screen_rect(camera: Camera3D, at := Vector3.INF, size := -1.0) -> Rect2:
	if at == Vector3.INF:
		at = global_position
	if size < 0.0:
		size = scale.x
	var lines := text.split("\n")
	var width := 0.0
	for line in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	var line_height := font.get_height(font_size)
	var height := line_height * (lines.size() - 1) + font_size * INK_HEIGHT
	var right := camera.global_basis.x * width * pixel_size * size * 0.5
	var up := camera.global_basis.y * height * pixel_size * size * 0.5
	var rect := Rect2(camera.unproject_position(at), Vector2.ZERO)
	for corner in [at + right + up, at + right - up, at - right + up, at - right - up]:
		rect = rect.expand(camera.unproject_position(corner))
	return rect


## Each stack's place on screen ({"key", "rect"}): its letters and the room
## above that its top word still rises into or is pushed into by the next.
static func columns(camera: Camera3D) -> Array:
	var out := []
	for key in _stacks:
		var column := Rect2()
		var first := true
		var top: DamageNumber = null
		for n in _stacks[key]:
			if not is_instance_valid(n) or not n.is_inside_tree() or camera.is_position_behind(n.global_position):
				continue
			var r: Rect2 = n.screen_rect(camera)
			column = r if first else column.merge(r)
			first = false
			if top == null:
				top = n
		if first:
			continue
		var step := camera.unproject_position(top.global_position).distance_to(
				camera.unproject_position(top.global_position + camera.global_basis.y * (STEP + top.rise)))
		out.append({"key": key, "rect": column.grow_individual(0, step, 0, 0)})
	return out


## The numbers alive over `target`, oldest first (for tests).
static func over(target: Node) -> Array:
	var stack: Array = _stacks.get(target.get_instance_id(), [])
	return stack.filter(func(n): return is_instance_valid(n))


## The height above the head this number is drawn at.
func height() -> float:
	return _shown


func _drift() -> float:
	var t := clampf(_age / life, 0.0, 1.0)
	return rise * (1.0 - pow(1.0 - t, 2.0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		_leave()
		return
	# Follow the head while the target lives (it may be knocked back).
	if is_instance_valid(_target) and _target.is_inside_tree():
		_anchor = _target.global_position + _offset
	var pop := clampf(_age / POP_TIME, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(POP, 1.0, pop * (2.0 - pop))
	var fade := clampf((_age - fade_at) / (life - fade_at), 0.0, 1.0)
	modulate.a = _alpha * (1.0 - fade)
	# The outline ignores `modulate`, so it has to fade on its own.
	outline_modulate.a = _outline_alpha * (1.0 - fade)
	# The newest number over a head places the whole stack, once a frame,
	# after the others have aged (it was added last, so it runs last).
	var stack: Array = _stacks.get(_key, [])
	if not stack.is_empty() and stack.back() == self:
		_place(stack)


## Lays out one head's numbers from the newest up: each one rises on its own,
## but always stays a full step above the next newer one.
static func _place(stack: Array) -> void:
	# The newest number starts a little clear of the head, never on it.
	var below := HEAD_GAP - STEP
	# The camera looks down at the floor at a slant, so "up" means up on the
	# screen: the numbers climb along the camera's up, not the world's, and a
	# step keeps its full height in the picture.
	var newest: DamageNumber = stack.back()
	var camera := newest.get_viewport().get_camera_3d()
	var up := camera.global_basis.y if camera else Vector3.UP
	for j in range(stack.size() - 1, -1, -1):
		var n: DamageNumber = stack[j]
		if not is_instance_valid(n):
			continue
		var goal := n._drift() + n._lift
		if goal < below + STEP:
			n._lift += below + STEP - goal
			goal = below + STEP
		# A push slides in quickly but never lets two numbers touch.
		n._shown = goal if n._age <= POP_TIME else maxf(lerpf(n._shown, goal, 0.5), below + STEP)
		n._shown = maxf(n._shown, 0.0)
		n.global_position = newest._anchor + up * n._shown
		below = n._shown


func _leave() -> void:
	_forget()
	queue_free()


func _forget() -> void:
	var stack: Array = _stacks.get(_key, [])
	stack.erase(self)
	if stack.is_empty():
		_stacks.erase(_key)


func _exit_tree() -> void:
	_forget()
