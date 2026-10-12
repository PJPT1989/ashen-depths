class_name AreaGen
extends RefCounted
## Builds the shape of an area into a Dungeon: the walled town, wide outdoor ground with a
## road, rock clusters, fields, woods or ruins, and dungeons (caves, crypts, the abbey, the
## deep). Everything is drawn from one seed, so an area keeps its shape for the whole run.

static func generate(d: Dungeon, area_i: int, area_seed: int) -> void:
	seed(area_seed)
	var a: Dictionary = Act.area(area_i)
	d.reset(a.size, area_i)
	match a.kind:
		"town":
			_town(d)
		"open":
			_open(d, a.biome)
		_:
			match a.biome:
				"cave": _cave(d)
				"abbey": _abbey(d)
				"deep": _rooms(d, true)
				_: _rooms(d, false)
	if area_i > 0:
		d.entrance_style = style_between(area_i, area_i - 1)
	if area_i < Act.count() - 1:
		d.exit_style = style_between(area_i, area_i + 1)
	if a.kind != "town":
		_pack_spots(d)
	randomize()


## What the way from area a to area b looks like.
static func style_between(a: int, b: int) -> String:
	var ka: String = Act.area(a).kind
	var kb: String = Act.area(b).kind
	if kb == "dungeon":
		if ka == "dungeon":
			return "stairs_down" if b > a else "stairs_up"
		return "cave" if Act.area(b).biome == "cave" else ("door" if Act.area(b).biome == "abbey" else "stairs_down")
	if ka == "dungeon":
		return "stairs_up"
	return "gate"


# ---------- helpers ----------

static func _flood(d: Dungeon, from: Vector2i) -> PackedInt32Array:
	## Breadth-first distances over walkable tiles (-1 = unreachable).
	var dist := PackedInt32Array()
	dist.resize(d.W * d.H)
	dist.fill(-1)
	if not d.is_floor(from.x, from.y):
		return dist
	var q: Array[Vector2i] = [from]
	dist[d.idx(from.x, from.y)] = 0
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		var cd := dist[d.idx(c.x, c.y)]
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + o
			if d.is_floor(n.x, n.y) and dist[d.idx(n.x, n.y)] < 0:
				dist[d.idx(n.x, n.y)] = cd + 1
				q.append(n)
	return dist


static func _farthest(d: Dungeon, dist: PackedInt32Array) -> Vector2i:
	var best := Vector2i.ZERO
	var bd := -1
	for y in d.H:
		for x in d.W:
			var v := dist[d.idx(x, y)]
			if v > bd:
				bd = v
				best = Vector2i(x, y)
	return best


## A tile whose flood distance is close to `want`.
static func _at_distance(d: Dungeon, dist: PackedInt32Array, want: int) -> Vector2i:
	var best := Vector2i.ZERO
	var bd := 1 << 30
	for y in d.H:
		for x in d.W:
			var v := dist[d.idx(x, y)]
			if v < 0:
				continue
			var e := absi(v - want) * 4 + (0 if _open_around(d, x, y) else 50)
			if e < bd:
				bd = e
				best = Vector2i(x, y)
	return best


static func _open_around(d: Dungeon, x: int, y: int) -> bool:
	for j in range(y - 1, y + 2):
		for i in range(x - 1, x + 2):
			if not d.is_floor(i, j):
				return false
	return true


static func _c(v: Vector2i) -> Vector2:
	return Vector2(v) + Vector2(0.5, 0.5)


## Every remaining blocked tile next to the ground gets something visible standing on it.
static func _dress_border(d: Dungeon, kinds: Array, weights: Array, depth := 3) -> void:
	for y in d.H:
		for x in d.W:
			if d.map[d.idx(x, y)] == 1 or d.obst.has(Vector2i(x, y)) or d.ground[d.idx(x, y)] == Dungeon.GROUND_WATER:
				continue
			var near := d.near_floor(x, y, 1)
			if near or (d.near_floor(x, y, depth) and randf() < 0.55):
				d.obst[Vector2i(x, y)] = _weighted(kinds, weights)
				d.ground[d.idx(x, y)] = Dungeon.GROUND_FLOOR


static func _weighted(kinds: Array, weights: Array) -> String:
	var total := 0.0
	for w in weights:
		total += w
	var r := randf() * total
	for i in kinds.size():
		r -= weights[i]
		if r <= 0.0:
			return kinds[i]
	return kinds[0]


