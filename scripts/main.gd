extends Node2D
## Main: owns the run (the town and the eight areas of Act I, the hero, monsters, loot and
## the ways between areas), routes mouse input, and ties the map, effects and HUD together.

const PlayerScene := preload("res://scenes/player.tscn")
const MonsterScene := preload("res://scenes/monster.tscn")
const ProjectileScene := preload("res://scenes/projectile.tscn")

const NPCS := {
	"elder": {"name": "Elder Maelis", "tint": Color(0.75, 0.72, 0.9)},
	"healer": {"name": "Sister Wren", "tint": Color(0.95, 0.75, 0.7)},
	"vendor": {"name": "Garrick the Smith", "tint": Color(0.85, 0.7, 0.5)},
}
const ELDER_LINES := [
	"The lamps of Vell went dark the night the abbey fell silent. Go north through the gate, across the Ashen Moor. Grisk the Gnawer hunts there.",
	"The Gallows Fields lie past the moor. Hangman Orrel still keeps his rope. Touch every waypoint you find; they will bring you home.",
	"Beneath the fields is Hollowroot Cave. Mother Cinder breeds her spitters in the deep roots. Carry draughts against her bile.",
	"The cave opens into the Sunken Ossuary, where Ossric the Unburied walks. Bones remember. Strike them hard.",
	"Beyond the ossuary, the Witherwood. Old Thornhide is older than this town. Watch for the archers in the trees.",
	"The Ruins of Calder were our sister town. The Pale Huntress hunts there now. She will not miss twice.",
	"The Abbey of Vell. The Hollow Abbot reads his black prayers there. Lightning answers him; seek things that resist it.",
	"Below the abbey lies the Lampless Deep, and the Lampless King. End him, and the lamps of Vell may burn again.",
	"The Lampless King is dead. The lamps of Vell are lit again. Rest, wanderer.",
]

@onready var dungeon: Dungeon = $Dungeon
@onready var floor_fx: FloorFx = $FloorFx
@onready var world: Node2D = $World
@onready var particles: Particles = $Particles
@onready var camera: Camera2D = $Camera2D
@onready var overlay: Overlay = $Overlay/Labels
@onready var darkness: CanvasModulate = $Darkness
@onready var hud = $HUD

var state := "title"      # title | play | dead
var area := 0
var player: Player
var monsters: Array = []
var drops: Array = []
var objects: Array = []   # Interactables in this area
var boss: Monster = null
var exit_portal: Interactable = null
var hovered_monster: Monster = null
var hovered_drop = null
var hovered_obj = null
var mouse_held := false
var hold_timer := 0.0
var no_mana_timer := 0.0
var ghosted: Array = []
var flashes: Array = []   # [node, life]
var braziers: Array = []
var shake_amount := 0.0
var hurt_flash := 0.0
var post: ShaderMaterial
var flat: Node2D          # flat things on the ground (waypoints, stairs down), under the world

var area_seeds: Array = []
var area_state: Array = []    # per area: visited, waypoint, killed {uid: true}, seen, drops
var tp = null                 # the open town portal: {"area": i, "wpos": Vector2}
var stock := {"vendor": [], "healer": []}
var bosses_killed := 0


func _ready() -> void:
	floor_fx.main = self
	overlay.main = self
	flat = Node2D.new()
	add_child(flat)
	move_child(flat, floor_fx.get_index() + 1)
	_build_post()
	_build_ambient()
	new_game()
	hud.setup(self)
	if "--autotest" in OS.get_cmdline_user_args():
		var t := preload("res://scripts/autotest.gd").new()
		t.main = self
		add_child(t)


func new_game() -> void:
	if player:
		player.queue_free()
	area_seeds.clear()
	area_state.clear()
	for i in Act.count():
		area_seeds.append(randi())
		area_state.append({"visited": false, "waypoint": i == 0, "killed": {}, "seen": PackedByteArray(), "drops": []})
	tp = null
	bosses_killed = 0
	player = PlayerScene.instantiate()
	player.main = self
	player.dungeon = dungeon
	world.add_child(player)
	player.equip.mainhand = Items.make("weapon", "normal", 1)
	player.equip.offhand = Items.make("shield", "normal", 1)
	player.gold = 120
	player.recalc()
	player.hp = player.st.max_hp
	player.mp = player.st.max_mp
	player.leveled_up.connect(_on_level_up)
	load_area(0, "start")


