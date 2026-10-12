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
# skills (see Skills): the six hotbar slots, the rune picked for each skill, passives
var bar: Array = ["", "", "", "", "", ""]
var runes := {}                 # skill id -> rune index, -1 or missing = no rune
var passives: Array = []        # passive ids, up to Skills.passive_slots(level)
var cds := {}                   # skill id -> cooldown left
var buffs: Array = []           # {id, fx, t, len}
var fx := {}                    # buffs and passives summed (_sum_fx)
var attack_slot := 0            # the slot used on the clicked monster
var lunge := {}                 # leap or charge in progress
var combat_t := 9.0             # seconds since the hero last hit or was hit
var cheat_cd := 0.0
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
	bar = Skills.DEFAULT_BAR[c].duplicate()
	runes = {}
	passives = []
	cds = {}
	buffs = []
	recalc()
	hp = st.max_hp
	mp = Skills.RESOURCE[c].get("start", st.max_mp)


## Put skill id on hotbar slot i (it leaves any other slot it was on).
func set_slot(i: int, id: String) -> void:
	for k in bar.size():
		if bar[k] == id:
			bar[k] = ""
	bar[i] = id
	stats_changed.emit()


func set_rune(id: String, r: int) -> void:
	runes[id] = r
	stats_changed.emit()


func set_passive(i: int, id: String) -> void:
	passives = passives.filter(func(p): return p != id)
	while passives.size() <= i:
		passives.append("")
	passives[i] = id
	passives = passives.filter(func(p): return p != "")
	recalc()


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
	fx = _sum_fx()
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
	s.def = roundi((def + s.dex / 4) * (1.0 + fx.get("def", 0.0) / 100.0))
	var sh = equip.offhand if equip.offhand in active else null
	s.block = 0
	if sh != null:
		s.block = clampi(roundi((sh.block + m.block) * (s.dex - 15) / float(level * 2)), 0, 75)
	var c: Dictionary = CLASSES[cls]
	s.max_hp = roundi((c.life + (level - 1) * c.life_lvl + (s.vit - c.stats.vit) * c.life_vit + m.life) * (1.0 + fx.get("life", 0.0) / 100.0))
	var res: Dictionary = Skills.RESOURCE[cls]
	var mana: float = res.max + m.mana if res.has("max") else c.mana + (level - 1) * c.mana_lvl + (s.ene - c.stats.ene) * c.mana_ene + m.mana
	s.max_mp = roundi(mana * (1.0 + fx.get("rmax", 0.0) / 100.0))
	s.leech += fx.get("leech", 0.0)
	for e in ["fire", "cold", "lit", "pois"]:
		s["res_" + e] = mini(75, m["res_" + e] + m.res_all)
	var wspd: float = w.spd if w != null else 1.0
	s.atk_time = 0.6 * wspd / (1.0 + s.ias / 120.0) / (1.0 + fx.get("aspd", 0.0) / 100.0)
	s.speed = SPEED * (1.0 + s.frw * 1.5 / (s.frw + 150.0)) * (1.0 + fx.get("speed", 0.0) / 100.0)
	s.thorns += roundi((s.dmg_min + s.dmg_max) * 0.5 * fx.get("thorns", 0.0) / 100.0)
	# spell damage: grows with level and the +% spell damage on items
	var sp: float = 1.0 + s.spell / 100.0
	s.spell_dmg = [roundi((5 + level * 2) * sp), roundi((9 + level * 3) * sp)]
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
		# a newly learned skill goes onto the first empty hotbar slot
		for id in Skills.of_hero(cls):
			if Skills.SKILLS[id].lvl == level and not id in bar and bar.has(""):
				bar[bar.find("")] = id
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
	attack_slot = 0
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


# ---------- skills ----------

## Use the skill on hotbar slot i (0 = left click ... 5 = key 4) toward world point `at`;
## target is the monster under the cursor, if any. Returns true if the skill went off.
func use_slot(i: int, at: Vector2, target: Monster = null) -> bool:
	if i < 0 or i >= bar.size() or bar[i] == "":
		return false
	return use_skill(bar[i], at, target, i)


