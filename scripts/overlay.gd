class_name Overlay
extends Node2D
## Drawn on a CanvasLayer that follows the camera but ignores the darkness:
## loot labels (clickable) and floating combat text.

var main
var floaters: Array = []      # [wpos, text, color, life]
var label_rects: Array = []   # [Rect2 in world-canvas pixels, drop]
var hovered_drop = null
var hovered_obj = null


func add_floater(at: Vector2, text: String, color: Color) -> void:
	floaters.append([at, text, color, 1.0])


func _process(dt: float) -> void:
	for i in range(floaters.size() - 1, -1, -1):
		floaters[i][3] -= dt * 0.9
		if floaters[i][3] <= 0.0:
			floaters.remove_at(i)
	queue_redraw()


func drop_at(canvas_pos: Vector2):
	for i in range(label_rects.size() - 1, -1, -1):
		if label_rects[i][0].has_point(canvas_pos):
			return label_rects[i][1]
	return null


func _draw() -> void:
	if main == null or main.player == null:
		return
	var font: Font = Game.font_body
	var bold: Font = Game.font_bold
	label_rects.clear()
	var near: Array = main.drops.filter(func(d): return d.wpos.distance_to(main.player.wpos) < 10.0)
	near.sort_custom(func(a, b): return a.wpos.x + a.wpos.y < b.wpos.x + b.wpos.y)
	for d in near:
		var text := ""
		var col := Color("d9d4c7")
		match d.kind:
			"gold": text = "%d Gold" % d.amt; col = Color("e2c26a")
			"hp": text = "Healing Draught"
			"mp": text = "Mana Draught"
			_: text = d.item.name; col = Game.RARITY_COLORS[d.item.rarity]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0
		var s: Vector2 = Game.iso(d.wpos)
		var r := Rect2(s.x - w / 2.0, s.y - 30.0, w, 18.0)
		for k in 12:
			var overlap = null
			for o in label_rects:
				if o[0].intersects(r):
					overlap = o[0]
					break
			if overlap == null:
				break
			r.position.y = overlap.position.y - r.size.y - 2.0
		var hov: bool = hovered_drop == d
		draw_rect(r, Color(0.16, 0.12, 0.08, 0.92) if hov else Color(0, 0, 0, 0.72))
		if hov:
			draw_rect(r, col, false, 1.0)
		draw_string(font, Vector2(r.position.x + 6.0, r.position.y + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
		label_rects.append([r, d])
	# names of the people of the town, and whatever the mouse is over
	for o in main.objects:
		if not is_instance_valid(o):
			continue
		if o == hovered_obj or (o.kind == "npc" and o.wpos.distance_to(main.player.wpos) < 7.0):
			var text: String = o.label
			if o.kind == "portal" and o.sealed:
				text += " (sealed)"
			elif o.kind == "waypoint" and not o.active:
				text = "Waypoint (not yet found)"
			var col := Color("e8dcc0") if o.kind == "npc" else Color("8ec8ff") if o.kind in ["waypoint", "tportal"] else Color("ffd38a")
			if o == hovered_obj:
				col = col.lightened(0.25)
			var fs := 14
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12.0
			var top: float = o.position.y - (78.0 if o.kind == "npc" else (96.0 if o.kind == "portal" and o.style in ["gate", "door", "cave"] else 60.0))
			var r := Rect2(o.position.x - w / 2.0, top, w, 19.0)
			draw_rect(r, Color(0, 0, 0, 0.7))
			draw_string(font, Vector2(r.position.x + 6.0, r.position.y + 15.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	for f in floaters:
		var s: Vector2 = Game.iso(f[0])
		var a: float = minf(1.0, f[3] * 2.0)
		var text: String = f[1]
		var pop := 1.0 + maxf(0.0, f[3] - 0.82) * 4.0
		var fs := int((14 if text.length() > 4 else 18) * pop)
		var y: float = s.y - 56.0 - (1.0 - f[3]) * 40.0
		var w := bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var c: Color = f[2]
		draw_string(bold, Vector2(s.x - w / 2.0 + 1.0, y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a))
		draw_string(bold, Vector2(s.x - w / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(c, a))
