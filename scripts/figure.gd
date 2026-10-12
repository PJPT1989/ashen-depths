class_name Figure
extends Node2D
## Base for anything that walks the dungeon: world position, radius, facing,
## path following with wall sliding, and small drawing helpers that mirror by facing.

var main                  # the Main node (untyped so its methods resolve at runtime); set on spawn
var dungeon: Dungeon
var wpos := Vector2.ZERO  # position in tiles
var radius := 0.3
var fdir := 1.0           # +1 faces screen-right, -1 screen-left
var path: Array[Vector2] = []
var anim := 0.0
var moving := false
var size := 1.0           # drawing scale
var face_vec := Vector2(1, 1)  # world-space facing
var sprite_type := ""     # key into Game.sheet(); empty = no sprite
var act_name := ""        # one-shot animation playing (attack, cast)
var act_t := 0.0
var act_len := 1.0
var glow_node: Glow
var body: Body            # draws the sprite, so it can carry its own material (rank colours)
var frame_anim := "idle"
var frame_i := 0


## Additive overlay that draws the same frame from the glow sheet (eyes, orbs).
class Glow extends Node2D:
	var tex: Texture2D
	var src := Rect2()
	var dst := Rect2()
	func _draw() -> void:
		if tex:
			draw_texture_rect_region(tex, dst, src)


## Child node that draws the current frame; Figure._draw keeps shadows and rings under it.
class Body extends Node2D:
	var fig
	func _draw() -> void:
		fig.draw_body(self)


func sync_position() -> void:
	position = Game.iso(wpos)


func face(d: Vector2) -> void:
	var s := d.x - d.y
	if absf(s) > 0.05:
		fdir = 1.0 if s > 0 else -1.0
	if d.length_squared() > 0.0001:
		face_vec = d.normalized()


## Which of the 8 baked directions matches the facing (0 = screen right, 2 = toward camera).
func dir_index() -> int:
	var sv := Vector2((face_vec.x - face_vec.y) * Game.HW, (face_vec.x + face_vec.y) * Game.HH)
	return posmod(roundi(sv.angle() / (PI / 4.0)), 8)


func setup_sprite(type: String) -> void:
	sprite_type = type
	body = Body.new()
	body.fig = self
	add_child(body)
	if type != "hero":
		var sh: Dictionary = Game.sheet(type)
		glow_node = Glow.new()
		glow_node.tex = sh.glow
		glow_node.material = Game.add_material
		add_child(glow_node)


func play_action(name: String, length: float) -> void:
	act_name = name
	act_len = length
	act_t = length


func tick_action(dt: float) -> void:
	act_t = maxf(0.0, act_t - dt)


## Show one frame of the baked sheet with its feet at this node's origin.
func draw_frame(anim_name: String, frame: int) -> void:
	frame_anim = anim_name
	frame_i = frame
	if body:
		body.queue_redraw()


func frame_rects(type: String) -> Array:
	var sh: Dictionary = Game.sheet(type)
	var cell: int = sh.cell
	var row: int = Game.SPRITE_ANIMS.find(frame_anim) * 8 + dir_index()
	return [sh, Rect2(clampi(frame_i, 0, 7) * cell, row * cell, cell, cell), Rect2(-sh.anchor, Vector2(cell, cell))]


func draw_body(c: CanvasItem) -> void:
	var r := frame_rects(sprite_type)
	c.draw_texture_rect_region(r[0].tex, r[2], r[1])
	if glow_node:
		glow_node.src = r[1]
		glow_node.dst = r[2]
		glow_node.queue_redraw()


## The animation frame for the current state: an action if one is playing, else walk or idle.
func pick_frame() -> Array:
	if act_t > 0.0:
		var p := 1.0 - act_t / act_len
		return [act_name, mini(7, int(p * 8.0))]
	if moving:
		return ["walk", int(anim * 11.0) % 8]
	return ["idle", int(anim * 5.0) % 8]


## Move with collision, sliding along walls. Returns distance actually moved.
func move_by(d: Vector2) -> float:
	var old := wpos
	if dungeon.is_free(Vector2(wpos.x + d.x, wpos.y), radius):
		wpos.x += d.x
	if dungeon.is_free(Vector2(wpos.x, wpos.y + d.y), radius):
		wpos.y += d.y
	return absf(wpos.x - old.x) + absf(wpos.y - old.y)


## Step along the current path. Returns true if the figure made progress.
func follow(speed: float, dt: float) -> bool:
	if path.is_empty():
		return false
	var wp := path[0]
	var d := wp - wpos
	var dist := d.length()
	var step := speed * dt
	face(d)
	if dist <= step:
		move_by(d)
		path.pop_front()
		return true
	return move_by(d / dist * step) > step * 0.2


# ---------- drawing helpers (local coords face right; x is mirrored by fdir) ----------

func P(x: float, y: float) -> Vector2:
	return Vector2(x * fdir, y) * size


func ln(x1: float, y1: float, x2: float, y2: float, col: Color, w: float) -> void:
	draw_line(P(x1, y1), P(x2, y2), col, w * size, true)


func circ(x: float, y: float, r: float, col: Color) -> void:
	draw_circle(P(x, y), r * size, col)


func poly(pts: Array, col: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(P(p[0], p[1]))
	draw_colored_polygon(arr, col)


func ellipse(c: Vector2, rx: float, ry: float, col: Color, filled := true, width := 2.0) -> void:
	var arr := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		arr.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if filled:
		draw_colored_polygon(arr, col)
	else:
		arr.append(arr[0])
		draw_polyline(arr, col, width, true)


func shadow(rx: float) -> void:
	draw_texture_rect(Game.soft_dot, Rect2(-rx * 1.4, -rx * 0.6, rx * 2.8, rx * 1.2), false, Color(0, 0, 0, 0.75))
