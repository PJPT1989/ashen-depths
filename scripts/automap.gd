class_name Automap
extends Control
## Tab overlay: outlines of every explored edge, with the waypoint, the ways in and out,
## the town's people and the hero. The outline is rebuilt only when new ground is seen.

var main
var _lines := PackedVector2Array()
var _version := -1
var _area := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


## Edges between seen walkable ground and anything else, in unscaled tile-iso units.
func _rebuild(dg: Dungeon) -> void:
	_lines = PackedVector2Array()
	for j in dg.H:
		for i in dg.W:
			if dg.seen[dg.idx(i, j)] == 0 or not dg.is_floor(i, j):
				continue
			var s := Vector2(i - j, i + j)
			if not dg.is_floor(i, j - 1):
				_lines.append_array([s, s + Vector2(1, 1)])
			if not dg.is_floor(i + 1, j):
				_lines.append_array([s + Vector2(1, 1), s + Vector2(0, 2)])
			if not dg.is_floor(i, j + 1):
				_lines.append_array([s + Vector2(0, 2), s + Vector2(-1, 1)])
			if not dg.is_floor(i - 1, j):
				_lines.append_array([s + Vector2(-1, 1), s])
	_version = dg.seen_version
	_area = main.area


func _draw() -> void:
	var dg: Dungeon = main.dungeon
	if _version != dg.seen_version or _area != main.area:
		_rebuild(dg)
	var p: Vector2 = main.player.wpos
	var vs := get_viewport_rect().size
	var sc := clampf(minf(vs.x, vs.y) / 2400.0, 0.1, 0.3)
	var hw := Game.HW * sc
	var hh := Game.HH * sc
	var center := Vector2(vs.x / 2.0, vs.y * 0.42)
	var o := center - Vector2((p.x - p.y) * hw, (p.x + p.y) * hh)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.45))
	draw_set_transform(o, 0.0, Vector2(hw, hh))
	if _lines.size() > 0:
		draw_multiline(_lines, Color(0.84, 0.75, 0.55, 0.7), -1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var to_screen := func(w: Vector2) -> Vector2: return o + Vector2((w.x - w.y) * hw, (w.x + w.y) * hh)
	for ob in main.objects:
		if not is_instance_valid(ob):
			continue
		var w: Vector2 = ob.wpos
		if not dg.outdoor and dg.seen[dg.idx(clampi(floori(w.x), 0, dg.W - 1), clampi(floori(w.y), 0, dg.H - 1))] == 0:
			continue
		var c: Vector2 = to_screen.call(w)
		match ob.kind:
			"waypoint":
				draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), Color("6fa8ff") if ob.active else Color("4a5060"))
			"portal":
				draw_circle(c, 5, Color("dd3333") if ob.sealed else Color("ffbe5a"))
			"tportal":
				draw_circle(c, 5, Color("8ec8ff"))
			"npc":
				draw_circle(c, 3.5, Color("e8dcc0"))
	draw_circle(center, 3.5, Color("e8e0c8"))
	var a := Act.area(main.area)
	var f: Font = Game.font_display
	draw_string(f, Vector2(24, 48), a.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("c8a165"))
