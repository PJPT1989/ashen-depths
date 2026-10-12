extends Node
## Autoload "Game": shared constants, isometric math, input actions, fonts and synthesized sound.

const HW := 32.0          # half tile width in pixels
const HH := 16.0          # half tile height in pixels
const TH := 32.0
const WALL := 36.0        # wall block height in pixels

const RARITY_COLORS := {
	"normal": Color("d9d4c7"), "magic": Color("8597ff"),
	"rare": Color("f2d25c"), "unique": Color("c8a165"),
}
## Monster rank colours (rank 1 keeps its natural colours). See rank_material().
const RANK_TINTS := [Color(1, 1, 1), Color(0.6, 0.8, 0.35), Color(1, 0.7, 0.3), Color(0.4, 0.6, 1), Color(0.75, 0.45, 1),
	Color(1, 0.3, 0.3), Color(0.3, 0.9, 0.8), Color(1, 0.85, 0.35), Color(0.85, 0.85, 0.9), Color(0.35, 0.3, 0.5),
	Color(1, 0.45, 0.15), Color(0.55, 1, 1)]

var muted := false
## Low quality, for slow computers: no shadows, one light instead of each shadowed pair, no
## monster glow lights or normal maps, a cheap finishing pass and no drifting embers. L toggles it; saved in user://settings.cfg.
signal quality_changed
const SETTINGS := "user://settings.cfg"
var low_quality := false
var quality_chosen := false  # the player picked a setting, so the automatic switch leaves it alone
var font_display: Font
var font_body: Font
var font_bold: Font
var sounds := {}
var soft_dot: Texture2D            # white radial blob for particles, glows and shadows
var add_material: CanvasItemMaterial  # additive and unaffected by lights (fire, sparks)
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	randomize()
	font_display = load("res://fonts/GrenzeGotisch.ttf")
	font_body = load("res://fonts/AlegreyaSans-Regular.ttf")
	font_bold = load("res://fonts/AlegreyaSans-Bold.ttf")
	soft_dot = _radial_texture(64, [0.0, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	add_material = CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_register_inputs()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		low_quality = cfg.get_value("video", "low_quality", false)
		quality_chosen = cfg.get_value("video", "chosen", false)
	_build_sounds()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)


# ---------- isometric helpers ----------

func iso(w: Vector2) -> Vector2:
	return Vector2((w.x - w.y) * HW, (w.x + w.y) * HH)


func to_world(s: Vector2) -> Vector2:
	var a := s.x / HW
	var b := s.y / HH
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


func hsl(h: float, s: float, l: float, a := 1.0) -> Color:
	# Godot's Color.from_hsv is HSV; convert HSL -> HSV.
	var v := l + s * minf(l, 1.0 - l)
	var sv := 0.0 if v == 0.0 else 2.0 * (1.0 - l / v)
	return Color.from_hsv(fposmod(h, 360.0) / 360.0, sv, v, a)


## Light layers: 1 = floor, figures and props (shadowed by walls), 2 = wall blocks (never shadowed,
## so a wall's own faces stay lit). A light that should cast wall shadows gets shadows = true
## and only touches layer 1; pair it with an unshadowed twin on layer 2 to light the walls.
func make_light(diameter: float, color: Color, energy: float, shadows := false, mask := 3) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_texture()
	l.texture_scale = diameter / 256.0
	l.color = color
	l.energy = energy
	l.range_item_cull_mask = mask
	# lights sit above the floor; with height 0 they would graze the normal-mapped stone
	l.height = clampf(diameter * 0.18, 30.0, 140.0)
	if shadows:
		l.shadow_enabled = true
		l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		l.shadow_filter_smooth = 3.0
		l.shadow_color = Color(0, 0, 0, 1)
		l.shadow_item_cull_mask = 1
	return l


## A shadow-casting light for floor and figures plus an unshadowed twin for walls.
func make_light_pair(parent: Node2D, diameter: float, color: Color, energy: float, offset := Vector2.ZERO) -> Array:
	var a := make_light(diameter, color, energy, true, 1)
	var b := make_light(diameter * 0.9, color, energy * 0.9, false, 2)
	a.position = offset
	b.position = offset + Vector2(0, -10)
	parent.add_child(a)
	parent.add_child(b)
	a.set_meta("twin", b)
	a.add_to_group("light_pairs")
	_apply_quality(a)
	return [a, b]


## In low quality a pair becomes one unshadowed light that also lights the walls.
func _apply_quality(a: PointLight2D) -> void:
	a.shadow_enabled = not low_quality
	a.range_item_cull_mask = 3 if low_quality else 1
	var b = a.get_meta("twin")
	if is_instance_valid(b):
		b.visible = not low_quality


## Normal maps make lights pick out the relief of stone and figures; low quality draws flat.
func _set_normal(t: CanvasTexture) -> void:
	t.normal_texture = null if low_quality else load(t.get_meta("normal"))


func set_low_quality(on: bool, chosen := true) -> void:
	low_quality = on
	quality_chosen = quality_chosen or chosen
	var cfg := ConfigFile.new()
	cfg.set_value("video", "low_quality", low_quality)
	cfg.set_value("video", "chosen", quality_chosen)
	cfg.save(SETTINGS)
	for a in get_tree().get_nodes_in_group("light_pairs"):
		_apply_quality(a)
	for l in get_tree().get_nodes_in_group("minor_lights"):
		l.visible = not low_quality
	for d in _sheets.values():
		_set_normal(d.tex)
	for t in _tex_cache.values():
		_set_normal(t)
	quality_changed.emit()


var _light_tex: GradientTexture2D
func _light_texture() -> GradientTexture2D:
	if _light_tex == null:
		_light_tex = _radial_texture(256, [0.0, 0.35, 0.7, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0)])
	return _light_tex


