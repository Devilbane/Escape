class_name WinterHats
extends RefCounted
## The winter hats of the village (see WinterWear.HAT_OF): soft, rounded shapes that sit snugly over
## the head instead of standing on it, in the chunky low-poly look of the KayKit people.
##
## - "bobble": a knit cap with a ribbed cuff, a stripe and a fluffy bobble on top.
## - "earflap": a knit cap with earflaps, a zigzag band, braided ties and a bobble.
## - "stocking": a long knit cap whose tip flops over to the back, with a bobble at its end.
## - "watch": a snug rolled knit cap with a deep ribbed cuff (for the workers).
## - "ushanka": a fur hat, a thick fur roll round a cloth crown, with fur earflaps.
## - "herald": a fur cap with a soft cloth top that falls to one side, a gold tassel, a plume and a
##   brooch on the front.
## - "hood": a hood over the head and shoulders, open round the face, with a point at the back and a
##   rolled edge round the face (fur where it has fur, else the trim colour).
## - "shawl": a wool shawl over the head and round the shoulders, striped, with a fringe.
##
## Everything is measured from the head's box (WinterWear._head_box): `top` is the crown of the head
## and `w` half its width, so the same hat fits every model, child or grown-up.

const SIDES := 16
## How square the rings are (2 is round): the KayKit heads are rounded boxes.
const SQUARE := 2.6


## The hat of the given kind, sized to the head's box, in one mesh.
static func mesh(kind: String, box: AABB, cloth: Color, trim: Color, fur: Array) -> ArrayMesh:
	var st := WinterWear._start()
	var top := box.end.y
	var w := box.size.x * 0.5
	# A fur hat always has fur; only a hood goes without.
	var pelt: Array = fur if not fur.is_empty() else WinterWear.FURS["bear"]
	match kind:
		"earflap":
			_earflap(st, top, w, cloth, trim)
		"stocking":
			_stocking(st, top, w, cloth, trim)
		"watch":
			_watch(st, top, w, cloth, trim)
		"ushanka":
			_ushanka(st, top, w, cloth, pelt)
		"herald":
			_herald(st, top, w, cloth, trim, pelt)
		"hood":
			_hood(st, top, w, cloth, trim, fur, true)
		"shawl":
			_hood(st, top, w, cloth, trim, [], false)
		_:
			_bobble(st, top, w, cloth, trim)
	return WinterWear._finish(st)


# --- The hats ------------------------------------------------------------------------

## The rounded crown every knit cap shares, from `from` (a height below the top) up: rings of
## (height, width), closed at the top.
static func _crown(top: float, w: float, from: float) -> Array:
	var rings := [[top - from, w * 1.02]]
	for r in [[top - 0.14, w * 0.98], [top - 0.02, w * 0.9], [top + 0.09, w * 0.74], [top + 0.17, w * 0.48], [top + 0.21, 0.0]]:
		if r[0] > top - from:
			rings.append(r)
	return rings


static func _bobble(st: SurfaceTool, top: float, w: float, cloth: Color, trim: Color) -> void:
	var cuff := top - 0.38
	_cuff(st, cuff, cuff + 0.15, w, cloth, 0.0)
	var rings := _crown(top, w, 0.23)
	# A stripe in the trim colour round the middle of the crown.
	_shell(st, rings, func(k: int, _i: int) -> Color: return trim if k == 1 else cloth.darkened(0.04 * (k % 2)))
	_ball(st, Vector3(0, top + 0.27, 0), 0.14, trim)


static func _earflap(st: SurfaceTool, top: float, w: float, cloth: Color, trim: Color) -> void:
	var foot := top - 0.38
	# A zigzag band round the brow, then the plain crown.
	var rings := [[foot, w * 1.04], [foot + 0.08, w * 1.04], [foot + 0.16, w * 1.02]]
	rings.append_array(_crown(top, w, 0.22))
	var zigzag := func(k: int, i: int) -> Color:
		if k == 0:
			return trim if i % 2 == 0 else cloth
		if k == 1:
			return cloth if i % 2 == 0 else trim
		return cloth
	_shell(st, rings, zigzag)
	# The earflaps over the ears, and a braided tie hanging from each.
	for side in [-1.0, 1.0]:
		var a: float = side * PI * 0.5
		_flap(st, a, [[foot + 0.06, w * 1.05, 0.62], [foot - 0.14, w * 1.06, 0.5], [foot - 0.3, w * 1.05, 0.28]], 0.06, cloth, trim)
		var low := _sq(a, w * 1.07, foot - 0.32)
		_tube(st, [low, low + Vector3(0, -0.14, 0.02), low + Vector3(0, -0.3, 0.05)], [0.045, 0.04, 0.035], trim, 6)
		_ball(st, low + Vector3(0, -0.34, 0.05), 0.065, trim)
	_ball(st, Vector3(0, top + 0.26, 0), 0.13, trim)


