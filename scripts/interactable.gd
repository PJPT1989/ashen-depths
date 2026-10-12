class_name Interactable
extends Figure
## Things the hero walks up to and uses: the ways between areas (gates, cave mouths, doors,
## stairs), town portals, waypoints and the people of the town.

var kind := "portal"        # portal | tportal | waypoint | npc
var style := "gate"         # for portals: gate, cave, door, stairs_down, stairs_up
var label := ""
var target_area := -1
var forward := true         # portal leads deeper into the act
var sealed := false
var active := false         # waypoint: discovered
var role := ""              # npc: vendor, healer, elder
var tint := Color.WHITE
var use_offset := Vector2.ZERO
var use_range := 1.3
var lights: Array = []
var t := 0.0
var sealed_light: PointLight2D


func setup_portal(at: Vector2, s: String, to_area: int, is_forward: bool) -> void:
	kind = "portal"
	style = s
	wpos = at
	target_area = to_area
	forward = is_forward
	label = Act.area(to_area).name
	use_range = 1.1
	sync_position()


func setup_tportal(at: Vector2, to_area: int) -> void:
	kind = "tportal"
	wpos = at
	target_area = to_area
	label = "Town Portal to %s" % Act.area(to_area).name
	use_range = 1.1
	sync_position()


func setup_waypoint(at: Vector2, is_active: bool) -> void:
	kind = "waypoint"
	wpos = at
	active = is_active
	label = "Waypoint"
	use_range = 1.6
	sync_position()


func setup_npc(at: Vector2, r: String, n: String, c: Color) -> void:
	kind = "npc"
	role = r
	label = n
	tint = c
	wpos = at
	use_range = 1.7
	radius = 0.3
	sync_position()


## Flat things lie on the ground under everyone; the rest stand in the y-sorted world.
func is_flat() -> bool:
	return kind == "waypoint" or (kind == "portal" and style == "stairs_down")


func _ready() -> void:
	match kind:
		"npc":
			setup_sprite("townsfolk")
			body.modulate = tint
			anim = randf() * 5.0
		"waypoint":
			lights = [Game.make_light(260.0, Color(0.45, 0.65, 1.0), 0.0)]
			lights[0].position = Vector2(0, -8)
			add_child(lights[0])
		"tportal":
			lights = Game.make_light_pair(self, 380.0, Color(0.4, 0.6, 1.0), 1.1, Vector2(0, -26))
		"portal":
			var c := Color(1.0, 0.7, 0.4)
			if style == "stairs_up":
				c = Color(0.85, 0.85, 1.0)
			lights = [Game.make_light(200.0, c, 0.55)]
			lights[0].position = Vector2(0, -20)
			add_child(lights[0])
			sealed_light = Game.make_light(240.0, Color(1, 0.2, 0.12), 0.0)
			sealed_light.position = Vector2(0, -10)
			add_child(sealed_light)


func _process(dt: float) -> void:
	t += dt
	match kind:
		"npc":
			anim += dt
			var p: Player = main.player
			if p.wpos.distance_to(wpos) < 5.0:
				face(p.wpos - wpos)
			var f := pick_frame()
			draw_frame(f[0], f[1])
		"waypoint":
			lights[0].energy = (0.9 + sin(t * 2.0) * 0.1) if active else 0.0
		"tportal":
			for l in lights:
				l.energy = 1.1 + sin(t * 5.0) * 0.15
		"portal":
			if sealed_light:
				sealed_light.energy = (0.8 + sin(t * 3.0) * 0.25) if sealed else 0.0
	queue_redraw()


# ---------- drawing ----------