static func _pack_spots(d: Dungeon) -> void:
	var dist := _flood(d, Vector2i(d.start))
	var cands: Array[Vector2i] = []
	for y in d.H:
		for x in d.W:
			var v := dist[d.idx(x, y)]
			if v > 10 and _open_around(d, x, y):
				cands.append(Vector2i(x, y))
	cands.shuffle()
	var floor_n := 0
	for y in d.H:
		for x in d.W:
			if d.map[d.idx(x, y)] == 1:
				floor_n += 1
	var want := clampi(floor_n / (120 if d.outdoor else 70), 10, 30)
	for c in cands:
		if d.pack_spots.size() >= want:
			break
		var p := _c(c)
		if p.distance_to(d.boss_spot) < 9.0 or p.distance_to(d.waypoint) < 5.0:
			continue
		var ok := true
		for o in d.pack_spots:
			if o.distance_to(p) < (8.0 if d.outdoor else 6.0):
				ok = false
				break
		if ok:
			d.pack_spots.append(p)


# ---------- the town ----------

static func _town(d: Dungeon) -> void:
	var W := d.W
	var lo := 5
	var hi := W - 6
	for y in range(1, d.H - 1):
		for x in range(1, W - 1):
			if x >= lo and x <= hi and y >= lo and y <= hi:
				d.carve(x, y)
	for i in range(lo - 1, hi + 2):
		for p in [Vector2i(i, lo - 1), Vector2i(i, hi + 1), Vector2i(lo - 1, i), Vector2i(hi + 1, i)]:
			d.block(p.x, p.y, "palisade")
	var center := Vector2i(W / 2, W / 2 + 1)
	# the gate in the north-east wall, with the road out
	var gx := W / 2
	for y in range(1, lo + 1):
		for x in range(gx - 1, gx + 2):
			d.carve(x, y, Dungeon.GROUND_PATH)
	for y in range(lo, center.y):
		for x in range(gx - 1, gx + 1):
			d.carve(x, y, Dungeon.GROUND_PATH)
	for x in range(lo + 2, hi - 1):
		d.carve(x, center.y + 4, Dungeon.GROUND_PATH)
	# a ring of beaten earth around the fire
	for y in range(center.y - 3, center.y + 4):
		for x in range(center.x - 3, center.x + 4):
			if Vector2(x, y).distance_to(Vector2(center)) < 3.3:
				d.carve(x, y, Dungeon.GROUND_PATH)
	d.spots.fire = _c(center)
	d.block(center.x, center.y, "firepit")
	d.map[d.idx(center.x, center.y)] = 0
	# tents and stores
	var tents := [Vector2i(-8, -6), Vector2i(8, -7), Vector2i(-9, 6), Vector2i(9, 8), Vector2i(-2, -11), Vector2i(12, -1), Vector2i(-13, -1)]
	for t in tents:
		var p: Vector2i = center + t
		d.block(p.x, p.y, "tent")
	for k in 10:
		var p := Vector2i(randi_range(lo + 1, hi - 1), randi_range(lo + 1, hi - 1))
		if Vector2(p).distance_to(Vector2(center)) > 6.0 and d.ground[d.idx(p.x, p.y)] != Dungeon.GROUND_PATH:
			d.block(p.x, p.y, ["hay", "stump", "bush"].pick_random())
	d.spots.vendor = _c(center + Vector2i(7, -5))
	d.spots.healer = _c(center + Vector2i(-7, 5))
	d.spots.elder = _c(center + Vector2i(-6, -5))
	d.waypoint = _c(center + Vector2i(-7, 0))
	d.start = _c(center + Vector2i(2, 3))
	d.exit = _c(Vector2i(gx, 2))
	d.entrance = Vector2(-100, -100)
	d.boss_spot = Vector2(-100, -100)
	_dress_border(d, ["tree", "pine", "rock"], [5, 3, 1], 4)


# ---------- wide outdoor areas ----------