func use_skill(id: String, at: Vector2, target: Monster = null, slot := -1) -> bool:
	if dead or main.state != "play" or main.in_town():
		return false
	var s := Skills.resolve(id, runes.get(id, -1))
	if level < s.lvl or cds.get(id, 0.0) > 0.0 or cast_t > 0.0 or not lunge.is_empty():
		return false
	var cost := skill_cost(s)
	if mp < cost:
		main.no_mana()
		return false
	if s.has("life_cost") and hp <= st.max_hp * s.life_cost / 100.0 + 1.0:
		main.floater(wpos, "Not enough life", Color("ff7b7b"))
		return false
	var dir := at - wpos
	dir = dir.normalized() if dir.length() > 0.05 else face_vec.normalized()
	if s.kind == "melee":
		if target == null or target.dead:
			target = _melee_target(dir)
		if target == null:
			return false
		if target.wpos.distance_to(wpos) > 1.0 + target.radius:
			# walk up to it first; _process uses the skill when in reach
			command_attack(target)
			attack_slot = maxi(slot, 0)
			return false
		if atk_t > 0.0:
			return false
	if not _run_skill(s, at, dir, target):
		return false
	mp -= cost
	cds[id] = s.get("cd", 0.0) * fx.get("cdr", 1.0)
	return true


func skill_cost(s: Dictionary) -> float:
	return s.get("cost", 0) * fx.get("cost", 1.0)


## How close the hero must be to a target before an attacking skill is used on it.
func skill_reach(s: Dictionary) -> float:
	match s.kind:
		"melee": return 1.0
		"cone": return s.range * 0.85
		"beam": return s.length * 0.9
		"nova": return s.radius * 0.8
		"missile", "chain": return 8.0
		"blast", "cloud", "curse", "corpse": return 10.0
	return 99.0


## Skills that keep firing at a clicked monster, rather than going off once.
func skill_repeats(s: Dictionary) -> bool:
	return s.kind in ["melee", "cone", "beam", "missile", "chain", "nova"]


func _melee_target(dir: Vector2) -> Monster:
	var best: Monster = null
	var bd := INF
	for m in main.monsters:
		var v: Vector2 = m.wpos - wpos
		var dd := v.length()
		if dd <= 1.0 + m.radius and dd < bd and (dd < 0.5 or v.normalized().dot(dir) > 0.2):
			bd = dd
			best = m
	return best


