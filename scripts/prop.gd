class_name Prop
extends Node2D
## Something standing on a tile that blocks walking: trees, rocks, fences, pillars, tents...
## Drawn in code with a little variation per tile. Tall props occlude light like walls do.

static var _occ_small: OccluderPolygon2D
static var _occ_tile: OccluderPolygon2D

var tile := Vector2i.ZERO
var kind := "rock"
var v := 0.5
var tint := Color.WHITE
var rng := RandomNumberGenerator.new()

const TALL := ["tree", "pine", "deadtree", "stone", "pillar", "tent", "rock", "gallows"]


func setup(t: Vector2i, k: String, shade_value: float, area_tint: Color) -> void:
	tile = t
	kind = k
	v = shade_value
	tint = area_tint
	position = Game.iso(Vector2(t) + Vector2(0.5, 0.5))
	light_mask = 2
	if _occ_small == null:
		_occ_small = OccluderPolygon2D.new()
		_occ_small.cull_mode = OccluderPolygon2D.CULL_DISABLED
		_occ_small.polygon = PackedVector2Array([Vector2(0, -5), Vector2(10, 0), Vector2(0, 5), Vector2(-10, 0)])
		_occ_tile = OccluderPolygon2D.new()
		_occ_tile.cull_mode = OccluderPolygon2D.CULL_DISABLED
		_occ_tile.polygon = PackedVector2Array([Vector2(0, -Game.HH * 0.8), Vector2(Game.HW * 0.8, 0), Vector2(0, Game.HH * 0.8), Vector2(-Game.HW * 0.8, 0)])
	if kind in TALL:
		var occ := LightOccluder2D.new()
		occ.occluder = _occ_tile if kind in ["rock", "tent", "pillar"] else _occ_small
		occ.occluder_light_mask = 1
		add_child(occ)
	rng.seed = hash(t)


func _shadow(rx: float, ry: float) -> void:
	draw_texture_rect(Game.soft_dot, Rect2(-rx, -ry, rx * 2, ry * 2), false, Color(0, 0, 0, 0.55))


func _blob(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col)


func _draw() -> void:
	match kind:
		"tree": _tree()
		"pine": _pine()
		"deadtree": _deadtree()
		"rock": _rock()
		"stone": _stone()
		"fence": _fence()
		"hay": _hay()
		"grave": _grave()
		"pillar": _pillar()
		"tent": _tent()
		"stump": _stump()
		"bush": _bush()
		"gallows": _gallows()
		_: _rock()


func _tree() -> void:
	var h := 46.0 + rng.randf() * 26.0
	var lean := rng.randf_range(-4, 4)
	_shadow(26, 12)
	var bark := Color(0.24, 0.17, 0.11) * tint
	draw_colored_polygon(PackedVector2Array([Vector2(-4, 2), Vector2(4, 2), Vector2(2.5 + lean, -h * 0.6), Vector2(-2.5 + lean, -h * 0.6)]), bark)
	var leaf := Color(0.16, 0.24, 0.1).lerp(Color(0.26, 0.28, 0.1), rng.randf()) * tint
	var top := Vector2(lean, -h)
	# canopy: dark underside first, lit clumps on top
	for i in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(10, 17)
		_blob(top + Vector2(cos(a) * 12, sin(a) * 7 + 6), r, leaf * 0.65)
	for i in 6:
		var a := rng.randf() * TAU
		var r := rng.randf_range(8, 13)
		_blob(top + Vector2(cos(a) * 10 - 2, sin(a) * 6 - 2), r, leaf)
	for i in 4:
		var a := rng.randf() * TAU
		_blob(top + Vector2(cos(a) * 7 - 5, sin(a) * 4 - 8), rng.randf_range(4, 8), leaf * 1.35)


func _pine() -> void:
	var h := 60.0 + rng.randf() * 30.0
	_shadow(20, 10)
	draw_rect(Rect2(-3, -12, 6, 14), Color(0.22, 0.15, 0.1) * tint)
	var g := Color(0.1, 0.2, 0.13).lerp(Color(0.14, 0.24, 0.16), rng.randf()) * tint
	for i in 4:
		var y := -10.0 - i * h / 5.0
		var w := 20.0 - i * 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(-w, y), Vector2(0, y - h / 3.2), Vector2(w, y)]), g * (0.75 + i * 0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.2, y - 2), Vector2(0, y - h / 3.2), Vector2(w, y)]), g * (0.95 + i * 0.1))


func _deadtree() -> void:
	var h := 40.0 + rng.randf() * 25.0
	_shadow(14, 7)
	var c := Color(0.3, 0.27, 0.24) * tint
	draw_line(Vector2(0, 2), Vector2(0, -h), c, 4.0, true)
	for i in 5:
		var y := -h * (0.45 + i * 0.12)
		var d := -1.0 if i % 2 == 0 else 1.0
		var e := Vector2(d * rng.randf_range(10, 18), y - rng.randf_range(6, 14))
		draw_line(Vector2(0, y), e, c, 2.0, true)
		draw_line(e, e + Vector2(d * 5, -6), c, 1.2, true)


func _rock() -> void:
	_shadow(28, 13)
	var base := Color(0.4, 0.38, 0.36).lerp(Color(0.48, 0.44, 0.4), rng.randf()) * tint
	for i in 3:
		var o := Vector2(rng.randf_range(-12, 12), rng.randf_range(-4, 4))
		var w := rng.randf_range(10, 18)
		var hh := rng.randf_range(10, 22)
		var pts := PackedVector2Array([o + Vector2(-w, 2), o + Vector2(-w * 0.8, -hh * 0.6), o + Vector2(-w * 0.2, -hh), o + Vector2(w * 0.6, -hh * 0.8), o + Vector2(w, 0), o + Vector2(0, 5)])
		draw_colored_polygon(pts, base * 0.75)
		draw_colored_polygon(PackedVector2Array([o + Vector2(-w * 0.8, -hh * 0.6), o + Vector2(-w * 0.2, -hh), o + Vector2(w * 0.6, -hh * 0.8), o + Vector2(0, -hh * 0.4)]), base * 1.15)


