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

const TALL := ["tree", "pine", "deadtree", "stone", "pillar", "tent", "rock", "gallows", "willow"]


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
		occ.sdf_collision = false  # nothing reads the SDF, and building it every frame was costly
		add_child(occ)
	rng.seed = hash(t)


# Everything is drawn as triangles from Game.prop_atlas, so Godot batches a whole prop (and often
# its neighbours) into one draw call; circles, lines and polygons were one draw call each.
const UV_DOT := Rect2(0, 0, 0.5, 1)
const UV_DISC := Rect2(0.5, 0, 0.5, 1)
const UV_WHITE := Vector2(0.75, 0.5)


func _shadow(rx: float, ry: float) -> void:
	_image(Rect2(-rx, -ry, rx * 2, ry * 2), UV_DOT, Color(0, 0, 0, 0.55))


func _blob(c: Vector2, r: float, col: Color) -> void:
	_image(Rect2(c.x - r, c.y - r, r * 2, r * 2), UV_DISC, col)


func _image(r: Rect2, uv: Rect2, col: Color) -> void:
	Game.quad(self, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col,
		PackedVector2Array([uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]), Game.prop_atlas)


func _rect(r: Rect2, col: Color) -> void:
	_poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col)


func _line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var n := (b - a).normalized().orthogonal() * (w * 0.5)
	_poly(PackedVector2Array([a + n, b + n, b - n, a - n]), col)


func _draw() -> void:
	Game.begin_batch(self, Game.prop_atlas)
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
		"willow": _willow()
		"reeds": _reeds()
		_: _rock()


func _tree() -> void:
	var h := 46.0 + rng.randf() * 26.0
	var lean := rng.randf_range(-4, 4)
	_shadow(26, 12)
	var bark := Color(0.24, 0.17, 0.11) * tint
	_poly(PackedVector2Array([Vector2(-4, 2), Vector2(4, 2), Vector2(2.5 + lean, -h * 0.6), Vector2(-2.5 + lean, -h * 0.6)]), bark)
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
	_rect(Rect2(-3, -12, 6, 14), Color(0.22, 0.15, 0.1) * tint)
	var g := Color(0.1, 0.2, 0.13).lerp(Color(0.14, 0.24, 0.16), rng.randf()) * tint
	for i in 4:
		var y := -10.0 - i * h / 5.0
		var w := 20.0 - i * 4.0
		_poly(PackedVector2Array([Vector2(-w, y), Vector2(0, y - h / 3.2), Vector2(w, y)]), g * (0.75 + i * 0.1))
		_poly(PackedVector2Array([Vector2(-w * 0.2, y - 2), Vector2(0, y - h / 3.2), Vector2(w, y)]), g * (0.95 + i * 0.1))


func _deadtree() -> void:
	var h := 40.0 + rng.randf() * 25.0
	_shadow(14, 7)
	var c := Color(0.3, 0.27, 0.24) * tint
	_line(Vector2(0, 2), Vector2(0, -h), c, 4.0)
	for i in 5:
		var y := -h * (0.45 + i * 0.12)
		var d := -1.0 if i % 2 == 0 else 1.0
		var e := Vector2(d * rng.randf_range(10, 18), y - rng.randf_range(6, 14))
		_line(Vector2(0, y), e, c, 2.0)
		_line(e, e + Vector2(d * 5, -6), c, 1.2)


func _rock() -> void:
	_shadow(28, 13)
	var base := Color(0.4, 0.38, 0.36).lerp(Color(0.48, 0.44, 0.4), rng.randf()) * tint
	for i in 3:
		var o := Vector2(rng.randf_range(-12, 12), rng.randf_range(-4, 4))
		var w := rng.randf_range(10, 18)
		var hh := rng.randf_range(10, 22)
		var pts := PackedVector2Array([o + Vector2(-w, 2), o + Vector2(-w * 0.8, -hh * 0.6), o + Vector2(-w * 0.2, -hh), o + Vector2(w * 0.6, -hh * 0.8), o + Vector2(w, 0), o + Vector2(0, 5)])
		_poly(pts, base * 0.75)
		_poly(PackedVector2Array([o + Vector2(-w * 0.8, -hh * 0.6), o + Vector2(-w * 0.2, -hh), o + Vector2(w * 0.6, -hh * 0.8), o + Vector2(0, -hh * 0.4)]), base * 1.15)


