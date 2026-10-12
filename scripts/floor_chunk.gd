class_name FloorChunk
extends Node2D
## Draws the ground of one 16 x 16 block of tiles, so revealing a few tiles only redraws a
## small piece of a large area. Indoors only explored tiles are drawn; outdoors everything.

var dungeon: Dungeon
var rect := Rect2i()


func _draw() -> void:
	var dg := dungeon
	var col := dg.tint
	# Tiles are triangle primitives (Game.quad), grouped by texture so Godot batches each group
	# into a few draw calls; water and decoration come after.
	var floor_tiles := []
	var path_tiles := []
	var water := []
	var decor := []
	for j in range(rect.position.y, mini(rect.end.y, dg.H)):
		for i in range(rect.position.x, mini(rect.end.x, dg.W)):
			var k := dg.idx(i, j)
			var g := dg.ground[k]
			if g == Dungeon.GROUND_VOID:
				continue
			if not dg.outdoor and dg.seen[k] == 0:
				continue
			var s := Game.iso(Vector2(i, j))
			var v := dg.shade[k]
			if g == Dungeon.GROUND_WATER:
				water.append([s, Act.WATER[0].lerp(Act.WATER[1], v), v])
				continue
			var variant := 3 if v < 0.08 else (2 if v > 0.84 else (k * 7 + j) % 2)
			var c := col * (0.85 + v * 0.3)
			if g == Dungeon.GROUND_DARK:
				c = col * (0.35 + v * 0.1)
			c.a = 1.0
			(path_tiles if g == Dungeon.GROUND_PATH else floor_tiles).append([s, variant * 0.25, c])
			if g != Dungeon.GROUND_DARK:
				decor.append([i, j, s + Vector2(0, Game.HH), v])
	Game.begin_batch(self, dg.floor_tex)
	for t in floor_tiles:
		_tile(t, dg.floor_tex)
	Game.begin_batch(self, dg.path_tex)
	for t in path_tiles:
		_tile(t, dg.path_tex)
	Game.begin_batch(self, null)
	for w in water:
		var s: Vector2 = w[0]
		Game.quad(self, PackedVector2Array([s, s + Vector2(Game.HW, Game.HH), s + Vector2(0, Game.TH), s + Vector2(-Game.HW, Game.HH)]), w[1])
	for w in water:
		if w[2] > 0.7:
			draw_line(w[0] + Vector2(-10, Game.HH + 2), w[0] + Vector2(8, Game.HH + 2), Color(0.45, 0.55, 0.4, 0.22), 1.0)
	for d in decor:
		_decor(d[0], d[1], d[2], d[3], dg)


func _tile(t: Array, tex: Texture2D) -> void:
	var top: Vector2 = t[0]
	var u0: float = t[1]
	Game.quad(self, PackedVector2Array([top, top + Vector2(Game.HW, Game.HH), top + Vector2(0, Game.TH), top + Vector2(-Game.HW, Game.HH)]), t[2],
		PackedVector2Array([Vector2(u0, 0), Vector2(u0 + 0.25, 0), Vector2(u0 + 0.25, 1), Vector2(u0, 1)]), tex)


## Scattered detail so the ground doesn't read as repeated tiles.
func _decor(i: int, j: int, c: Vector2, v: float, dg: Dungeon) -> void:
	var h := fposmod(v * 977.0 + i * 13.0 + j * 7.0, 1.0)
	var rot := h * 40.0
	if dg.outdoor:
		if h < 0.05:
			# a tuft of grass or a few pebbles
			if h < 0.03:
				var gc := Color(0.3, 0.4, 0.18) * dg.tint
				for b in 5:
					var a := -PI / 2 + (b - 2) * 0.3
					draw_line(c + Vector2((b - 2) * 2, 0), c + Vector2((b - 2) * 2 + cos(a) * 6, sin(a) * 7), gc, 1.5, true)
			else:
				for r in 3:
					var p := c + Vector2(cos(rot + r * 2.1) * 6, sin(rot + r * 2.1) * 3)
					draw_circle(p, 1.8, Color(0.42, 0.4, 0.37) * dg.tint)
		elif h < 0.056 and dg.area_index != 0 and fposmod(h * 7919.0, 1.0) < 0.25:
			_bones(c, rot, 0.8)
		return
	if h > 0.06:
		return
	if h < 0.025:
		_bones(c, rot, 1.0)
	else:
		for r in 5:
			var a := rot + r * 1.3
			var p := c + Vector2(cos(a) * (4 + r * 2.5), sin(a) * (2 + r * 1.2))
			var sz := 2.5 + fposmod(a * 3.0, 2.5)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-sz, 0), p + Vector2(0, -sz * 0.7), p + Vector2(sz, 0), p + Vector2(0, sz * 0.5)]), dg.tint * Color(0.22 + r * 0.02, 0.2 + r * 0.02, 0.19 + r * 0.02))


func _bones(c: Vector2, rot: float, s: float) -> void:
	var bone := Color(0.78, 0.74, 0.64)
	var o := c + Vector2(cos(rot) * 6, sin(rot) * 3)
	draw_circle(o, 4.0 * s, bone)
	draw_circle(o + Vector2(-1.4, 0.6) * s, 1.1 * s, Color(0.1, 0.08, 0.07))
	draw_circle(o + Vector2(1.6, 0.6) * s, 1.1 * s, Color(0.1, 0.08, 0.07))
	for b in 2:
		var a := rot + b * 1.7
		var m := c + Vector2(cos(a + 2) * 8, sin(a + 2) * 4)
		var d := Vector2(cos(a), sin(a) * 0.5) * 7.0 * s
		draw_line(m - d, m + d, bone, 2.0, true)
		draw_circle(m - d, 1.6, bone)
		draw_circle(m + d, 1.6, bone)