static func _open(d: Dungeon, biome: String) -> void:
	var W := d.W
	var H := d.H
	var n := FastNoiseLite.new()
	n.seed = randi()
	n.frequency = 0.09
	var n2 := FastNoiseLite.new()
	n2.seed = randi()
	n2.frequency = 0.045
	var n3 := FastNoiseLite.new()
	n3.seed = randi()
	n3.frequency = 0.03
	var margin := 6
	for y in H:
		for x in W:
			var e := mini(mini(x, y), mini(W - 1 - x, H - 1 - y))
			if e > margin + n.get_noise_2d(x, y) * 4.0:
				d.carve(x, y)
	# a wandering road from the bottom edge to the top edge
	var road: Array[Vector2i] = []
	var p := Vector2(randi_range(W / 4, 3 * W / 4), H - 2)
	var target := Vector2(randi_range(W / 4, 3 * W / 4), 1)
	var dir := Vector2(0, -1)
	while p.y > 1.5:
		var want := (target - p).normalized()
		dir = (dir + want * 0.22 + Vector2(randf_range(-0.55, 0.55), 0)).normalized()
		if dir.y > -0.35:
			dir = Vector2(dir.x, -0.35).normalized()
		p += dir
		p.x = clampf(p.x, margin + 4, W - margin - 5)
		var c := Vector2i(floori(p.x), floori(p.y))
		if road.is_empty() or road[road.size() - 1] != c:
			road.append(c)
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				d.carve(c.x + ox, c.y + oy, Dungeon.GROUND_PATH)
	var near_road := PackedByteArray()
	near_road.resize(W * H)
	for c in road:
		for oy in range(-3, 4):
			for ox in range(-3, 4):
				if d.inside(c.x + ox, c.y + oy):
					near_road[d.idx(c.x + ox, c.y + oy)] = 1
	d.entrance = _c(road[1])
	d.start = _c(road[mini(5, road.size() - 1)])
	d.exit = _c(road[road.size() - 2])
	d.boss_spot = _c(road[int(road.size() * 0.88)])
	var wp := road[int(road.size() * 0.3)]
	d.waypoint = _c(wp + Vector2i(3 if randf() < 0.5 else -3, 0))
	var keep := func(x: int, y: int) -> bool:
		var q := Vector2(x, y)
		return near_road[d.idx(x, y)] == 1 or q.distance_to(d.start) < 6 or q.distance_to(d.exit) < 6 \
			or q.distance_to(d.waypoint) < 3 or q.distance_to(d.boss_spot) < 5
	match biome:
		"moor":
			for y in H:
				for x in W:
					if not d.is_floor(x, y) or keep.call(x, y):
						continue
					if n3.get_noise_2d(x, y) > 0.42:
						d.map[d.idx(x, y)] = 0
						d.ground[d.idx(x, y)] = Dungeon.GROUND_WATER
					elif n2.get_noise_2d(x, y) > 0.38 and randf() < 0.7:
						d.block(x, y, "rock")
					elif randf() < 0.012:
						d.block(x, y, "deadtree")
					elif randf() < 0.01:
						d.block(x, y, "bush")
			for k in 2:
				_stone_circle(d, keep)
		"fields":
			for k in 4:
				_house(d, keep, 0.25)
			for k in 14:
				_fence_line(d, keep)
			for y in H:
				for x in W:
					if not d.is_floor(x, y) or keep.call(x, y):
						continue
					if randf() < 0.008:
						d.block(x, y, "hay")
					elif randf() < 0.008:
						d.block(x, y, "tree")
					elif randf() < 0.003:
						d.block(x, y, "gallows")
		"forest":
			for y in H:
				for x in W:
					if not d.is_floor(x, y) or keep.call(x, y):
						continue
					var v := n2.get_noise_2d(x, y)
					if v > -0.05 and randf() < 0.8:
						d.block(x, y, "pine" if randf() < 0.35 else "tree")
					elif randf() < 0.025:
						d.block(x, y, ["bush", "stump", "deadtree"].pick_random())
		"ruins":
			for k in 11:
				_house(d, keep, 0.4)
			for y in H:
				for x in W:
					if not d.is_floor(x, y) or keep.call(x, y):
						continue
					if n2.get_noise_2d(x, y) > 0.45:
						d.ground[d.idx(x, y)] = Dungeon.GROUND_PATH
					if randf() < 0.01:
						d.block(x, y, ["pillar", "rock", "tree", "grave"].pick_random())
			_graveyard(d, keep)
	# whatever the road can't reach becomes part of the scenery
	var dist := _flood(d, Vector2i(d.start))
	for y in H:
		for x in W:
			if d.map[d.idx(x, y)] == 1 and dist[d.idx(x, y)] < 0:
				d.map[d.idx(x, y)] = 0
	match biome:
		"moor": _dress_border(d, ["rock", "deadtree", "bush"], [5, 3, 2])
		"fields": _dress_border(d, ["tree", "bush", "rock"], [5, 3, 1])
		"forest": _dress_border(d, ["tree", "pine"], [3, 2], 4)
		_: _dress_border(d, ["tree", "rock", "pine"], [3, 3, 1])