func _iso_poly(pts: Array, col: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(Vector2((p.x - p.y) * Game.HW, (p.x + p.y) * Game.HH))
	draw_colored_polygon(arr, col)


func _draw() -> void:
	match kind:
		"npc":
			shadow(11)
		"waypoint":
			_draw_waypoint()
		"tportal":
			_draw_tportal()
		"portal":
			match style:
				"gate": _draw_gate()
				"cave": _draw_cave()
				"door": _draw_door()
				"stairs_down": _draw_stairs_down()
				"stairs_up": _draw_stairs_up()
			if sealed:
				_draw_seal()


func _draw_waypoint() -> void:
	var stone := Color(0.42, 0.4, 0.42)
	ellipse(Vector2.ZERO, 46, 23, Color(0, 0, 0, 0.45))
	ellipse(Vector2(0, -2), 44, 22, stone.darkened(0.35))
	ellipse(Vector2(0, -4), 42, 21, stone)
	ellipse(Vector2(0, -4), 32, 16, stone.darkened(0.15))
	var glow := Color(0.5, 0.75, 1.0, 0.85 + sin(t * 2.0) * 0.15) if active else Color(0.25, 0.25, 0.3, 0.9)
	ellipse(Vector2(0, -4), 28, 14, glow, false, 2.0)
	ellipse(Vector2(0, -4), 18, 9, glow, false, 1.5)
	for k in 8:
		var a := TAU * k / 8.0 + (t * 0.3 if active else 0.0)
		var p := Vector2(cos(a) * 23, sin(a) * 11.5 - 4)
		draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), glow, 2.0)
		draw_line(p + Vector2(0, -2), p + Vector2(0, 2), glow, 2.0)
	# four short standing stones at the corners
	for c in [Vector2(-40, -4), Vector2(40, -4), Vector2(0, -24), Vector2(0, 16)]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-4, -18), c + Vector2(0, -22), c + Vector2(4, -18), c + Vector2(5, 0)]), stone.darkened(0.1))
		draw_line(c + Vector2(-2, -12), c + Vector2(2, -12), glow, 2.0)
	if active:
		draw_texture_rect(Game.soft_dot, Rect2(-30, -30, 60, 40), false, Color(0.4, 0.6, 1.0, 0.25 + sin(t * 2.0) * 0.08))


func _draw_tportal() -> void:
	ellipse(Vector2.ZERO, 22, 9, Color(0, 0, 0, 0.5))
	var c := Vector2(0, -32)
	for k in 5:
		var f := 1.0 - k * 0.17
		var col := Color(0.3 + k * 0.12, 0.5 + k * 0.1, 1.0, 0.55 + k * 0.08)
		ellipse(c, 17 * f, 30 * f, col)
	for k in 6:
		var a := t * 3.0 + k * TAU / 6.0
		draw_arc(c, 10 + k * 1.5, a, a + 1.6, 12, Color(0.85, 0.95, 1.0, 0.6), 1.5, true)
	ellipse(c, 18, 31, Color(0.75, 0.9, 1.0, 0.9), false, 2.0)


func _draw_gate() -> void:
	# two timber posts, a lintel with a hanging lamp, and the road running through
	var wood := Color(0.33, 0.24, 0.16)
	var dark := wood.darkened(0.4)
	for x in [-30.0, 30.0]:
		draw_texture_rect(Game.soft_dot, Rect2(x - 8, -4, 16, 8), false, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(x - 4, -72, 8, 72), wood)
		draw_rect(Rect2(x + 1, -72, 3, 72), dark)
	draw_rect(Rect2(-40, -78, 80, 9), wood.lightened(0.1))
	draw_rect(Rect2(-40, -71, 80, 2), dark)
	draw_line(Vector2(0, -69), Vector2(0, -58), Color(0.2, 0.18, 0.16), 1.5)
	var lamp := Color(1.0, 0.75, 0.4, 0.9 + sin(t * 7.0) * 0.08)
	draw_rect(Rect2(-4, -58, 8, 9), Color(0.15, 0.13, 0.12))
	draw_rect(Rect2(-2.5, -56.5, 5, 6), lamp)
	draw_texture_rect(Game.soft_dot, Rect2(-14, -66, 28, 26), false, Color(1, 0.6, 0.3, 0.35))


func _draw_cave() -> void:
	var rock := Color(0.34, 0.31, 0.29)
	# mound of rock with a black mouth
	draw_colored_polygon(PackedVector2Array([Vector2(-58, 6), Vector2(-50, -30), Vector2(-28, -58), Vector2(0, -66), Vector2(30, -56), Vector2(52, -30), Vector2(60, 6), Vector2(0, 20)]), rock.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-50, 0), Vector2(-44, -28), Vector2(-24, -52), Vector2(0, -58), Vector2(26, -50), Vector2(44, -28), Vector2(50, 0), Vector2(0, 12)]), rock)
	draw_colored_polygon(PackedVector2Array([Vector2(-26, 8), Vector2(-24, -20), Vector2(-12, -38), Vector2(4, -42), Vector2(18, -34), Vector2(26, -16), Vector2(28, 8), Vector2(0, 16)]), Color(0.02, 0.015, 0.02))
	for k in 5:
		var x := -40.0 + k * 20.0
		draw_line(Vector2(x, -40 + absf(x) * 0.5), Vector2(x + 8, -30 + absf(x) * 0.4), rock.darkened(0.35), 2.0)


