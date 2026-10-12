class_name Monster
extends Figure
## A creature of Act I. Fifteen kinds; each comes in ranks 1 to 12. A higher rank means more
## life, damage, defense and attack rating, a new name and a new colour. Packs sometimes hold
## a veteran a rank or two higher; unique sub-bosses and area bosses are higher still.

## Base numbers are rank 1. names: one per rank tier (ranks 1-3, 4-6, 7-9, 10-12).
## shot: missile kind for ranged attackers. elem: element of its attacks.
const TYPES := {
	"scrabbler": {"names": ["Scrabbler", "Gnasher", "Pitspawn", "Ashfiend"], "hp": 9, "dmg": [1, 4], "spd": 2.8, "xp": 8, "r": 0.28, "range": 0.95, "cd": 0.9, "blood": "5a0d0d"},
	"bonewalker": {"names": ["Bonewalker", "Grave Knight", "Ossuary Guard", "Bone Lord"], "hp": 16, "dmg": [2, 6], "spd": 1.9, "xp": 14, "r": 0.3, "range": 1.0, "cd": 1.2, "blood": "6d675a"},
	"hexcaller": {"names": ["Hexcaller", "Curse Weaver", "Dread Chanter", "Void Prophet"], "hp": 12, "dmg": [2, 6], "spd": 1.6, "xp": 20, "r": 0.3, "range": 6.5, "cd": 2.2, "shot": "hex", "elem": "lit", "blood": "3a1650"},
	"brute": {"names": ["Tusked Brute", "Gore Hulk", "Pit Ogre", "Doom Brute"], "hp": 34, "dmg": [4, 9], "spd": 1.5, "xp": 30, "r": 0.4, "range": 1.15, "cd": 1.6, "blood": "4a0a0a"},
	"warden": {"names": ["Gravewarden", "Tomb Warden", "Crypt Colossus", "Lampless Warden"], "hp": 40, "dmg": [5, 10], "spd": 1.9, "xp": 38, "r": 0.45, "range": 1.3, "cd": 1.4, "blood": "10252a"},
	"rotling": {"names": ["Rotling", "Plague Walker", "Bloated Dead", "Carrion Lord"], "hp": 18, "dmg": [2, 5], "spd": 1.1, "xp": 12, "r": 0.32, "range": 1.0, "cd": 1.5, "blood": "3e4a1c"},
	"gloomhound": {"names": ["Gloomhound", "Dusk Jackal", "Night Stalker", "Hellhound"], "hp": 11, "dmg": [2, 5], "spd": 3.6, "xp": 11, "r": 0.32, "range": 1.0, "cd": 1.0, "blood": "4a0d0d"},
	"quillback": {"names": ["Quillback", "Spike Fiend", "Thorn Rat", "Razorspine"], "hp": 13, "dmg": [1, 4], "spd": 2.2, "xp": 13, "r": 0.3, "range": 5.5, "cd": 1.8, "shot": "quill", "blood": "5a2d0d"},
	"bone_archer": {"names": ["Bone Archer", "Corpse Archer", "Grave Bowman", "Horror Archer"], "hp": 12, "dmg": [2, 5], "spd": 1.8, "xp": 16, "r": 0.3, "range": 7.0, "cd": 1.7, "shot": "arrow", "blood": "6d675a"},
	"wraith": {"names": ["Wraith", "Gloam", "Black Soul", "Spectre"], "hp": 15, "dmg": [2, 6], "spd": 2.4, "xp": 18, "r": 0.3, "range": 1.0, "cd": 1.2, "elem": "cold", "float": true, "blood": "203040"},
	"zealot": {"names": ["Zealot", "Flagellant", "Inquisitor", "Ash Templar"], "hp": 20, "dmg": [3, 7], "spd": 2.0, "xp": 20, "r": 0.32, "range": 1.6, "cd": 1.3, "blood": "5a0d0d"},
	"reaver": {"names": ["Reaver", "Marauder", "Butcher", "Warlord"], "hp": 22, "dmg": [3, 7], "spd": 2.3, "xp": 20, "r": 0.33, "range": 1.1, "cd": 1.2, "blood": "5a0d0d"},
	"moonsister": {"names": ["Moon Sister", "Dark Ranger", "Vile Huntress", "Night Lancer"], "hp": 14, "dmg": [2, 6], "spd": 2.2, "xp": 20, "r": 0.3, "range": 7.5, "cd": 1.6, "shot": "arrow", "blood": "5a0d0d"},
	"spitter": {"names": ["Spitter", "Bile Toad", "Plague Belcher", "Mire Horror"], "hp": 24, "dmg": [3, 6], "spd": 1.2, "xp": 22, "r": 0.36, "range": 5.5, "cd": 2.0, "shot": "bile", "elem": "pois", "blood": "3e4a1c"},
	"thornback": {"names": ["Thornback", "Briar Beast", "Bramble Hulk", "Old Growth"], "hp": 46, "dmg": [5, 11], "spd": 1.3, "xp": 40, "r": 0.42, "range": 1.2, "cd": 1.6, "blood": "2d3a12"},
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


func setup(t: String, at: Vector2, r: int, as_role := "normal") -> void:
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
		mods = pool.slice(0, 1 if randf() < 0.5 else 2)
	elif is_boss:
		hpm *= 2.6; dmm *= 1.2; xpm *= 12.0
		draw_scale = 1.3
		mods = [["strong", "fast", "stone", "fire", "cold"].pick_random()]
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
	cd -= dt * (0.6 if slow > 0.0 else 1.0)
	moving = false
	if hit > 0.0:
		modulate = Color(2.6, 2.6, 2.6)
	elif slow > 0.0:
		modulate = Color(0.6, 0.85, 1.5)
	else:
		modulate = Color.WHITE
	_think(dt, player)
	sync_position()
	queue_redraw()


func _think(dt: float, player: Player) -> void:
	var dist := wpos.distance_to(player.wpos)
	if not aggro:
		var sight := 9.0 if dungeon.outdoor else 7.5
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
			main.spawn_shot(self, shot, wpos + dir * 0.4, dir * v, dmg, elem())
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
	repath -= dt
	if repath <= 0.0 or path.is_empty():
		if sees and dist < 3.0:
			path = [player.wpos]
		else:
			path = dungeon.find_path(wpos, player.wpos, radius)
		repath = 0.45 + randf() * 0.35
	if not path.is_empty():
		moving = follow(spd, dt)


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
	var amount := randi_range(dmg[0], dmg[1])
	var e := elem()
	if e == "fire" or e == "cold":
		# enchanted: the hit carries the element on top of the blow
		player.take_hit(int(ceil(amount * 0.6)), "phys", self)
		player.take_hit(int(ceil(amount * 0.6)), e, null)
	else:
		player.take_hit(amount, e, self)
	if "manaburn" in mods:
		player.mp = maxf(0.0, player.mp - amount * 1.5)


## Topple, sink and fade, then free.
func die() -> void:
	dead = true
	dying = 0.9
	highlighted = false
	z_index = -1
	if light:
		light.queue_free()
		light = null


func _animate_death(dt: float) -> void:
	dying -= dt
	var t := 1.0 - dying / 0.9
	death_frame = mini(7, int(t * 1.6 * 8.0))
	modulate = Color(0.75, 0.7, 0.7, clampf(dying * 2.5, 0.0, 1.0))
	queue_redraw()
	if dying <= 0.0:
		queue_free()


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
