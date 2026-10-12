class_name Player
extends Figure
## The hero, one of three planeswalkers (CLASSES): the four Diablo II attributes, equipment on
## ten slots, a 10 x 4 inventory grid (charms work while they sit in it), melee and two spells.
##
## Attributes work as in Diablo II:
##   Strength   +1% weapon damage per point; needed to use heavier gear.
##   Dexterity  +5 attack rating per point, +1 defense per 4 points, better chance to block;
##              needed for finer weapons.
##   Vitality   life per point, by class (as the Barbarian, Sorceress and Necromancer).
##   Energy     mana per point, by class.

signal stats_changed
signal leveled_up(level: int)

const SPEED := 3.6
const GRID_W := 10
const GRID_H := 4
## The planeswalkers. Starting attributes, life and mana follow the Diablo II class each one
## stands in for: Ajani the Barbarian, Chandra the Sorceress, Liliana the Necromancer.
const CLASSES := {
	"ajani": {"name": "Ajani Goldmane", "role": "Leonin warrior. Fights up close and takes a beating.",
		"stats": {"str": 30, "dex": 20, "vit": 25, "ene": 10}, "life": 55, "life_lvl": 2.0, "life_vit": 4, "mana": 10, "mana_lvl": 1.0, "mana_ene": 1},
	"chandra": {"name": "Chandra Nalaar", "role": "Pyromancer. Fragile, with the strongest spells.",
		"stats": {"str": 10, "dex": 25, "vit": 10, "ene": 35}, "life": 40, "life_lvl": 1.0, "life_vit": 2, "mana": 35, "mana_lvl": 2.0, "mana_ene": 2},
	"liliana": {"name": "Liliana Vess", "role": "Necromancer. Raises the dead and curses the living.",
		"stats": {"str": 15, "dex": 25, "vit": 15, "ene": 25}, "life": 45, "life_lvl": 1.5, "life_vit": 2, "mana": 25, "mana_lvl": 2.0, "mana_ene": 2},
}
const CLASS_ORDER := ["ajani", "chandra", "liliana"]
const STAT_POINTS_PER_LEVEL := 5

var level := 1
var xp := 0
var gold := 0
var hp := 1.0
var mp := 1.0
var cls := "ajani"
var base: Dictionary = CLASSES.ajani.stats.duplicate()
var stat_points := 0
var equip := {}
var inv: Array = []             # items with gx, gy set: their cell in the grid
var held = null                 # the item on the cursor
var belt := {"hp": 3, "mp": 2}
var st := {}
var gear_layers: Array = []     # [sheet name, tint] drawn over the body, in order

var target_monster: Monster = null
var target_drop = null          # Dictionary or null
var target_obj = null           # an Interactable to walk to and use
var atk_t := 0.0
var swing := 0.0
var cast_t := 0.0
var nova_cd := 0.0
var hit_flash := 0.0
var chill := 0.0
var poison_t := 0.0
var poison_dps := 0.0
var stuck := 0.0
var repath := 0.0
var dead := false
var death_t := 0.0
var lights: Array = []


func _init() -> void:
	for s in Items.EQUIP_SLOTS:
		equip[s] = null


func _ready() -> void:
	radius = 0.3
	setup_sprite("hero")
	lights = Game.make_light_pair(self, 820.0, Color(1.0, 0.88, 0.74), 1.15, Vector2(0, -2))
	# a soft unshadowed fill so the hero never stands in his own darkness
	add_child(Game.make_light(150.0, Color(1.0, 0.85, 0.7), 0.2, false, 1))


## Become another planeswalker: a fresh level-1 hero of that class (used when the game starts).
func set_class(c: String) -> void:
	cls = c
	base = CLASSES[c].stats.duplicate()
	recalc()
	hp = st.max_hp
	mp = st.max_mp


static func xp_needed(l: int) -> int:
	return roundi(50.0 * pow(l, 1.8))


# ---------- stats ----------

## Meets the item's level, strength and dexterity requirements (with what the hero has now).
func can_use(it: Dictionary) -> bool:
	return level >= it.req_lvl and st.get("str", base.str) >= it.req_str and st.get("dex", base.dex) >= it.req_dex


func why_not(it: Dictionary) -> String:
	if level < it.req_lvl:
		return "You must be level %d" % it.req_lvl
	if st.str < it.req_str:
		return "Not enough Strength"
	if st.dex < it.req_dex:
		return "Not enough Dexterity"
	return ""


func _sum_mods(active: Array) -> Dictionary:
	var m := {}
	for k in Items.MOD_TEXT:
		m[k] = 0
	for it in active:
		for k in it.mods:
			m[k] += it.mods[k]
	return m