static func _stocking(st: SurfaceTool, top: float, w: float, cloth: Color, trim: Color) -> void:
	var cuff := top - 0.38
	_cuff(st, cuff, cuff + 0.14, w, trim, 0.0)
	_shell(st, [[cuff + 0.14, w * 1.02], [top - 0.12, w * 0.98], [top - 0.02, w * 0.92], [top + 0.04, w * 0.74], [top + 0.09, 0.0]], func(_k: int, _i: int) -> Color: return cloth)
	# The crown is closed over the head (the tip's tube is round, the crown square: no gap where they meet).
	# The tip rises from the crown and flops over to the back and the side, in stripes.
	var path := [Vector3(0, top - 0.06, 0), Vector3(0, top + 0.1, -0.03), Vector3(0.04, top + 0.26, -0.14),
		Vector3(0.14, top + 0.33, -0.32), Vector3(0.26, top + 0.27, -0.5), Vector3(0.34, top + 0.1, -0.62)]
	var radii := [w * 0.9, w * 0.74, w * 0.56, w * 0.38, w * 0.24, w * 0.13]
	_tube(st, path, radii, cloth, SIDES, trim)
	_ball(st, path[path.size() - 1] + Vector3(0.02, -0.08, -0.03), 0.13, trim)


static func _watch(st: SurfaceTool, top: float, w: float, cloth: Color, trim: Color) -> void:
	var cuff := top - 0.34
	# A deep turned-up cuff with a stripe in the trim colour, and a small rounded crown that sits
	# high on the head.
	_cuff(st, cuff, cuff + 0.18, w, cloth, 0.09, trim)
	_shell(st, [[cuff + 0.18, w * 1.0], [top - 0.04, w * 0.92], [top + 0.07, w * 0.74], [top + 0.14, w * 0.44], [top + 0.17, 0.0]],
		func(k: int, i: int) -> Color: return cloth.darkened(0.06) if (i + k) % 2 == 0 else cloth)


static func _ushanka(st: SurfaceTool, top: float, w: float, cloth: Color, fur: Array) -> void:
	var foot := top - 0.4
	# The cloth crown, rounded, with a seam across it.
	_shell(st, [[foot + 0.1, w * 1.0], [top - 0.1, w * 0.98], [top + 0.03, w * 0.88], [top + 0.12, w * 0.68], [top + 0.18, w * 0.36], [top + 0.2, 0.0]],
		func(_k: int, i: int) -> Color: return cloth.darkened(0.12) if i % (SIDES / 2) == 0 else cloth)
	# The thick fur roll round it, higher at the front where the flap is turned up.
	_roll(st, foot, w * 1.04, 0.2, 0.1, fur, 0.07)
	# The fur earflaps, hanging down over the ears.
	for side in [-1.0, 1.0]:
		var a: float = side * PI * 0.5
		_flap(st, a, [[foot + 0.06, w * 1.1, 0.62], [foot - 0.14, w * 1.1, 0.54], [foot - 0.3, w * 1.08, 0.36]], 0.08, fur[0], fur[1])


