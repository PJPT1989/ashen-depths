class_name Monster
extends Figure
## A creature of Act I. Fifteen kinds, named after black Magic: The Gathering creatures (one
## name per rank tier); each comes in ranks 1 to 12. A higher rank means more
## life, damage, defense and attack rating, a new name and a new colour. Packs sometimes hold
## a veteran a rank or two higher; unique sub-bosses and area bosses are higher still.

## Base numbers are rank 1. names: one per rank tier (ranks 1-3, 4-6, 7-9, 10-12).
## shot: missile kind for ranged attackers. elem: element of its attacks.
const TYPES := {
	"scrabbler": {"names": ["Typhoid Rats", "Plague Rats", "Crypt Rats", "Rat Colony"], "hp": 9, "dmg": [1, 4], "spd": 2.8, "xp": 8, "r": 0.28, "range": 0.95, "cd": 0.9, "blood": "5a0d0d"},
	"bonewalker": {"names": ["Drudge Skeletons", "Reassembling Skeleton", "Death Baron", "Lord of the Undead"], "hp": 16, "dmg": [2, 6], "spd": 1.9, "xp": 14, "r": 0.3, "range": 1.0, "cd": 1.2, "blood": "6d675a"},
	"hexcaller": {"names": ["Vampire Hexmage", "Cabal Archon", "Witch of the Moors", "Liliana's Devotee"], "hp": 12, "dmg": [2, 6], "spd": 1.6, "xp": 20, "r": 0.3, "range": 6.5, "cd": 2.2, "shot": "hex", "elem": "lit", "blood": "3a1650"},
	"brute": {"names": ["Phyrexian Ghoul", "Phyrexian Rager", "Phyrexian Hulk", "Phyrexian Obliterator"], "hp": 34, "dmg": [4, 9], "spd": 1.5, "xp": 30, "r": 0.4, "range": 1.15, "cd": 1.6, "blood": "4a0a0a"},
	"warden": {"names": ["Abyssal Gatekeeper", "Abyssal Persecutor", "Lord of the Pit", "Grave Titan"], "hp": 40, "dmg": [5, 10], "spd": 1.9, "xp": 38, "r": 0.45, "range": 1.3, "cd": 1.4, "blood": "10252a"},
	"rotling": {"names": ["Walking Corpse", "Scathe Zombies", "Diregraf Ghoul", "Carrion Feeder"], "hp": 18, "dmg": [2, 5], "spd": 1.1, "xp": 12, "r": 0.32, "range": 1.0, "cd": 1.5, "blood": "3e4a1c"},
	"gloomhound": {"names": ["Hollow Dogs", "Nightmare", "Bloodhunter Bat", "Vampire Nighthawk"], "hp": 11, "dmg": [2, 5], "spd": 3.6, "xp": 11, "r": 0.32, "range": 1.0, "cd": 1.0, "blood": "4a0d0d"},
	"quillback": {"names": ["Carrion Beetles", "Giant Cockroach", "Bog Imp", "Dusk Imp"], "hp": 13, "dmg": [1, 4], "spd": 2.2, "xp": 13, "r": 0.3, "range": 5.5, "cd": 1.8, "shot": "quill", "blood": "5a2d0d"},
	"bone_archer": {"names": ["Skeleton Archer", "Royal Assassin", "Nezumi Cutthroat", "Okiba-Gang Shinobi"], "hp": 12, "dmg": [2, 5], "spd": 1.8, "xp": 16, "r": 0.3, "range": 7.0, "cd": 1.7, "shot": "arrow", "blood": "6d675a"},
	"wraith": {"names": ["Bog Wraith", "Dread Shade", "Looming Shade", "Nantuko Shade"], "hp": 15, "dmg": [2, 6], "spd": 2.4, "xp": 18, "r": 0.3, "range": 1.0, "cd": 1.2, "elem": "cold", "float": true, "blood": "203040"},
	"zealot": {"names": ["Order of the Ebon Hand", "Black Knight", "Knight of Malice", "Knight of the Ebon Legion"], "hp": 20, "dmg": [3, 7], "spd": 2.0, "xp": 20, "r": 0.32, "range": 1.6, "cd": 1.3, "blood": "5a0d0d"},
	"reaver": {"names": ["Gutless Ghoul", "Skinrender", "Bloodthrone Vampire", "Sengir Vampire"], "hp": 22, "dmg": [3, 7], "spd": 2.3, "xp": 20, "r": 0.33, "range": 1.1, "cd": 1.2, "blood": "5a0d0d"},
	"moonsister": {"names": ["Hypnotic Specter", "Liliana's Specter", "Abyssal Specter", "Vampire Aristocrat"], "hp": 14, "dmg": [2, 6], "spd": 2.2, "xp": 20, "r": 0.3, "range": 7.5, "cd": 1.6, "shot": "hex", "float": true, "blood": "1a1020"},
	"spitter": {"names": ["Festering Newt", "Plague Belcher", "Phyrexian Plaguelord", "Massacre Wurm"], "hp": 24, "dmg": [3, 6], "spd": 1.2, "xp": 22, "r": 0.36, "range": 5.5, "cd": 2.0, "shot": "bile", "elem": "pois", "blood": "3e4a1c"},
	"thornback": {"names": ["Gurmag Angler", "Krovikan Horror", "Thrashing Wumpus", "Archfiend of Despair"], "hp": 46, "dmg": [5, 11], "spd": 1.3, "xp": 40, "r": 0.42, "range": 1.2, "cd": 1.6, "blood": "2d3a12"},
}
## Unique monster modifiers, like Diablo II's.
const MODS := {"strong": "Extra Strong", "fast": "Extra Fast", "stone": "Stone Skin", "fire": "Fire Enchanted",
	"cold": "Cold Enchanted", "manaburn": "Mana Burn"}