func _run_skill(s: Dictionary, at: Vector2, dir: Vector2, target: Monster) -> bool:
	var col := elem_color(s.get("elem", "phys"))
	var spell_lock: float = 0.32 / (1.0 + fx.get("aspd", 0.0) / 100.0)
	path.clear()
	match s.kind:
		"melee":
			face(target.wpos - wpos)
			atk_t = st.atk_time * s.get("aspd", 1.0)
			swing = 0.25
			play_action("attack", maxf(0.3, atk_t * 0.85))
			Game.play("swing")
			var list: Array = [target]
			if s.get("arc", 0.0) > 0.0:
				main.add_ring(target.wpos, s.arc, 0.3, false, col)
				for m in main.monsters:
					if m != target and m.wpos.distance_to(target.wpos) <= s.arc + m.radius:
						list.append(m)
			_hit_list(list, s)
		"cone":
			face(dir)
			cast_t = spell_lock
			atk_t = spell_lock + 0.05
			play_action("cast", 0.35)
			Game.play("fire" if s.elem == "fire" else "swing")
			var half: float = s.angle * 0.5
			for k in 9:
				var a: float = -half + s.angle * k / 8.0
				main.burst(wpos + dir.rotated(a) * s.range * 0.75, col, 4, 1.6, 20.0, 0.35, 3.0)
			var list: Array = []
			for m in main.monsters:
				var v: Vector2 = m.wpos - wpos
				if v.length() <= s.range + m.radius and absf(dir.angle_to(v)) <= half + 0.15 and main.dungeon.los(wpos, m.wpos):
					list.append(m)
			_hit_list(list, s)
		"missile":
			face(dir)
			cast_t = spell_lock
			atk_t = spell_lock + 0.05
			play_action("cast", 0.35)
			Game.play("fire" if s.look in ["fire", "spark"] else "bolt")
			var n: int = s.get("count", 1)
			var gained := {"done": false}
			for k in n:
				var dk := dir if n == 1 else dir.rotated(s.spread * (float(k) / (n - 1) - 0.5))
				var on_hit := func(m: Monster):
					if _hit(m, s) and s.has("gen") and not gained.done:
						gained.done = true
						_gain(s.gen)
				var p: Projectile = preload("res://scenes/projectile.tscn").instantiate()
				p.setup_hero(main, s.look, wpos + dk * 0.4, dk * s.speed, on_hit, s.get("pierce", false), s.get("boom", 0.0))
				main.world.add_child(p)
		"chain":
			var first := target if target != null and target.wpos.distance_to(wpos) <= s.range else _nearest_to(at, 3.0, s.range)
			if first == null:
				first = _nearest_to(wpos + dir * 4.0, 4.5, s.range)
			if first == null:
				return false
			face(first.wpos - wpos)
			cast_t = spell_lock
			atk_t = spell_lock + 0.05
			play_action("cast", 0.35)
			Game.play("bolt")
			var pts: Array = [wpos]
			var hit_set: Array = []
			var cur: Monster = first
			for j in s.jumps + 1:
				hit_set.append(cur)
				pts.append(cur.wpos)
				var next: Monster = null
				var nd := 4.5
				for m in main.monsters:
					if not m in hit_set and m.wpos.distance_to(cur.wpos) < nd and main.dungeon.los(cur.wpos, m.wpos):
						nd = m.wpos.distance_to(cur.wpos)
						next = m
				if next == null:
					break
				cur = next
			SkillFx.make(main, "chain", pts, col, 0.3)
			_hit_list(hit_set, s)
		"beam":
			face(dir)
			cast_t = spell_lock + 0.1
			atk_t = cast_t + 0.05
			play_action("cast", 0.4)
			Game.play("fire")
			var end := wpos
			var step := 0.0
			while step < s.length:
				var nxt: Vector2 = wpos + dir * (step + 0.25)
				if not main.dungeon.open_air(nxt):
					break
				step += 0.25
				end = nxt
			SkillFx.make(main, "beam", [wpos + dir * 0.4, end], col, 0.3)
			var list: Array = []
			for m in main.monsters:
				if Geometry2D.get_closest_point_to_segment(m.wpos, wpos, end).distance_to(m.wpos) <= 0.55 + m.radius:
					list.append(m)
			_hit_list(list, s)
		"nova":
			cast_t = spell_lock
			atk_t = spell_lock + 0.05
			play_action("attack" if s.src == "weapon" else "cast", 0.4)
			_nova(s, wpos)
			if s.has("again"):
				get_tree().create_timer(s.again).timeout.connect(func():
					if not dead and main.state == "play":
						_nova(s, wpos))
			if s.has("self_heal"):
				_heal(s.self_heal)
		"blast":
			var p := _clamp_reach(at, 14.0)
			face(p - wpos)
			cast_t = spell_lock
			play_action("cast", 0.4)
			Game.play("fire")
			var n: int = s.get("count", 1)
			for k in n:
				var q := p if k == 0 else p + Vector2(randf_range(-1.8, 1.8), randf_range(-1.8, 1.8))
				var f := SkillFx.make(main, "blast", [q], col, s.delay + k * 0.22, s.radius)
				f.done = func():
					Game.play("boom")
					main.flash(q)
					main.shake(6.0)
					main.burst(q, col, 24, 3.2, 20.0, 0.6, 3.5)
					main.add_ring(q, s.radius, 0.4, false, col)
					var list: Array = []
					for m in main.monsters:
						if m.wpos.distance_to(q) <= s.radius + m.radius:
							list.append(m)
					_hit_list(list, s)
		"cloud":
			var p := _clamp_reach(at, 14.0)
			face(p - wpos)
			cast_t = spell_lock
			play_action("cast", 0.4)
			Game.play("nova")
			var per := maxi(1, roundi(_dmg(s) / (s.dur * 2.0)))
			var f := SkillFx.make(main, "cloud", [p], col, s.dur, s.radius)
			f.tick = func():
				for m in main.monsters.duplicate():
					if m.wpos.distance_to(p) <= s.radius + m.radius:
						_hit(m, s, per)
		"leap", "charge":
			var to := wpos
			if s.kind == "leap":
				to = main.dungeon.nearest_floor(wpos + dir * minf(s.dist, maxf(1.0, (at - wpos).length())))
				if to == Vector2.INF:
					return false
			else:
				var step := 0.0
				while step < s.dist and main.dungeon.is_free(wpos + dir * (step + 0.25), radius):
					step += 0.25
				if step < 0.75:
					return false
				to = wpos + dir * step
			face(to - wpos)
			target_monster = null
			lunge = {"s": s, "from": wpos, "to": to, "t": 0.0, "len": 0.42 if s.kind == "leap" else maxf(0.12, wpos.distance_to(to) / 20.0), "hit": []}
			cast_t = lunge.len + 0.05
			play_action("attack" if s.kind == "charge" else "cast", lunge.len + 0.1)
			Game.play("swing")
		"teleport":
			var to: Vector2 = main.dungeon.nearest_floor(wpos + dir * minf(s.dist, maxf(1.0, (at - wpos).length())))
			if to == Vector2.INF or not main.dungeon.is_free(to, radius):
				return false
			Game.play("nova")
			main.burst(wpos, col, 20, 2.5, 20.0, 0.5, 3.0)
			if s.get("pct", 0) > 0:
				main.flash(wpos)
				main.add_ring(wpos, s.boom, 0.35, false, col)
				var list: Array = []
				for m in main.monsters:
					if m.wpos.distance_to(wpos) <= s.boom + m.radius:
						list.append(m)
				_hit_list(list, s)
			wpos = to
			target_monster = null
			sync_position()
			main.burst(wpos, col, 20, 2.5, 20.0, 0.5, 3.0)
			_self_buff(s)
		"buff":
			if s.has("life_cost"):
				hp -= st.max_hp * s.life_cost / 100.0
				main.burst(wpos, Color("8a0b0b"), 16, 2.0, 20.0, 0.6, 3.0)
			add_buff(s.id, s.fx, s.dur)
			if s.get("fill", false):
				mp = st.max_mp
			cast_t = spell_lock
			play_action("cast", 0.4)
			Game.play("level")
			main.burst(wpos, Skills.RESOURCE[cls].color, 24, 2.0, 30.0, 0.8, 3.0)
		"shout":
			add_buff(s.id, s.fx, s.dur)
			cast_t = spell_lock
			play_action("cast", 0.4)
			Game.play("nova")
			main.add_ring(wpos, s.radius, 0.5, false, Color(1.0, 0.8, 0.4))
			main.shake(4.0)
			for m in main.monsters:
				if m.wpos.distance_to(wpos) <= s.radius and main.dungeon.los(wpos, m.wpos):
					m.afflict(s.debuff, s.dur)
					m.wake()
		"curse":
			var p := _clamp_reach(at, 14.0)
			face(p - wpos)
			cast_t = spell_lock
			play_action("cast", 0.4)
			Game.play("nova")
			main.add_ring(p, s.radius, 0.6, false, Color(0.7, 0.35, 1.0))
			main.burst(p, Color(0.55, 0.25, 0.8), 18, 2.0, 10.0, 0.8, 3.0)
			var rot := 0.0
			if s.debuff.has("dot"):
				var ds := s.duplicate()
				ds.pct = s.debuff.dot
				ds.src = "spell"
				rot = _dmg(ds)
			for m in main.monsters:
				if m.wpos.distance_to(p) <= s.radius + m.radius:
					m.afflict(s.debuff, s.dur)
					m.wake()
					if rot > 0.0:
						m.add_dot(rot, s.dur, elem_color("pois"))
		"summon":
			if not _summon(s, at):
				return false
			cast_t = spell_lock
			play_action("cast", 0.4)
			Game.play("nova")
		"corpse":
			var bodies: Array = main.corpses_near(_clamp_reach(at, 14.0), s.radius, s.corpses)
			if bodies.is_empty():
				main.floater(wpos, "No corpses there", Color("bbbbbb"))
				return false
			face(at - wpos)
			cast_t = spell_lock
			play_action("cast", 0.4)
			Game.play("boom")
			main.shake(5.0)
			for c in bodies:
				var q: Vector2 = c.wpos
				var dmg := _dmg(s) + roundi(c.max_hp / 10.0)
				main.burst(q, Color(c.d.blood).lightened(0.1), 26, 3.4, 12.0, 0.7, 3.5)
				main.add_ring(q, s.boom, 0.35, false, col)
				for m in main.monsters.duplicate():
					if m.wpos.distance_to(q) <= s.boom + m.radius:
						_hit(m, s, dmg)
				main.remove_corpse(c)
				if s.has("self_heal_per"):
					_heal(s.self_heal_per)
	return true