func recalc() -> void:
	# items whose requirements aren't met do nothing; check against stats with everything on,
	# then once more without the ones that failed
	var worn: Array = []
	for s in Items.EQUIP_SLOTS:
		if equip[s] != null:
			worn.append(equip[s])
	for it in inv:
		if it.type == "charm":
			worn.append(it)
	var active := worn
	for pass_i in 2:
		var mm := _sum_mods(active)
		var total := {"str": base.str + mm.str + mm.all, "dex": base.dex + mm.dex + mm.all}
		active = worn.filter(func(it): return level >= it.req_lvl and total.str >= it.req_str and total.dex >= it.req_dex)
	var m := _sum_mods(active)
	var s := {}
	s.str = base.str + m.str + m.all
	s.dex = base.dex + m.dex + m.all
	s.vit = base.vit + m.vit + m.all
	s.ene = base.ene + m.ene + m.all
	for k in ["mf", "gold", "leech", "mleech", "ias", "frw", "dr", "thorns", "regen", "spell", "fdmg", "cdmg", "ldmg"]:
		s[k] = m[k]
	var w = equip.mainhand if equip.mainhand in active else null
	var wd := Items.weapon_damage(w) if w != null else [1, 2]
	var other_ed: int = m.ed - (w.mods.get("ed", 0) if w != null else 0)
	var other_maxd: int = m.maxd - (w.mods.get("maxd", 0) if w != null else 0)
	var pct: float = 1.0 + (s.str + other_ed) / 100.0
	s.dmg_min = maxi(1, floori(wd[0] * pct))
	s.dmg_max = maxi(s.dmg_min, floori(wd[1] * pct) + other_maxd)
	s.ar = (s.dex - 7) * 5 + 20 + m.ar
	var def := 0
	for it in active:
		if it.type != "charm":
			def += it.def
	s.def = def + s.dex / 4
	var sh = equip.offhand if equip.offhand in active else null
	s.block = 0
	if sh != null:
		s.block = clampi(roundi((sh.block + m.block) * (s.dex - 15) / float(level * 2)), 0, 75)
	var c: Dictionary = CLASSES[cls]
	s.max_hp = roundi(c.life + (level - 1) * c.life_lvl + (s.vit - c.stats.vit) * c.life_vit + m.life)
	s.max_mp = roundi(c.mana + (level - 1) * c.mana_lvl + (s.ene - c.stats.ene) * c.mana_ene + m.mana)
	for e in ["fire", "cold", "lit", "pois"]:
		s["res_" + e] = mini(75, m["res_" + e] + m.res_all)
	var wspd: float = w.spd if w != null else 1.0
	s.atk_time = 0.6 * wspd / (1.0 + s.ias / 120.0)
	s.speed = SPEED * (1.0 + s.frw * 1.5 / (s.frw + 150.0))
	var sp: float = 1.0 + s.spell / 100.0
	s.fire = [roundi((5 + level * 2) * sp), roundi((9 + level * 3) * sp)]
	s.nova = [roundi((4 + level * 1.5) * sp), roundi((8 + level * 2) * sp)]
	s.belt_cap = equip.belt.potions if equip.belt != null else 3
	st = s
	belt.hp = mini(belt.hp, s.belt_cap)
	belt.mp = mini(belt.mp, s.belt_cap)
	hp = minf(hp, s.max_hp)
	mp = minf(mp, s.max_mp)
	_gear_look()
	stats_changed.emit()
	queue_redraw()


## Which layer sheets show the worn gear, tinted by each item's colour.
func _gear_look() -> void:
	gear_layers.clear()
	for s in ["boots", "armor", "belt", "gloves", "helm", "offhand", "mainhand"]:
		var it = equip[s]
		if it == null:
			continue
		var t: Color = it.tint
		var c := Color(minf(1.6, t.r * 1.35), minf(1.6, t.g * 1.35), minf(1.6, t.b * 1.35))
		gear_layers.append(["hero_" + it.look, c])


func add_stat(k: String) -> void:
	if stat_points <= 0:
		return
	stat_points -= 1
	base[k] += 1
	var old_hp: float = st.max_hp
	var old_mp: float = st.max_mp
	recalc()
	hp += st.max_hp - old_hp
	mp += st.max_mp - old_mp
	Game.play("pick")


func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		stat_points += STAT_POINTS_PER_LEVEL
		recalc()
		hp = st.max_hp
		mp = st.max_mp
		Game.play("level")
		main.burst(wpos, Color("f2d25c"), 30, 2.0, 30.0, 1.0, 2.5)
		leveled_up.emit(level)