var kind := "scrabbler"
var d: Dictionary
var display_name := ""
var rank := 1
var mlvl := 1
var role := "normal"       # normal | unique | minion | boss
var uid := ""               # set on uniques and bosses so they stay dead
var mods: Array = []
var hp := 1
var max_hp := 1
var dmg := [1, 2]
var def := 1
var ar := 1
var xp := 1
var speed := 1.0
var attack_cd := 1.0
var champion := false       # unique sub-boss (gold name)
var is_boss := false
var ranged := false
var dead := false
var aggro := false
var cd := 0.0
var slow := 0.0
var hit := 0.0
var repath := 0.0
var highlighted := false
var light: PointLight2D
var dying := 0.0
var death_frame := 0
var leader: Monster = null
var draw_scale := 1.0
# what the heroes' skills do to it
var stun := 0.0
var fear := 0.0
var weak := 0.0             # % less damage dealt, while weak_t lasts
var weak_t := 0.0
var vuln := 0.0             # % more damage taken, while vuln_t lasts
var vuln_t := 0.0
var blind_t := 0.0          # Darkness: can barely see
var confuse_t := 0.0        # Delirium: attacks the nearest creature
var bait_t := 0.0           # Lure of the Grave: the others go for this one
var reflect := 0.0          # Torment: % of its blows' damage it takes back, while reflect_t lasts
var reflect_t := 0.0
var tap := 0.0              # Vampiric Embrace: % of damage done to it heals the hero, while tap_t lasts
var tap_t := 0.0
var dot_dps := 0.0          # burning or rotting, while dot_t lasts
var dot_t := 0.0
var dot_acc := 0.0
var dot_color := Color.WHITE
var corpse_t := 0.0         # after death: how long the body lies (Liliana raises and bursts them)


## keep_mods: the mods it had before (a monster put back when the hero returns), else rolled.
func setup(t: String, at: Vector2, r: int, as_role := "normal", keep_mods = null) -> void:
	kind = t
	d = TYPES[t]
	rank = clampi(r, 1, 12)
	role = as_role
	mlvl = Act.mlvl(rank)
	champion = role == "unique"
	is_boss = role == "boss"
	ranged = d.has("shot")
	radius = d.r
	wpos = at
	var hpm := pow(1.3, rank - 1)
	var dmm := pow(1.17, rank - 1)
	var xpm := pow(1.3, rank - 1)
	var spd_m := 1.0
	var cd_m := 1.0
	def = 4 + mlvl * 5
	ar = 15 + mlvl * 9
	if champion:
		hpm *= 3.0; dmm *= 1.3; xpm *= 4.0
		draw_scale = 1.12
		var pool := MODS.keys()
		pool.shuffle()
		mods = pool.slice(0, 1 if randf() < 0.5 else 2) if keep_mods == null else keep_mods
	elif is_boss:
		hpm *= 2.6; dmm *= 1.2; xpm *= 12.0
		draw_scale = 1.3
		mods = [["strong", "fast", "stone", "fire", "cold"].pick_random()] if keep_mods == null else keep_mods
	if "strong" in mods:
		dmm *= 1.5
	if "fast" in mods:
		spd_m = 1.35; cd_m = 0.7
	if "stone" in mods:
		def *= 3
		hpm *= 1.2
	max_hp = maxi(1, roundi(d.hp * hpm))
	hp = max_hp
	dmg = [maxi(1, roundi(d.dmg[0] * dmm)), maxi(1, roundi(d.dmg[1] * dmm))]
	xp = roundi(d.xp * xpm)
	speed = d.spd * spd_m
	attack_cd = d.cd * cd_m
	size = draw_scale * Game.SPRITE_CELLS[t] / 112.0
	display_name = type_name(t, rank)
	cd = randf()
	anim = randf() * 10.0
	sync_position()


