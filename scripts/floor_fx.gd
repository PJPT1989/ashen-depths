class_name FloorFx
extends Node2D
## Things painted on the floor under everyone: blood decals, spell rings, loot.

var main
var decals: Array = []   # [wpos, color, radius]
var rings: Array = []    # [wpos, max_radius, life, total, is_click_mark, color]


func add_decal(at: Vector2, color: Color, r: float) -> void:
	decals.append([at, color, r])
	if decals.size() > 220:
		decals.pop_front()


func _process(dt: float) -> void:
	for i in range(rings.size() - 1, -1, -1):
		rings[i][2] -= dt
		if rings[i][2] <= 0.0:
			rings.remove_at(i)
	queue_redraw()


func _ellipse(c: Vector2, rx: float, ry: float, col: Color, filled: bool, w := 2.0) -> void:
	var arr := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		arr.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if filled:
		draw_colored_polygon(arr, col)
	else:
		arr.append(arr[0])
		draw_polyline(arr, col, w, true)


func _draw() -> void:
	if main == null or main.dungeon == null or main.player == null:
		return
	for d in decals:
		var c: Color = d[1]
		c.a = 0.7
		_ellipse(Game.iso(d[0]), d[2] * Game.HW, d[2] * Game.HH, c, true)
	for r in rings:
		var p: float = 1.0 - r[2] / r[3]
		var rad: float = r[1] * p * 1.41
		var col := Color(0.9, 0.78, 0.55, r[2] * 2.0) if r[4] else Color(r[5], minf(1.0, r[2] * 3.0))
		_ellipse(Game.iso(r[0]), rad * Game.HW, rad * Game.HH, col, false, 1.5 if r[4] else 4.0)
	var now := Time.get_ticks_msec() / 400.0
	for d in main.drops:
		if d.wpos.distance_to(main.player.wpos) > 13.0:
			continue
		var s: Vector2 = Game.iso(d.wpos)
		var b := sin(now + d.bob) * 1.5
		match d.kind:
			"gold":
				for k in 4:
					_ellipse(s + Vector2(-4 + k * 3, -1 - (k % 2) * 2), 3, 1.6, Color("e2c26a"), true)
			"hp", "mp":
				draw_circle(s + Vector2(0, -4 + b), 4, Color("d0282c") if d.kind == "hp" else Color("3050e0"))
				draw_rect(Rect2(s + Vector2(-1.5, -11 + b), Vector2(3, 4)), Color("c9b99a"))
			_:
				# the item itself, small and lying on its side
				var it: Dictionary = d.item
				var col: Color = Game.RARITY_COLORS[it.rarity]
				var sz := Vector2(it.w, it.h) * 11.0
				draw_set_transform(s + Vector2(0, -3 + b * 0.5), 0.9 if it.h > it.w else 0.0, Vector2(1, 0.75))
				if it.rarity != "normal":
					draw_texture_rect(Game.soft_dot, Rect2(-sz * 0.9, sz * 1.8), false, Color(col, 0.35))
				ItemArt.draw_item(self, it, Rect2(-sz / 2.0, sz))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
