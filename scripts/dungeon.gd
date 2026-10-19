class_name Dungeon
extends Node2D
## The current area's map: which tiles can be walked, what stands on the others, collision,
## line of sight and pathfinding in world (tile) coordinates, and the ground drawing.
## Area shapes come from AreaGen; this node only stores and draws them.

const CHUNK := 16

var W := 64
var H := 64
var map := PackedByteArray()       # 1 = walkable
var ground := PackedByteArray()    # GROUND_* : what the tile looks like
var seen := PackedByteArray()
var shade := PackedFloat32Array()
var obst := {}                     # Vector2i -> obstacle kind ("wall", "tree", "rock", ...)
var blockers := {}                 # Vector2i -> the node drawn there (walls and props)
var rooms: Array[Rect2i] = []
var area_index := 0
var biome := {}
var outdoor := false

# points of interest, filled by AreaGen
var start := Vector2.ZERO          # where the hero arrives from the previous area
var entrance := Vector2.ZERO       # the way back
var exit := Vector2.ZERO           # the way on
var exit_style := "stairs_down"
var entrance_style := "stairs_up"
var waypoint := Vector2.ZERO
var boss_spot := Vector2.ZERO
var pack_spots: Array[Vector2] = []
var spots := {}                    # named extras (town: fire, vendor, healer)

var astar := AStarGrid2D.new()
var floor_tex: CanvasTexture
var path_tex: CanvasTexture
var tint := Color.WHITE
var _chunks := {}                  # Vector2i -> FloorChunk
var seen_version := 0              # bumps whenever new tiles are revealed (the automap caches on it)

enum { GROUND_FLOOR, GROUND_PATH, GROUND_WATER, GROUND_DARK, GROUND_VOID }

## Low obstacles that block walking but not sight or missiles.
const LOW := ["fence", "hay", "grave", "stump", "bush"]


func idx(x: int, y: int) -> int:
	return y * W + x


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H


func is_floor(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and map[idx(x, y)] == 1


func walkable(p: Vector2) -> bool:
	return is_floor(floori(p.x), floori(p.y))


## True where a missile can fly: floor, water and low obstacles.
func open_air(p: Vector2) -> bool:
	var x := floori(p.x)
	var y := floori(p.y)
	if not inside(x, y):
		return false
	if map[idx(x, y)] == 1 or ground[idx(x, y)] == GROUND_WATER:
		return true
	return obst.get(Vector2i(x, y), "") in LOW


func is_free(p: Vector2, r: float) -> bool:
	r -= 0.01
	return walkable(p + Vector2(-r, -r)) and walkable(p + Vector2(r, -r)) \
		and walkable(p + Vector2(-r, r)) and walkable(p + Vector2(r, r))


func los(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / 0.3))
	for i in range(1, steps):
		if not open_air(a.lerp(b, float(i) / steps)):
			return false
	return true


func line_clear(a: Vector2, b: Vector2, r: float) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / 0.2))
	for i in range(1, steps + 1):
		if not is_free(a.lerp(b, float(i) / steps), r):
			return false
	return true


## Fresh, empty map of the given size; every tile solid until carved.
func reset(size: Vector2i, area_i: int) -> void:
	W = size.x
	H = size.y
	area_index = area_i
	biome = Act.biome(area_i)
	outdoor = biome.outdoor
	map = PackedByteArray(); map.resize(W * H)
	ground = PackedByteArray(); ground.resize(W * H)
	ground.fill(GROUND_DARK if outdoor else GROUND_VOID)
	seen = PackedByteArray(); seen.resize(W * H)
	shade = PackedFloat32Array(); shade.resize(W * H)
	for i in W * H:
		shade[i] = randf()
	obst.clear()
	rooms.clear()
	pack_spots.clear()
	spots.clear()


func carve(x: int, y: int, g := GROUND_FLOOR) -> void:
	if x > 0 and y > 0 and x < W - 1 and y < H - 1:
		map[idx(x, y)] = 1
		ground[idx(x, y)] = g
		obst.erase(Vector2i(x, y))


func block(x: int, y: int, kind: String) -> void:
	if inside(x, y):
		map[idx(x, y)] = 0
		if outdoor and ground[idx(x, y)] != GROUND_WATER:
			ground[idx(x, y)] = GROUND_FLOOR
		obst[Vector2i(x, y)] = kind