static func _stone_circle(d: Dungeon, keep: Callable) -> void:
	for t in 30:
		var c := Vector2i(randi_range(12, d.W - 12), randi_range(12, d.H - 12))
		if not d.is_floor(c.x, c.y) or keep.call(c.x, c.y):
			continue
		for k in 7:
			var a := TAU * k / 7.0
			var p := c + Vector2i(roundi(cos(a) * 3.5), roundi(sin(a) * 3.5))
			if d.is_floor(p.x, p.y) and not keep.call(p.x, p.y):
				d.block(p.x, p.y, "stone")
		return


## A ruined house: stone walls with a doorway and gaps.
static func _house(d: Dungeon, keep: Callable, broken: float) -> void:
	for t in 40:
		var w := randi_range(6, 10)
		var h := randi_range(5, 8)
		var x0 := randi_range(8, d.W - w - 9)
		var y0 := randi_range(8, d.H - h - 9)
		var ok := true
		for y in range(y0 - 1, y0 + h + 1):
			for x in range(x0 - 1, x0 + w + 1):
				if not d.is_floor(x, y) or keep.call(x, y):
					ok = false
		if not ok:
			continue
		var door := randi_range(1, w - 2)
		for x in range(x0, x0 + w):
			for y in range(y0, y0 + h):
				var edge := x == x0 or y == y0 or x == x0 + w - 1 or y == y0 + h - 1
				if edge:
					if (y == y0 + h - 1 and (x == x0 + door or x == x0 + door + 1)) or randf() < broken:
						continue
					d.block(x, y, "wall")
				else:
					d.ground[d.idx(x, y)] = Dungeon.GROUND_PATH
		return


static func _fence_line(d: Dungeon, keep: Callable) -> void:
	var p := Vector2i(randi_range(8, d.W - 8), randi_range(8, d.H - 8))
	var dir := [Vector2i(1, 0), Vector2i(0, 1)].pick_random() as Vector2i
	for k in randi_range(5, 12):
		if d.is_floor(p.x, p.y) and not keep.call(p.x, p.y) and randf() < 0.9:
			d.block(p.x, p.y, "fence")
		p += dir


static func _graveyard(d: Dungeon, keep: Callable) -> void:
	for t in 30:
		var c := Vector2i(randi_range(10, d.W - 16), randi_range(10, d.H - 16))
		var ok := true
		for y in range(c.y, c.y + 7):
			for x in range(c.x, c.x + 9):
				if not d.is_floor(x, y) or keep.call(x, y):
					ok = false
		if not ok:
			continue
		for y in range(c.y + 1, c.y + 6, 2):
			for x in range(c.x + 1, c.x + 8, 2):
				if randf() < 0.75:
					d.block(x, y, "grave")
		return


# ---------- dungeons ----------

static func _finish_dungeon(d: Dungeon) -> void:
	var dist := _flood(d, Vector2i(d.start))
	var far := _farthest(d, dist)
	d.exit = _c(far)
	var back := _flood(d, far)
	d.boss_spot = _c(_at_distance(d, back, 5))
	d.waypoint = _c(_at_distance(d, dist, 9))