func in_town() -> bool:
	return area == 0


# ---------- areas ----------

func _save_area() -> void:
	if area_state.is_empty() or dungeon.seen.is_empty():
		return
	area_state[area].seen = dungeon.seen.duplicate()
	area_state[area].drops = drops.duplicate()


## Build area i and put the hero in it. arrive: start (from the previous area), back (from
## the next one), waypoint, tp (through the town portal) or town_tp (home through the portal).
func load_area(i: int, arrive: String) -> void:
	_save_area()
	for m in monsters:
		m.queue_free()
	monsters.clear()
	for o in objects:
		o.queue_free()
	objects.clear()
	for b in braziers:
		b.queue_free()
	braziers.clear()
	floor_fx.decals.clear()
	floor_fx.rings.clear()
	for c in world.get_children():
		if c is Projectile:
			c.queue_free()
	hovered_monster = null
	hovered_drop = null
	hovered_obj = null
	ghosted.clear()
	boss = null
	exit_portal = null
	dungeon.clear_nodes()
	area = i
	AreaGen.generate(dungeon, i, area_seeds[i])
	dungeon.finish(world)
	var stt: Dictionary = area_state[i]
	if stt.seen.size() == dungeon.W * dungeon.H:
		dungeon.seen = stt.seen
		for k in dungeon.blockers:
			if dungeon.seen[dungeon.idx(k.x, k.y)] == 1:
				dungeon.blockers[k].visible = true
	stt.visited = true
	drops = stt.drops
	darkness.color = dungeon.biome.ambient
	_place_objects()
	if not in_town():
		_place_braziers()
		_populate()
	else:
		_restock()
	var keep := ["townsfolk"]
	for m in monsters:
		keep.append(m.kind)
	Game.trim_sheets(keep)
	match arrive:
		"start":
			player.wpos = dungeon.start
		"back":
			var p := dungeon.nearest_floor(dungeon.exit + (dungeon.start - dungeon.exit).normalized() * 2.5)
			player.wpos = p if p != Vector2.INF else dungeon.spot_near(dungeon.exit, 2.0)
		"waypoint":
			player.wpos = dungeon.spot_near(dungeon.waypoint + Vector2(1.6, 1.6), 0.6)
		"tp":
			player.wpos = dungeon.spot_near(tp.wpos + Vector2(0.8, 0.8), 0.4)
		"town_tp":
			player.wpos = dungeon.spot_near(dungeon.waypoint + Vector2(0, 2.5), 0.6)
	player.path.clear()
	player.target_monster = null
	player.target_drop = null
	player.target_obj = null
	player.sync_position()
	dungeon.mark_seen(player.wpos)
	camera.position = player.position
	camera.reset_smoothing()
	hud.refresh()
	if state == "play":
		_announce()


func _announce() -> void:
	var a := Act.area(area)
	if in_town():
		show_msg(a.name, "Act I · the last lit town", 3.5)
	else:
		var kind := "Wilderness" if a.kind == "open" else "Dungeon"
		show_msg(a.name, "Act I · %s · area %d of %d" % [kind, area, Act.count() - 1], 3.5)


func _add_object(o: Interactable) -> Interactable:
	o.main = self
	o.dungeon = dungeon
	if o.is_flat():
		flat.add_child(o)
	else:
		world.add_child(o)
	objects.append(o)
	return o