# ---------- inventory grid ----------

func grid_fits(it: Dictionary, x: int, y: int, ignore = null) -> bool:
	if x < 0 or y < 0 or x + it.w > GRID_W or y + it.h > GRID_H:
		return false
	return items_in(x, y, it.w, it.h, ignore).is_empty()


func items_in(x: int, y: int, w: int, h: int, ignore = null) -> Array:
	var out: Array = []
	var r := Rect2i(x, y, w, h)
	for o in inv:
		if o != ignore and r.intersects(Rect2i(o.gx, o.gy, o.w, o.h)):
			out.append(o)
	return out


func item_at_cell(x: int, y: int):
	for o in inv:
		if Rect2i(o.gx, o.gy, o.w, o.h).has_point(Vector2i(x, y)):
			return o
	return null


## Put an item in the first free place, column by column like Diablo II. False when full.
func auto_place(it: Dictionary) -> bool:
	for x in GRID_W:
		for y in GRID_H:
			if grid_fits(it, x, y):
				it.gx = x
				it.gy = y
				inv.append(it)
				if it.type == "charm":
					recalc()
				return true
	return false


func remove_from_grid(it: Dictionary) -> void:
	inv.erase(it)
	if it.type == "charm":
		recalc()


## Drop the held item into the grid at (x, y), swapping with a single item under it.
func place_held(x: int, y: int) -> bool:
	if held == null:
		return false
	var it: Dictionary = held
	x = clampi(x, 0, GRID_W - it.w)
	y = clampi(y, 0, GRID_H - it.h)
	var under := items_in(x, y, it.w, it.h)
	if under.size() > 1:
		return false
	it.gx = x
	it.gy = y
	inv.append(it)
	held = null
	if under.size() == 1:
		inv.erase(under[0])
		held = under[0]
	Game.play("pick")
	recalc()
	return true


func slot_accepts(slot: String, it: Dictionary) -> bool:
	return slot in Items.SLOT_OF[it.type]


## Click on a paper-doll slot: put the held item on (swapping), or pick up what is worn.
func click_slot(slot: String) -> void:
	if held != null:
		if not slot_accepts(slot, held):
			return
		if not can_use(held):
			main.floater(wpos, why_not(held), Color("ff6a5a"))
			return
		var old = equip[slot]
		equip[slot] = held
		held = old
		Game.play("pick")
		recalc()
	elif equip[slot] != null:
		held = equip[slot]
		equip[slot] = null
		recalc()


## Right-click in the grid: wear the item, moving whatever was worn into the pack.
func quick_equip(it: Dictionary) -> void:
	var slots: Array = Items.SLOT_OF[it.type]
	if slots.is_empty():
		return
	if not can_use(it):
		main.floater(wpos, why_not(it), Color("ff6a5a"))
		return
	var slot: String = slots[0]
	for s in slots:
		if equip[s] == null:
			slot = s
			break
	var old = equip[slot]
	inv.erase(it)
	equip[slot] = it
	if old != null:
		if grid_fits(old, it.gx, it.gy):
			old.gx = it.gx
			old.gy = it.gy
			inv.append(old)
		elif not auto_place(old):
			# no room for the old piece: undo
			equip[slot] = old
			inv.append(it)
			main.floater(wpos, "No room in the inventory", Color("bbbbbb"))
			return
	Game.play("pick")
	recalc()


func quick_unequip(slot: String) -> void:
	var it = equip[slot]
	if it == null:
		return
	if auto_place(it):
		equip[slot] = null
		Game.play("pick")
		recalc()
	else:
		main.floater(wpos, "No room in the inventory", Color("bbbbbb"))


# ---------- commands from input ----------

func command_attack(m: Monster) -> void:
	target_monster = m
	target_drop = null
	target_obj = null
	path.clear()
	repath = 0.0


func command_pickup(d: Dictionary) -> void:
	target_monster = null
	target_obj = null
	target_drop = d
	path = dungeon.find_path(wpos, d.wpos, radius)


func command_use(o) -> void:
	target_monster = null
	target_drop = null
	target_obj = o
	var to: Vector2 = dungeon.nearest_floor(o.wpos + o.use_offset)
	path = dungeon.find_path(wpos, to, radius) if to != Vector2.INF else []


func command_move(to: Vector2) -> void:
	target_monster = null
	target_drop = null
	target_obj = null
	var p := dungeon.nearest_floor(to)
	if p == Vector2.INF:
		return
	path = dungeon.find_path(wpos, p, radius)
	stuck = 0.0