func _radial_texture(size: int, offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex


## Baked character sheets (see tools/bake_sprites.gd). Cell sizes must match the baker.
## The hero is drawn from layers: "hero_base" plus one sheet per piece of gear.
const SPRITE_CELLS := {"hero": 112, "townsfolk": 96, "scrabbler": 80, "bonewalker": 112, "hexcaller": 112, "brute": 144,
	"warden": 160, "rotling": 112, "gloomhound": 112, "quillback": 96, "bone_archer": 112, "wraith": 112,
	"zealot": 128, "reaver": 128, "moonsister": 112, "spitter": 112, "thornback": 144}
const HERO_LAYERS := ["base", "boots", "armor_light", "armor_medium", "armor_heavy", "belt", "gloves", "helm_hood", "helm_cap",
	"helm_great", "shield_buckler", "shield_kite", "weapon_sword", "weapon_axe", "weapon_mace"]
const SPRITE_ANIMS := ["idle", "walk", "attack", "death", "cast"]
const SPRITE_ANCHOR_Y := 0.8
var _sheets := {}
var _tex_cache := {}
var _rank_mats := {}


func sheet(type: String) -> Dictionary:
	if not _sheets.has(type):
		var t := CanvasTexture.new()
		t.diffuse_texture = load("res://sprites/%s_color.png" % type)
		t.set_meta("normal", "res://sprites/%s_normal.png" % type)
		_set_normal(t)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var layer := type.begins_with("hero_")
		var cell: int = SPRITE_CELLS["hero" if layer else type]
		_sheets[type] = {"tex": t, "glow": null if layer else load("res://sprites/%s_glow.png" % type), "cell": cell,
			"anchor": Vector2(cell * 0.5, cell * SPRITE_ANCHOR_Y)}
	return _sheets[type]


## Forget sheets nothing is using any more (called when an area changes).
func trim_sheets(keep: Array) -> void:
	for k in _sheets.keys():
		if not k.begins_with("hero_") and not k in keep:
			_sheets.erase(k)


## Ground and wall textures: albedo plus normal map, shared by everything that uses them.
func canvas_tex(name: String) -> CanvasTexture:
	if not _tex_cache.has(name):
		var t := CanvasTexture.new()
		t.diffuse_texture = load("res://textures/%s_albedo.png" % name)
		t.set_meta("normal", "res://textures/%s_normal.png" % name)
		_set_normal(t)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		t.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_tex_cache[name] = t
	return _tex_cache[name]


## Recolours a monster by rank: keeps its shading but pulls its hue toward the rank colour.
func rank_material(rank: int) -> ShaderMaterial:
	rank = clampi(rank, 1, RANK_TINTS.size())
	if not _rank_mats.has(rank):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/rank.gdshader")
		m.set_shader_parameter("tint", RANK_TINTS[rank - 1])
		m.set_shader_parameter("amount", 0.0 if rank == 1 else 0.55)
		_rank_mats[rank] = m
	return _rank_mats[rank]


## Diablo II chance to hit: 2 * AR / (AR + DEF) * alvl / (alvl + dlvl), kept within 5 to 95 percent.
func hit_chance(ar: float, def: float, alvl: int, dlvl: int) -> float:
	var c := 2.0 * ar / maxf(1.0, ar + def) * float(alvl) / float(alvl + dlvl)
	return clampf(c, 0.05, 0.95)


## Fire, sparks and embers: additive soft particles with a color ramp and a shrinking size.
func make_fire(amount: int, size: float, colors: Array, lifetime := 0.7, rise := 60.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.texture = soft_dot
	p.material = add_material
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.4
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -rise)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 18.0
	p.scale_amount_min = size / 64.0 * 0.6
	p.scale_amount_max = size / 64.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.25, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in colors.size():
		offs.append(float(i) / (colors.size() - 1))
	g.offsets = offs
	g.colors = PackedColorArray(colors)
	p.color_ramp = g
	return p


const FIRE_COLORS := [Color(1, 0.95, 0.7, 1), Color(1, 0.6, 0.15, 0.9), Color(0.9, 0.2, 0.05, 0.5), Color(0.3, 0.05, 0.0, 0)]


# ---------- input ----------

func _register_inputs() -> void:
	var keys := {
		"drink_heal": [KEY_1, KEY_Q], "drink_mana": [KEY_2, KEY_W],
		"cast_fire": [KEY_F], "cast_nova": [KEY_SPACE],
		"toggle_inv": [KEY_I, KEY_B], "toggle_char": [KEY_C, KEY_A], "toggle_map": [KEY_TAB],
		"town_portal": [KEY_T], "toggle_sound": [KEY_M], "toggle_quality": [KEY_L], "close": [KEY_ESCAPE],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


# ---------- sound ----------

func play(name: String) -> void:
	if muted or not sounds.has(name):
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = sounds[name]
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


func _wav(dur: float, gen: Callable) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var p := float(i) / n
		var env := pow(1.0 - p, 2.0) * minf(1.0, i / 60.0)
		var v: float = gen.call(float(i) / rate, p) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = data
	return s


static func _sweep(t: float, f0: float, f1: float, dur: float) -> float:
	return TAU * (f0 * t + (f1 - f0) * t * t / (2.0 * dur))


func _noise_gen(cut: float) -> Callable:
	# One-pole low-pass filtered noise; state lives in an array so the lambda can mutate it.
	var st := [0.0]
	return func(_t: float, _p: float) -> float:
		st[0] += (randf() * 2.0 - 1.0 - st[0]) * cut
		return st[0] * (1.0 / sqrt(cut))


func _build_sounds() -> void:
	var n_hi := _noise_gen(0.6)
	sounds["swing"] = _wav(0.12, func(t, p): return n_hi.call(t, p) * 0.25)
	var n_lo := _noise_gen(0.12)
	sounds["hit"] = _wav(0.12, func(t, p): return n_lo.call(t, p) * 0.5 + signf(sin(_sweep(t, 120, 60, 0.12))) * 0.15)
	sounds["hurt"] = _wav(0.2, func(t, p): return (fposmod(_sweep(t, 180, 90, 0.2) / TAU, 1.0) * 2.0 - 1.0) * 0.3)
	var n_fire := _noise_gen(0.2)
	sounds["fire"] = _wav(0.35, func(t, p): return n_fire.call(t, p) * 0.45 * sin(p * PI) + (fposmod(_sweep(t, 220, 110, 0.35) / TAU, 1.0) - 0.5) * 0.15)
	var n_boom := _noise_gen(0.06)
	sounds["boom"] = _wav(0.45, func(t, p): return n_boom.call(t, p) * 0.8)
	var n_nova := _noise_gen(0.8)
	sounds["nova"] = _wav(0.5, func(t, p): return n_nova.call(t, p) * 0.12 + sin(_sweep(t, 900, 300, 0.5)) * 0.25)
	sounds["coin"] = _wav(0.18, func(t, p): return signf(sin(TAU * (1600.0 if t < 0.06 else 2200.0) * t)) * 0.12)
	sounds["pick"] = _wav(0.1, func(t, p): return sin(_sweep(t, 500, 800, 0.1)) * 0.35)
	sounds["drink"] = _wav(0.25, func(t, p): return sin(_sweep(t, 300, 700, 0.25)) * 0.35)
	sounds["level"] = _wav(0.7, func(t, p): return sin(TAU * [392.0, 494.0, 587.0, 784.0][mini(3, int(t / 0.12))] * t) * 0.3)
	sounds["die"] = _wav(0.7, func(t, p): return (fposmod(_sweep(t, 150, 40, 0.7) / TAU, 1.0) - 0.5) * 0.4)
	var n_kill := _noise_gen(0.1)
	sounds["kill"] = _wav(0.22, func(t, p): return n_kill.call(t, p) * 0.5)
	sounds["bolt"] = _wav(0.25, func(t, p): return sin(_sweep(t, 700, 200, 0.25)) * 0.25)