func _place_objects() -> void:
	var stt: Dictionary = area_state[area]
	var wp := Interactable.new()
	wp.setup_waypoint(dungeon.waypoint, stt.waypoint)
	_add_object(wp)
	if area < Act.count() - 1:
		var e := Interactable.new()
		e.setup_portal(dungeon.exit, dungeon.exit_style, area + 1, true)
		e.sealed = not in_town() and not stt.killed.has("boss")
		exit_portal = _add_object(e)
	if area > 0:
		var b := Interactable.new()
		b.setup_portal(dungeon.entrance, dungeon.entrance_style, area - 1, false)
		_add_object(b)
	if tp != null:
		var t := Interactable.new()
		if in_town():
			t.setup_tportal(dungeon.waypoint + Vector2(0, 2.0), tp.area)
			_add_object(t)
		elif tp.area == area:
			t.setup_tportal(tp.wpos, 0)
			t.label = "Town Portal to Vell's Hollow"
			_add_object(t)
	if in_town():
		for role in NPCS:
			var n := Interactable.new()
			n.setup_npc(dungeon.spots[role], role, NPCS[role].name, NPCS[role].tint)
			_add_object(n)
		var fire := Brazier.new()
		fire.bonfire = true
		fire.place(dungeon.spots.fire)
		world.add_child(fire)
		braziers.append(fire)