func _nova(s: Dictionary, at: Vector2) -> void:
	var col := elem_color(s.get("elem", "phys"))
	Game.play("boom" if s.get("elem", "phys") == "fire" else "nova")
	main.add_ring(at, s.radius, 0.45, false, col)
	for k in 16:
		var a := TAU * k / 16.0
		main.burst(at + Vector2(cos(a), sin(a)) * s.radius * 0.7, col, 3, 1.8, 16.0, 0.4, 3.0)
	if s.get("elem", "phys") == "fire":
		main.flash(at)
	main.shake(3.0 + s.radius)
	var list: Array = []
	for m in main.monsters:
		if m.wpos.distance_to(at) <= s.radius + m.radius and main.dungeon.los(at, m.wpos):
			list.append(m)
	_hit_list(list, s)


func _summon(s: Dictionary, at: Vector2) -> bool:
	var mine: Array = main.minions.filter(func(m): return m.skill_id == s.id)
	var spots: Array = []
	if s.has("corpse"):
		var bodies: Array = main.corpses_near(_clamp_reach(at, 14.0), 4.0, s.corpse)
		if bodies.is_empty():
			bodies = main.corpses_near(wpos, 6.0, s.corpse)
		if bodies.is_empty():
			main.floater(wpos, "No corpses nearby", Color("bbbbbb"))
			return false
		for c in bodies:
			spots.append(c.wpos)
			main.remove_corpse(c)
	else:
		var n: int = s.count
		if s.dur == 0:
			n = mini(n, s.max - mine.size())
			if n <= 0:
				for m in mine:
					m.hp = m.max_hp
				main.floater(wpos, "Already at full strength", Color("bbbbbb"))
				return false
		for k in n:
			spots.append(main.dungeon.spot_near(wpos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)), 0.4))
	for q in spots:
		var m := Minion.new()
		m.main = main
		m.dungeon = main.dungeon
		m.setup(s, q, level, fx.get("minion", 0.0))
		main.world.add_child(m)
		main.minions.append(m)
		mine.append(m)
		main.burst(q, Color(0.45, 0.95, 0.6), 14, 1.6, 8.0, 0.6, 3.0)
	while mine.size() > s.max:
		mine.pop_front().die()
	return true