static func _herald(st: SurfaceTool, top: float, w: float, cloth: Color, trim: Color, fur: Array) -> void:
	var foot := top - 0.4
	# The soft cloth top rises out of the fur and falls over to the left, ending in a gold tassel.
	var path := [Vector3(0, foot + 0.2, 0), Vector3(0, top + 0.02, 0), Vector3(-0.08, top + 0.2, -0.02),
		Vector3(-0.3, top + 0.26, -0.05), Vector3(-0.5, top + 0.14, -0.08), Vector3(-0.6, top - 0.04, -0.1)]
	var radii := [w * 0.98, w * 0.94, w * 0.72, w * 0.46, w * 0.28, w * 0.14]
	_tube(st, path, radii, cloth, SIDES)
	var tip: Vector3 = path[path.size() - 1]
	_tube(st, [tip, tip + Vector3(-0.02, -0.08, 0)], [0.05, 0.03], trim, 6)
	_cone(st, tip + Vector3(-0.02, -0.07, 0), tip + Vector3(-0.03, -0.26, 0), 0.08, trim)
	# A tall, thick fur band, puffed out in the middle.
	_shell(st, [[foot, w * 1.04], [foot + 0.07, w * 1.13], [foot + 0.17, w * 1.15], [foot + 0.24, w * 1.1], [foot + 0.27, w * 0.98]],
		func(k: int, i: int) -> Color: return fur[0].lerp(fur[1], 0.35) if (i + k) % 3 == 0 else fur[0])
	# A gold brooch on the front of the band, and a white plume rising from it, swept back.
	var front := _sq(0.0, w * 1.15, foot + 0.13)
	_ball(st, front + Vector3(0.12, 0, 0.02), 0.08, trim, 0.0)
	_plume(st, front + Vector3(0.14, 0.04, -0.02), [Vector3(0.18, 0.2, -0.05), Vector3(0.26, 0.44, -0.18), Vector3(0.3, 0.6, -0.42)], 0.1, Color(0.98, 0.97, 0.94), trim)


## A hood (or, without its point, a shawl) over the head and shoulders, open round the face. `fur`
## gives the face's edge a fur roll; without fur the edge is rolled in the trim colour.
static func _hood(st: SurfaceTool, top: float, w: float, cloth: Color, trim: Color, fur: Array, pointed: bool) -> void:
	const N := 20
	# The rings from the shoulders up: height, width, depth, how far back the ring's centre lies,
	# and how wide the face's opening is below it (a half angle from the front; 0 closes it).
	var rings := [
		[top - 1.06, w * 1.42, w * 1.12, -0.06, 0.95],
		[top - 0.88, w * 1.16, w * 1.08, -0.06, 0.75],
		[top - 0.62, w * 1.18, w * 1.1, -0.06, 0.62],
		[top - 0.36, w * 1.18, w * 1.12, -0.07, 0.56],
		[top - 0.18, w * 1.14, w * 1.1, -0.08, 0.0],
		[top + 0.0, w * 1.02, w * 1.04, -0.1, 0.0],
		[top + 0.12, w * 0.8, w * 0.86, -0.14, 0.0],
		[top + 0.18, w * 0.46, w * 0.52, -0.2, 0.0],
	]
	var peak := Vector3(0, top + 0.2, -0.26)
	if pointed:
		peak = Vector3(0, top + 0.12, -0.78)
	var stripe := cloth.darkened(0.14) if pointed else trim
	var colour_of := func(k: int) -> Color:
		if pointed:
			return cloth if k % 2 == 0 else cloth.darkened(0.05)
		return stripe if k == 1 or k == 4 else cloth
	var edge := []
	for k in rings.size() - 1:
		var r0: Array = rings[k]
		var r1: Array = rings[k + 1]
		var opening: float = r0[4]
		st.set_color(colour_of.call(k))
		for i in N:
			var a0 := TAU * i / N - PI
			var a1 := TAU * (i + 1) / N - PI
			if absf((a0 + a1) * 0.5) < opening:
				continue
			var b0 := _sq3(a0, r0)
			var b1 := _sq3(a1, r0)
			var t0 := _sq3(a0, r1)
			var t1 := _sq3(a1, r1)
			for p in [b0, b1, t1, b0, t1, t0]:
				st.add_vertex(p)
	# The edge round the face: up the right side, across the brow, down the left.
	var right := []
	for k in 4:
		var e := _edge_angle(rings[k][4], N)
		right.append(_sq3(e, rings[k]))
		right.append(_sq3(e, rings[k + 1]))
		if k < 3:
			var e_next := _edge_angle(rings[k + 1][4], N)
			if absf(e_next - e) > 0.01:
				right.append(_sq3(e_next, rings[k + 1]))
	var brow := []
	var e_top := _edge_angle(rings[3][4], N)
	for j in 5:
		brow.append(_sq3(lerpf(e_top, -e_top, float(j) / 4), rings[4]))
	for p in right:
		edge.append(p)
	for j in range(1, brow.size() - 1):
		edge.append(brow[j])
	for k in range(right.size() - 1, -1, -1):
		var p: Vector3 = right[k]
		edge.append(Vector3(-p.x, p.y, p.z))
	# Lifted a little off the hood, so the roll sits on its edge.
	var radii := []
	for p in edge:
		radii.append(0.085 if not fur.is_empty() else 0.045)
	if not fur.is_empty():
		_tube(st, edge, radii, fur[0], 7, fur[1])
	else:
		_tube(st, edge, radii, trim, 6)
	# The crown, closed, running out to the point at the back.
	var last: Array = rings[rings.size() - 1]
	st.set_color(colour_of.call(rings.size() - 1))
	for i in N:
		var a0 := TAU * i / N - PI
		var a1 := TAU * (i + 1) / N - PI
		st.add_vertex(_sq3(a0, last))
		st.add_vertex(_sq3(a1, last))
		st.add_vertex(peak)
	# The shawl's fringe along its lower edge.
	if not pointed:
		var low: Array = rings[0]
		st.set_color(trim)
		for i in N:
			var a0 := TAU * i / N - PI
			var a1 := TAU * (i + 1) / N - PI
			if absf((a0 + a1) * 0.5) < low[4]:
				continue
			var p0 := _sq3(a0, low)
			var p1 := _sq3(a1, low)
			var mid := (p0 + p1) * 0.5 + Vector3(0, -0.1, 0)
			for p in [p0, p1, mid]:
				st.add_vertex(p)


