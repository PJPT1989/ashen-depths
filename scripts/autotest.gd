extends Node
## Smoke test, enabled with:  godot --path . -- --autotest [--shots=/some/dir]
## Walks through the town, the panels and every area of Act I, fights a little, kills a boss,
## dies, saves screenshots, prints a summary and quits. Not used in normal play.

var main
var t := 0.0
var shots_dir := ""
var steps: Array = []
var step_i := 0
var wait := 0.0
var fight_until := 0.0


func _ready() -> void:
	Game.save_settings = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	steps = [
		[1.0, func(): _shot("title")],
		[0.3, func():
			main.hud.title_screen.visible = false
			main.start_game("chandra")],
		[0.6, func():
			print("AUTOTEST hero %s: life %d, mana %d" % [main.player.cls, main.player.st.max_hp, main.player.st.max_mp])
			_shot("hero_chandra")],
		[0.3, func(): main.player.set_class("liliana")],
		[0.6, func():
			print("AUTOTEST hero %s: life %d, mana %d" % [main.player.cls, main.player.st.max_hp, main.player.st.max_mp])
			_shot("hero_liliana")],
		[0.3, func(): main.player.set_class("ajani")],
		[1.0, func():
			print("AUTOTEST hero %s: life %d, mana %d" % [main.player.cls, main.player.st.max_hp, main.player.st.max_mp])
			print("AUTOTEST town fps %d, nodes %d" % [Engine.get_frames_per_second(), get_tree().get_node_count()])
			_shot("town")],
		[0.5, func(): _fill_inventory()],
		[0.8, func():
			_shot("inventory")
			_click_test()],
		[0.3, func():
			main.hud.close_panels()
			main.use_object(_npc("vendor"))],
		[0.8, func(): _shot("trade")],
		[0.3, func():
			main.hud.close_panels()
			main.waypoint_travel(0)
			main.load_area(1, "start")
			fight_until = t + 18.0],
		[18.5, func():
			print("AUTOTEST moor fight: level %d, xp %d, gold %d, monsters left %d, drops %d" % [main.player.level, main.player.xp, main.player.gold, main.monsters.size(), main.drops.size()])
			_shot("moor")],
		[0.2, func(): _kill_some(6)],
		[1.2, func():
			_skill_test("ajani")
			_shot("skills_ajani")],
		[0.2, func(): _kill_some(6)],
		[1.2, func():
			_skill_test("chandra")
			_shot("skills_chandra")],
		[0.2, func(): _kill_some(6)],
		[1.2, func():
			_skill_test("liliana")
			_shot("skills_liliana")],
		[0.3, func(): _showcase("chandra", ["fireblast", "chain_lightning", "wall_of_fire"])],
		[0.45, func(): _shot("showcase_chandra")],
		[0.3, func(): _showcase("liliana", ["death_cloud", "bone_golem", "bone_splinters"])],
		[0.6, func(): _shot("showcase_liliana")],
		[0.3, func(): _showcase("ajani", ["thunderous_roar"])],
		[0.25, func(): _shot("showcase_ajani")],
		[1.0, func(): _learn_test()],
		[0.3, func(): _tree_shot("chandra", 0, "fireball")],
		[0.6, func(): _shot("tree_chandra")],
		[0.3, func(): _tree_shot("liliana", 0, "raise_dead")],
		[0.6, func(): _shot("tree_liliana")],
		[0.3, func(): _tree_shot("ajani", 2, "battle_cry")],
		[0.6, func(): _shot("tree_ajani")],
		[0.3, func():
			main.hud.close_panels()
			main.hud.open_picker(1)],
		[0.5, func(): _shot("skill_picker")],
		[0.3, func():
			print("AUTOTEST minions: %d, corpses %d" % [main.minions.size(), main.corpses.size()])
			main.hud.close_panels()
			var p: Player = main.player
			p.set_class("ajani")
			p.level = 12
			p.base.str = 60
			p.base.dex = 45
			p.recalc()],
		[0.2, func(): Game.set_quality(Game.LOW)],
		[0.8, func():
			var pairs := get_tree().get_nodes_in_group("light_pairs")
			var shadowed := pairs.filter(func(l): return l.shadow_enabled).size()
			print("AUTOTEST low quality: %d light pairs, %d still shadowed, post %s" % [pairs.size(), shadowed, main.post.shader.resource_path.get_file()])
			_shot("low_quality")
			Game.set_quality(Game.HIGH)],
		[0.8, func():
			print("AUTOTEST high quality: scale mode %d, post %s" % [get_tree().root.content_scale_mode, main.post.shader.resource_path.get_file()])
			_shot("high_quality")
			Game.set_quality(Game.MEDIUM)],
		[0.8, func():
			print("AUTOTEST medium quality: scale mode %d, post %s" % [get_tree().root.content_scale_mode, main.post.shader.resource_path.get_file()])
			_shot("medium_quality")],
		[0.5, func():
			main.hud.toggle_char(true)
			main.hud.toggle_inv(true)],
		[0.8, func(): _shot("character")],
		[0.3, func():
			main.hud.close_panels()
			main.hud.toggle_map()],
		[0.8, func(): _shot("map")],
		[0.3, func():
			main.hud.toggle_map()
			main.open_town_portal()],
		[0.8, func(): _shot("portal")],
	]
	for i in range(2, Act.count()):
		var ai := i
		steps.append([0.3, func():
			main.load_area(ai, "start")
			fight_until = t + 4.0])
		steps.append([4.5, func():
			_report(ai)
			_shot("area%d_%s" % [ai, Act.area(ai).id])])
	steps.append([0.3, func():
		var b: Monster = main.boss
		main.player.wpos = main.dungeon.boss_spot + Vector2(1.5, 1.5)
		main.player.sync_position()
		print("AUTOTEST act boss %s rank %d hp %d" % [b.display_name, b.rank, b.max_hp])])
	steps.append([1.0, func(): _shot("boss")])
	steps.append([0.3, func(): main.kill_monster(main.boss)])
	steps.append([1.0, func():
		print("AUTOTEST boss dead, exit sealed: %s" % (main.exit_portal.sealed if main.exit_portal else "none"))
		main.area_state[3].waypoint = true
		main.hud.show_waypoints()])
	steps.append([0.6, func(): _shot("waypoints")])
	steps.append([0.3, func():
		main.hud.close_panels()
		main.player.take_hit(99999)])
	steps.append([1.6, func():
		print("AUTOTEST death screen visible: %s" % main.hud.dead_screen.visible)
		main.hud.dead_screen.visible = false
		main.revive()])
	steps.append([1.0, func():
		print("AUTOTEST revived in area %d, hp %d" % [main.area, main.player.hp])
		print("AUTOTEST done")
		get_tree().quit()])
	wait = steps[0][0]