func _stone() -> void:
	_shadow(14, 7)
	var c := Color(0.42, 0.42, 0.45) * tint
	var h := 38.0 + rng.randf() * 16.0
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 2), Vector2(-7, -h), Vector2(0, -h - 4), Vector2(2, -h + 2), Vector2(2, 4)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(2, 4), Vector2(2, -h + 2), Vector2(9, -h + 4), Vector2(10, 1)]), c * 0.7)
	draw_line(Vector2(-4, -h * 0.5), Vector2(-1, -h * 0.55), Color(0.3, 0.5, 0.6, 0.6), 1.5)


func _fence() -> void:
	var wood := Color(0.36, 0.26, 0.17) * tint
	var dir := Vector2(Game.HW, Game.HH) * 0.5 if (tile.x + tile.y) % 2 == 0 else Vector2(Game.HW, -Game.HH) * 0.5
	for e in [-1.0, 1.0]:
		draw_line(dir * e, dir * e + Vector2(0, -18), wood * 0.8, 3.0)
	for y in [-7.0, -14.0]:
		draw_line(-dir + Vector2(0, y), dir + Vector2(0, y), wood, 2.5)


func _hay() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.35, 1.35))
	_shadow(18, 8)
	var c := Color(0.62, 0.5, 0.24) * tint
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 2), Vector2(-14, -10), Vector2(-4, -18), Vector2(8, -17), Vector2(16, -8), Vector2(16, 2), Vector2(0, 7)]), c * 0.8)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -10), Vector2(-4, -18), Vector2(8, -17), Vector2(2, -8)]), c * 1.1)
	for i in 6:
		var x := rng.randf_range(-12, 12)
		draw_line(Vector2(x, -4), Vector2(x + 2, -12), c * 0.65, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _grave() -> void:
	_shadow(10, 5)
	var c := Color(0.45, 0.45, 0.47) * tint
	draw_rect(Rect2(-6, -18, 12, 18), c)
	draw_circle(Vector2(0, -18), 6, c)
	draw_line(Vector2(0, -20), Vector2(0, -10), c * 0.6, 1.5)
	draw_line(Vector2(-3, -16), Vector2(3, -16), c * 0.6, 1.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 4), Vector2(0, -1), Vector2(10, 4), Vector2(0, 9)]), Color(0.25, 0.2, 0.15) * tint)


func _pillar() -> void:
	_shadow(16, 8)
	var c := Color(0.5, 0.47, 0.44) * tint
	var h := 64.0
	if rng.randf() < 0.3:
		h = rng.randf_range(18, 40)     # broken
	draw_rect(Rect2(-9, -h, 9, h), c)
	draw_rect(Rect2(0, -h, 9, h), c * 0.72)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -h), Vector2(0, -h - 6), Vector2(12, -h), Vector2(0, -h + 6)]), c * 1.15)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(0, -6), Vector2(12, 0), Vector2(0, 6)]), c * 0.9)


func _tent() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.8, 1.8))
	_shadow(30, 14)
	var cloth := Color(0.55, 0.45, 0.32).lerp(Color(0.45, 0.2, 0.15), rng.randf() * 0.6) * tint
	draw_colored_polygon(PackedVector2Array([Vector2(-26, 4), Vector2(0, -36), Vector2(4, 12)]), cloth)
	draw_colored_polygon(PackedVector2Array([Vector2(4, 12), Vector2(0, -36), Vector2(28, 2)]), cloth * 0.7)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 8), Vector2(0, -10), Vector2(4, 10)]), Color(0.06, 0.05, 0.04))
	draw_line(Vector2(0, -36), Vector2(0, -44), Color(0.3, 0.22, 0.14), 2.0)
	draw_line(Vector2(-26, 4), Vector2(0, -36), cloth * 1.2, 1.0)
	draw_line(Vector2(0, -36), Vector2(28, 2), cloth * 0.5, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _stump() -> void:
	_shadow(10, 5)
	var c := Color(0.3, 0.21, 0.14) * tint
	draw_rect(Rect2(-6, -8, 12, 9), c)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -8), Vector2(0, -11), Vector2(6, -8), Vector2(0, -5)]), Color(0.55, 0.42, 0.28) * tint)


func _bush() -> void:
	_shadow(14, 6)
	var g := Color(0.18, 0.26, 0.12) * tint
	for i in 5:
		_blob(Vector2(rng.randf_range(-9, 9), rng.randf_range(-12, -4)), rng.randf_range(5, 8), g * (0.8 + i * 0.08))


func _gallows() -> void:
	_shadow(20, 9)
	var w := Color(0.3, 0.22, 0.15) * tint
	draw_line(Vector2(-8, 2), Vector2(-8, -60), w, 4.0)
	draw_line(Vector2(-10, -58), Vector2(16, -66), w, 4.0)
	draw_line(Vector2(-8, -42), Vector2(4, -60), w, 2.0)
	draw_line(Vector2(14, -65), Vector2(14, -44), Color(0.5, 0.45, 0.35), 1.0)
	draw_circle(Vector2(14, -42), 2.5, Color(0.5, 0.45, 0.35))
