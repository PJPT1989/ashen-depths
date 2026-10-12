class_name Minion
extends Figure
## A creature fighting for the hero: Liliana's skeletons, zombies and golem, Chandra's fire
## elemental, Ajani's war-cat. Drawn from the monster sheets (tinted), it follows the hero,
## attacks the nearest foe, and monsters that stand next to it attack it back.

var skill_id := ""
var group := ""             # minions of one group share a limit (all golems)
var kind := "bonewalker"
var d: Dictionary
var hp := 1.0
var max_hp := 1.0
var dmg := [1, 2]
var speed := 2.4
var shot := ""              # missile kind for ranged minions, empty for melee
var dur := 0.0              # seconds left; 0 = stays until killed
var timed := false
var lifelink := 0.0         # % of the hero's life healed per hit (Blood Golem)
var tint := Color.WHITE
var target: Monster = null
var cd := 0.0
var think_t := 0.0
var repath := 0.0
var hit := 0.0
var dead := false
var dying := 0.0
var spawn_t := 0.4


## s: the resolved summon skill (see Skills); level and minion_bonus (%) come from the hero.
func setup(s: Dictionary, at: Vector2, level: int, minion_bonus: float) -> void:
	skill_id = s.id
	group = s.get("group", s.id)
	kind = s.minion
	d = Monster.TYPES[kind]
	wpos = at
	var r := clampi(1 + (level - 1) / 2, 1, 12)
	var m := pow(1.3, r - 1) * (1.0 + minion_bonus / 100.0)
	max_hp = d.hp * m * s.get("hp", 1.0)
	hp = max_hp
	dmg = [maxi(1, roundi(d.dmg[0] * m * s.get("dmg", 1.0))), maxi(1, roundi(d.dmg[1] * m * s.get("dmg", 1.0)))]
	speed = maxf(d.spd, 2.4)
	shot = s.get("shot", "")
	dur = s.get("dur", 0)
	timed = dur > 0
	lifelink = s.get("lifelink", 0.0)
	tint = s.get("tint", Color(0.8, 1.0, 0.86))
	radius = d.r
	size = Game.SPRITE_CELLS[kind] / 112.0
	anim = randf() * 10.0
	sync_position()


func _ready() -> void:
	setup_sprite(kind)
	body.modulate = tint
	glow_node.modulate = tint


func take_hit(amount: int) -> void:
	if dead:
		return
	hp -= amount * (1.0 - minf(75.0, main.player.fx.get("minion_dr", 0.0)) / 100.0)
	hit = 0.12
	if hp <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	dying = 0.9
	main.minions.erase(self)
	main.burst(wpos, Color(0.6, 0.65, 0.6), 10, 1.8, 16.0 * size, 0.5, 2.5)


func _process(dt: float) -> void:
	anim += dt
	tick_action(dt)
	if dying > 0.0:
		dying -= dt
		modulate.a = clampf(dying * 1.5, 0.0, 1.0)
		queue_redraw()
		if dying <= 0.0:
			queue_free()
		return
	if main.state != "play":
		return
	hit = maxf(0.0, hit - dt)
	spawn_t = maxf(0.0, spawn_t - dt)
	modulate = Color(2.2, 2.2, 2.2) if hit > 0.0 else Color.WHITE
	if timed:
		dur -= dt
		if dur <= 0.0:
			die()
			return
	cd -= dt
	moving = false
	var player: Player = main.player
	think_t -= dt
	if think_t <= 0.0:
		think_t = 0.35
		target = _pick_target(player)
	var reach: float = d.range if shot != "" else d.r + 0.75
	if target != null and is_instance_valid(target) and not target.dead:
		var dist := wpos.distance_to(target.wpos)
		if dist <= reach + target.radius and (shot == "" or main.dungeon.los(wpos, target.wpos)):
			face(target.wpos - wpos)
			path.clear()
			if cd <= 0.0:
				_attack()
		else:
			repath -= dt
			if repath <= 0.0 or path.is_empty():
				path = main.dungeon.find_path(wpos, target.wpos, radius)
				repath = 0.4
			moving = follow(speed, dt)
	else:
		var to_hero := wpos.distance_to(player.wpos)
		if to_hero > 16.0:
			wpos = main.dungeon.spot_near(player.wpos, 1.5)
			path.clear()
		elif to_hero > 3.0:
			repath -= dt
			if repath <= 0.0 or path.is_empty():
				path = main.dungeon.find_path(wpos, player.wpos, radius)
				repath = 0.5
			moving = follow(speed * (1.3 if to_hero > 6.0 else 1.0), dt)
		else:
			path.clear()
	sync_position()
	queue_redraw()


## The nearest awake foe near the minion and not too far from the hero.
func _pick_target(player: Player) -> Monster:
	var best: Monster = null
	var bd := 7.5
	for m in main.monsters:
		if m.dead:
			continue
		var dm: float = m.wpos.distance_to(wpos)
		if dm < bd and m.wpos.distance_to(player.wpos) < 12.0 and (m.aggro or dm < 4.0):
			bd = dm
			best = m
	return best


func _attack() -> void:
	cd = d.cd
	play_action("attack", 0.5)
	var t := target
	if shot != "":
		var dir := (t.wpos - wpos).normalized()
		var hurt := func(m: Monster): _strike(m)
		var p: Projectile = preload("res://scenes/projectile.tscn").instantiate()
		p.setup_hero(main, shot, wpos + dir * 0.4, dir * (9.0 if shot == "arrow" else 7.5), hurt, false, 0.0, d.range + 1.5)
		main.world.add_child(p)
		Game.play("bolt" if shot == "arrow" else "fire")
	else:
		_strike(t)
		Game.play("hit")


func _strike(m: Monster) -> void:
	if m.dead:
		return
	var col := Color("ffb347") if shot == "fire" else Color("cfe8c0")
	main.damage_monster(m, randi_range(dmg[0], dmg[1]), col)
	main.burst(m.wpos, Color(m.d.blood).lightened(0.15), 4, 1.6, 18.0 * m.size, 0.4, 2.0)
	if lifelink > 0.0:
		var p: Player = main.player
		p.hp = minf(p.st.max_hp, p.hp + p.st.max_hp * lifelink / 100.0)


func _draw() -> void:
	ellipse(Vector2.ZERO, 14 * size, 6 * size, Color(0.45, 0.95, 0.6, 0.35), false, 1.5)
	shadow((8.0 if d.has("float") else 11.0) * size)
	if dying > 0.0:
		draw_frame("death", mini(7, int((1.0 - dying / 0.9) * 12.0)))
		return
	if spawn_t > 0.0:
		draw_frame("death", mini(7, int(spawn_t / 0.4 * 8.0)))  # climbs up out of the ground
		return
	var f := pick_frame()
	draw_frame(f[0], f[1])