static func _cave(d: Dungeon) -> void:
	var W := d.W
	var H := d.H
	var m := PackedByteArray()
	m.resize(W * H)
	for y in H:
		for x in W:
			m[y * W + x] = 1 if (x > 2 and y > 2 and x < W - 3 and y < H - 3 and randf() > 0.44) else 0
	for it in 5:
		var nm := m.duplicate()
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				var walls := 0
				for j in range(-1, 2):
					for i in range(-1, 2):
						if m[(y + j) * W + x + i] == 0:
							walls += 1
				nm[y * W + x] = 0 if walls >= 5 else 1
		m = nm
	for y in H:
		for x in W:
			if m[y * W + x] == 1:
				d.carve(x, y)
	# keep only the biggest cavern
	var best := Vector2i.ZERO
	var best_n := 0
	var label := PackedInt32Array()
	label.resize(W * H)
	for y in H:
		for x in W:
			if d.is_floor(x, y) and label[d.idx(x, y)] == 0:
				var dist := _flood(d, Vector2i(x, y))
				var cnt := 0
				for i in W * H:
					if dist[i] >= 0:
						label[i] = 1
						cnt += 1
				if cnt > best_n:
					best_n = cnt
					best = Vector2i(x, y)
	var keepd := _flood(d, best)
	for i in W * H:
		if d.map[i] == 1 and keepd[i] < 0:
			d.map[i] = 0
			d.ground[i] = Dungeon.GROUND_VOID
	var a := _farthest(d, _flood(d, best))
	d.start = _c(a)
	d.entrance = d.start
	_finish_dungeon(d)
	var sd := _flood(d, a)
	d.start = _c(_at_distance(d, sd, 3))
	for y in H:
		for x in W:
			if d.is_floor(x, y) and randf() < 0.012 and Vector2(x, y).distance_to(d.start) > 5 and Vector2(x, y).distance_to(d.exit) > 4 \
					and Vector2(x, y).distance_to(d.waypoint) > 3 and _open_around(d, x, y):
				d.block(x, y, "rock")
	# a stray rock must not cut the cave in two
	var check := _flood(d, Vector2i(d.start))
	if check[d.idx(floori(d.exit.x), floori(d.exit.y))] < 0:
		for k in d.obst.keys():
			if d.obst[k] == "rock":
				d.carve(k.x, k.y)


static func _rooms(d: Dungeon, blobs: bool) -> void:
	var W := d.W
	var H := d.H
	var want := 11 + randi_range(0, 4)
	for t in 900:
		if d.rooms.size() >= want:
			break
		var w := randi_range(5, 11)
		var h := randi_range(5, 11)
		var r := Rect2i(randi_range(2, W - w - 3), randi_range(2, H - h - 3), w, h)
		var overlaps := false
		for o in d.rooms:
			if r.grow(2).intersects(o):
				overlaps = true
				break
		if not overlaps:
			d.rooms.append(r)
	for r in d.rooms:
		var c := Vector2(r.get_center())
		for i in range(r.position.x, r.end.x):
			for j in range(r.position.y, r.end.y):
				if blobs:
					var e := Vector2((i - c.x) / (r.size.x * 0.5), (j - c.y) / (r.size.y * 0.5))
					if e.length() > 1.0 + randf_range(-0.12, 0.12):
						continue
				d.carve(i, j)
	var connected: Array[Rect2i] = [d.rooms[0]]
	var rest: Array[Rect2i] = []
	for i in range(1, d.rooms.size()):
		rest.append(d.rooms[i])
	while not rest.is_empty():
		var best_d := INF
		var bi := 0
		var best := d.rooms[0]
		for i in rest.size():
			for c in connected:
				var dd := Vector2(rest[i].get_center()).distance_to(Vector2(c.get_center()))
				if dd < best_d:
					best_d = dd; bi = i; best = c
		var room: Rect2i = rest.pop_at(bi)
		_corridor(d, room, best)
		connected.append(room)
	for k in 2:
		var a: Rect2i = d.rooms.pick_random()
		var b: Rect2i = d.rooms.pick_random()
		if a != b:
			_corridor(d, a, b)
	d.start = _c(d.rooms[0].get_center())
	d.entrance = d.start + Vector2(-1.5, -1.0)
	if not d.walkable(d.entrance):
		d.entrance = d.start
	_finish_dungeon(d)
	# furnish: pillars in big crypt rooms, coffins here and there
	for r in d.rooms:
		if blobs:
			continue
		if r.size.x >= 8 and r.size.y >= 8:
			for x in range(r.position.x + 2, r.end.x - 2, 3):
				for y in [r.position.y + 1, r.end.y - 2]:
					_furnish(d, x, y, "pillar")
		elif randf() < 0.4:
			_furnish(d, r.position.x + 1, r.position.y + 1, "grave")


static func _furnish(d: Dungeon, x: int, y: int, kind: String) -> void:
	var q := Vector2(x + 0.5, y + 0.5)
	if q.distance_to(d.start) < 3 or q.distance_to(d.exit) < 3 or q.distance_to(d.waypoint) < 3 or q.distance_to(d.boss_spot) < 3:
		return
	if not _open_around(d, x, y):
		return
	d.block(x, y, kind)
	if _flood(d, Vector2i(d.start))[d.idx(floori(d.exit.x), floori(d.exit.y))] < 0:
		d.carve(x, y)


