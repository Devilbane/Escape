extends SceneTree
## Headless test: feet stay planted (Stride).
## - The ground speed in Stride.FEET of every walk and run is measured again
##   from the bones of each model: the planted foot (on the floor) travels
##   backwards that fast at normal playback.
## - The push-offs in Stride.PUSH_OFF are where the back heel is highest with
##   the toes still down; the lift onto the toes peaks there and is gone by
##   the next heel strike.
## - Every walker's speeds fit its gaits without running into the playback
##   limits (which would let a foot slide): monsters strolling and hunting,
##   villagers, animals, the companion and the hero.
## - In play, the hero walks, jogs and runs with the planted foot nearly
##   still on the ground, and lifts a little onto the toes while walking.
## Run with: godot --headless --fixed-fps 60 -s tests/stride.gd

var failures := 0
var game: Node
var frames := 0
var started := false


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _initialize() -> void:
	seed(5)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 5 and not started:
		started = true
		_run()
	return false


func _finish() -> void:
	game.delete_save(game.save_path())
	print("PASS: stride" if failures == 0 else "FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _measure_feet()
	await _measure_push_off()
	_check_speeds()
	await _hero_in_play()
	_finish()


# --- Measured from the animations ---------------------------------------------

const FOOT_BONES := {
	"kaykit": ["foot.l", "toes.l", "foot.r", "toes.r"],
	"brute": ["Foot.L", "Foot.R"],
	"hound": ["FF.L", "FF.R", "FFB.L", "FFB.R"],
	"deer": ["FF.L", "FF.R", "FFB.L", "FFB.R"],
	"spider": ["FrontFoot_L", "MidFrontFoot_L", "BackFoot_L", "MidBackFoot_L",
		"FrontFoot2_R", "MidFrontFoot_R", "BackFoot_R", "MidBackFoot_R"],
}
const MODEL_FILES := {
	"Rogue": "characters/Rogue.glb", "Knight": "characters/Knight.glb", "Barbarian": "characters/Barbarian.glb",
	"Mage": "characters/Mage.glb", "Skeleton_Warrior": "enemies/Skeleton_Warrior.glb",
	"Skeleton_Minion": "enemies/Skeleton_Minion.glb", "Orc": "wild/Orc.glb", "Yeti": "wild/Yeti.glb",
	"Wolf": "wild/Wolf.glb", "Fox": "animals/Fox.glb", "Deer": "animals/Deer.glb", "Stag": "animals/Stag.glb",
	"Spider": "wild/Spider.glb",
}


## A model posed at `phase` (0..1) of `anim`: the bones' positions in the
## model's own space.
func _posed(model: Node3D, anim: String, phase: float, bones: Array) -> Array:
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	player.seek(player.get_animation(anim).length * phase, true, true)
	var to_model := model.global_transform.affine_inverse() * skel.global_transform
	var out := []
	for b: String in bones:
		out.append(to_model * skel.get_bone_global_pose(skel.find_bone(b)).origin)
	return out


## How fast the feet on the floor travel in `anim` (m/s, playback 1): every
## foot point within a centimetre of its lowest, over the whole cycle.
func _feet_speed(model: Node3D, anim: String, bones: Array) -> float:
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	player.play(anim)
	var steps := 240
	var length := player.get_animation(anim).length
	var poses := []
	for i in steps + 1:
		poses.append(_posed(model, anim, float(i) / steps, bones))
	var travelled := 0.0
	var time := 0.0
	for b in bones.size():
		var low := INF
		for i in steps:
			low = minf(low, poses[i][b].y)
		for i in steps:
			if poses[i][b].y - low < 0.012 and poses[i + 1][b].y - low < 0.012:
				var d: Vector3 = poses[i + 1][b] - poses[i][b]
				travelled += Vector2(d.x, d.z).length()
				time += length / steps
	return travelled / time if time > 0.0 else 0.0


func _measure_feet() -> void:
	for model_name: String in MODEL_FILES:
		var rig := Stride.rig_of(model_name)
		check(rig != "", "%s has a rig" % model_name)
		var model: Node3D = load("res://assets/" + MODEL_FILES[model_name]).instantiate()
		root.add_child(model)
		await process_frame
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		for anim: String in Stride.FEET[rig]:
			if not player.has_animation(anim):
				continue
			var measured := _feet_speed(model, anim, FOOT_BONES[rig])
			var listed := Stride.pace(rig, anim, 1.0)
			check(absf(measured - listed) <= listed * 0.06,
				"%s %s: feet travel %.2f m/s, Stride lists %.2f" % [model_name, anim, measured, listed])
		for anim: String in Stride.GAITS[rig]:
			check(player.has_animation(anim), "%s has its gait %s" % [model_name, anim])
		model.queue_free()


## The heel lift of each foot with its toes still down, through the walk:
## its peaks are the push-offs.
func _measure_push_off() -> void:
	var model: Node3D = load("res://assets/characters/Rogue.glb").instantiate()
	root.add_child(model)
	await process_frame
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var bones := ["foot.l", "toes.l", "foot.r", "toes.r"]
	for anim: String in Stride.PUSH_OFF:
		player.play(anim)
		var steps := 200
		var poses := []
		for i in steps:
			poses.append(_posed(model, anim, float(i) / steps, bones))
		var low := [INF, INF, INF, INF]
		for p in poses:
			for b in 4:
				low[b] = minf(low[b], p[b].y)
		for side in 2:
			var best := -1.0
			var at := 0.0
			for i in steps:
				var heel: float = poses[i][side * 2].y - low[side * 2]
				var toes: float = poses[i][side * 2 + 1].y - low[side * 2 + 1]
				var roll := heel * (1.0 - smoothstep(0.01, 0.06, toes))
				if roll > best:
					best = roll
					at = float(i) / steps
			var listed: float = Stride.PUSH_OFF[anim][side]
			check(absf(at - listed) < 0.025, "%s: push-off %d at %.3f, Stride lists %.3f" % [anim, side, at, listed])
			check(is_equal_approx(Stride.lift_at(anim, listed), 1.0), "%s: the full lift at push-off %d" % [anim, side])
			# Down again by the next heel strike (the other foot's push-off
			# comes half a cycle later, its heel strike just after).
			check(Stride.lift_at(anim, fposmod(listed + 0.12, 1.0)) == 0.0, "%s: off the toes again after push-off %d" % [anim, side])
			check(Stride.lift_at(anim, fposmod(listed - 0.25, 1.0)) == 0.0, "%s: flat-footed at mid-stance before push-off %d" % [anim, side])
			# Walking lifts; the same walk playing on a body that stands still
			# (held up, waiting, talking) stays flat-footed.
			player.seek(player.get_animation(anim).length * listed, true, true)
			check(Stride.lift(player, anim, 1.0, 1.5) > Stride.LIFT_HEIGHT * 0.9, "%s: walking lifts onto the toes at push-off %d" % [anim, side])
			check(Stride.lift(player, anim, 1.0, 0.0) == 0.0, "%s: standing still stays flat-footed at push-off %d" % [anim, side])
	check(Stride.LIFT_HEIGHT > 0.0 and Stride.LIFT_HEIGHT <= 0.08, "the lift onto the toes is only a little")
	model.queue_free()


# --- Every walker's speeds fit its gaits -----------------------------------------

## Whether `speed` plays `anim` without hitting the playback limits.
func _fits(rig: String, anim: String, size: float, speed: float) -> bool:
	var rate := speed / Stride.pace(rig, anim, size)
	return rate > Stride.SLOWEST and rate < Stride.FASTEST


func _check_speeds() -> void:
	# The gaits step up and back down with the speed, never flickering.
	var walk: String = Stride.gait("kaykit", Stride.GAITS.kaykit, 1.0, 1.0, "")
	check(walk == "Walking_A", "a slow human walks")
	check(Stride.gait("kaykit", Stride.GAITS.kaykit, 1.0, 2.5, "") == "Running_B", "a quicker one jogs")
	check(Stride.gait("kaykit", Stride.GAITS.kaykit, 1.0, 6.0, "") == "Running_A", "a fast one runs")
	check(Stride.gait("kaykit", Stride.GAITS.kaykit, 1.0, 1.9, "Walking_A") == "Walking_A"
		and Stride.gait("kaykit", Stride.GAITS.kaykit, 1.0, 1.9, "Running_B") == "Running_B", "between walk and jog, the gait in use stays")
	for g: String in Stride.GAITS.kaykit:
		check(Stride.gait("kaykit", Stride.GAITS.kaykit, 1.0, Stride.pace("kaykit", g, 1.0), g) == g, "%s stays at its own pace" % g)

	# Monsters: a stroll at most as fast as the walk steps, a hunt at a gait
	# that fits its speed.
	for kind: String in Enemy.KINDS:
		var stats: Dictionary = Enemy.KINDS[kind]
		var rig: String = Stride.rig_of(str(stats.model))
		if rig == "" or stats.has("ghost") or float(stats.speed) <= 0.0:
			continue
		var beast: bool = stats.get("beast", false)
		var size := float(stats.size) * (float(stats.model_scale) if beast else 1.0)
		var anims: Dictionary = stats.get("anims", {})
		var gaits: Array = []
		for n: String in (["Walking_A", "Running_A"] if beast else ["Walking_A", "Running_B", "Running_A"]):
			var a: String = anims.get(n, n)
			if Stride.pace(rig, a, size) > 0.0 and not gaits.has(a):
				gaits.append(a)
		for slow: float in [1.0, 0.7]:
			var speed := float(stats.speed) * slow
			var g: String = Stride.gait(rig, gaits, size, speed, "")
			check(_fits(rig, g, size, speed), "%s hunts at %.1f m/s in %s at %.2f times its pace" % [kind, speed, g, speed / Stride.pace(rig, g, size)])
		var walk_anim: String = anims.get("Walking_A", "Walking_A")
		var stroll := minf(float(stats.speed) * 0.5, Stride.top_speed(rig, walk_anim, size))
		check(_fits(rig, walk_anim, size, stroll), "%s strolls with planted feet" % kind)

	# Villagers walk, amble and run.
	for id: String in Villager.ROLES:
		var size := float(Villager.ROLES[id].get("scale", 1.0)) * BodyLook.scale_of(Villager.ROLES[id].get("sex", BodyLook.DEFAULT))
		for pair in [["Walking_A", Villager.WALK_SPEED * 1.2], ["Walking_B", Villager.WALK_SPEED * 0.6], ["Running_A", Villager.RUN_SPEED]]:
			var speed := minf(pair[1], Stride.top_speed("kaykit", pair[0], size))
			check(_fits("kaykit", pair[0], size, speed), "villager %s: %s at %.1f m/s" % [id, pair[0], speed])

	# Wild animals stroll and bolt; companions amble, follow and race.
	for kind: String in Animal.KINDS:
		var stats: Dictionary = Animal.KINDS[kind]
		var rig: String = Stride.rig_of(str(stats.model))
		var size := float(stats.scale)
		check(_fits(rig, "Walk", size, minf(float(stats.walk) * 1.4, Stride.top_speed(rig, "Walk", size))), "%s walks with planted hooves" % kind)
		check(_fits(rig, "Gallop", size, float(stats.run)), "%s bolts with planted hooves" % kind)
	for kind: String in Companions.SPECIES:
		var species: Dictionary = Companions.SPECIES[kind]
		var rig: String = Stride.rig_of(str(species.model))
		var size := float(species.scale)
		for speed: float in [Pet.AMBLE_SPEED, Pet.WALK_SPEED, Pet.RUN_SPEED]:
			var g: String = Stride.gait(rig, Stride.GAITS[rig], size, speed, "")
			var moved := minf(speed, Stride.top_speed(rig, g, size)) if g == "Walk" else speed
			check(_fits(rig, g, size, moved), "companion %s: %s at %.1f m/s" % [kind, g, moved])

	# The hero: walk, sneak and the top of the run.
	var walk_pace := Player.SPEED * Player.WALK_FACTOR
	check(Stride.gait("kaykit", Stride.GAITS.kaykit, 1.0, walk_pace, "") == "Walking_A", "the hero walks at walking pace")
	check(_fits("kaykit", "Walking_A", 1.0, walk_pace), "the hero's walk keeps the feet planted")
	check(_fits("kaykit", "Walking_C", 1.0, Player.SPEED * Player.SNEAK_SPEED), "the hero's sneak keeps the feet planted")
	check(_fits("kaykit", "Walking_C", 1.0, Player.SPEED * (Player.SNEAK_SPEED + Player.SNEAK_PER_LEVEL * 13)), "a master sneak too, cloak and amulet on")
	check(_fits("kaykit", "Running_A", 1.0, walk_pace * Player.RUN_TOP), "the hero's full run keeps the feet planted")
	check(walk_pace * Player.RUN_TOP > 6.0, "running stays as fast as before")


# --- In play ---------------------------------------------------------------------

## The hero goes `cells` tiles along open floor, with the run held at
## `boost`. Returns how fast the planted foot slid over the ground compared
## with how fast the hero moved, and the highest lift onto the toes.
func _hero_stride(boost: float, anim: String) -> Array:
	var player: Player = game.player
	var lvl: Level = game.level
	var skel: Skeleton3D = player._model.find_children("*", "Skeleton3D", true, false)[0]
	var bones := ["toes.l", "toes.r"]
	# The longest straight way out along open floor from where the hero stands.
	var here := lvl.world_to_cell(player.global_position)
	var best := Vector2i.ZERO
	var best_n := 0
	for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n := 0
		while n < 12 and lvl.astar.is_in_boundsv(here + dir * (n + 1)) and not lvl.astar.is_point_solid(here + dir * (n + 1)):
			n += 1
		if n > best_n:
			best_n = n
			best = dir
	check(best_n >= 3, "open floor to walk on")
	var target := lvl.cell_to_world(here + best * best_n)
	player.path.clear()
	player.path.append(target)
	var lows := [INF, INF]
	var samples := []
	var top_lift := 0.0
	for i in 150:
		player.run_boost = boost
		await process_frame
		if player.path.is_empty():
			break
		if i < 40 or player._current_anim != anim:
			continue
		var at := []
		for b: String in bones:
			at.append(skel.global_transform * skel.get_bone_global_pose(skel.find_bone(b)).origin)
		for k in 2:
			lows[k] = minf(lows[k], at[k].y)
		samples.append([at, player.global_position])
		top_lift = maxf(top_lift, player._model.position.y)
	player.path.clear()
	var slide := 0.0
	var moved := 0.0
	for i in range(1, samples.size()):
		var body: Vector3 = samples[i][1] - samples[i - 1][1]
		for k in 2:
			if samples[i][0][k].y - lows[k] < 0.02 and samples[i - 1][0][k].y - lows[k] < 0.02:
				var d: Vector3 = samples[i][0][k] - samples[i - 1][0][k]
				slide += Vector2(d.x, d.z).length()
				moved += Vector2(body.x, body.z).length()
	await _wait(30)
	return [slide / moved if moved > 0.0 else 1.0, top_lift, samples.size()]


func _hero_in_play() -> void:
	var player: Player = game.player
	var walk: Array = await _hero_stride(1.0, "Walking_A")
	check(walk[2] > 20, "the hero walked (%d frames)" % walk[2])
	# The walk's own foot speeds up and slows down a little within each step,
	# so even matched on average the toes creep a bit; out of step (as
	# before Stride) they slid over half the way.
	check(walk[0] < 0.3, "a walking hero's planted foot stays put (slides %.0f %% of the way)" % (walk[0] * 100.0))
	check(walk[1] > Stride.LIFT_HEIGHT * player._model.scale.x * 0.8, "the walking hero rises onto the toes (%.3f m)" % walk[1])
	var jog: Array = await _hero_stride(1.35, "Running_B")
	check(jog[2] > 10, "the hero jogged (%d frames)" % jog[2])
	check(jog[0] < 0.2, "a jogging hero's planted foot stays put (slides %.0f %% of the way)" % (jog[0] * 100.0))
	check(jog[1] == 0.0, "no toe lift in the jog")
	var run: Array = await _hero_stride(Player.RUN_TOP, "Running_A")
	check(run[2] > 10, "the hero ran (%d frames)" % run[2])
	check(run[0] < 0.25, "a running hero's planted foot stays put (slides %.0f %% of the way)" % (run[0] * 100.0))