# --- Shapes --------------------------------------------------------------------------

## A point on a rounded-square ring of half-width `r` at height `y`, at the angle `a` (0 is the
## front, +z).
static func _sq(a: float, r: float, y: float, depth := 0.96, back := 0.0) -> Vector3:
	var s := sin(a)
	var c := cos(a)
	var e := 2.0 / SQUARE
	return Vector3(signf(s) * pow(absf(s), e) * r, y, back + signf(c) * pow(absf(c), e) * r * depth)


## A hood ring's point: ring is (height, width, depth, back, opening).
static func _sq3(a: float, ring: Array) -> Vector3:
	return _sq(a, ring[1], ring[0], float(ring[2]) / float(ring[1]), ring[3])


## Where the face's opening of a hood band ends: the edge of the last segment left out.
static func _edge_angle(opening: float, n: int) -> float:
	var step := TAU / n
	var e := 0.0
	for i in n:
		var mid := TAU * (i + 0.5) / n - PI
		if absf(mid) < opening:
			e = maxf(e, absf(mid) + step * 0.5)
	return e


## Rings of (height, half-width) from the bottom up, each band coloured by `colour_of(k, i)`; a last
## ring of width 0 closes the top.
static func _shell(st: SurfaceTool, rings: Array, colour_of: Callable) -> void:
	for k in rings.size() - 1:
		var r0: Array = rings[k]
		var r1: Array = rings[k + 1]
		for i in SIDES:
			var a0 := TAU * i / SIDES
			var a1 := TAU * (i + 1) / SIDES
			st.set_color(colour_of.call(k, i))
			var b0 := _sq(a0, r0[1], r0[0])
			var b1 := _sq(a1, r0[1], r0[0])
			var t0 := _sq(a0, r1[1], r1[0])
			var t1 := _sq(a1, r1[1], r1[0])
			for p in [b0, b1, t1, b0, t1, t0]:
				st.add_vertex(p)


## A turned-up knit cuff from `y0` to `y1`: a little wider than the cap, ribbed in two shades, its
## top edge rolled over. `stripe` > 0 also knits a thin stripe of `stripe_colour` into it at that
## height above `y0`.
static func _cuff(st: SurfaceTool, y0: float, y1: float, w: float, wool: Color, stripe: float, stripe_colour := Color.WHITE) -> void:
	var rib := wool.darkened(0.1)
	var rings := [[y0, w * 1.03], [y0 + 0.02, w * 1.07], [y1 - 0.03, w * 1.08], [y1, w * 1.06], [y1 + 0.005, w * 1.01]]
	_shell(st, rings, func(_k: int, i: int) -> Color: return wool if i % 2 == 0 else rib)
	if stripe > 0.0:
		_shell(st, [[y0 + stripe - 0.03, w * 1.085], [y0 + stripe + 0.0, w * 1.085]], func(_k: int, _i: int) -> Color: return stripe_colour)