func _self_buff(s: Dictionary) -> void:
	if s.has("self"):
		add_buff(s.id + "_after", s.self.fx, s.self.dur)


## A buff on the hero (fx as in Skills); a newer one with the same id replaces the old.
func add_buff(id: String, effects: Dictionary, dur: float) -> void:
	buffs = buffs.filter(func(b): return b.id != id)
	buffs.append({"id": id, "fx": effects, "t": dur, "len": dur})
	recalc()


## Sum of the hero's buffs and passives. Multipliers (taken, gen, cost, cdr, decay, low_life)
## multiply; everything else adds.
func _sum_fx() -> Dictionary:
	var out := {}
	var parts: Array = []
	for b in buffs:
		parts.append(b.fx)
	for id in passives:
		parts.append(Skills.PASSIVES[id])
	for p in parts:
		for k in p:
			if k in ["name", "lvl", "desc", "hero"]:
				continue
			if k in ["taken", "gen", "cost", "cdr", "decay", "low_life"]:
				out[k] = out.get(k, 1.0) * p[k]
			else:
				out[k] = out.get(k, 0.0) + p[k]
	return out


func _dmg(s: Dictionary) -> int:
	var base: Array = [st.dmg_min, st.dmg_max] if s.get("src", "spell") == "weapon" else st.spell_dmg
	var v: float = randi_range(base[0], base[1]) * s.get("pct", 100) / 100.0 * (1.0 + fx.get("dmg", 0.0) / 100.0)
	return maxi(1, roundi(v))


