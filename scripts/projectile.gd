class_name Projectile
extends Node2D
## Missiles: the heroes' skill shots and their minions' fire and arrows, and monster hex
## bolts, arrows, quills and bile.
## They fly over low obstacles and water, and stop at walls, trees and rocks.

const LOOK := {
	"fire": {"core": Color(1, 0.9, 0.6), "mid": Color(1, 0.45, 0.1), "r": 13.0, "light": Color(1.0, 0.55, 0.2)},
	"hex": {"core": Color(0.95, 0.85, 1), "mid": Color(0.65, 0.3, 1.0), "r": 8.0, "light": Color(0.7, 0.45, 1.0)},
	"bile": {"core": Color(0.85, 1, 0.6), "mid": Color(0.35, 0.75, 0.1), "r": 8.0, "light": Color(0.5, 0.9, 0.2)},
	"arrow": {"core": Color(0.85, 0.8, 0.7), "mid": Color(0.5, 0.4, 0.3), "r": 0.0},
	"quill": {"core": Color(0.9, 0.85, 0.7), "mid": Color(0.45, 0.3, 0.2), "r": 0.0},
	"spark": {"core": Color(1, 0.95, 0.75), "mid": Color(1, 0.5, 0.12), "r": 7.0, "light": Color(1.0, 0.6, 0.25)},
	"bone": {"core": Color(0.98, 0.96, 0.88), "mid": Color(0.75, 0.72, 0.62), "r": 0.0},
}

var main
var source = null           # the Monster that fired it, or null for the hero
var wpos := Vector2.ZERO
var vel := Vector2.ZERO
var from_player := true
var kind := "fire"
var elem := "phys"
var dmg := [1, 2]
var life := 1.4
var radius := 0.25
# hero and minion shots: what a hit does, and how the shot behaves
var hit_cb: Callable
var pierce := false
var boom := 0.0
var hit_list: Array = []


func setup(m, src, k: String, at: Vector2, v: Vector2, damage: Array, element: String) -> void:
	main = m
	source = src
	from_player = src == null
	kind = k
	elem = element
	wpos = at
	vel = v
	dmg = damage
	life = 1.4 if k == "fire" else 1.6
	radius = 0.25 if k == "fire" else 0.2
	position = Game.iso(wpos)


## A shot of the hero or a minion: hit(monster) applies the damage; pierce flies on through
## foes; boom > 0 explodes on impact and hits everything within that radius.
func setup_hero(m, k: String, at: Vector2, v: Vector2, hit: Callable, pierces := false, boom_r := 0.0, reach := 12.0) -> void:
	main = m
	source = null
	from_player = true
	kind = k
	wpos = at
	vel = v
	hit_cb = hit
	pierce = pierces
	boom = boom_r
	life = reach / maxf(1.0, v.length())
	radius = 0.25
	position = Game.iso(wpos)


func _ready() -> void:
	var look: Dictionary = LOOK[kind]
	if look.r <= 0.0:
		return
	material = Game.add_material
	if kind == "fire":
		Game.make_light_pair(self, 360.0, look.light, 1.3, Vector2(0, -6))
	else:
		add_child(Game.make_light(170.0, look.light, 1.0))
	var trail := Game.make_fire(60 if kind == "fire" else 30, 18.0 if kind == "fire" else 10.0,
		Game.FIRE_COLORS if kind == "fire" else [Color(look.core, 1), Color(look.mid, 0.8), Color(look.mid.darkened(0.6), 0)], 0.45 if kind == "fire" else 0.35, 20.0 if kind == "fire" else 0.0)
	trail.local_coords = false
	trail.position = Vector2(0, -22)
	trail.spread = 180.0
	add_child(trail)


func _process(dt: float) -> void:
	if main.state != "play":
		return
	life -= dt
	var next := wpos + vel * dt
	var hit: bool = not main.dungeon.open_air(next) or life <= 0.0
	if not hit:
		wpos = next
	if from_player:
		var struck: Monster = null
		if not hit:
			for m in main.monsters:
				if not m.dead and not m in hit_list and m.wpos.distance_to(wpos) < m.radius + radius:
					struck = m
					break
		if struck and pierce:
			hit_list.append(struck)
			hit_cb.call(struck)
			main.burst(wpos, LOOK[kind].mid, 5, 1.5, 22.0, 0.3, 2.0)
		elif struck or (hit and boom > 0.0):
			hit = true
			if boom > 0.0:
				Game.play("boom")
				main.burst(wpos, LOOK[kind].mid, 22, 3.0, 22.0, 0.5, 3.0)
				main.burst(wpos, LOOK[kind].core, 8, 1.5, 22.0, 0.4, 2.0)
				if kind in ["fire", "spark"]:
					main.flash(wpos)
				main.shake(4.0)
				main.add_ring(wpos, boom, 0.35, false, LOOK[kind].mid)
				for m in main.monsters.duplicate():
					if not m.dead and m.wpos.distance_to(wpos) < boom + m.radius:
						hit_cb.call(m)
			else:
				hit_cb.call(struck)
				main.burst(wpos, LOOK[kind].mid, 10, 1.5, 22.0, 0.35, 2.0)
	else:
		var p: Player = main.player
		if not hit and p.wpos.distance_to(wpos) < p.radius + radius:
			hit = true
			var src_ok: bool = source != null and is_instance_valid(source)
			var ar: int = source.ar if src_ok else 50
			var lvl: int = source.mlvl if src_ok else 1
			if elem == "phys" and randf() > Game.hit_chance(ar, p.st.def, lvl, p.level):
				main.floater(p.wpos, "miss", Color("9a9080"))
			elif (elem == "phys" or elem == "fire") and p.try_block():
				pass
			else:
				p.take_hit(randi_range(dmg[0], dmg[1]), elem, null)
		if hit:
			main.burst(wpos, LOOK[kind].mid, 10, 1.5, 22.0, 0.35, 2.0)
	if hit:
		queue_free()
		return
	position = Game.iso(wpos)
	queue_redraw()


func _draw() -> void:
	var look: Dictionary = LOOK[kind]
	if look.r <= 0.0:
		# a shaft along the flight direction
		var sv := Vector2((vel.x - vel.y) * Game.HW, (vel.x + vel.y) * Game.HH).normalized()
		var tip := Vector2(0, -22) + sv * 10.0
		var tail := Vector2(0, -22) - sv * (12.0 if kind == "arrow" else 6.0)
		draw_line(tail, tip, look.mid, 2.0, true)
		draw_line(tip - sv * 3.0, tip, look.core, 2.5, true)
		if kind == "arrow":
			var n := Vector2(-sv.y, sv.x)
			draw_line(tail, tail + n * 3.0 - sv * 3.0, Color(0.8, 0.75, 0.65), 1.5, true)
			draw_line(tail, tail - n * 3.0 - sv * 3.0, Color(0.8, 0.75, 0.65), 1.5, true)
		return
	var t := Time.get_ticks_msec() / 1000.0
	var r: float = look.r * (1.0 + sin(t * 30.0) * 0.08)
	draw_texture_rect(Game.soft_dot, Rect2(Vector2(-r * 2, -22 - r * 2), Vector2(r * 4, r * 4)), false, Color(look.mid, 0.6))
	draw_texture_rect(Game.soft_dot, Rect2(Vector2(-r, -22 - r), Vector2(r * 2, r * 2)), false, look.core)