## A rounded fur roll round the head from `foot`, `height` high and bulging out by `bulge`, raised
## by `lift` at the front (a turned-up flap), its tufts in the fur's two colours.
static func _roll(st: SurfaceTool, foot: float, w: float, height: float, lift: float, fur: Array, bulge: float) -> void:
	var steps := [[0.0, 0.0], [0.25, 0.75], [0.5, 1.0], [0.8, 0.7], [1.0, -0.4]]
	for k in steps.size() - 1:
		for i in SIDES:
			var a0 := TAU * i / SIDES
			var a1 := TAU * (i + 1) / SIDES
			st.set_color(fur[0].lerp(fur[1], 0.45) if (i + k) % 3 == 0 else fur[0])
			var pts := []
			for q in [[a0, k], [a1, k], [a1, k + 1], [a0, k + 1]]:
				var a: float = q[0]
				var s: Array = steps[q[1]]
				var up := lift * pow(maxf(cos(a), 0.0), 2.0)
				pts.append(_sq(a, w + bulge * s[1], foot + (height + up) * s[0]))
			for p in [pts[0], pts[1], pts[2], pts[0], pts[2], pts[3]]:
				st.add_vertex(p)


## A flap over the ear at the angle `a`: rows of (height, distance out, half-width in radians) from
## the top down, `thick` deep, its lower edge in the second colour.
static func _flap(st: SurfaceTool, a: float, rows: Array, thick: float, colour: Color, edge: Color) -> void:
	var outer := []
	var inner := []
	for row in rows:
		var h: float = row[2]
		var o := []
		var n := []
		for j in 5:
			var b := a + lerpf(-h, h, j / 4.0) * 0.5
			o.append(_sq(b, row[1], row[0]))
			n.append(_sq(b, row[1] - thick, row[0]))
		outer.append(o)
		inner.append(n)
	for k in rows.size() - 1:
		st.set_color(colour if k < rows.size() - 2 else colour.lerp(edge, 0.5))
		for j in 4:
			var q := [outer[k][j], outer[k][j + 1], outer[k + 1][j + 1], outer[k + 1][j]]
			for p in [q[0], q[1], q[2], q[0], q[2], q[3]]:
				st.add_vertex(p)
			var m := [inner[k][j], inner[k][j + 1], inner[k + 1][j + 1], inner[k + 1][j]]
			for p in [m[0], m[2], m[1], m[0], m[3], m[2]]:
				st.add_vertex(p)
		# The sides of the flap.
		for j in [0, 4]:
			var q := [outer[k][j], outer[k + 1][j], inner[k + 1][j], inner[k][j]]
			for p in [q[0], q[1], q[2], q[0], q[2], q[3]]:
				st.add_vertex(p)
	# The rounded bottom edge.
	var last := rows.size() - 1
	st.set_color(edge)
	for j in 4:
		var q := [outer[last][j], outer[last][j + 1], inner[last][j + 1], inner[last][j]]
		for p in [q[0], q[1], q[2], q[0], q[2], q[3]]:
			st.add_vertex(p)