func _place_braziers() -> void:
	if dungeon.outdoor:
		# a campfire by the waypoint, and lamps at the way on
		var c := Brazier.new()
		c.place(dungeon.spot_near(dungeon.waypoint + Vector2(-2.5, 1.5), 0.6))
		world.add_child(c)
		braziers.append(c)
		return
	var spots: Array = [dungeon.start + Vector2(1.5, -1.5), dungeon.boss_spot + Vector2(2, 2), dungeon.exit + Vector2(-1.5, 1.5)]
	for p in dungeon.pack_spots:
		if randf() < 0.5:
			spots.append(p + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
	for p in spots:
		var q := dungeon.spot_near(p, 1.0, 0.45)
		if not dungeon.is_free(q, 0.45):
			continue
		var b := Brazier.new()
		b.place(q)
		b.visible = false
		world.add_child(b)
		braziers.append(b)


## Packs at the pack spots; a few of them are led by unique sub-bosses. The area boss waits
## near the way on with a large escort. Uniques and bosses stay dead once killed.
func _populate() -> void:
	var a := Act.area(area)
	var r: int = a.rank
	var killed: Dictionary = area_state[area].killed
	var spots: Array = dungeon.pack_spots.duplicate()
	var uniques := randi_range(2, 4)
	for k in spots.size():
		var p: Vector2 = spots[k]
		var type: String = a.types.pick_random()
		if k < uniques:
			var uid := "u%d" % k
			if killed.has(uid):
				continue
			var lead := spawn_monster(type, p, r + 2, "unique")
			lead.uid = uid
			lead.display_name = Act.unique_name()
			for n in randi_range(3, 5):
				var mm := spawn_monster(type, dungeon.spot_near(p, 2.0), r + 1, "minion")
				mm.leader = lead
		else:
			var big: bool = type in ["brute", "warden", "thornback"]
			var n := randi_range(2, 3) if big else (randi_range(2, 4) if Monster.TYPES[type].has("shot") else randi_range(3, 6))
			for j in n:
				var mr := r
				var roll := randf()
				if roll < 0.03:
					mr += 2
				elif roll < 0.13:
					mr += 1
				spawn_monster(type, dungeon.spot_near(p, 2.2), mr, "normal")
	if not killed.has("boss"):
		var bp := dungeon.boss_spot
		boss = spawn_monster(a.boss.type, bp, r + 4, "boss")
		boss.uid = "boss"
		boss.display_name = a.boss.name
		for n in randi_range(5, 7):
			var mm := spawn_monster(a.boss.type if n % 2 == 0 else a.types.pick_random(), dungeon.spot_near(bp, 2.8), r + 1, "minion")
			mm.leader = boss


func spawn_monster(type: String, at: Vector2, rank: int, role := "normal") -> Monster:
	var m: Monster = MonsterScene.instantiate()
	m.main = self
	m.dungeon = dungeon
	var r: float = Monster.TYPES[type].r
	if not dungeon.is_free(at, r):
		at = dungeon.spot_near(at, 1.5, r)
	m.setup(type, at, rank, role)
	world.add_child(m)
	monsters.append(m)
	return m


func start_game() -> void:
	state = "play"
	show_msg("Vell's Hollow", "Speak with Elder Maelis, then take the north gate onto the Ashen Moor.", 5.0)


# ---------- using things ----------

func use_object(o: Interactable) -> void:
	match o.kind:
		"portal":
			if o.sealed:
				show_msg("The way is sealed", "Slay %s to break the seal." % Act.area(area).boss.name, 2.5)
				return
			Game.play("pick")
			load_area(o.target_area, "start" if o.forward else "back")
		"tportal":
			Game.play("nova")
			if in_town():
				var back: int = tp.area
				load_area(back, "tp")
				tp = null
				for t in objects:
					if t.kind == "tportal":
						t.queue_free()
						objects.erase(t)
						break
			else:
				load_area(0, "town_tp")
		"waypoint":
			_activate_waypoint(o)
			hud.show_waypoints()
		"npc":
			match o.role:
				"elder":
					hud.show_dialog(o.label, ELDER_LINES[mini(bosses_killed, ELDER_LINES.size() - 1)])
				"healer":
					if player.hp < player.st.max_hp or player.mp < player.st.max_mp or player.poison_t > 0.0:
						player.hp = player.st.max_hp
						player.mp = player.st.max_mp
						player.poison_t = 0.0
						burst(player.wpos, Color("ffd38a"), 20, 1.4, 30.0, 0.8, 2.0)
						Game.play("level")
						floater(player.wpos, "Healed", Color("ffd38a"))
					hud.open_trade("healer", o.label)
				"vendor":
					hud.open_trade("vendor", o.label)


func _activate_waypoint(o: Interactable) -> void:
	if o.active:
		return
	o.active = true
	area_state[area].waypoint = true
	Game.play("level")
	floater(player.wpos, "Waypoint activated", Color("8ec8ff"))


func waypoint_travel(i: int) -> void:
	if not area_state[i].waypoint:
		return
	hud.close_panels()
	Game.play("nova")
	if i == area:
		return
	load_area(i, "waypoint")


func open_town_portal() -> void:
	if in_town() or state != "play" or player.dead:
		return
	for t in objects:
		if t.kind == "tportal":
			t.queue_free()
			objects.erase(t)
			break
	var at := dungeon.spot_near(player.wpos + Vector2(-1.2, -1.2), 0.5, 0.4)
	tp = {"area": area, "wpos": at}
	var o := Interactable.new()
	o.setup_tportal(at, 0)
	o.label = "Town Portal to Vell's Hollow"
	_add_object(o)
	Game.play("nova")
	burst(at, Color("8ec8ff"), 20, 1.6, 30.0, 0.7, 2.5)


# ---------- the town's traders ----------

func _restock() -> void:
	var lvl := maxi(1, player.level + 1)
	var v: Array = []
	for k in 14:
		var type: String = ["weapon", "weapon", "weapon", "shield", "armor", "armor", "helm", "gloves", "belt", "boots"].pick_random()
		v.append(Items.make(type, "magic" if randf() < 0.35 else "normal", lvl))
	stock.vendor = _arrange(v)
	var h: Array = [_potion("hp"), _potion("mp")]
	for k in 6:
		h.append(Items.make(["ring", "amulet", "charm", "charm"].pick_random(), "magic", lvl))
	stock.healer = _arrange(h)


func _potion(kind: String) -> Dictionary:
	return {"type": "potion", "potion": kind, "name": "Healing Draught" if kind == "hp" else "Mana Draught", "rarity": "normal",
		"w": 1, "h": 1, "art": "potion_" + kind, "tint": Color("d0282c") if kind == "hp" else Color("3050e0"), "seed": 1,
		"value": 25, "mods": {}}


## Lay items out in a 10 x 10 trade grid, biggest first.
func _arrange(items: Array) -> Array:
	items.sort_custom(func(a, b): return a.w * a.h > b.w * b.h)
	var out: Array = []
	for it in items:
		var placed := false
		for y in 10:
			for x in 10:
				if placed:
					break
				if x + it.w > 10 or y + it.h > 10:
					continue
				var r := Rect2i(x, y, it.w, it.h)
				var free := true
				for o in out:
					if r.intersects(Rect2i(o.gx, o.gy, o.w, o.h)):
						free = false
						break
				if free:
					it.gx = x
					it.gy = y
					out.append(it)
					placed = true
	return out


func buy_price(it: Dictionary) -> int:
	return 25 if it.type == "potion" else it.value * 3


func buy(role: String, it: Dictionary) -> void:
	var price := buy_price(it)
	if player.gold < price:
		floater(player.wpos, "Not enough gold", Color("bbbbbb"))
		return
	if it.type == "potion":
		if player.belt[it.potion] >= player.st.belt_cap:
			floater(player.wpos, "Your belt is full", Color("bbbbbb"))
			return
		player.belt[it.potion] += 1
	else:
		var copy: Dictionary = it.duplicate(true)
		if not player.auto_place(copy):
			floater(player.wpos, "No room in the inventory", Color("bbbbbb"))
			return
		stock[role].erase(it)
	player.gold -= price
	Game.play("coin")
	hud.refresh()


func sell(it: Dictionary) -> void:
	player.remove_from_grid(it)
	player.gold += it.value
	Game.play("coin")
	hud.refresh()


# ---------- services used by the hero, monsters and projectiles ----------

func floater(at: Vector2, text: String, color: Color) -> void:
	overlay.add_floater(at, text, color)


func burst(at: Vector2, color: Color, n: int, speed := 2.5, z := 14.0, life := 0.6, size := 2.5) -> void:
	particles.burst(at, color, n, speed, z, life, size)


func add_ring(at: Vector2, max_radius: float, life: float, click_mark: bool) -> void:
	floor_fx.rings.append([at, max_radius, life, life, click_mark])


func flash(at: Vector2) -> void:
	var n := Node2D.new()
	n.position = Game.iso(at)
	add_child(n)
	Game.make_light_pair(n, 520.0, Color(1.0, 0.7, 0.4), 1.3, Vector2(0, -4))
	flashes.append([n, 0.3])
	# a one-shot fire blast
	var p := Game.make_fire(45, 22.0, Game.FIRE_COLORS, 0.5, 40.0)
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 130.0
	p.damping_min = 120.0
	p.damping_max = 200.0
	p.position = Vector2(0, -18)
	p.emitting = true
	n.add_child(p)


func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)


