class_name WeatherWarmup
extends RefCounted
## Builds the shaders of every weather while a level in the open air loads, so a change of weather
## later does not freeze the screen.
##
## The first, dark frame of a level builds the shaders of everything in it, but only as the
## weather of that moment draws it (see LevelWarmup). Bad weather brings the haze (the
## environment's fog), and with it every material in view needs a version of its shader with fog:
## when rain or fog rolled in later, or the hero walked on and new things came into view, each was
## built in the middle of play and the screen stuttered. The rain, the snow, the drifting mist,
## the fog clouds, the filled puddles and the snow on the world (see SnowCover) were never drawn
## at all before their weather came.
##
## So the level's warm-up gets one more frame (a pass, see LevelWarmup.begin): in it the haze is
## the other way round (on in clear air, off in bad weather), and every weather effect is shown
## at once, though nothing of it can be seen (the particles have not started, the clouds are
## clear and the screen is still dark). Game.hold_weather_warmup keeps that state over the game's
## own weather drawing for the frame; the next frame draws the weather as it is again.

## Haze as thick as in the rain (see Weather.LOOKS): any amount builds the same shaders.
const HAZE := 0.006

## True for the one frame of the pass.
static var on := false


## The extra warm-up frame for `game`'s level: one in the open air, none below ground.
static func passes(game: Node) -> Array:
	if not (game.level is Outdoor):
		return []
	return [[func() -> void: _start(game), func() -> void: _stop(game)]]


static func _start(game: Node) -> void:
	on = true
	for p in _effects(game):
		p.set_meta(LevelWarmup.KEY, p.extra_cull_margin)
	hold(game)


## The particles that follow the hero: rain, drifting mist, snowflakes and autumn leaves.
static func _effects(game: Node) -> Array[GeometryInstance3D]:
	return [game._rain, game._mist, game._snow, game._leaves]


## Shows every weather effect of `game` for the warm-up frame, over what the game set for this
## frame (call it after the game drew its weather; calling it twice changes nothing).
static func hold(game: Node) -> void:
	if not on or game.level == null or not is_instance_valid(game.level):
		return
	# The other way round from what the weather of the moment draws (see Weather.apply).
	var env: Environment = game._env
	var hazy := float(game._seen_look().fog) > 0.0005
	env.fog_enabled = not hazy
	if not hazy:
		env.fog_density = HAZE
	var at: Vector3 = game.player.global_position if game.player else Vector3.ZERO
	for p in _effects(game):
		p.visible = true
		p.extra_cull_margin = LevelWarmup.MARGIN
		p.global_position = at + Vector3(0, 1, 0)
	game._clouds.visible = true
	var lvl := game.level as Outdoor
	lvl.set_puddles(1.0, 1.0)
	if lvl.snow != null and not lvl.snow.lies():
		lvl.snow.set_amount(0.01)


## After the frame: the game draws its weather as it is again from the next frame on; only the
## snow that was put on the world for the frame is taken off here, and the particles' margins.
static func _stop(game: Node) -> void:
	on = false
	for p in _effects(game):
		if is_instance_valid(p) and p.has_meta(LevelWarmup.KEY):
			p.extra_cull_margin = p.get_meta(LevelWarmup.KEY)
			p.remove_meta(LevelWarmup.KEY)
	if game.level is Outdoor and is_instance_valid(game.level):
		var lvl := game.level as Outdoor
		if lvl.snow != null:
			lvl.snow.set_amount(game.snow_cover)