## One hit of skill s on monster m; dmg < 0 rolls the skill's damage. Weapon skills can miss
## (Diablo II to-hit) and crit. Returns true if it hit.
func _hit(m: Monster, s: Dictionary, dmg := -1) -> bool:
	if m == null or m.dead:
		return false
	var weapon: bool = s.get("src", "spell") == "weapon"
	if weapon and randf() > Game.hit_chance(st.ar, m.def, level, m.mlvl):
		main.floater(m.wpos, "miss", Color("9a9080"))
		m.wake()
		return false
	if dmg < 0:
		dmg = _dmg(s)
	var elem: String = s.get("elem", "phys")
	var col := elem_color(elem)
	if weapon and randf() < 0.08:
		dmg *= 2
		col = Color("ffd34a")
		main.shake(3.0)
	if weapon:
		Game.play("hit")
		main.burst(m.wpos, Color(m.d.blood).lightened(0.15), 6, 1.8, 18.0 * m.size, 0.5, 2.5)
	var dealt: int = main.damage_monster(m, dmg, col)
	combat_t = 0.0
	if not m.dead:
		var deb := {}
		for k in ["slow", "stun", "fear"]:
			if s.has(k):
				deb[k] = s[k]
		if s.has("vuln"):
			deb.vuln = s.vuln
		if not deb.is_empty():
			m.afflict(deb, 4.0 if s.has("vuln") else s.get("slow", 0.0))
		if s.has("knock") and not m.is_boss:
			var away: Vector2 = (m.wpos - wpos).normalized()
			for k in 4:
				m.move_by(away * s.knock / 4.0)
		var burn: float = s.get("burn", 0.0) + (fx.get("burn", 0.0) if elem == "fire" else 0.0)
		if burn > 0.0 and dealt * burn / 100.0 >= 1.0:
			m.add_dot(dealt * burn / 100.0, 3.0, col)
	if s.has("heal"):
		_heal(s.heal)
	var leech: float = s.get("leech", 0.0) + (st.leech if weapon else fx.get("leech", 0.0))
	if leech > 0.0:
		hp = minf(st.max_hp, hp + dealt * leech / 100.0)
	if weapon and st.mleech > 0:
		mp = minf(st.max_mp, mp + dealt * st.mleech / 100.0)
	return true


## Hit every monster in the list; gives the skill's resource once if anything was hit
## (Overrun's Rallying rune gives it per foe).
func _hit_list(list: Array, s: Dictionary) -> int:
	var n := 0
	for m in list:
		if _hit(m, s):
			n += 1
	if n > 0 and s.has("gen"):
		_gain(s.gen * (n if s.kind == "charge" else 1))
	return n


func _gain(n: float) -> void:
	mp = minf(st.max_mp, mp + n * fx.get("gen", 1.0))


func _heal(pct: float) -> void:
	hp = minf(st.max_hp, hp + st.max_hp * pct / 100.0)


func _clamp_reach(at: Vector2, r: float) -> Vector2:
	return wpos + (at - wpos).limit_length(r)


func _nearest_to(at: Vector2, within: float, reach: float) -> Monster:
	var best: Monster = null
	var bd := within
	for m in main.monsters:
		var dd: float = m.wpos.distance_to(at)
		if dd < bd and m.wpos.distance_to(wpos) <= reach and main.dungeon.los(wpos, m.wpos):
			bd = dd
			best = m
	return best


static func elem_color(elem: String) -> Color:
	return {"fire": Color("ff9a3a"), "cold": Color("8ec8ff"), "lit": Color("fff07a"), "pois": Color("7adf5a")}.get(elem, Color("e8e0d0"))


## Leap and charge: move along the jump, hitting what is in the way (charge) or where it lands.
func _update_lunge(dt: float) -> void:
	var s: Dictionary = lunge.s
	lunge.t += dt
	var p := minf(1.0, lunge.t / lunge.len)
	wpos = lunge.from.lerp(lunge.to, p)
	if s.kind == "leap":
		body.position.y = -sin(p * PI) * 46.0
	else:
		main.burst(wpos, Color(0.6, 0.55, 0.45), 2, 1.0, 4.0, 0.4, 2.5)
		for m in main.monsters.duplicate():
			if not m in lunge.hit and m.wpos.distance_to(wpos) <= 0.8 + m.radius:
				lunge.hit.append(m)
				_hit_list([m], s)
	sync_position()
	if p >= 1.0:
		body.position.y = 0.0
		if s.kind == "leap":
			_nova(s, wpos)
			main.burst(wpos, Color(0.55, 0.5, 0.4), 20, 3.0, 4.0, 0.6, 3.0)
		_self_buff(s)
		lunge = {}