static func type_name(t: String, r: int) -> String:
	return TYPES[t].names[clampi((r - 1) / 3, 0, 3)]


## Damage multiplier from curses and shouts that weaken it.
func dmg_mult() -> float:
	return 1.0 - weak / 100.0 if weak_t > 0.0 else 1.0


## A skill's lingering effects (see Skills): weak, vuln, reflect, tap (%) and slow last dur
## seconds; fear and stun give their own seconds; blind, confuse and bait last dur seconds.
## Bosses ignore fear, blinding and confusion, and shrug off most of a stun.
func afflict(debuff: Dictionary, dur: float) -> void:
	if debuff.has("reflect"):
		reflect = maxf(reflect if reflect_t > 0.0 else 0.0, debuff.reflect)
		reflect_t = maxf(reflect_t, dur)
	if debuff.has("tap"):
		tap = maxf(tap if tap_t > 0.0 else 0.0, debuff.tap)
		tap_t = maxf(tap_t, dur)
	if debuff.has("bait"):
		bait_t = maxf(bait_t, dur)
	if not is_boss:
		if debuff.has("blind"):
			blind_t = maxf(blind_t, dur)
		if debuff.has("confuse"):
			confuse_t = maxf(confuse_t, dur)
	if debuff.has("weak"):
		weak = maxf(weak if weak_t > 0.0 else 0.0, debuff.weak)
		weak_t = maxf(weak_t, dur)
	if debuff.has("vuln"):
		vuln = maxf(vuln if vuln_t > 0.0 else 0.0, debuff.vuln)
		vuln_t = maxf(vuln_t, dur)
	if debuff.has("slow"):
		slow = maxf(slow, dur * debuff.slow if debuff.slow <= 1 else debuff.slow)
	if debuff.has("fear") and not is_boss:
		fear = maxf(fear, debuff.fear)
	if debuff.has("stun") and not is_boss:
		stun = maxf(stun, debuff.stun)
	elif debuff.has("stun"):
		stun = maxf(stun, debuff.stun * 0.3)   # bosses shrug most of it off


## Burn or rot: total damage spread over dur seconds; a stronger one replaces a weaker.
func add_dot(total: float, dur: float, col: Color) -> void:
	var dps := total / dur
	if dot_t <= 0.0 or dps * dur >= dot_dps * dot_t:
		dot_dps = dps
		dot_t = dur
		dot_color = col


func elem() -> String:
	if "fire" in mods:
		return "fire"
	if "cold" in mods:
		return "cold"
	return d.get("elem", "phys")


func _ready() -> void:
	setup_sprite(kind)
	body.material = Game.rank_material(rank)
	body.scale = Vector2.ONE * draw_scale
	glow_node.scale = body.scale
	if is_boss or champion or kind == "hexcaller":
		var c := Color(0.5, 1.0, 0.6)
		if is_boss:
			c = Color(1.0, 0.55, 0.35)
		elif champion:
			c = Color(1.0, 0.85, 0.5)
		light = Game.make_light(240.0 if is_boss else 130.0, c, 0.6)
		light.position = Vector2(0, -30)
		add_child(light)
		light.add_to_group("minor_lights")  # off in low quality
		light.visible = not Game.low_quality