static func _corridor(d: Dungeon, a: Rect2i, b: Rect2i) -> void:
	var p := a.get_center()
	var t := b.get_center()
	var horizontal_first := randf() < 0.5
	for pass_i in 2:
		if (pass_i == 0) == horizontal_first:
			while p.x != t.x:
				d.carve(p.x, p.y); d.carve(p.x, p.y + 1)
				p.x += signi(t.x - p.x)
		else:
			while p.y != t.y:
				d.carve(p.x, p.y); d.carve(p.x + 1, p.y)
				p.y += signi(t.y - p.y)
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		d.carve(p.x + o.x, p.y + o.y)


## The abbey: one building split into halls and chambers joined by doorways.
static func _abbey(d: Dungeon) -> void:
	var leaves: Array[Rect2i] = []
	var splits: Array = []
	_split(Rect2i(2, 2, d.W - 4, d.H - 4), 0, leaves, splits)
	for r in leaves:
		for y in range(r.position.y + 1, r.end.y):
			for x in range(r.position.x + 1, r.end.x):
				d.carve(x, y)
		d.rooms.append(Rect2i(r.position + Vector2i.ONE, r.size - Vector2i.ONE))
	for s in splits:
		# s = [axis (0 = vertical wall at x), coordinate, from, to]
		for t in 30:
			var u := randi_range(s[2] + 1, s[3] - 2)
			var a := Vector2i(s[1], u) if s[0] == 0 else Vector2i(u, s[1])
			var o := Vector2i(1, 0) if s[0] == 0 else Vector2i(0, 1)
			var o2 := Vector2i(0, 1) if s[0] == 0 else Vector2i(1, 0)
			if d.is_floor(a.x - o.x, a.y - o.y) and d.is_floor(a.x + o.x, a.y + o.y) \
					and d.is_floor(a.x - o.x + o2.x, a.y - o.y + o2.y) and d.is_floor(a.x + o.x + o2.x, a.y + o.y + o2.y):
				d.carve(a.x, a.y)
				d.carve(a.x + o2.x, a.y + o2.y)
				break
	# start in the room nearest the bottom corner
	var start_room := d.rooms[0]
	for r in d.rooms:
		if r.get_center().x + r.get_center().y > start_room.get_center().x + start_room.get_center().y:
			start_room = r
	d.start = _c(start_room.get_center())
	d.entrance = d.start + Vector2(1.0, 1.0)
	if not d.walkable(d.entrance):
		d.entrance = d.start
	var dist := _flood(d, Vector2i(d.start))
	# the doors may have missed a room; drop anything unreachable
	for i in d.W * d.H:
		if d.map[i] == 1 and dist[i] < 0:
			d.map[i] = 0
			d.ground[i] = Dungeon.GROUND_VOID
	_finish_dungeon(d)
	for r in d.rooms:
		if r.size.x >= 9 and r.size.y >= 7:
			for x in range(r.position.x + 2, r.end.x - 2, 3):
				for y in [r.position.y + 1, r.end.y - 2]:
					_furnish(d, x, y, "pillar")


static func _split(r: Rect2i, depth: int, leaves: Array[Rect2i], splits: Array) -> void:
	var big := r.size.x > 15 or r.size.y > 15
	if depth >= 6 or not big or (depth >= 3 and randf() < 0.2):
		leaves.append(r)
		return
	if r.size.x >= r.size.y:
		var s := r.position.x + int(r.size.x * randf_range(0.38, 0.62))
		splits.append([0, s, r.position.y + 1, r.end.y])
		_split(Rect2i(r.position.x, r.position.y, s - r.position.x, r.size.y), depth + 1, leaves, splits)
		_split(Rect2i(s, r.position.y, r.end.x - s, r.size.y), depth + 1, leaves, splits)
	else:
		var s := r.position.y + int(r.size.y * randf_range(0.38, 0.62))
		splits.append([1, s, r.position.x + 1, r.end.x])
		_split(Rect2i(r.position.x, r.position.y, r.size.x, s - r.position.y), depth + 1, leaves, splits)
		_split(Rect2i(r.position.x, s, r.size.x, r.end.y - s), depth + 1, leaves, splits)