## Kill the monsters nearest the hero so there are corpses for Liliana.
func _kill_some(n: int) -> void:
	var p: Player = main.player
	var list: Array = main.monsters.filter(func(m): return not m.is_boss)
	list.sort_custom(func(a, b): return a.wpos.distance_to(p.wpos) < b.wpos.distance_to(p.wpos))
	for m in list.slice(0, n):
		main.kill_monster(m)


## Every skill of a hero at level 10, cast at the nearest monster; prints what failed.
func _skill_test(hero: String) -> void:
	var p: Player = main.player
	p.set_class(hero)
	p.level = 30
	for id in Skills.of_hero(hero):
		p.skills[id] = 10
	p.recalc()
	var ok := 0
	var tried := 0
	var failed: Array = []
	for id in Skills.of_hero(hero):
		if Skills.is_passive(id):
			continue
		var m: Monster = null
		var bd := INF
		for o in main.monsters:
			var dd: float = o.wpos.distance_to(p.wpos)
			if not o.is_boss and dd < bd:
				bd = dd
				m = o
		if m == null:
			continue
		if bd > 1.2:
			p.wpos = main.dungeon.spot_near(m.wpos + (p.wpos - m.wpos).normalized() * 1.0, 0.3)
			p.sync_position()
		p.cds.clear()
		p.cast_t = 0.0
		p.atk_t = 0.0
		p.lunge = {}
		p.body.position = Vector2.ZERO
		p.mp = p.st.max_mp
		p.hp = p.st.max_hp
		p.set_slot(0, id)
		tried += 1
		var at: Vector2 = m.wpos
		var sk: Dictionary = Skills.SKILLS[id]
		if sk.kind in ["corpse", "scavenge"] or sk.has("corpse"):
			var c: Array = main.corpses_near(p.wpos, 999.0, 1)
			if not c.is_empty():
				at = c[0].wpos
				p.wpos = main.dungeon.spot_near(at, 1.5)
				p.sync_position()
		if p.use_slot(0, at, null if at != m.wpos else m):
			ok += 1
		else:
			failed.append(id)
	print("AUTOTEST skills %s: %d of %d went off, minions %d, corpses %d, life %d, mana %d%s" % [hero, ok, tried, main.minions.size(), main.corpses.size(),
		p.st.max_hp, p.st.max_mp, "" if failed.is_empty() else ", failed: " + ", ".join(PackedStringArray(failed))])
	p.bar = ["", Skills.START[hero]]
	p.lunge = {}
	p.body.position = Vector2.ZERO