## Freeze the action for a moment so heavy hits land.
func hit_stop(duration: float) -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func no_mana() -> void:
	if no_mana_timer <= 0.0:
		floater(player.wpos, "Not enough mana", Color("8ea4ff"))
		no_mana_timer = 1.0


func spawn_shot(src, kind: String, at: Vector2, vel: Vector2, dmg: Array, elem: String) -> void:
	var p: Projectile = ProjectileScene.instantiate()
	p.setup(self, src, kind, at, vel, dmg, elem)
	world.add_child(p)


func damage_monster(m: Monster, dmg: int, color: Color) -> void:
	if m.dead:
		return
	m.hp -= dmg
	m.hit = 0.12
	if not m.aggro:
		m.wake()
	floater(m.wpos, str(dmg), color)
	if m.hp <= 0:
		kill_monster(m)


func kill_monster(m: Monster) -> void:
	if m.dead:
		return
	m.dead = true
	Game.play("kill")
	var blood := Color(m.d.blood)
	burst(m.wpos, blood, 18, 2.2, 16.0 * m.size, 0.7, 3.0)
	floor_fx.add_decal(m.wpos, blood, 0.35 * m.size + randf() * 0.2)
	monsters.erase(m)
	m.die()
	shake(3.0 if not m.is_boss else 12.0)
	if m.is_boss or m.champion:
		hit_stop(0.12 if m.is_boss else 0.05)
	if "fire" in m.mods:
		# fire enchanted monsters burst when they die
		flash(m.wpos)
		if m.wpos.distance_to(player.wpos) < 2.0:
			player.take_hit(randi_range(m.dmg[0], m.dmg[1]), "fire", null)
	if player.target_monster == m:
		player.target_monster = null
	if hovered_monster == m:
		hovered_monster = null
	player.gain_xp(m.xp)
	_drop_loot(m)
	if m.uid != "":
		area_state[area].killed[m.uid] = true
	if m == boss:
		boss = null
		bosses_killed = maxi(bosses_killed, area)
		if exit_portal:
			exit_portal.sealed = false
		Game.play("level")
		if Act.area(area).boss.get("act_boss", false):
			show_msg("Act I complete", "%s is dead. The lamps of Vell burn again. Press T to go home." % m.display_name, 7.0)
		else:
			show_msg("%s falls" % m.display_name, "The way on to %s is open." % Act.area(area + 1).name, 3.5)