func _draw_door() -> void:
	var stone := Color(0.45, 0.42, 0.42)
	draw_texture_rect(Game.soft_dot, Rect2(-34, -8, 68, 16), false, Color(0, 0, 0, 0.6))
	draw_colored_polygon(PackedVector2Array([Vector2(-32, 4), Vector2(-32, -64), Vector2(-20, -82), Vector2(0, -88), Vector2(20, -82), Vector2(32, -64), Vector2(32, 4)]), stone)
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 4), Vector2(-20, -58), Vector2(-10, -70), Vector2(0, -73), Vector2(10, -70), Vector2(20, -58), Vector2(20, 4)]), Color(0.28, 0.18, 0.1))
	for x in [-12.0, -4.0, 4.0, 12.0]:
		draw_line(Vector2(x, 2), Vector2(x, -64 + absf(x) * 0.5), Color(0.18, 0.11, 0.06), 1.5)
	draw_circle(Vector2(10, -28), 2.5, Color(0.6, 0.5, 0.3))
	draw_polyline(PackedVector2Array([Vector2(-32, -64), Vector2(-20, -82), Vector2(0, -88), Vector2(20, -82), Vector2(32, -64)]), stone.lightened(0.2), 2.0)


func _draw_stairs_down() -> void:
	# a black opening in the floor with steps leading down into it
	_iso_poly([Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)], Color(0.12, 0.11, 0.11))
	_iso_poly([Vector2(-0.85, -0.85), Vector2(0.85, -0.85), Vector2(0.85, 0.85), Vector2(-0.85, 0.85)], Color(0.02, 0.015, 0.02))
	for k in 5:
		var f := k / 5.0
		var y0 := -0.85 + f * 1.4
		var col := Color(0.38, 0.36, 0.36).darkened(f * 0.85)
		_iso_poly([Vector2(-0.8, y0), Vector2(0.8, y0), Vector2(0.8, y0 + 0.18), Vector2(-0.8, y0 + 0.18)], col)


func _draw_stairs_up() -> void:
	var stone := Color(0.46, 0.44, 0.44)
	draw_texture_rect(Game.soft_dot, Rect2(-40, -14, 80, 28), false, Color(0, 0, 0, 0.55))
	for k in 6:
		var h := k * 8.0
		var off := Vector2(-k * 5.0, -k * 2.5)
		var top := PackedVector2Array([Vector2(-28, 0), Vector2(0, -14), Vector2(28, 0), Vector2(0, 14)])
		var side := PackedVector2Array([Vector2(-28, 0), Vector2(0, 14), Vector2(0, 22), Vector2(-28, 8)])
		var side2 := PackedVector2Array([Vector2(0, 14), Vector2(28, 0), Vector2(28, 8), Vector2(0, 22)])
		var sc := 1.0 - k * 0.08
		var o := off + Vector2(0, -h)
		for arr_c in [[side, stone.darkened(0.3)], [side2, stone.darkened(0.45)], [top, stone.lightened(0.05 * k)]]:
			var pts := PackedVector2Array()
			for p in arr_c[0]:
				pts.append(o + p * Vector2(sc, sc))
			draw_colored_polygon(pts, arr_c[1])
	draw_texture_rect(Game.soft_dot, Rect2(-40, -80, 50, 40), false, Color(0.8, 0.85, 1.0, 0.15))


func _draw_seal() -> void:
	var c := Vector2(0, -6)
	var rc := Color(0.86, 0.16, 0.12, 0.55 + sin(t * 3.0) * 0.25)
	ellipse(c, 40, 20, rc, false, 2.5)
	for k in 6:
		var a := k / 6.0 * TAU + t * 0.4
		draw_line(c + Vector2(cos(a) * 34, sin(a) * 17), c + Vector2(cos(a + 2.1) * 34, sin(a + 2.1) * 17), rc, 2.0)