## Diablo II point rules: rows open by level, prerequisites come first, one point per level.
func _learn_test() -> void:
	var p: Player = main.player
	p.set_class("chandra")
	p.level = 1
	p.xp = 0
	p.skill_points = 0
	var r: Array = []
	var try := func(id: String) -> String:
		var why: String = p.why_not_learn(id)
		return "%s %s" % [id, "ok" if p.learn(id) else why]
	r.append(try.call("flame_slash"))
	var to := func(l: int):
		while p.level < l:
			p.gain_xp(Player.xp_needed(p.level) - p.xp)
	to.call(6)
	r.append("level %d with %d points" % [p.level, p.skill_points])
	r.append(try.call("flame_slash"))
	r.append(try.call("flamewake"))
	r.append(try.call("fireball"))
	to.call(12)
	r.append(try.call("fireball"))
	var d1 := p.dmg_range(p.skill("fireball"))
	r.append(try.call("shock"))
	var d2 := p.dmg_range(p.skill("fireball"))
	r.append("fireball %d-%d, then %d-%d with Shock at %d" % [d1[0], d1[1], d2[0], d2[1], p.skills.shock])
	print("AUTOTEST learning: " + "; ".join(PackedStringArray(r)))


## A hero with points spread through a tree, the skill tree open on one tab with a skill's text.
func _tree_shot(hero: String, tab: int, tip_id: String) -> void:
	var p: Player = main.player
	p.set_class(hero)
	p.level = 18
	p.skill_points = 17
	var plan := {
		"chandra": ["fireball", "fireball", "inner_fire", "flame_slash", "flamewake", "wall_of_fire", "fireball", "fireball", "shock", "shock", "fervor", "lava_spike", "flame_ward", "fling", "spark_volley", "fireball", "wall_of_fire"],
		"liliana": ["raise_dead", "raise_dead", "death_mastery", "grave_golem", "golem_mastery", "bone_archers", "blood_golem", "raise_dead", "death_mastery", "agony_warp", "bone_splinters", "grisly_spectacle", "bone_shroud", "raise_dead", "weakness", "bone_archers", "darkness"],
		"ajani": ["fearsome_roar", "provoke", "ajanis_presence", "battle_cry", "prides_strength", "scavenge", "hunters_eye", "savage_swipe", "twin_claws", "bound", "blade_mastery", "blade_mastery", "battle_cry", "leonin_vigor", "shield_guard", "thick_hide", "battle_cry"],
	}
	var learned := 0
	for id in plan[hero]:
		if p.learn(id):
			learned += 1
	print("AUTOTEST tree %s: %d of %d points spent, %d left" % [hero, learned, plan[hero].size(), p.skill_points])
	main.hud.close_panels()
	main.hud.tree_view.tab = tab
	main.hud.toggle_skills(true)
	var box: Rect2 = main.hud.tree_view.box(tip_id)
	get_viewport().warp_mouse(main.hud.tree_view.get_global_rect().position + box.get_center())
	main.hud.show_skill_tip(tip_id)


## Stand by the biggest pack and cast a few skills, for a screenshot of how they look.
func _showcase(hero: String, ids: Array) -> void:
	var p: Player = main.player
	p.set_class(hero)
	p.level = 24
	p.recalc()
	var best: Monster = null
	var bn := -1
	for m in main.monsters:
		if m.is_boss:
			continue
		var n := 0
		for o in main.monsters:
			if o.wpos.distance_to(m.wpos) < 3.5:
				n += 1
		if n > bn:
			bn = n
			best = m
	if best == null:
		return
	p.wpos = main.dungeon.spot_near(best.wpos + Vector2(2.5, 2.5), 1.0)
	p.sync_position()
	main.camera.position = p.position
	main.camera.reset_smoothing()
	for m in main.monsters:
		if m.wpos.distance_to(best.wpos) < 4.0:
			m.wake()
	for id in ids:
		p.skills[id] = 10
	p.recalc()
	for id in ids:
		p.cds.clear()
		p.cast_t = 0.0
		p.atk_t = 0.0
		p.mp = p.st.max_mp
		p.use_skill(id, best.wpos, best)


func _npc(role: String):
	for o in main.objects:
		if o.kind == "npc" and o.role == role:
			return o
	return null


