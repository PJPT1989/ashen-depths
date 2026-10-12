class_name Orb
extends Control
## A glass orb filled with liquid to `fraction`, like the life and mana globes.

var fraction := 1.0
var text := ""
var top_color := Color("e44a4e")
var deep_color := Color("5e080b")


func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	draw_circle(c, r, Color("4a3f33"))
	draw_circle(c, r - 3.0, Color("0c0a0a"))
	var inner := r - 4.0
	var level := c.y + inner - fraction * inner * 2.0
	# liquid: horizontal chords of the circle below the surface line
	var y := c.y - inner
	while y < c.y + inner:
		if y >= level:
			var half := sqrt(maxf(0.0, inner * inner - (y - c.y) * (y - c.y)))
			var t := (y - (c.y - inner)) / (inner * 2.0)
			draw_line(Vector2(c.x - half, y), Vector2(c.x + half, y), top_color.lerp(deep_color, t), 1.2)
		y += 1.0
	draw_circle(c + Vector2(-r * 0.18, -r * 0.42), r * 0.28, Color(1, 1, 1, 0.13))
	var font: Font = Game.font_bold
	var fs := 13 if r > 40.0 else 11
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-w / 2.0 + 1, 5 + 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.9))
	draw_string(font, c + Vector2(-w / 2.0, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ddd3c0"))