## A monster died: Soul Harvest feeds on deaths nearby.
func on_kill(m: Monster) -> void:
	if fx.get("soul_kill", 0.0) > 0.0 and m.wpos.distance_to(wpos) < 10.0:
		_gain(fx.soul_kill)


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
	amount = roundi(amount * fx.get("taken", 1.0) * (fx.get("low_life", 1.0) if hp < st.max_hp * 0.3 else 1.0))
	combat_t = 0.0
	hp -= amount
	hit_flash = 0.15
	main.hurt_flash = minf(1.0, main.hurt_flash + 0.25 + amount / float(st.max_hp) * 2.0)
	main.shake(2.0 + amount / float(st.max_hp) * 20.0)
	Game.play("hurt")
	main.floater(wpos, str(amount), col)
	main.burst(wpos, Color("6a0b0b"), 5, 1.5, 20.0, 0.4, 2.0)
	if attacker != null and st.thorns > 0 and is_instance_valid(attacker) and not attacker.dead:
		main.damage_monster(attacker, st.thorns, Color("c9b99a"))
	if hp <= 0 and fx.get("cheat_death", 0.0) > 0.0 and cheat_cd <= 0.0:
		hp = st.max_hp * 0.5
		cheat_cd = fx.cheat_death
		main.floater(wpos, "Phoenix Heart", Color("ffb347"))
		main.flash(wpos)
		main.burst(wpos, Color("ff9a3a"), 30, 3.0, 30.0, 0.8, 3.0)
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
	combat_t += dt
	cheat_cd -= dt
	for k in cds:
		cds[k] = maxf(0.0, cds[k] - dt)
	if not buffs.is_empty():
		var had := buffs.size()
		for b in buffs:
			b.t -= dt
		buffs = buffs.filter(func(b): return b.t > 0.0)
		if buffs.size() != had:
			recalc()
	if not lunge.is_empty():
		_update_lunge(dt)
		dungeon.mark_seen(wpos)
		queue_redraw()
		return
	if poison_t > 0.0:
		poison_t -= dt
		hp -= poison_dps * dt
		if hp <= 0.0:
			hp = 0
			main.player_died()
			return
	hp = minf(st.max_hp, hp + (0.4 + st.regen * 0.5 + st.max_hp * fx.get("regen", 0.0) / 100.0) * dt)
	var res: Dictionary = Skills.RESOURCE[cls]
	if res.has("regen"):
		if combat_t > 3.0:
			mp += res.regen * fx.get("decay", 1.0) * dt     # Ferocity fades out of combat
	else:
		mp += st.max_mp * res.regen_frac * (1.0 + fx.get("rfast", 0.0) / 100.0) * dt
	mp = clampf(mp + fx.get("rregen", 0.0) * dt, 0.0, st.max_mp)

	if target_monster != null:
		var m := target_monster
		if not is_instance_valid(m) or m.dead:
			target_monster = null
		else:
			var d := m.wpos.distance_to(wpos)
			var sk := Skills.resolve(bar[attack_slot], runes.get(bar[attack_slot], -1)) if bar[attack_slot] != "" else {}
			var reach: float = 1.0 + m.radius if sk.is_empty() or sk.kind == "melee" else skill_reach(sk)
			if d <= reach and (sk.is_empty() or sk.kind == "melee" or dungeon.los(wpos, m.wpos)):
				path.clear()
				face(m.wpos - wpos)
				if atk_t <= 0.0 and cast_t <= 0.0:
					if sk.is_empty():
						_attack(m)
					elif not use_slot(attack_slot, m.wpos, m):
						if attack_slot != 0:
							attack_slot = 0      # out of resource or cooling down: back to the left-click skill
						elif sk.kind == "melee" and mp < skill_cost(sk):
							_attack(m)
						elif not skill_repeats(sk):
							target_monster = null
					elif not skill_repeats(sk):
						target_monster = null
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