func _fill_inventory() -> void:
	var p: Player = main.player
	for type in ["weapon", "armor", "helm", "boots", "gloves", "belt", "ring", "amulet", "charm", "charm", "charm", "shield"]:
		var it := Items.make(type, ["normal", "magic", "rare", "unique"].pick_random(), 12)
		p.auto_place(it)
	# wear what can be worn so the hero shows his gear
	for it in p.inv.duplicate():
		if it.type in ["armor", "helm", "boots", "gloves", "belt"] and p.can_use(it):
			p.quick_equip(it)
	p.base.str = 60
	p.base.dex = 45
	p.level = 12
	p.recalc()
	for it in p.inv.duplicate():
		if it.type in ["armor", "helm", "boots", "gloves", "belt", "weapon", "shield"]:
			p.quick_equip(it)
	print("AUTOTEST gear: %s" % ", ".join(PackedStringArray(Items.EQUIP_SLOTS.map(func(s): return "%s=%s" % [s, p.equip[s].name if p.equip[s] else "-"]))))
	print("AUTOTEST stats: str %d dex %d life %d def %d ar %d block %d dmg %d-%d" % [p.st.str, p.st.dex, p.st.max_hp, p.st.def, p.st.ar, p.st.block, p.st.dmg_min, p.st.dmg_max])
	main.hud.toggle_inv(true)
	main.hud.toggle_char(true)


## Drive the inventory grid with synthetic clicks: pick an item up, put it down elsewhere,
## right-click a charm (nothing happens), then wear a ring with a right-click.
func _click_test() -> void:
	var p: Player = main.player
	var iv: InvView = main.hud.inv_view
	var it: Dictionary = p.inv[0]
	var from := Vector2i(it.gx, it.gy)
	_click(iv, Vector2(it.gx + 0.5, it.gy + 0.5) * InvView.C + Vector2(0, InvView.GRID_Y), MOUSE_BUTTON_LEFT)
	var picked: bool = p.held == it
	# find a free spot for it
	var to := Vector2i(-1, -1)
	for x in range(9, -1, -1):
		for y in 4:
			if to.x < 0 and p.grid_fits(it, x, y):
				to = Vector2i(x, y)
	var centre := (Vector2(to) + Vector2(it.w, it.h) / 2.0) * InvView.C + Vector2(0, InvView.GRID_Y)
	_click(iv, centre, MOUSE_BUTTON_LEFT)
	print("AUTOTEST click: picked %s, placed %s, moved %s -> %s" % [picked, p.held == null, from, Vector2i(it.gx, it.gy)])
	for r in p.inv.duplicate():
		if r.type == "ring":
			_click(iv, Vector2(r.gx + 0.5, r.gy + 0.5) * InvView.C + Vector2(0, InvView.GRID_Y), MOUSE_BUTTON_RIGHT)
			print("AUTOTEST right-click ring: worn %s" % (p.equip.ring1 == r or p.equip.ring2 == r))
			break
	# drag the helm off and back on through the paper doll
	var helm = p.equip.helm
	_click(iv, InvView.SLOT_RECTS.helm.get_center(), MOUSE_BUTTON_LEFT)
	var off: bool = p.held == helm and p.equip.helm == null
	_click(iv, InvView.SLOT_RECTS.helm.get_center(), MOUSE_BUTTON_LEFT)
	print("AUTOTEST helm off %s, back on %s" % [off, p.equip.helm == helm and p.held == null])


func _click(iv: Control, pos: Vector2, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = pos
	iv._gui_input(ev)


func _report(i: int) -> void:
	var counts := {}
	var uniques := 0
	for m in main.monsters:
		counts[m.display_name] = counts.get(m.display_name, 0) + 1
		if m.champion:
			uniques += 1
	var d: Dungeon = main.dungeon
	print("AUTOTEST nodes %d, blockers %d" % [get_tree().get_node_count(), main.dungeon.blockers.size()])
	print("AUTOTEST area %d %s: %dx%d, %d monsters, %d uniques, boss %s (rank %d), fps %d" % [i, Act.area(i).name, d.W, d.H, main.monsters.size(), uniques,
		main.boss.display_name if main.boss else "-", main.boss.rank if main.boss else 0, Engine.get_frames_per_second()])


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(name + ".png"))


func _process(dt: float) -> void:
	t += dt
	var p: Player = main.player
	if not p.dead and step_i < steps.size() - 3:
		p.hp = p.st.max_hp
		p.mp = p.st.max_mp
	if t < fight_until and int(t * 2.5) != int((t - dt) * 2.5):
		var best: Monster = null
		var bd := INF
		for m in main.monsters:
			if m.is_boss:
				continue
			var d: float = m.wpos.distance_to(p.wpos)
			if d < bd:
				bd = d; best = m
		if best and bd < 25.0:
			p.command_attack(best)
			if bd < 6.0 and main.dungeon.los(p.wpos, best.wpos):
				p.use_slot(1, best.wpos, best)
	wait -= dt
	if wait <= 0.0 and step_i < steps.size():
		steps[step_i][1].call()
		step_i += 1
		if step_i < steps.size():
			wait = steps[step_i][0]