func cast_fire(at: Vector2) -> void:
	if dead or cast_t > 0.0:
		return
	if main.in_town():
		return
	if mp < 5:
		main.no_mana()
		return
	var d := at - wpos
	if d.length() < 0.01:
		d = Vector2(fdir, -fdir)
	d = d.normalized()
	mp -= 5
	cast_t = 0.35
	play_action("cast", 0.4)
	path.clear()
	target_monster = null
	face(d)
	main.spawn_shot(null, "fire", wpos + d * 0.4, d * 9.0, st.fire, "fire")
	Game.play("fire")


func cast_nova() -> void:
	if dead or main.in_town():
		return
	if level < 3:
		main.floater(wpos, "Frost Nova unlocks at level 3", Color("8ea4ff"))
		return
	if nova_cd > 0.0 or cast_t > 0.0:
		return
	if mp < 12:
		main.no_mana()
		return
	mp -= 12
	nova_cd = 0.8
	cast_t = 0.3
	play_action("cast", 0.35)
	Game.play("nova")
	main.add_ring(wpos, 4.2, 0.45, false)
	for m in main.monsters.duplicate():
		if m.dead:
			continue
		if m.wpos.distance_to(wpos) < 4.2 and dungeon.los(wpos, m.wpos):
			m.slow = 3.0
			main.damage_monster(m, randi_range(st.nova[0], st.nova[1]), Color("a8c8ff"))


func drink(kind: String) -> void:
	if dead:
		return
	if belt[kind] <= 0:
		main.floater(wpos, "No healing draughts" if kind == "hp" else "No mana draughts", Color("bbbbbb"))
		return
	belt[kind] -= 1
	Game.play("drink")
	if kind == "hp":
		hp = minf(st.max_hp, hp + st.max_hp * 0.5)
		poison_t = 0.0
		main.burst(wpos, Color("e44a4e"), 12, 1.0, 30.0, 0.6, 2.0)
	else:
		mp = minf(st.max_mp, mp + st.max_mp * 0.6)
		main.burst(wpos, Color("7090ff"), 12, 1.0, 30.0, 0.6, 2.0)
	stats_changed.emit()


## Shield block, rolled against the block chance shown on the character panel.
func try_block() -> bool:
	if st.block > 0 and randf() * 100.0 < st.block and swing <= 0.0:
		main.floater(wpos, "block", Color("c9b99a"))
		Game.play("hit")
		return true
	return false


## elem: phys, fire, cold, lit or pois. Resistances cut elemental damage; Damage Reduced cuts
## physical. Cold chills, poison hurts over time. Attackers in melee range take thorns damage.
func take_hit(amount: int, elem := "phys", attacker = null) -> void:
	if dead:
		return
	var col := Color("ff5a4a")
	if elem == "phys":
		amount = maxi(1, amount - st.dr)
	else:
		amount = maxi(0, roundi(amount * (1.0 - st["res_" + elem] / 100.0)))
		col = {"fire": Color("ff9a3a"), "cold": Color("8ec8ff"), "lit": Color("fff07a"), "pois": Color("7adf5a")}[elem]
	if elem == "pois":
		if amount > 0:
			poison_dps = maxf(poison_dps if poison_t > 0.0 else 0.0, amount / 2.5)
			poison_t = 2.5
			main.floater(wpos, "poisoned", col)
		return
	if elem == "cold":
		chill = 2.5
	hp -= amount
	hit_flash = 0.15
	main.hurt_flash = minf(1.0, main.hurt_flash + 0.25 + amount / float(st.max_hp) * 2.0)
	main.shake(2.0 + amount / float(st.max_hp) * 20.0)
	Game.play("hurt")
	main.floater(wpos, str(amount), col)
	main.burst(wpos, Color("6a0b0b"), 5, 1.5, 20.0, 0.4, 2.0)
	if attacker != null and st.thorns > 0 and is_instance_valid(attacker) and not attacker.dead:
		main.damage_monster(attacker, st.thorns, Color("c9b99a"))
	if hp <= 0:
		hp = 0
		main.player_died()


# ---------- update ----------