func _add_drop(d: Dictionary, near: Vector2) -> void:
	var at := near
	for t in 8:
		var p := near + Vector2(randf() - 0.5, randf() - 0.5) * 1.6
		if dungeon.is_free(p, 0.15):
			at = p
			break
	d.wpos = at
	d.bob = randf() * TAU
	drops.append(d)


func _drop_loot(m: Monster) -> void:
	var b := m.is_boss
	var c := m.champion
	var mf: int = player.st.mf
	if randf() < (1.0 if b or c else 0.3):
		var amt := maxi(1, roundi(randi_range(2, 8) * (m.mlvl + 1) * (5.0 if b else (2.5 if c else 1.0)) * (1.0 + player.st.gold / 100.0)))
		_add_drop({"kind": "gold", "amt": amt}, m.wpos)
	if randf() < (1.0 if b else (0.6 if c else 0.12)):
		_add_drop({"kind": "hp" if randf() < 0.6 else "mp"}, m.wpos)
	var n := randi_range(3, 4) if b else (2 if c else (1 if randf() < 0.12 else 0))
	for i in n:
		var rarity := Items.roll_rarity(4.0 if b else (2.2 if c else 1.0), mf)
		if b and i == 0 and rarity == "normal":
			rarity = "magic"
		_add_drop({"kind": "item", "item": Items.make(Items.pick_type(), rarity, m.mlvl)}, m.wpos)


func pickup(d: Dictionary) -> bool:
	match d.kind:
		"item":
			if not player.auto_place(d.item):
				floater(player.wpos, "No room in the inventory", Color("bbbbbb"))
				return false
			Game.play("pick")
			floater(player.wpos, d.item.name, Game.RARITY_COLORS[d.item.rarity])
		"gold":
			player.gold += d.amt
			Game.play("coin")
			floater(player.wpos, "+%d gold" % d.amt, Color("e2c26a"))
		_:
			if player.belt[d.kind] >= player.st.belt_cap:
				return false
			player.belt[d.kind] += 1
			Game.play("pick")
	drops.erase(d)
	hud.refresh()
	return true


## Put the item on the cursor down on the ground at the hero's feet.
func drop_held() -> void:
	if player.held == null:
		return
	_add_drop({"kind": "item", "item": player.held}, player.wpos)
	player.held = null
	Game.play("pick")
	hud.refresh()


func player_died() -> void:
	state = "dead"
	player.dead = true
	player.death_t = 0.0
	player.target_monster = null
	player.path.clear()
	mouse_held = false
	Game.play("die")
	burst(player.wpos, Color("6a0b0b"), 30, 2.0, 20.0, 1.0, 3.0)
	get_tree().create_timer(0.9).timeout.connect(hud.show_dead)


## Wake in town with full life, a tenth of the gold lost.
func revive() -> void:
	player.gold = int(player.gold * 0.9)
	player.dead = false
	player.poison_t = 0.0
	player.chill = 0.0
	player.recalc()
	player.hp = player.st.max_hp
	player.mp = player.st.max_mp
	state = "play"
	load_area(0, "waypoint")


func show_msg(title: String, sub: String, dur := 3.0) -> void:
	hud.show_msg(title, sub, dur)


func _on_level_up(level: int) -> void:
	var extra := " You learned Frost Nova: press Space." if level == 3 else ""
	show_msg("Level %d" % level, "5 new stat points: press C to spend them.%s" % extra, 3.5)
	hud.refresh()


# ---------- input ----------