## After generation: pathfinding grid, wall and prop nodes, ground chunks.
func finish(world: Node) -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2.ONE
	astar.offset = Vector2(0.5, 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y in H:
		for x in W:
			if map[idx(x, y)] != 1:
				astar.set_point_solid(Vector2i(x, y), true)
	tint = biome.tint
	floor_tex = Game.canvas_tex(biome.floor)
	path_tex = Game.canvas_tex(biome.get("path", biome.floor))
	_build_blockers(world)
	_build_chunks()


func clear_nodes() -> void:
	for w in blockers.values():
		w.queue_free()
	blockers.clear()
	for c in _chunks.values():
		c.queue_free()
	_chunks.clear()


func near_floor(x: int, y: int, r: int) -> bool:
	for j in range(y - r, y + r + 1):
		for i in range(x - r, x + r + 1):
			if is_floor(i, j):
				return true
	return false


func _build_blockers(parent: Node) -> void:
	var wall_tex: CanvasTexture = Game.canvas_tex(biome.wall)
	for y in H:
		for x in W:
			if map[idx(x, y)] == 1:
				continue
			var k := Vector2i(x, y)
			var kind: String = obst.get(k, "")
			if kind == "":
				# a plain solid tile: in dungeons a wall where it meets the floor
				if outdoor or not near_floor(x, y, 1):
					continue
				kind = "wall"
			if kind == "wall" or kind == "palisade":
				if not near_floor(x, y, 1):
					continue
				var w := WallBlock.new()
				w.setup(k, shade[idx(x, y)], tint, Game.canvas_tex("wood") if kind == "palisade" else wall_tex, kind == "palisade")
				if outdoor:
					w.visible = true
				parent.add_child(w)
				blockers[k] = w
			else:
				if not near_floor(x, y, 3):
					continue
				var p := Prop.new()
				p.setup(k, kind, shade[idx(x, y)], tint)
				p.visible = outdoor
				parent.add_child(p)
				blockers[k] = p


func _build_chunks() -> void:
	for cy in ceili(H / float(CHUNK)):
		for cx in ceili(W / float(CHUNK)):
			var c := FloorChunk.new()
			c.dungeon = self
			c.rect = Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK)
			add_child(c)
			_chunks[Vector2i(cx, cy)] = c


## Reveal tiles around p; redraws only the ground chunks that changed.
func mark_seen(p: Vector2, radius := 9) -> void:
	if outdoor:
		radius = 13
	var c := Vector2i(floori(p.x), floori(p.y))
	var dirty := {}
	for j in range(c.y - radius, c.y + radius + 1):
		for i in range(c.x - radius, c.x + radius + 1):
			if i < 0 or j < 0 or i >= W or j >= H:
				continue
			if (i - c.x) * (i - c.x) + (j - c.y) * (j - c.y) > radius * radius + 1:
				continue
			var k := idx(i, j)
			if seen[k] == 0:
				seen[k] = 1
				dirty[Vector2i(i / CHUNK, j / CHUNK)] = true
				var w = blockers.get(Vector2i(i, j))
				if w:
					w.visible = true
	if not dirty.is_empty():
		seen_version += 1
	if not outdoor:
		for ck in dirty:
			if _chunks.has(ck):
				_chunks[ck].queue_redraw()


# ---------- pathfinding ----------

## Path from a to b in world coordinates, smoothed so the mover walks straight lines
## wherever a body of radius r fits. Returns [] when there is no route.
func find_path(a: Vector2, b: Vector2, r: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var from := Vector2i(floori(a.x), floori(a.y))
	var to := Vector2i(floori(b.x), floori(b.y))
	if not astar.is_in_boundsv(from) or not astar.is_in_boundsv(to) or astar.is_point_solid(to) or astar.is_point_solid(from):
		return out
	var raw := astar.get_point_path(from, to)
	if raw.size() < 2:
		if is_free(b, r):
			out.append(b)
		return out
	var pts: Array[Vector2] = []
	for i in range(1, raw.size()):
		pts.append(raw[i])
	if is_free(b, r):
		pts[pts.size() - 1] = b
	var cur := a
	var i := 0
	while i < pts.size():
		var j := i
		while j + 1 < pts.size() and j - i < 12 and line_clear(cur, pts[j + 1], r):
			j += 1
		out.append(pts[j])
		cur = pts[j]
		i = j + 1
	return out


## Nearest floor tile center to p within a small search radius.
func nearest_floor(p: Vector2) -> Vector2:
	if walkable(p):
		return p
	var best := Vector2.INF
	var bd := INF
	var c := Vector2i(floori(p.x), floori(p.y))
	for j in range(c.y - 3, c.y + 4):
		for i in range(c.x - 3, c.x + 4):
			if is_floor(i, j):
				var q := Vector2(i + 0.5, j + 0.5)
				if q.distance_squared_to(p) < bd:
					bd = q.distance_squared_to(p); best = q
	return best


## A random walkable spot within radius r of p (falls back to the nearest floor).
func spot_near(p: Vector2, r: float, body := 0.3) -> Vector2:
	for t in 24:
		var q := p + Vector2(randf_range(-r, r), randf_range(-r, r))
		if is_free(q, body):
			return q
	var f := nearest_floor(p)
	return f if f != Vector2.INF else p
