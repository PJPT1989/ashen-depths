class_name WallBlock
extends Node2D
## One raised block of wall: stone, cave rock or a timber palisade. Its origin sits at the
## tile's center so the y-sorted World orders it correctly against the hero and monsters.
## The footprint is a light occluder, so torches cast real shadows and hide what is behind.

static var _occluder: OccluderPolygon2D

var tile := Vector2i.ZERO
var v := 0.5
var tint := Color.WHITE
var tex: CanvasTexture
var palisade := false


func setup(t: Vector2i, shade_value: float, area_tint: Color, texture: CanvasTexture, is_palisade := false) -> void:
	tile = t
	v = shade_value
	tint = area_tint
	tex = texture
	palisade = is_palisade
	position = Game.iso(Vector2(t) + Vector2(0.5, 0.5))
	visible = false
	light_mask = 2
	if _occluder == null:
		_occluder = OccluderPolygon2D.new()
		_occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED
		_occluder.polygon = PackedVector2Array([Vector2(0, -Game.HH), Vector2(Game.HW, 0), Vector2(0, Game.HH), Vector2(-Game.HW, 0)])
	var occ := LightOccluder2D.new()
	occ.occluder = _occluder
	occ.occluder_light_mask = 1
	occ.sdf_collision = false  # nothing reads the SDF, and building it every frame was costly
	add_child(occ)


func _draw() -> void:
	var HW := Game.HW
	var HH := Game.HH
	var W := Game.WALL * (1.15 if palisade else 1.0) + (v - 0.5) * (8.0 if palisade else 0.0)
	var base := tint * 0.75
	var s := Vector2(0, -HH)  # top corner of the footprint, relative to the center
	var bl := s + Vector2(-HW, HH)
	var bm := s + Vector2(0, 2 * HH)
	var br := s + Vector2(HW, HH)
	var up := Vector2(0, -W)
	var u0 := fposmod(v * 3.0, 1.0) * 0.25   # vary which bricks show
	var lc := base * (0.95 + v * 0.1)
	var rc := base * (0.7 + v * 0.1)
	lc.a = 1.0
	rc.a = 1.0
	Game.begin_batch(self, tex)
	Game.quad(self, PackedVector2Array([bl, bm, bm + up, bl + up]), lc,
		PackedVector2Array([Vector2(u0, 1), Vector2(u0 + 0.25, 1), Vector2(u0 + 0.25, 0.3), Vector2(u0, 0.3)]), tex)
	Game.quad(self, PackedVector2Array([bm, br, br + up, bm + up]), rc,
		PackedVector2Array([Vector2(u0 + 0.25, 1), Vector2(u0, 1), Vector2(u0, 0.3), Vector2(u0 + 0.25, 0.3)]), tex)
	var foot := Color(0, 0, 0, 0.35)
	draw_line(bl, bm, foot, 3.0)
	draw_line(bm, br, foot, 3.0)
	var tc := base * (1.1 + v * 0.15)
	tc.a = 1.0
	if palisade:
		# sharpened stakes along the top
		for k in 4:
			var f := (k + 0.5) / 4.0
			var pl := (bl + up).lerp(bm + up, f)
			var pr := (bm + up).lerp(br + up, f)
			for p in [pl, pr]:
				draw_colored_polygon(PackedVector2Array([p + Vector2(-4, 1), p + Vector2(0, -9), p + Vector2(4, 1)]), tc * 0.8)
		return
	Game.quad(self, PackedVector2Array([s + up, br + up, bm + up, bl + up]), tc,
		PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0.5, 1)]), tex)
	draw_polyline(PackedVector2Array([bl + up, s + up, br + up]), Color(1, 0.9, 0.75, 0.08), 1.0)
	draw_polyline(PackedVector2Array([bl + up, bm + up, br + up]), Color(0, 0, 0, 0.45), 1.0)
	draw_line(bm, bm + up, Color(0, 0, 0, 0.3), 1.0)