func _stone() -> void:
	_shadow(14, 7)
	var c := Color(0.42, 0.42, 0.45) * tint
	var h := 38.0 + rng.randf() * 16.0
	_poly(PackedVector2Array([Vector2(-9, 2), Vector2(-7, -h), Vector2(0, -h - 4), Vector2(2, -h + 2), Vector2(2, 4)]), c)
	_poly(PackedVector2Array([Vector2(2, 4), Vector2(2, -h + 2), Vector2(9, -h + 4), Vector2(10, 1)]), c * 0.7)
	_line(Vector2(-4, -h * 0.5), Vector2(-1, -h * 0.55), Color(0.3, 0.5, 0.6, 0.6), 1.5)


func _fence() -> void:
	var wood := Color(0.36, 0.26, 0.17) * tint
	var dir := Vector2(Game.HW, Game.HH) * 0.5 if (tile.x + tile.y) % 2 == 0 else Vector2(Game.HW, -Game.HH) * 0.5
	for e in [-1.0, 1.0]:
		_line(dir * e, dir * e + Vector2(0, -18), wood * 0.8, 3.0)
	for y in [-7.0, -14.0]:
		_line(-dir + Vector2(0, y), dir + Vector2(0, y), wood, 2.5)


func _hay() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.35, 1.35))
	_shadow(18, 8)
	var c := Color(0.62, 0.5, 0.24) * tint
	_poly(PackedVector2Array([Vector2(-16, 2), Vector2(-14, -10), Vector2(-4, -18), Vector2(8, -17), Vector2(16, -8), Vector2(16, 2), Vector2(0, 7)]), c * 0.8)
	_poly(PackedVector2Array([Vector2(-14, -10), Vector2(-4, -18), Vector2(8, -17), Vector2(2, -8)]), c * 1.1)
	for i in 6:
		var x := rng.randf_range(-12, 12)
		_line(Vector2(x, -4), Vector2(x + 2, -12), c * 0.65, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _grave() -> void:
	_shadow(10, 5)
	var c := Color(0.45, 0.45, 0.47) * tint
	_rect(Rect2(-6, -18, 12, 18), c)
	_blob(Vector2(0, -18), 6, c)
	_line(Vector2(0, -20), Vector2(0, -10), c * 0.6, 1.5)
	_line(Vector2(-3, -16), Vector2(3, -16), c * 0.6, 1.5)
	_poly(PackedVector2Array([Vector2(-10, 4), Vector2(0, -1), Vector2(10, 4), Vector2(0, 9)]), Color(0.25, 0.2, 0.15) * tint)


func _pillar() -> void:
	_shadow(16, 8)
	var c := Color(0.5, 0.47, 0.44) * tint
	var h := 64.0
	if rng.randf() < 0.3:
		h = rng.randf_range(18, 40)     # broken
	_rect(Rect2(-9, -h, 9, h), c)
	_rect(Rect2(0, -h, 9, h), c * 0.72)
	_poly(PackedVector2Array([Vector2(-12, -h), Vector2(0, -h - 6), Vector2(12, -h), Vector2(0, -h + 6)]), c * 1.15)
	_poly(PackedVector2Array([Vector2(-12, 0), Vector2(0, -6), Vector2(12, 0), Vector2(0, 6)]), c * 0.9)


func _tent() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.8, 1.8))
	_shadow(30, 14)
	var cloth := Color(0.55, 0.45, 0.32).lerp(Color(0.45, 0.2, 0.15), rng.randf() * 0.6) * tint
	_poly(PackedVector2Array([Vector2(-26, 4), Vector2(0, -36), Vector2(4, 12)]), cloth)
	_poly(PackedVector2Array([Vector2(4, 12), Vector2(0, -36), Vector2(28, 2)]), cloth * 0.7)
	_poly(PackedVector2Array([Vector2(-6, 8), Vector2(0, -10), Vector2(4, 10)]), Color(0.06, 0.05, 0.04))
	_line(Vector2(0, -36), Vector2(0, -44), Color(0.3, 0.22, 0.14), 2.0)
	_line(Vector2(-26, 4), Vector2(0, -36), cloth * 1.2, 1.0)
	_line(Vector2(0, -36), Vector2(28, 2), cloth * 0.5, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _stump() -> void:
	_shadow(10, 5)
	var c := Color(0.3, 0.21, 0.14) * tint
	_rect(Rect2(-6, -8, 12, 9), c)
	_poly(PackedVector2Array([Vector2(-6, -8), Vector2(0, -11), Vector2(6, -8), Vector2(0, -5)]), Color(0.55, 0.42, 0.28) * tint)


func _bush() -> void:
	_shadow(14, 6)
	var g := Color(0.18, 0.26, 0.12) * tint
	for i in 5:
		_blob(Vector2(rng.randf_range(-9, 9), rng.randf_range(-12, -4)), rng.randf_range(5, 8), g * (0.8 + i * 0.08))


## Swamp tree: a crooked trunk under a dark crown that trails hanging moss.
func _willow() -> void:
	var h := 44.0 + rng.randf() * 22.0
	var lean := rng.randf_range(-7, 7)
	_shadow(28, 12)
	var bark := Color(0.2, 0.17, 0.14) * tint
	var mid := Vector2(lean * 0.4 + rng.randf_range(-3, 3), -h * 0.45)
	_poly(PackedVector2Array([Vector2(-5, 2), Vector2(5, 2), mid + Vector2(3, 0), mid + Vector2(-3, 0)]), bark)
	_poly(PackedVector2Array([mid + Vector2(-3, 0), mid + Vector2(3, 0), Vector2(lean + 2, -h * 0.8), Vector2(lean - 2, -h * 0.8)]), bark * 0.9)
	var crown := Color(0.13, 0.16, 0.1).lerp(Color(0.17, 0.18, 0.1), rng.randf()) * tint
	var top := Vector2(lean, -h)
	for i in 6:
		var a := rng.randf() * TAU
		_blob(top + Vector2(cos(a) * 13, sin(a) * 5 + 4), rng.randf_range(9, 14), crown * 0.7)
	for i in 5:
		var a := rng.randf() * TAU
		_blob(top + Vector2(cos(a) * 10, sin(a) * 4), rng.randf_range(7, 11), crown)
	var moss := Color(0.3, 0.33, 0.2) * tint
	for i in 9:
		var x := lean + rng.randf_range(-20, 20)
		var y0 := top.y + rng.randf_range(2, 10)
		_line(Vector2(x, y0), Vector2(x + rng.randf_range(-2, 2), y0 + rng.randf_range(14, 30)), moss * rng.randf_range(0.7, 1.1), 1.4)


## Reeds and cattails at the water's edge.
func _reeds() -> void:
	_shadow(12, 5)
	var g := Color(0.28, 0.3, 0.16) * tint
	for i in 9:
		var x := rng.randf_range(-10, 10)
		var hh := rng.randf_range(10, 22)
		var bend := rng.randf_range(-3, 3)
		_line(Vector2(x, rng.randf_range(-2, 3)), Vector2(x + bend, -hh), g * rng.randf_range(0.7, 1.2), 1.2)
		if i % 3 == 0:
			_rect(Rect2(x + bend - 1.3, -hh - 1, 2.6, 6), Color(0.24, 0.15, 0.09) * tint)


func _gallows() -> void:
	_shadow(20, 9)
	var w := Color(0.3, 0.22, 0.15) * tint
	_line(Vector2(-8, 2), Vector2(-8, -60), w, 4.0)
	_line(Vector2(-10, -58), Vector2(16, -66), w, 4.0)
	_line(Vector2(-8, -42), Vector2(4, -60), w, 2.0)
	_line(Vector2(14, -65), Vector2(14, -44), Color(0.5, 0.45, 0.35), 1.0)
	_blob(Vector2(14, -42), 2.5, Color(0.5, 0.45, 0.35))


## A convex polygon as a fan of triangles in plain white from the atlas, tinted by col.
func _poly(pts: PackedVector2Array, col: Color) -> void:
	var cs := PackedColorArray([col, col, col])
	var uvs := PackedVector2Array([UV_WHITE, UV_WHITE, UV_WHITE])
	for i in range(1, pts.size() - 1):
		draw_primitive(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), cs, uvs, Game.prop_atlas)
