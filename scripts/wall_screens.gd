class_name WallScreens
extends RefCounted
## The two wall screens the game opens over everything (the game stands still while one is open): the wall
## workshop (from the testing panel) and a climb on a placed wall (see WallPlacements). Each is a layer
## above the game that runs while the tree is paused, and goes away when it is done.

const LAYER := 90
## Klettern training for each metre of wall climbed (a part of what the mountain rock gives).
const TRAIN_FRACTION := 0.5


static func _layer(game: Node) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(layer)
	game.get_tree().paused = true
	return layer


static func _close(game: Node, layer: CanvasLayer) -> void:
	layer.queue_free()
	game.get_tree().paused = false


## The wall workshop over the game.
## The chat command that opens the workshop (dev builds, like the testing panel it is also in).
const COMMAND := "climbwall"


static func is_command(line: String) -> bool:
	return TestPanel.ENABLED and line.strip_edges().to_lower() == COMMAND


static func open_workshop(game: Node) -> void:
	var layer := _layer(game)
	var shop := WallWorkshop.new()
	shop.closed.connect(_close.bind(game, layer))
	layer.add_child(shop)


## The weather of the game as the wall's weather.
static func weather_of(game_weather: String) -> String:
	match game_weather:
		Weather.RAIN:
			return WallWeather.RAIN
		Weather.STORM:
			return WallWeather.STORM
		Weather.SNOW:
			return WallWeather.SNOW
	return WallWeather.CLEAR


## A climb of the hero on the wall file `file` (see WallPlacements). The hero's Klettern (with the climbing
## set's bonus) is the climber's level, stones that graze the hero take life points, the wall's weather
## worsens while the climb lasts, and at the top the wall's summit takes the hero on.
static func open_climb(game: Node, file: String) -> void:
	var wall := WallPlacements.load_wall(file)
	if wall == null:
		Events.tell(Lang.t("Diese Wand gibt es nicht mehr."), Color(0.8, 0.85, 1.0))
		return
	var layer := _layer(game)
	var stage := WallStage.new()
	stage.drift = true
	var level: int = game.player.skill("klettern") + Climbing.set_bonus(game.player.equipped)
	stage.setup(wall, maxi(1, level), true, weather_of(game.weather), int(game.player.attribute("konstitution")))
	layer.add_child(stage)
	stage.climb.gear = game.player._rock_has_gear()
	stage.climb.dexterity = int(game.player.attribute("geschick"))
	stage.climb.intuition = int(game.player.attribute("intuition"))
	stage.climb.wisdom = int(game.player.attribute("weisheit"))
	# The climbing meter is the run meter: the hero starts with what is left of it and keeps what is left.
	stage.climb.stamina_max = game.player.max_stamina()
	stage.climb.recovery = game.player.stamina_recovery()
	stage.climb.stamina = game.player.stamina if game.player.stamina >= 0.0 else stage.climb.stamina_max
	stage.hurt.connect(func(n: int) -> void: game.player.hp = maxi(1, game.player.hp - n))
	stage.gathered.connect(func(id: String, count: int) -> void: game._on_ingredient_collected(id, count))
	stage.door_reached.connect(func(_cell: Vector2i) -> void:
		var door := WallPlacements.door_of(wall)
		var index: int = game.level_files.find(game.LEVEL_DIR + String(door[0])) if not door.is_empty() else -1
		if index < 0:
			return
		_close(game, layer)
		game.teleport_to(index, false, String(door[1])))
	stage.finished.connect(func(outcome: String) -> void:
		var best := float(wall.height - (stage.climb.cell.y if not stage.climb.on_ground() else wall.height))
		game.player.train("klettern", Training.CLIMB_PER_METRE * best * TRAIN_FRACTION)
		game.player.stamina = minf(stage.climb.stamina, game.player.max_stamina())
		_close(game, layer)
		var summit := WallPlacements.summit_of(wall)
		if outcome == "top" and not summit.is_empty():
			var index: int = game.level_files.find(game.LEVEL_DIR + String(summit[0]))
			if index >= 0:
				game.teleport_to(index, false, String(summit[1]))
				return
		if outcome == "top":
			Events.tell(Lang.t("Du stehst am Gipfel der Wand."), Color(0.8, 0.95, 1.0))
		elif outcome == "gave_up":
			Events.tell(Lang.t("Du hast aufgegeben und bist abgeseilt."), Color(0.8, 0.85, 1.0)))