func _process(dt: float) -> void:
	if dying > 0.0:
		_animate_death(dt)
		return
	if dead:
		corpse_t -= dt
		if corpse_t <= 0.0:
			main.corpses.erase(self)
			queue_free()
		return
	var player: Player = main.player
	var near := wpos.distance_to(player.wpos)
	# only show what the hero has seen (indoors) or what is near enough to make out
	if dungeon.outdoor:
		visible = near < 16.0
	else:
		visible = near < 13.0 and dungeon.seen[dungeon.idx(floori(wpos.x), floori(wpos.y))] == 1
	if dead or near > 24.0:
		return
	anim += dt
	tick_action(dt)
	hit = maxf(0.0, hit - dt)
	slow = maxf(0.0, slow - dt)
	stun = maxf(0.0, stun - dt)
	fear = maxf(0.0, fear - dt)
	weak_t = maxf(0.0, weak_t - dt)
	vuln_t = maxf(0.0, vuln_t - dt)
	blind_t = maxf(0.0, blind_t - dt)
	confuse_t = maxf(0.0, confuse_t - dt)
	bait_t = maxf(0.0, bait_t - dt)
	reflect_t = maxf(0.0, reflect_t - dt)
	tap_t = maxf(0.0, tap_t - dt)
	cd -= dt * (0.6 if slow > 0.0 else 1.0)
	moving = false
	if hit > 0.0:
		modulate = Color(2.6, 2.6, 2.6)
	elif stun > 0.0:
		modulate = Color(1.5, 1.4, 0.8)
	elif slow > 0.0:
		modulate = Color(0.6, 0.85, 1.5)
	elif vuln_t > 0.0 or weak_t > 0.0 or reflect_t > 0.0 or tap_t > 0.0 or confuse_t > 0.0 or blind_t > 0.0 or bait_t > 0.0:
		modulate = Color(1.15, 0.7, 1.35)
	else:
		modulate = Color.WHITE
	if dot_t > 0.0:
		dot_t -= dt
		dot_acc += dot_dps * dt
		if dot_acc >= maxf(1.0, dot_dps * 0.5):
			var n := floori(dot_acc)
			dot_acc -= n
			main.damage_monster(self, n, dot_color)
			if dead:
				return
	if stun > 0.0:
		sync_position()
		queue_redraw()
		return
	if fear > 0.0:
		moving = move_by((wpos - player.wpos).normalized() * speed * 0.8 * dt) > 0.0
		face(wpos - player.wpos)
		sync_position()
		queue_redraw()
		return
	_think(dt, player)
	sync_position()
	queue_redraw()


func _think(dt: float, player: Player) -> void:
	var dist := wpos.distance_to(player.wpos)
	if confuse_t > 0.0 and _fight_others(dt):
		return
	if blind_t > 0.0 and dist > 2.0:
		aggro = false
	if not aggro:
		var sight := (9.0 if dungeon.outdoor else 7.5) if blind_t <= 0.0 else 2.0
		if dist < sight and dungeon.los(wpos, player.wpos):
			wake()
		else:
			if randf() < dt * 0.3:
				var home := leader.wpos if leader and is_instance_valid(leader) and not leader.dead else wpos
				path = [home + Vector2(randf() - 0.5, randf() - 0.5) * 3.0]
			if not path.is_empty():
				moving = follow(speed * 0.35, dt)
			return
	if main.state != "play" or player.dead:
		return
	if dist > 18.0:
		aggro = false
		path.clear()
		return
	var spd := speed * (0.5 if slow > 0.0 else 1.0)
	var sees := dist < 10.0 and dungeon.los(wpos, player.wpos)
	if ranged and sees and dist <= d.range:
		face(player.wpos - wpos)
		if cd <= 0.0:
			cd = attack_cd
			play_action("attack", 0.55)
			var dir := (player.wpos - wpos).normalized()
			var shot: String = d.shot
			var v := 9.0 if shot == "arrow" else (7.0 if shot == "quill" else 5.5)
			var m := dmg_mult()
			main.spawn_shot(self, shot, wpos + dir * 0.4, dir * v, [roundi(dmg[0] * m), roundi(dmg[1] * m)], elem())
			Game.play("bolt")
		if dist < 2.5:
			moving = move_by((wpos - player.wpos).normalized() * spd * 0.7 * dt) > 0.0
		return
	if not ranged and dist <= d.range + player.radius:
		face(player.wpos - wpos)
		if cd <= 0.0:
			cd = attack_cd
			play_action("attack", 0.5)
			_melee(player)
		return
	# a minion in the way gets attacked instead
	if not ranged:
		for mi in main.minions:
			if not mi.dead and mi.wpos.distance_to(wpos) <= d.range + mi.radius:
				face(mi.wpos - wpos)
				if cd <= 0.0:
					cd = attack_cd
					play_action("attack", 0.5)
					if randf() < 0.75:
						mi.take_hit(roundi(randi_range(dmg[0], dmg[1]) * dmg_mult()))
				return
	repath -= dt
	if repath <= 0.0 or path.is_empty():
		if sees and dist < 3.0:
			path = [player.wpos]
		else:
			path = dungeon.find_path(wpos, player.wpos, radius)
		repath = 0.45 + randf() * 0.35
	if not path.is_empty():
		moving = follow(spd, dt)