## A tube along `path` with a radius at each point, closed at both ends. With `stripe`, every other
## stretch is knitted in that colour.
static func _tube(st: SurfaceTool, path: Array, radii: Array, colour: Color, sides: int, stripe = null) -> void:
	var rings := []
	var normal := Vector3.ZERO
	for k in path.size():
		var p: Vector3 = path[k]
		var ahead: Vector3 = path[mini(k + 1, path.size() - 1)]
		var behind: Vector3 = path[maxi(k - 1, 0)]
		var t := (ahead - behind).normalized()
		if normal == Vector3.ZERO:
			normal = t.cross(Vector3.RIGHT if absf(t.x) < 0.9 else Vector3.FORWARD).normalized()
		normal = (normal - t * t.dot(normal)).normalized()
		var bi := t.cross(normal)
		var ring := []
		for i in sides:
			var a := TAU * i / sides
			ring.append(p + (normal * cos(a) + bi * sin(a)) * float(radii[k]))
		rings.append(ring)
	for k in path.size() - 1:
		st.set_color(stripe if stripe is Color and k % 2 == 1 else colour)
		for i in sides:
			var j := (i + 1) % sides
			var b0: Vector3 = rings[k][i]
			var b1: Vector3 = rings[k][j]
			var t0: Vector3 = rings[k + 1][i]
			var t1: Vector3 = rings[k + 1][j]
			for q in [b0, b1, t1, b0, t1, t0]:
				st.add_vertex(q)
	st.set_color(colour)
	for end in [0, path.size() - 1]:
		for i in sides:
			st.add_vertex(path[end])
			st.add_vertex(rings[end][i])
			st.add_vertex(rings[end][(i + 1) % sides])


## A fluffy ball (a bobble or a brooch): a low-poly sphere, its points pushed in and out a little
## so it looks knotted from wool. `fluff` 0 keeps it smooth.
static func _ball(st: SurfaceTool, at: Vector3, r: float, colour: Color, fluff := 0.18) -> void:
	const RINGS := 5
	const AROUND := 8
	var pts := []
	for k in RINGS + 1:
		var lat := PI * k / RINGS
		var row := []
		for i in AROUND:
			var lon := TAU * (i + 0.5 * (k % 2)) / AROUND
			var d := Vector3(sin(lat) * sin(lon), cos(lat), sin(lat) * cos(lon))
			var jitter := 1.0 + fluff * (fposmod(sin(k * 12.9 + i * 78.2) * 43758.5, 1.0) - 0.5)
			row.append(at + d * r * (jitter if k > 0 and k < RINGS else 1.0))
		pts.append(row)
	for k in RINGS:
		st.set_color(colour.darkened(0.06) if k % 2 == 1 else colour)
		for i in AROUND:
			var j := (i + 1) % AROUND
			var b0: Vector3 = pts[k][i]
			var b1: Vector3 = pts[k][j]
			var t0: Vector3 = pts[k + 1][i]
			var t1: Vector3 = pts[k + 1][j]
			for q in [b0, t0, t1, b0, t1, b1]:
				st.add_vertex(q)


## A tassel: a cone from `from` widening down to `to`, `r` wide at its foot.
static func _cone(st: SurfaceTool, from: Vector3, to: Vector3, r: float, colour: Color) -> void:
	const AROUND := 7
	st.set_color(colour)
	for i in AROUND:
		var a0 := TAU * i / AROUND
		var a1 := TAU * (i + 1) / AROUND
		var p0 := to + Vector3(sin(a0) * r, 0, cos(a0) * r)
		var p1 := to + Vector3(sin(a1) * r, 0, cos(a1) * r)
		for q in [from, p0, p1, to, p1, p0]:
			st.add_vertex(q)


## A feather plume: a blade from `root` along `bends` (offsets from the root), widest in the middle,
## its quill in the second colour.
static func _plume(st: SurfaceTool, root: Vector3, bends: Array, width: float, colour: Color, quill: Color) -> void:
	var spine := [root]
	for b in bends:
		spine.append(root + b)
	var widths := [0.02, width, width * 0.9, 0.01]
	for k in spine.size() - 1:
		var p0: Vector3 = spine[k]
		var p1: Vector3 = spine[k + 1]
		var side := Vector3(1, 0, 0.35).normalized()
		var w0: float = widths[mini(k, widths.size() - 1)]
		var w1: float = widths[mini(k + 1, widths.size() - 1)]
		st.set_color(colour if k > 0 else quill)
		for q in [p0 - side * w0, p0 + side * w0, p1 + side * w1, p0 - side * w0, p1 + side * w1, p1 - side * w1]:
			st.add_vertex(q)
		# A darker fold down the middle, so it reads as a feather from above.
		st.set_color(colour.darkened(0.12))
		var up := Vector3(0, 0.02, 0)
		for q in [p0 + up, p0 + side * w0 * 0.15, p1 + side * w1 * 0.15, p0 + up, p1 + side * w1 * 0.15, p1 + up]:
			st.add_vertex(q)
