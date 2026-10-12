class_name SkillFx
extends Node2D
## Short-lived pictures for hero skills that are not missiles: lightning chains, beams,
## falling meteors (which strike when they land) and lingering clouds (which tick).
##   chain  points: Array of world positions, drawn as jagged bolts
##   beam   points: [from, to]
##   blast  points: [where]; calls done() when it lands after `delay` seconds
##   cloud  points: [where]; calls tick() every half second for `dur` seconds

var main
var kind := "chain"
var points: Array = []
var color := Color.WHITE
var radius := 1.0
var life := 0.3
var total := 0.3
var done: Callable
var tick: Callable
var tick_t := 0.0
var jag: Array = []     # fixed random offsets so bolts don't flicker every frame


static func make(m, k: String, pts: Array, col: Color, dur: float, r := 1.0) -> SkillFx:
	var f := SkillFx.new()
	f.main = m
	f.kind = k
	f.points = pts
	f.color = col
	f.life = dur
	f.total = dur
	f.radius = r
	for i in 64:
		f.jag.append(randf_range(-1.0, 1.0))
	if k == "cloud":
		m.flat.add_child(f)
	else:
		f.z_index = 5
		m.add_child(f)
	return f


func _process(dt: float) -> void:
	if main.state != "play" and main.state != "dead":
		return
	life -= dt
	if kind == "cloud":
		tick_t -= dt
		if tick_t <= 0.0 and life > 0.0:
			tick_t = 0.5
			if tick.is_valid():
				tick.call()
	if life <= 0.0:
		if kind == "blast" and done.is_valid():
			done.call()
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := 1.0 - life / total
	match kind:
		"chain":
			var a := clampf(life / total * 1.5, 0.0, 1.0)
			for i in points.size() - 1:
				var from: Vector2 = Game.iso(points[i]) + Vector2(0, -24)
				var to: Vector2 = Game.iso(points[i + 1]) + Vector2(0, -24)
				var line := PackedVector2Array([from])
				var n := Vector2(-(to - from).y, (to - from).x).normalized()
				for k in range(1, 6):
					line.append(from.lerp(to, k / 6.0) + n * jag[(i * 6 + k) % 64] * 9.0)
				line.append(to)
				draw_polyline(line, Color(color, a * 0.5), 6.0)
				draw_polyline(line, Color(1, 1, 1, a), 2.0)
		"beam":
			var a := clampf(life / total * 2.0, 0.0, 1.0)
			var from: Vector2 = Game.iso(points[0]) + Vector2(0, -24)
			var to: Vector2 = Game.iso(points[1]) + Vector2(0, -24)
			draw_line(from, to, Color(color, a * 0.45), 16.0)
			draw_line(from, to, Color(color.lightened(0.4), a * 0.8), 7.0)
			draw_line(from, to, Color(1, 1, 0.9, a), 2.5)
		"blast":
			var c: Vector2 = Game.iso(points[0])
			var ring := PackedVector2Array()
			for i in 25:
				var ang := TAU * i / 24.0
				ring.append(c + Vector2(cos(ang) * radius * Game.HW * 1.41, sin(ang) * radius * Game.HH * 1.41))
			draw_polyline(ring, Color(color, 0.35 + p * 0.5), 2.0)
			# the meteor falls toward the ring
			var h := (1.0 - p) * 320.0
			var r := 9.0 + p * 7.0
			var head := c + Vector2(-h * 0.35, -h - 18.0)
			draw_line(head, head + Vector2(-60, -150) * (1.0 - p * 0.5), Color(color, 0.35), r)
			draw_texture_rect(Game.soft_dot, Rect2(head - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, Color(color, 0.8))
			draw_texture_rect(Game.soft_dot, Rect2(head - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 0.95, 0.8))
		"cloud":
			var c: Vector2 = Game.iso(points[0])
			var fade := clampf(minf(p * 6.0, life * 2.0), 0.0, 1.0)
			var t := Time.get_ticks_msec() / 1000.0
			for i in 9:
				var ang: float = jag[i] * PI + t * (0.4 + jag[i + 9] * 0.2)
				var d: float = radius * (0.25 + absf(jag[i + 18]) * 0.6)
				var at := c + Vector2(cos(ang) * d * Game.HW, sin(ang) * d * Game.HH) + Vector2(0, -6)
				var s: float = radius * Game.HW * (0.55 + absf(jag[i + 27]) * 0.3)
				draw_texture_rect(Game.soft_dot, Rect2(at - Vector2(s, s * 0.6), Vector2(s * 2.0, s * 1.2)), false, Color(color.darkened(0.15), 0.3 * fade))