func _process(dt: float) -> void:
	anim += dt
	tick_action(dt)
	if dead:
		death_t += dt
	var flicker := 1.0 + sin(anim * 7.3) * 0.03 + sin(anim * 13.1) * 0.025
	for l in lights:
		l.energy = 1.15 * flicker
	hit_flash = maxf(0.0, hit_flash - dt)
	chill = maxf(0.0, chill - dt)
	if hit_flash > 0.0:
		modulate = Color(2.4, 2.4, 2.4)
	elif poison_t > 0.0:
		modulate = Color(0.75, 1.15, 0.6)
	elif chill > 0.0:
		modulate = Color(0.65, 0.85, 1.4)
	else:
		modulate = Color.WHITE
	if dead or main.state != "play":
		queue_redraw()
		return
	atk_t -= dt
	swing = maxf(0.0, swing - dt)
	cast_t = maxf(0.0, cast_t - dt)
	nova_cd -= dt
	if poison_t > 0.0:
		poison_t -= dt
		hp -= poison_dps * dt
		if hp <= 0.0:
			hp = 0
			main.player_died()
			return
	hp = minf(st.max_hp, hp + (0.4 + st.regen * 0.5) * dt)
	mp = minf(st.max_mp, mp + (0.4 + st.max_mp / 40.0) * dt)

	if target_monster != null:
		var m := target_monster
		if not is_instance_valid(m) or m.dead:
			target_monster = null
		else:
			var d := m.wpos.distance_to(wpos)
			if d <= 1.0 + m.radius:
				path.clear()
				face(m.wpos - wpos)
				if atk_t <= 0.0 and cast_t <= 0.0:
					_attack(m)
			else:
				repath -= dt
				if repath <= 0.0 or path.is_empty():
					path = dungeon.find_path(wpos, m.wpos, radius)
					repath = 0.3
	elif target_drop != null:
		if not main.drops.has(target_drop):
			target_drop = null
		elif target_drop.wpos.distance_to(wpos) < 0.75:
			main.pickup(target_drop)
			target_drop = null
			path.clear()
	elif target_obj != null:
		if not is_instance_valid(target_obj):
			target_obj = null
		elif target_obj.wpos.distance_to(wpos) < target_obj.use_range:
			var o = target_obj
			target_obj = null
			path.clear()
			face(o.wpos - wpos)
			main.use_object(o)
			return

	moving = false
	if swing <= 0.0 and cast_t <= 0.0 and not path.is_empty():
		moving = follow(st.speed * (0.6 if chill > 0.0 else 1.0), dt)
		if not moving:
			stuck += dt
			if stuck > 0.4:
				path.clear(); stuck = 0.0
		else:
			stuck = 0.0
	sync_position()
	dungeon.mark_seen(wpos)
	queue_redraw()


func _attack(m: Monster) -> void:
	atk_t = st.atk_time
	swing = 0.25
	play_action("attack", maxf(0.35, st.atk_time * 0.85))
	Game.play("swing")
	face(m.wpos - wpos)
	m.wake()
	if randf() > Game.hit_chance(st.ar, m.def, level, m.mlvl):
		main.floater(m.wpos, "miss", Color("9a9080"))
		return
	var dmg := randi_range(st.dmg_min, st.dmg_max)
	var crit := randf() < 0.08
	if crit:
		dmg *= 2
		main.shake(3.0)
	var col := Color("ffd34a") if crit else Color.WHITE
	if st.fdmg > 0:
		dmg += randi_range(maxi(1, st.fdmg / 2), st.fdmg)
		col = Color("ffb070") if not crit else col
	if st.ldmg > 0:
		dmg += randi_range(1, st.ldmg)
	if st.cdmg > 0:
		dmg += randi_range(maxi(1, st.cdmg / 2), st.cdmg)
		m.slow = maxf(m.slow, 1.5)
	Game.play("hit")
	main.burst(m.wpos, Color("ffe7b0") if crit else Color("e8d8b0"), 10 if crit else 5, 2.4, 18.0 * m.size, 0.3, 2.0)
	main.burst(m.wpos, Color(m.d.blood).lightened(0.15), 6, 1.8, 18.0 * m.size, 0.5, 2.5)
	if st.leech > 0:
		hp = minf(st.max_hp, hp + dmg * st.leech / 100.0)
	if st.mleech > 0:
		mp = minf(st.max_mp, mp + dmg * st.mleech / 100.0)
	main.damage_monster(m, dmg, col)


# ---------- drawing ----------

func _draw() -> void:
	shadow(13)
	if dead:
		draw_frame("death", int(death_t * 9.0))
		return
	var f := pick_frame()
	draw_frame(f[0], f[1])


## The bare hero, then each worn piece over it in its own colour.
func draw_body(c: CanvasItem) -> void:
	var r := frame_rects("hero_base_" + cls)
	c.draw_texture_rect_region(r[0].tex, r[2], r[1])
	for g in gear_layers:
		c.draw_texture_rect_region(Game.sheet(g[0]).tex, r[2], r[1], g[1])
