class_name Brazier
extends Node2D
## An iron fire bowl on a tripod: flickering, shadow-casting light and live flames.

var lights: Array = []
var phase := randf() * 100.0
var base_energy := 0.95
var bonfire := false        # the town's open fire: bigger, on a ring of stones
var diameter := 560.0


func place(at: Vector2) -> void:
	position = Game.iso(at)


func _ready() -> void:
	if bonfire:
		diameter = 900.0
		base_energy = 1.2
	lights = Game.make_light_pair(self, diameter, Color(1.0, 0.66, 0.38), base_energy, Vector2(0, -6))
	var flame := Game.make_fire(70 if bonfire else 34, 30.0 if bonfire else 16.0, Game.FIRE_COLORS, 0.9 if bonfire else 0.75, 80.0 if bonfire else 70.0)
	flame.position = Vector2(0, -8 if bonfire else -27)
	flame.emission_sphere_radius = 14.0 if bonfire else 6.0
	add_child(flame)
	var sparks := Game.make_fire(6, 4.0, [Color(1, 0.9, 0.5, 1), Color(1, 0.4, 0.1, 0)], 1.6, 40.0)
	sparks.position = Vector2(0, -14 if bonfire else -30)
	sparks.initial_velocity_max = 40.0
	add_child(sparks)


func _process(dt: float) -> void:
	phase += dt
	var f := 1.0 + sin(phase * 9.0) * 0.06 + sin(phase * 23.0) * 0.04 + sin(phase * 3.1) * 0.05
	for l in lights:
		l.energy = base_energy * f
	lights[0].texture_scale = diameter / 256.0 * (1.0 + (f - 1.0) * 0.5)


func _draw() -> void:
	if bonfire:
		draw_texture_rect(Game.soft_dot, Rect2(-34, -14, 68, 28), false, Color(0, 0, 0, 0.5))
		for k in 9:
			var a := TAU * k / 9.0
			var p := Vector2(cos(a) * 24, sin(a) * 12)
			draw_circle(p, 6.0, Color(0.3, 0.28, 0.27))
			draw_circle(p + Vector2(-1, -2), 4.0, Color(0.42, 0.39, 0.37))
		for k in 4:
			var a := k * 0.8 + 0.3
			draw_line(Vector2(cos(a) * 14, sin(a) * 6), Vector2(-cos(a) * 14, -sin(a) * 6 - 4), Color(0.22, 0.14, 0.08), 4.0)
		draw_texture_rect(Game.soft_dot, Rect2(-20, -16, 40, 20), false, Color(1, 0.55, 0.15, 0.9))
		return
	var iron := Color(0.16, 0.14, 0.13)
	var rim := Color(0.32, 0.27, 0.22)
	draw_texture_rect(Game.soft_dot, Rect2(-14, -6, 28, 12), false, Color(0, 0, 0, 0.6))
	for x in [-8.0, 0.0, 8.0]:
		draw_line(Vector2(x * 0.6, -18), Vector2(x, 0), iron, 2.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -24), Vector2(11, -24), Vector2(7, -17), Vector2(-7, -17)]), iron)
	draw_line(Vector2(-11, -24), Vector2(11, -24), rim, 2.0, true)
	draw_texture_rect(Game.soft_dot, Rect2(-9, -29, 18, 8), false, Color(1, 0.55, 0.15, 0.9))