## Delirium: go for the nearest other monster (a lured one first) and hit it. False if none is near.
func _fight_others(dt: float) -> bool:
	var foe: Monster = null
	var bd := 6.0
	for o in main.monsters:
		if o == self or o.dead:
			continue
		var dd: float = o.wpos.distance_to(wpos) - (4.0 if o.bait_t > 0.0 else 0.0)
		if dd < bd:
			bd = dd
			foe = o
	if foe == null:
		return false
	var dist := wpos.distance_to(foe.wpos)
	var reach: float = d.range if ranged else d.range + foe.radius
	if dist <= reach:
		face(foe.wpos - wpos)
		path.clear()
		if cd <= 0.0:
			cd = attack_cd
			play_action("attack", 0.5)
			main.damage_monster(foe, roundi(randi_range(dmg[0], dmg[1]) * dmg_mult()), Color("d080ff"))
	else:
		repath -= dt
		if repath <= 0.0 or path.is_empty():
			path = dungeon.find_path(wpos, foe.wpos, radius)
			repath = 0.4
		moving = follow(speed * (0.5 if slow > 0.0 else 1.0), dt)
	return true


## Wake this monster and the ones around it.
func wake() -> void:
	aggro = true
	for o in main.monsters:
		if not o.aggro and o.wpos.distance_to(wpos) < 5.0:
			o.aggro = true


func _melee(player: Player) -> void:
	if randf() > Game.hit_chance(ar, player.st.def, mlvl, player.level):
		main.floater(player.wpos, "miss", Color("9a9080"))
		return
	if player.try_block():
		return
	var amount := roundi(randi_range(dmg[0], dmg[1]) * dmg_mult())
	var e := elem()
	if e == "fire" or e == "cold":
		# enchanted: the hit carries the element on top of the blow
		player.take_hit(int(ceil(amount * 0.6)), "phys", self)
		player.take_hit(int(ceil(amount * 0.6)), e, null)
	else:
		player.take_hit(amount, e, self)
	if reflect_t > 0.0 and not dead:
		main.damage_monster(self, maxi(1, roundi(amount * reflect / 100.0)), Color("c060ff"))
	if "manaburn" in mods:
		player.mp = maxf(0.0, player.mp - amount * 1.5)


## Topple and lie as a corpse for a while, then fade and free.
func die() -> void:
	dead = true
	dying = 0.9
	corpse_t = 45.0
	dot_t = 0.0
	highlighted = false
	z_index = -1
	if light:
		light.queue_free()
		light = null


func _animate_death(dt: float) -> void:
	dying -= dt
	var t := 1.0 - dying / 0.9
	death_frame = mini(7, int(t * 1.6 * 8.0))
	modulate = Color(0.75, 0.7, 0.7).lerp(Color(0.55, 0.5, 0.5), t)
	queue_redraw()
	if dying <= 0.0:
		main.add_corpse(self)


# ---------- drawing ----------

func _draw() -> void:
	var s := size
	if highlighted:
		ellipse(Vector2.ZERO, 16 * s, 7 * s, Color(0.86, 0.2, 0.16, 0.85), false, 2.0)
	if champion and not dead:
		ellipse(Vector2.ZERO, 15 * s, 6.5 * s, Color(0.95, 0.75, 0.3, 0.6), false, 2.0)
	if is_boss and not dead:
		ellipse(Vector2.ZERO, 34, 15, Color(0.9, 0.35, 0.2, 0.18))
	shadow((8.0 if d.has("float") else 11.0) * s)
	if dead:
		draw_frame("death", death_frame)
		return
	var f := pick_frame()
	draw_frame(f[0], f[1])
