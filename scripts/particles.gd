class_name Particles
extends Node2D
## Lightweight spark/blood/dust particles in world space with a fake height (z).

var items: Array = []   # each: [wpos: Vector2, vel: Vector3, z: float, life: float, max_life: float, color: Color, size: float]


func add(at: Vector2, vel: Vector3, z: float, life: float, color: Color, size: float) -> void:
	items.append([at, vel, z, life, life, color, size])


func burst(at: Vector2, color: Color, n: int, speed := 2.5, z := 14.0, life := 0.6, size := 2.5) -> void:
	for i in n:
		var a := randf() * TAU
		var s := speed * (0.3 + randf())
		add(at, Vector3(cos(a) * s, sin(a) * s, randf() * 40.0 + 10.0), z, life * (0.5 + randf() * 0.7), color, size)


func _process(dt: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		var q: Array = items[i]
		q[3] -= dt
		if q[3] <= 0.0:
			items.remove_at(i)
			continue
		var v: Vector3 = q[1]
		q[0] += Vector2(v.x, v.y) * dt
		q[2] += v.z * dt
		v.z -= 90.0 * dt
		if q[2] < 0.0:
			q[2] = 0.0
			v = Vector3(v.x * 0.5, v.y * 0.5, -v.z * 0.3)
		q[1] = v
	queue_redraw()


func _draw() -> void:
	for q in items:
		var s: Vector2 = Game.iso(q[0]) - Vector2(0, q[2])
		var c: Color = q[5]
		c.a = clampf(q[3] / q[4], 0.0, 1.0)
		var sz: float = q[6]
		draw_rect(Rect2(s - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), c)