func mouse_world() -> Vector2:
	return Game.to_world(get_global_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if state != "play":
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_held = event.pressed
			if event.pressed:
				if player.held != null:
					drop_held()
					mouse_held = false
					return
				hold_timer = 0.2
				_primary_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			player.cast_fire(mouse_world())
	elif event.is_action_pressed("drink_heal"):
		player.drink("hp")
	elif event.is_action_pressed("drink_mana"):
		player.drink("mp")
	elif event.is_action_pressed("cast_fire"):
		player.cast_fire(mouse_world())
	elif event.is_action_pressed("cast_nova"):
		player.cast_nova()
	elif event.is_action_pressed("toggle_inv"):
		hud.toggle_inv()
	elif event.is_action_pressed("toggle_char"):
		hud.toggle_char()
	elif event.is_action_pressed("toggle_map"):
		hud.toggle_map()
	elif event.is_action_pressed("town_portal"):
		open_town_portal()
	elif event.is_action_pressed("toggle_sound"):
		Game.muted = not Game.muted
		floater(player.wpos, "Sound off" if Game.muted else "Sound on", Color("bbbbbb"))
	elif event.is_action_pressed("close"):
		hud.close_panels()


func _primary_click() -> void:
	_update_hover()
	if hovered_drop != null:
		player.command_pickup(hovered_drop)
	elif hovered_monster:
		player.command_attack(hovered_monster)
	elif hovered_obj != null:
		player.command_use(hovered_obj)
	else:
		var to := dungeon.nearest_floor(mouse_world())
		player.command_move(to)
		if to != Vector2.INF:
			add_ring(to, 0.45, 0.35, true)


func nearest_foe() -> Monster:
	var best: Monster = null
	var bd := 9.0
	for m in monsters:
		var d: float = m.wpos.distance_to(player.wpos)
		if d < bd and dungeon.los(player.wpos, m.wpos):
			bd = d
			best = m
	return best


func _update_hover() -> void:
	var mp := get_global_mouse_position()
	hovered_drop = overlay.drop_at(mp)
	overlay.hovered_drop = hovered_drop
	var best: Monster = null
	var bd := INF
	if hovered_drop == null:
		for m in monsters:
			if m.wpos.distance_to(player.wpos) > 12.0 or not m.visible:
				continue
			var s: float = m.size
			var c: Vector2 = m.position + Vector2(0, -20.0 * s)
			var dx := mp.x - c.x
			var dy := mp.y - c.y
			if absf(dx) < 16.0 * s + 4.0 and absf(dy) < 24.0 * s + 4.0 and dx * dx + dy * dy < bd:
				bd = dx * dx + dy * dy
				best = m
	if hovered_monster and is_instance_valid(hovered_monster):
		hovered_monster.highlighted = false
	hovered_monster = best
	if best:
		best.highlighted = true
	if player.target_monster and is_instance_valid(player.target_monster):
		player.target_monster.highlighted = true
	hovered_obj = null
	if hovered_drop == null and best == null:
		for o in objects:
			if not is_instance_valid(o) or o.wpos.distance_to(player.wpos) > 16.0:
				continue
			var half := Vector2(16, 28)
			var c: Vector2 = o.position + Vector2(0, -26)
			match o.kind:
				"waypoint":
					half = Vector2(40, 22); c = o.position + Vector2(0, -4)
				"portal":
					half = Vector2(40, 38) if o.style != "stairs_down" else Vector2(60, 30)
					c = o.position + (Vector2(0, -34) if o.style != "stairs_down" else Vector2.ZERO)
				"tportal":
					half = Vector2(20, 32); c = o.position + Vector2(0, -32)
			if absf(mp.x - c.x) < half.x and absf(mp.y - c.y) < half.y:
				hovered_obj = o
				break
	overlay.hovered_obj = hovered_obj


# ---------- frame ----------

func _process(dt: float) -> void:
	if player == null:
		return
	camera.position = player.position + Vector2(0, -10)
	for i in range(flashes.size() - 1, -1, -1):
		flashes[i][1] -= dt
		for l in flashes[i][0].get_children():
			if l is PointLight2D:
				l.energy = maxf(0.0, flashes[i][1] * 4.5)
		if flashes[i][1] <= -0.6:
			flashes[i][0].queue_free()
			flashes.remove_at(i)
	_ghost_walls()
	_update_camera_fx(dt)
	if state != "play":
		return
	no_mana_timer -= dt
	_update_hover()
	if mouse_held and player.target_monster == null and player.target_obj == null:
		hold_timer -= dt
		if hold_timer <= 0.0:
			hold_timer = 0.15
			player.command_move(dungeon.nearest_floor(mouse_world()))
	# walk over gold and draughts to pick them up
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		if d.kind != "item" and d.wpos.distance_to(player.wpos) < 0.55:
			pickup(d)
	# indoors, fires show once their spot has been seen
	if not dungeon.outdoor:
		for b in braziers:
			if not b.visible:
				var bw := Game.to_world(b.position)
				b.visible = dungeon.seen[dungeon.idx(clampi(floori(bw.x), 0, dungeon.W - 1), clampi(floori(bw.y), 0, dungeon.H - 1))] == 1
	# waypoints wake when the hero walks onto them
	for o in objects:
		if o.kind == "waypoint" and not o.active and o.wpos.distance_to(player.wpos) < 2.0:
			_activate_waypoint(o)
	_separate()


## Push overlapping monsters apart, and off the hero.
func _separate() -> void:
	var act := monsters.filter(func(m): return m.aggro and not m.dead)
	for i in act.size():
		var a: Monster = act[i]
		for j in range(i + 1, act.size()):
			var b: Monster = act[j]
			var d := b.wpos - a.wpos
			var l := d.length()
			var min_d := a.radius + b.radius
			if l < min_d and l > 0.001:
				var push := d / l * (min_d - l) * 0.5
				a.move_by(-push)
				b.move_by(push)
		var dp := a.wpos - player.wpos
		var lp := dp.length()
		var mp := a.radius + player.radius
		if lp < mp and lp > 0.001:
			a.move_by(dp / lp * (mp - lp))


## Fade walls, trees and other tall things that stand between the camera and the hero.
func _ghost_walls() -> void:
	for w in ghosted:
		if is_instance_valid(w):
			w.modulate.a = 1.0
	ghosted.clear()
	var p := player.wpos
	var c := Vector2i(floori(p.x), floori(p.y))
	for j in range(c.y - 1, c.y + 8):
		for i in range(c.x - 1, c.x + 8):
			var w = dungeon.blockers.get(Vector2i(i, j))
			if w == null:
				continue
			if w is Prop and not w.kind in Prop.TALL:
				continue
			var dd := (i + j + 1) - (p.x + p.y)
			var dl := absf((i - j) - (p.x - p.y))
			var reach := 7.0 if w is Prop and w.kind in ["tree", "pine", "deadtree"] else 6.0
			if dd > 0.0 and dd < reach and dl < 3.5:
				w.modulate.a = 0.3
				ghosted.append(w)


# ---------- look and feel ----------

func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = load("res://shaders/post_web.gdshader" if OS.has_feature("web") else "res://shaders/post.gdshader")
	rect.material = post
	layer.add_child(rect)


func _build_ambient() -> void:
	# drifting embers (glow) and dust motes (only visible where light falls)
	var embers := Game.make_fire(40, 5.0, [Color(1, 0.7, 0.3, 0), Color(1, 0.55, 0.2, 0.8), Color(1, 0.3, 0.05, 0)], 6.0, 6.0)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(900, 600)
	embers.initial_velocity_min = 2.0
	embers.initial_velocity_max = 10.0
	embers.spread = 60.0
	embers.local_coords = false
	camera.add_child(embers)
	var dust := CPUParticles2D.new()
	dust.amount = 70
	dust.lifetime = 8.0
	dust.texture = Game.soft_dot
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(700, 450)
	dust.gravity = Vector2(4, 2)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 6.0
	dust.spread = 180.0
	dust.scale_amount_min = 0.03
	dust.scale_amount_max = 0.07
	dust.local_coords = false
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0, 0.3, 0.7, 1])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(0.9, 0.85, 0.75, 0.5), Color(0.9, 0.85, 0.75, 0.5), Color(1, 1, 1, 0)])
	dust.color_ramp = g
	camera.add_child(dust)


func _update_camera_fx(dt: float) -> void:
	shake_amount = maxf(0.0, shake_amount - dt * 30.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amount
	hurt_flash = maxf(0.0, hurt_flash - dt * 2.5)
	if post and player:
		var low := clampf(1.0 - player.hp / float(player.st.max_hp) / 0.3, 0.0, 1.0)
		var beat := low * (0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 6.0))
		post.set_shader_parameter("hurt", clampf(hurt_flash + beat * 0.6, 0.0, 1.0))
