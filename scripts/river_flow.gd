class_name RiverFlow
extends RefCounted
## Leaves and sticks drifting down the farming valley's river (map letter "≈"), so its current is seen: the
## river's spring in the west, past the bridge and on east. Each stretch between two waypoints is one
## seasonal StreamFlow (the same leaves and sticks as the stream's: half as many leaves in spring and
## summer, the autumn colours in autumn, none in winter, sticks all year). The little river that carries the
## sewer's water north from the outfall, and the stream to the grating, have their own flows
## (see SewerSurface).
##
## The waypoints are tile coordinates (x, y of a tile's middle) in the order of the current; every one lies on
## a water tile (tests/river_flow.gd checks).

const MAP := "Die Freiheit"
const WATER := "≈‖"
const WAYPOINTS: Array[Vector2] = [
	Vector2(26.5, 61.5), Vector2(27.5, 63.5), Vector2(30.5, 65.5), Vector2(34.5, 66.5), Vector2(38.5, 67.5),
	Vector2(42.5, 68.5), Vector2(46.5, 69.5), Vector2(50.5, 68.5), Vector2(55.5, 66.5), Vector2(60.5, 64.5),
	Vector2(65.5, 63.5), Vector2(72.5, 62.5), Vector2(80.5, 61.5), Vector2(90.5, 61.5), Vector2(100.5, 60.5),
	Vector2(105.5, 61.5), Vector2(108.5, 63.5), Vector2(112.5, 65.5), Vector2(116.5, 67.5), Vector2(125.5, 68.5),
	Vector2(136.5, 68.5),
]
## The river's width the bits spread over (m), the pace of the current (m/s) and how many leaves there are to a metre.
const WIDTH := 5.0
const SPEED := 0.6
const LEAVES_PER_METRE := 0.25
const SURFACE := 0.06


## Lays the flows on `lvl` (an Outdoor) if its map has this river.
static func build(lvl: Node3D) -> void:
	if lvl.level_name != MAP:
		return
	var tile := Level.TILE
	for i in WAYPOINTS.size() - 1:
		var a := WAYPOINTS[i]
		var b := WAYPOINTS[i + 1]
		var flow := StreamFlow.new()
		flow.name = "RiverFlow%d" % i
		flow.from = Vector3(a.x * tile, SURFACE, a.y * tile)
		flow.to = Vector3(b.x * tile, SURFACE, b.y * tile)
		flow.width = WIDTH
		flow.speed = SPEED
		flow.count = clampi(int(flow.from.distance_to(flow.to) * LEAVES_PER_METRE), 6, 40)
		flow.foam_every = 0
		flow.seasonal = true
		flow.palette = StreamFlow.GREEN_LEAVES
		lvl.add_child(flow)
