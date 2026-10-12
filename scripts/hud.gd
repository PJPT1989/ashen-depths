extends CanvasLayer
## Everything on screen that isn't the world: orbs, belt and skill bar, target bar, messages,
## the character panel (C), the skills panel (S), the inventory (I), trading, waypoints, the
## automap, and the title and death screens. Built in code so it is easy to restyle.

const BONE := Color("ddd3c0")
const MUTED := Color("8f8575")
const GOLD := Color("c8a165")
const EDGE := Color("4a3f33")
const EMBER := Color("e0782e")
const BLUE := Color("8597ff")

var main
var root: Control
var life_orb: Orb
var mana_orb: Orb
var xp_bar: ProgressBar
var hp_btn: Button
var mp_btn: Button
var skill_btns: Array = []     # SkillButton per hotbar slot
var stat_btn: Button
var skills_panel: PanelContainer
var skills_title: Label
var skill_rows: Array = []     # per slot: {pick: OptionButton, rune: OptionButton, desc: Label}
var passive_rows: Array = []   # per passive slot: {pick: OptionButton, desc: Label}
var skills_hint: Label
var level_lbl: Label
var area_lbl: Label
var gold_lbl: Label
var target_box: VBoxContainer
var target_name: Label
var target_sub: Label
var target_bar: ProgressBar
var msg_box: VBoxContainer
var msg_title: Label
var msg_sub: Label
var msg_timer := 0.0
var inv_panel: PanelContainer
var inv_view: InvView
var inv_gold: Label
var inv_hint: Label
var char_panel: PanelContainer
var char_vals := {}
var char_plus := {}
var char_points: Label
var char_head: Label
var char_xp: Label
var trade_panel: PanelContainer
var trade_view: InvView
var trade_title: Label
var wp_panel: PanelContainer
var wp_list: VBoxContainer
var dialog: PanelContainer
var dialog_name: Label
var dialog_text: Label
var tip: PanelContainer
var tip_text: RichTextLabel
var held_view: HeldView
var automap: Automap
var title_screen: Control
var char_title: Label
var dead_screen: Control


## A hotbar slot: skill name, its key, a strip in its element's colour, and a shade that
## shrinks as the cooldown runs out. Dim when the hero can't pay for it.
class SkillButton extends Button:
	var hud
	var slot := 0
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var p: Player = hud.main.player
		var id: String = p.bar[slot]
		if id == "":
			return
		var sk := Skills.resolve(id, p.runes.get(id, -1))
		draw_rect(Rect2(2, 2, size.x - 4, 3), Player.elem_color(sk.get("elem", "phys")) if sk.has("elem") else Skills.RESOURCE[p.cls].color)
		var cd: float = p.cds.get(id, 0.0)
		var full: float = sk.get("cd", 0.0) * p.fx.get("cdr", 1.0)
		if cd > 0.0 and full > 0.0:
			draw_rect(Rect2(1, 1, size.x - 2, (size.y - 2) * cd / full), Color(0, 0, 0, 0.6))
		if p.mp < p.skill_cost(sk):
			draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Color(0.05, 0.08, 0.3, 0.45))


## Draws the item on the cursor.
class HeldView extends Control:
	var hud
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = true
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var it = hud.main.player.held
		if it == null:
			return
		var s := Vector2(it.w, it.h) * InvView.C
		ItemArt.draw_item(self, it, Rect2(get_local_mouse_position() - s / 2.0, s))


func setup(m) -> void:
	main = m
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	automap = Automap.new()
	automap.main = main
	automap.visible = false
	root.add_child(automap)
	_build_bottom_bar()
	_build_target()
	_build_message()
	_build_inventory()
	_build_character()
	_build_skills()
	_build_trade()
	_build_waypoints()
	_build_dialog()
	_build_tip()
	held_view = HeldView.new()
	held_view.hud = self
	held_view.size = Vector2(1, 1)
	root.add_child(held_view)
	title_screen = _build_title()
	dead_screen = _build_dead()
	dead_screen.visible = false
	main.player.stats_changed.connect(refresh)
	refresh()


# ---------- theme ----------

func _box(bg: Color, border: Color, bw := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(8)
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Game.font_body
	t.default_font_size = 15
	t.set_color("font_color", "Label", BONE)
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.09, 0.075, 0.06, 0.96), EDGE))
	t.set_stylebox("normal", "Button", _box(Color("0e0c0a"), EDGE))
	t.set_stylebox("hover", "Button", _box(Color("1d1712"), GOLD))
	t.set_stylebox("pressed", "Button", _box(Color("2a2018"), GOLD))
	t.set_stylebox("disabled", "Button", _box(Color("0e0c0a"), Color("2a241e")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", BONE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("5a5248"))
	t.set_font_size("font_size", "Button", 13)
	t.set_stylebox("background", "ProgressBar", _box(Color("0b0908"), Color("3b3229")))
	t.set_color("default_color", "RichTextLabel", BONE)
	t.set_font("bold_font", "RichTextLabel", Game.font_bold)
	t.set_font_size("normal_font_size", "RichTextLabel", 14)
	t.set_font_size("bold_font_size", "RichTextLabel", 15)
	return t


func _label(text: String, size := 15, color := BONE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	return s


func _panel_head(v: VBoxContainer, title: String, close: Callable) -> Label:
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := _label(title, 28, GOLD, Game.font_display)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(_button("×", close))
	return t


# ---------- bottom bar ----------

func _build_bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position.y = -12
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	life_orb = Orb.new()
	bar.add_child(life_orb)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.custom_minimum_size = Vector2(900, 0)
	bar.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 7)
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("fill", _fill(Color("c8a24e")))
	col.add_child(xp_bar)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 5)
	col.add_child(slots)
	hp_btn = _button("", func(): main.player.drink("hp"))
	mp_btn = _button("", func(): main.player.drink("mp"))
	hp_btn.add_theme_color_override("font_color", Color("ff7b7b"))
	mp_btn.add_theme_color_override("font_color", Color("9db0ff"))
	for b in [hp_btn, mp_btn]:
		b.custom_minimum_size = Vector2(62, 44)
		slots.add_child(b)
	for i in Skills.SLOT_KEYS.size():
		var sb := SkillButton.new()
		sb.hud = self
		sb.slot = i
		sb.focus_mode = Control.FOCUS_NONE
		sb.custom_minimum_size = Vector2(86, 44)
		sb.add_theme_font_size_override("font_size", 12)
		sb.pressed.connect(func(): toggle_skills(true))
		sb.mouse_entered.connect(func(): _skill_tip(i))
		sb.mouse_exited.connect(hide_tip)
		slots.add_child(sb)
		skill_btns.append(sb)
	stat_btn = _button("Char\nC", toggle_char)
	var sk_btn := _button("Skills\nS", func(): toggle_skills())
	var bag_btn := _button("Bag\nI", toggle_inv)
	var map_btn := _button("Map\nTab", toggle_map)
	var tp_btn := _button("Portal\nT", func(): main.open_town_portal())
	for b in [stat_btn, sk_btn, bag_btn, map_btn, tp_btn]:
		b.custom_minimum_size = Vector2(54, 44)
		slots.add_child(b)
	var info := HBoxContainer.new()
	col.add_child(info)
	level_lbl = _label("", 13, MUTED)
	area_lbl = _label("", 13, MUTED)
	gold_lbl = _label("", 13, MUTED)
	area_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l in [level_lbl, area_lbl, gold_lbl]:
		info.add_child(l)

	mana_orb = Orb.new()
	mana_orb.top_color = Color("7090ff")
	mana_orb.deep_color = Color("0a1550")
	bar.add_child(mana_orb)


func _build_target() -> void:
	target_box = VBoxContainer.new()
	target_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	target_box.position.y = 14
	target_box.custom_minimum_size = Vector2(340, 0)
	target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_box.add_theme_constant_override("separation", 2)
	root.add_child(target_box)
	target_name = _label("", 22, BONE, Game.font_display)
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_name.add_theme_color_override("font_shadow_color", Color.BLACK)
	target_box.add_child(target_name)
	target_bar = ProgressBar.new()
	target_bar.custom_minimum_size = Vector2(340, 9)
	target_bar.show_percentage = false
	target_bar.add_theme_stylebox_override("fill", _fill(Color("a51d1d")))
	target_bar.add_theme_stylebox_override("background", _box(Color("1a0606"), Color("5a1a1a")))
	target_box.add_child(target_bar)
	target_sub = _label("", 13, MUTED)
	target_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_sub.add_theme_color_override("font_shadow_color", Color.BLACK)
	target_box.add_child(target_sub)
	target_box.visible = false


func _build_message() -> void:
	msg_box = VBoxContainer.new()
	msg_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	msg_box.position.y = 150
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg_box)
	msg_title = _label("", 44, GOLD, Game.font_display)
	msg_sub = _label("", 17, BONE)
	for l in [msg_title, msg_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("shadow_offset_y", 3)
		msg_box.add_child(l)
	msg_box.modulate.a = 0.0


# ---------- inventory ----------

func _build_inventory() -> void:
	inv_panel = PanelContainer.new()
	inv_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inv_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	inv_panel.position = Vector2(-16, 16)
	inv_panel.visible = false
	root.add_child(inv_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	inv_panel.add_child(v)
	_panel_head(v, "Inventory", func(): toggle_inv(false))
	inv_view = InvView.new()
	inv_view.hud = self
	inv_view.mode = "player"
	v.add_child(inv_view)
	inv_gold = _label("", 15, Color("e2c26a"))
	v.add_child(inv_gold)
	inv_hint = _label("", 12, MUTED)
	inv_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_hint.custom_minimum_size = Vector2(290, 0)
	v.add_child(inv_hint)


# ---------- character ----------

const STAT_NAMES := {"str": "Strength", "dex": "Dexterity", "vit": "Vitality", "ene": "Energy"}
const STAT_HELP := {"str": "+1% weapon damage", "dex": "+5 attack rating, block", "vit": "+%d life", "ene": "+%d mana"}
const DERIVED := ["Damage", "Attack Rating", "Chance to Hit", "Defense", "Chance to Block", "Attacks per Second", "Life", "Mana",
	"Fire Resist", "Cold Resist", "Lightning Resist", "Poison Resist", "Run Speed", "Magic Find", "Spell Damage"]
var char_help := {}


func _build_character() -> void:
	char_panel = PanelContainer.new()
	char_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	char_panel.position = Vector2(16, 16)
	char_panel.custom_minimum_size = Vector2(320, 0)
	char_panel.visible = false
	root.add_child(char_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	char_panel.add_child(v)
	char_title = _panel_head(v, "", func(): toggle_char(false))
	char_head = _label("", 15, BONE)
	v.add_child(char_head)
	char_xp = _label("", 13, MUTED)
	v.add_child(char_xp)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	v.add_child(g)
	for k in STAT_NAMES:
		var n := _label(STAT_NAMES[k], 16, BONE, Game.font_bold)
		n.custom_minimum_size = Vector2(90, 0)
		g.add_child(n)
		var val := _label("", 16)
		val.custom_minimum_size = Vector2(36, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(val)
		char_vals[k] = val
		var plus := _button("+", func(): main.player.add_stat(k))
		plus.custom_minimum_size = Vector2(28, 26)
		g.add_child(plus)
		char_plus[k] = plus
		char_help[k] = _label(STAT_HELP[k], 12, MUTED)
		g.add_child(char_help[k])
	char_points = _label("", 15, Color("f2d25c"))
	v.add_child(char_points)
	v.add_child(HSeparator.new())
	var d := GridContainer.new()
	d.columns = 2
	d.add_theme_constant_override("h_separation", 24)
	d.add_theme_constant_override("v_separation", 1)
	v.add_child(d)
	for k in DERIVED:
		var name_lbl := _label(k, 14, MUTED)
		char_vals[k + "_name"] = name_lbl
		d.add_child(name_lbl)
		var val := _label("", 14)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.add_child(val)
		char_vals[k] = val


func _refresh_character() -> void:
	var p: Player = main.player
	var s: Dictionary = p.st
	var c: Dictionary = Player.CLASSES[p.cls]
	char_title.text = c.name
	char_help.vit.text = "+%d life" % c.life_vit
	char_help.ene.text = ("+%d mana" % c.mana_ene) if p.cls != "ajani" else "no effect on Ferocity"
	char_vals["Mana_name"].text = Skills.RESOURCE[p.cls].name
	char_head.text = "Level %d" % p.level
	char_xp.text = "Experience %d / %d" % [p.xp, Player.xp_needed(p.level)]
	for k in STAT_NAMES:
		var lbl: Label = char_vals[k]
		lbl.text = str(s[k])
		lbl.add_theme_color_override("font_color", BLUE if s[k] != p.base[k] else BONE)
		char_plus[k].disabled = p.stat_points <= 0
		char_plus[k].modulate.a = 1.0 if p.stat_points > 0 else 0.0
	char_points.text = ("Stat points to spend: %d" % p.stat_points) if p.stat_points > 0 else ""
	var rank: int = maxi(1, Act.area(main.area).rank)
	var hit := Game.hit_chance(s.ar, 4 + Act.mlvl(rank) * 5, p.level, Act.mlvl(rank))
	var vals := {
		"Damage": "%d-%d" % [s.dmg_min, s.dmg_max], "Attack Rating": str(s.ar),
		"Chance to Hit": "%d%% vs rank %d" % [roundi(hit * 100), rank], "Defense": str(s.def),
		"Chance to Block": "%d%%" % s.block, "Attacks per Second": "%.2f" % (1.0 / s.atk_time),
		"Life": "%d / %d" % [ceili(p.hp), s.max_hp], "Mana": "%d / %d" % [floori(p.mp), s.max_mp],
		"Fire Resist": "%d%%" % s.res_fire, "Cold Resist": "%d%%" % s.res_cold, "Lightning Resist": "%d%%" % s.res_lit,
		"Poison Resist": "%d%%" % s.res_pois, "Run Speed": "+%d%%" % roundi((s.speed / Player.SPEED - 1.0) * 100),
		"Magic Find": "%d%%" % s.mf, "Spell Damage": "%d-%d" % [s.spell_dmg[0], s.spell_dmg[1]],
	}
	for k in vals:
		char_vals[k].text = vals[k]


# ---------- skills ----------

func _build_skills() -> void:
	skills_panel = PanelContainer.new()
	skills_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	skills_panel.position = Vector2(16, 16)
	skills_panel.custom_minimum_size = Vector2(600, 0)
	skills_panel.visible = false
	root.add_child(skills_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	skills_panel.add_child(v)
	skills_title = _panel_head(v, "Skills", func(): toggle_skills(false))
	for i in Skills.SLOT_KEYS.size():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		v.add_child(h)
		var key := _label(["Left click", "Right click", "Key 1", "Key 2", "Key 3", "Key 4"][i], 14, GOLD, Game.font_bold)
		key.custom_minimum_size = Vector2(84, 0)
		h.add_child(key)
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.custom_minimum_size = Vector2(250, 0)
		pick.item_selected.connect(func(idx): _pick_skill(i, idx))
		h.add_child(pick)
		var rune := OptionButton.new()
		rune.focus_mode = Control.FOCUS_NONE
		rune.custom_minimum_size = Vector2(230, 0)
		rune.item_selected.connect(func(idx): _pick_rune(i, idx))
		h.add_child(rune)
		var desc := _label("", 12, MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(580, 0)
		v.add_child(desc)
		skill_rows.append({"pick": pick, "rune": rune, "desc": desc})
	v.add_child(HSeparator.new())
	v.add_child(_label("Passives", 18, GOLD, Game.font_display))
	for i in Skills.PASSIVE_SLOTS.size():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		v.add_child(h)
		var pick := OptionButton.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.custom_minimum_size = Vector2(250, 0)
		pick.item_selected.connect(func(idx): _pick_passive(i, idx))
		h.add_child(pick)
		var desc := _label("", 12, MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(desc)
		passive_rows.append({"pick": pick, "desc": desc})
	skills_hint = _label("New skills, runes and passives unlock as you gain levels. A rune changes how its skill works.", 12, MUTED)
	skills_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_hint.custom_minimum_size = Vector2(580, 0)
	v.add_child(skills_hint)


## Fill the lists from the hero: unlocked choices are enabled, locked ones show their level.
func _refresh_skills() -> void:
	var p: Player = main.player
	var hero := p.cls
	skills_title.text = "Skills · %s" % Player.CLASSES[hero].name
	var cats: Array = Skills.CATEGORIES[hero]
	for i in skill_rows.size():
		var row: Dictionary = skill_rows[i]
		var pick: OptionButton = row.pick
		pick.clear()
		pick.add_item("(empty)")
		pick.set_item_metadata(0, "")
		var sel := 0
		for id in Skills.of_hero(hero):
			var sk: Dictionary = Skills.SKILLS[id]
			var n := pick.item_count
			pick.add_item("%s: %s%s" % [cats[sk.cat], sk.name, "" if p.level >= sk.lvl else "  (level %d)" % sk.lvl])
			pick.set_item_metadata(n, id)
			pick.set_item_disabled(n, p.level < sk.lvl)
			if p.bar[i] == id:
				sel = n
		pick.select(sel)
		var rune: OptionButton = row.rune
		rune.clear()
		var id: String = p.bar[i]
		if id == "":
			rune.disabled = true
			row.desc.text = ""
			continue
		rune.disabled = false
		rune.add_item("No rune")
		var sk: Dictionary = Skills.SKILLS[id]
		for r in sk.runes:
			var n := rune.item_count
			rune.add_item("%s%s" % [r.name, "" if p.level >= r.lvl else "  (level %d)" % r.lvl])
			rune.set_item_disabled(n, p.level < r.lvl)
		var cur: int = p.runes.get(id, -1)
		rune.select(cur + 1)
		row.desc.text = _skill_text(id, cur)
	var open := Skills.passive_slots(p.level)
	for i in passive_rows.size():
		var row: Dictionary = passive_rows[i]
		var pick: OptionButton = row.pick
		pick.clear()
		if i >= open:
			pick.add_item("Opens at level %d" % Skills.PASSIVE_SLOTS[i])
			pick.disabled = true
			row.desc.text = ""
			continue
		pick.disabled = false
		pick.add_item("(empty)")
		pick.set_item_metadata(0, "")
		var cur: String = p.passives[i] if i < p.passives.size() else ""
		var sel := 0
		for id in Skills.passives_of(p.cls):
			var ps: Dictionary = Skills.PASSIVES[id]
			var n := pick.item_count
			pick.add_item("%s%s" % [ps.name, "" if p.level >= ps.lvl else "  (level %d)" % ps.lvl])
			pick.set_item_metadata(n, id)
			pick.set_item_disabled(n, p.level < ps.lvl or (id in p.passives and id != cur))
			if id == cur:
				sel = n
		pick.select(sel)
		row.desc.text = Skills.PASSIVES[cur].desc if cur != "" else ""


func _pick_skill(i: int, idx: int) -> void:
	main.player.set_slot(i, skill_rows[i].pick.get_item_metadata(idx))
	_refresh_skills()


func _pick_rune(i: int, idx: int) -> void:
	var id: String = main.player.bar[i]
	if id != "":
		main.player.set_rune(id, idx - 1)
	_refresh_skills()


func _pick_passive(i: int, idx: int) -> void:
	main.player.set_passive(i, passive_rows[i].pick.get_item_metadata(idx))
	_refresh_skills()


## What a skill does with rune r, its cost and cooldown.
func _skill_text(id: String, r: int) -> String:
	var sk: Dictionary = Skills.SKILLS[id]
	var t: String = sk.desc
	if r >= 0:
		t += " Rune %s: %s" % [sk.runes[r].name, sk.runes[r].desc]
	var s := Skills.resolve(id, r)
	var bits: Array = []
	if s.get("cd", 0) > 0:
		bits.append("cooldown %ss" % str(s.cd))
	if s.get("gen", 0) > 0:
		bits.append("builds %d" % s.gen)
	if not bits.is_empty():
		t += " (" + ", ".join(bits) + ")"
	return t


func _skill_tip(i: int) -> void:
	var p: Player = main.player
	var id: String = p.bar[i]
	if id == "":
		tip_text.text = "[center][b]Empty slot[/b][/center]\nClick to choose a skill."
	else:
		var r: int = p.runes.get(id, -1)
		var head: String = Skills.SKILLS[id].name + ("  ·  " + Skills.SKILLS[id].runes[r].name if r >= 0 else "")
		tip_text.text = "[center][b]%s[/b][/center]\n%s\n[color=#8f8575]Click to change.[/color]" % [head, _skill_text(id, r)]
	tip.visible = true
	tip.reset_size()


# ---------- trade, waypoints, talk ----------

func _build_trade() -> void:
	trade_panel = PanelContainer.new()
	trade_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	trade_panel.position = Vector2(16, 16)
	trade_panel.visible = false
	root.add_child(trade_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	trade_panel.add_child(v)
	trade_title = _panel_head(v, "Trade", func(): close_panels())
	trade_view = InvView.new()
	trade_view.hud = self
	trade_view.mode = "trade"
	v.add_child(trade_view)
	var hint := _label("Click to buy. Right-click your own items to sell them, or drop the item on your cursor here.", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(290, 0)
	v.add_child(hint)


func _build_waypoints() -> void:
	wp_panel = PanelContainer.new()
	wp_panel.set_anchors_preset(Control.PRESET_CENTER)
	wp_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wp_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	wp_panel.custom_minimum_size = Vector2(340, 0)
	wp_panel.visible = false
	root.add_child(wp_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	wp_panel.add_child(v)
	_panel_head(v, "Waypoints", func(): wp_panel.visible = false)
	v.add_child(_label("Act I", 13, MUTED))
	wp_list = VBoxContainer.new()
	wp_list.add_theme_constant_override("separation", 4)
	v.add_child(wp_list)


func show_waypoints() -> void:
	for c in wp_list.get_children():
		c.queue_free()
	for i in Act.count():
		var known: bool = main.area_state[i].waypoint
		var b := _button(Act.area(i).name if known else "· · ·", func(): main.waypoint_travel(i))
		b.disabled = not known or i == main.area
		b.custom_minimum_size = Vector2(300, 32)
		if i == main.area:
			b.text += "   (you are here)"
		wp_list.add_child(b)
	wp_panel.visible = true


func _build_dialog() -> void:
	dialog = PanelContainer.new()
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	dialog.custom_minimum_size = Vector2(460, 0)
	dialog.visible = false
	root.add_child(dialog)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	dialog.add_child(v)
	dialog_name = _panel_head(v, "", func(): dialog.visible = false)
	dialog_text = _label("", 16)
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.custom_minimum_size = Vector2(440, 0)
	v.add_child(dialog_text)


func show_dialog(who: String, text: String) -> void:
	dialog_name.text = who
	dialog_text.text = text
	dialog.visible = true


var _trade_role := ""


func open_trade(role: String, who: String) -> void:
	_trade_role = role
	trade_view.role = role
	trade_title.text = who
	char_panel.visible = false
	trade_panel.visible = true
	inv_panel.visible = true
	refresh()


func trading() -> bool:
	return trade_panel.visible


# ---------- tooltip ----------

func _build_tip() -> void:
	tip = PanelContainer.new()
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_theme_stylebox_override("panel", _box(Color(0.03, 0.025, 0.02, 0.95), EDGE))
	tip_text = RichTextLabel.new()
	tip_text.bbcode_enabled = true
	tip_text.fit_content = true
	tip_text.custom_minimum_size = Vector2(270, 0)
	tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(tip_text)
	tip.visible = false
	tip.top_level = true
	root.add_child(tip)


func item_tip(it: Dictionary, in_shop: bool) -> void:
	var s := ""
	if it.type == "potion":
		s = "[center][b]%s[/b]\nGoes into your belt\n" % it.name
	else:
		s = Items.describe(it, main.player)
	if in_shop:
		s += "\n[center][color=#e2c26a]Buy for %d gold[/color][/center]" % main.buy_price(it)
	elif trading() and it.type != "potion":
		s += "\n[center][color=#e2c26a]Right-click to sell for %d gold[/color][/center]" % it.value
	tip_text.text = s
	tip.visible = true
	tip.reset_size()


func hide_tip() -> void:
	tip.visible = false


# ---------- panels ----------

func refresh() -> void:
	if main == null or inv_panel == null:
		return
	var p: Player = main.player
	if inv_panel.visible:
		inv_view.queue_redraw()
		inv_gold.text = "%d gold" % p.gold
		inv_hint.text = "Click to pick up and put down. Right-click to wear an item. Charms work while carried. Click the ground to drop what you hold."
	if trade_panel.visible:
		trade_view.queue_redraw()
	if char_panel.visible:
		_refresh_character()
	if skills_panel.visible:
		_refresh_skills()


func toggle_inv(force = null) -> void:
	inv_panel.visible = (not inv_panel.visible) if force == null else force
	if not inv_panel.visible:
		trade_panel.visible = false
		hide_tip()
	refresh()


func toggle_char(force = null) -> void:
	char_panel.visible = (not char_panel.visible) if force == null else force
	if char_panel.visible:
		trade_panel.visible = false
		skills_panel.visible = false
	refresh()


func toggle_skills(force = null) -> void:
	skills_panel.visible = (not skills_panel.visible) if force == null else force
	if skills_panel.visible:
		char_panel.visible = false
		trade_panel.visible = false
		_refresh_skills()


func toggle_map() -> void:
	automap.visible = not automap.visible


func close_panels() -> void:
	inv_panel.visible = false
	char_panel.visible = false
	skills_panel.visible = false
	trade_panel.visible = false
	wp_panel.visible = false
	dialog.visible = false
	automap.visible = false
	hide_tip()


# ---------- overlays ----------

func _overlay() -> Control:
	var o := ColorRect.new()
	o.color = Color(0.02, 0.015, 0.025, 0.86)
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(o)
	return o


func _build_title() -> Control:
	var o := _overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	var t := _label("Ashen Depths", 84, EMBER, Game.font_display)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color("2a0c04"))
	t.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(t)
	var sub := _label("Act I · The Black Mire", 26, GOLD, Game.font_display)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var lore := _label("Sheoldred, the Apocalypse stirs beneath the swamp, and her oil raises the dead.\nFrom Mirewatch, eight roads lead down into the black mire.", 17, Color("c9b99a"))
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lore)
	var keys := GridContainer.new()
	keys.columns = 4
	keys.add_theme_constant_override("h_separation", 18)
	keys.add_theme_constant_override("v_separation", 2)
	var kc := CenterContainer.new()
	kc.add_child(keys)
	v.add_child(kc)
	for row in [["Left click", "Walk; on a foe, use your left-click skill"], ["Right click", "Use your right-click skill"],
			["1 · 2 · 3 · 4", "Use the skills on those keys"], ["Q · W", "Drink healing or mana draught"],
			["S", "Skills: choose skills, runes, passives"], ["C · I · Tab", "Character, inventory, map"],
			["T · M", "Town portal, sound"], ["L", "Graphics quality: low, medium, high"]]:
		keys.add_child(_label(row[0], 14, BONE, Game.font_bold))
		keys.add_child(_label(row[1], 14, MUTED))
	var goal := _label("Cross the eight areas of Act I. Each one ends with a boss who seals the way on.", 16)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(goal)
	var pick := _label("Choose your planeswalker", 26, GOLD, Game.font_display)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pick)
	var heroes := HBoxContainer.new()
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes.add_theme_constant_override("separation", 18)
	v.add_child(heroes)
	for c in Player.CLASS_ORDER:
		heroes.add_child(_hero_card(c))
	var q := _button("", func(): Game.set_quality((Game.quality + 1) % 3))
	q.add_theme_font_size_override("font_size", 14)
	q.add_theme_color_override("font_color", MUTED)
	q.flat = true
	var show_q := func(): q.text = "Quality: %s (L)" % ["low, for slow computers", "medium", "high, for fast computers"][Game.quality]
	show_q.call()
	Game.quality_changed.connect(show_q)
	var qc := CenterContainer.new()
	qc.add_child(q)
	v.add_child(qc)
	return o


func _build_dead() -> Control:
	var o := _overlay()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	var t := _label("You have fallen", 84, Color("c22a2a"), Game.font_display)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label("The mire keeps a tithe of your gold. You wake by the fire in Mirewatch.", 17)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var bc := CenterContainer.new()
	bc.add_child(_big_button("Rise again", func():
		dead_screen.visible = false
		main.revive()))
	v.add_child(bc)
	return o


## One planeswalker on the title screen: a picture from the baked sheet, name, role and
## starting attributes. Clicking it starts the game as that hero.
func _hero_card(c: String) -> Button:
	var d: Dictionary = Player.CLASSES[c]
	var b := _button("", func():
		title_screen.visible = false
		main.start_game(c))
	b.custom_minimum_size = Vector2(250, 262)
	var n := _box(Color("1d0f0c"), Color("6b3a22"))
	var h := _box(Color("3a160b"), Color("c8653a"))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 6
	v.offset_bottom = -10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	# idle frame facing the camera (row 2), cropped to the figure
	var cell: int = Game.SPRITE_CELLS.hero
	var at := AtlasTexture.new()
	at.atlas = load("res://sprites/hero_base_%s_color.png" % c)
	at.region = Rect2(cell * 0.2, 2 * cell + cell * 0.12, cell * 0.6, cell * 0.74)
	var pic := TextureRect.new()
	pic.texture = at
	pic.custom_minimum_size = Vector2(0, 140)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	var name := _label(d.name, 26, EMBER, Game.font_display)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name)
	var role := _label(d.role, 14, Color("c9b99a"))
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(role)
	var st: Dictionary = d.stats
	var stats := _label("Str %d · Dex %d · Vit %d · Ene %d" % [st.str, st.dex, st.vit, st.ene], 13, MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats)
	return b


func _big_button(text: String, cb: Callable) -> Button:
	var b := _button(text, cb)
	b.add_theme_font_override("font", Game.font_display)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color("ffe2c4"))
	var n := _box(Color("5a1a0b"), Color("c8653a"))
	n.set_content_margin_all(12)
	n.content_margin_left = 36
	n.content_margin_right = 36
	var h := n.duplicate()
	h.bg_color = Color("7b2410")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	return b


func show_dead() -> void:
	close_panels()
	dead_screen.visible = true


func show_msg(title: String, sub: String, dur: float) -> void:
	msg_title.text = title
	msg_sub.text = sub
	msg_timer = dur
	msg_box.modulate.a = 1.0


# ---------- per frame ----------

func _process(dt: float) -> void:
	if main == null:
		return
	var p: Player = main.player
	var s: Dictionary = p.st
	life_orb.fraction = p.hp / s.max_hp
	life_orb.text = "%d/%d" % [ceili(p.hp), s.max_hp]
	life_orb.top_color = Color("6ab04a") if p.poison_t > 0.0 else Color("e44a4e")
	life_orb.queue_redraw()
	mana_orb.fraction = p.mp / s.max_mp
	mana_orb.text = "%d/%d" % [floori(p.mp), s.max_mp]
	var rc: Color = Skills.RESOURCE[p.cls].color
	mana_orb.top_color = rc
	mana_orb.deep_color = rc.darkened(0.85)
	mana_orb.queue_redraw()
	xp_bar.max_value = Player.xp_needed(p.level)
	xp_bar.value = p.xp
	hp_btn.text = "%d/%d\nHeal · Q" % [p.belt.hp, s.belt_cap]
	mp_btn.text = "%d/%d\nMana · W" % [p.belt.mp, s.belt_cap]
	for i in skill_btns.size():
		var id: String = p.bar[i]
		var key: String = ["Left", "Right", "1", "2", "3", "4"][i]
		skill_btns[i].text = ("%s\n%s" % [Skills.SKILLS[id].name, key]) if id != "" else "empty\n" + key
		skill_btns[i].modulate.a = 1.0 if id != "" else 0.5
	stat_btn.text = "Char\n" + ("+%d" % p.stat_points if p.stat_points > 0 else "C")
	stat_btn.modulate = Color(1.3, 1.15, 0.6) if p.stat_points > 0 and fmod(Time.get_ticks_msec() / 600.0, 2.0) < 1.0 else Color.WHITE
	level_lbl.text = "Level %d" % p.level
	area_lbl.text = Act.area(main.area).name
	gold_lbl.text = "%d gold" % p.gold
	if char_panel.visible:
		_refresh_character()
	var tm: Monster = null
	if main.state == "play":
		if main.hovered_monster:
			tm = main.hovered_monster
		elif p.target_monster and is_instance_valid(p.target_monster):
			tm = p.target_monster
		elif main.boss and main.boss.aggro and main.boss.wpos.distance_to(p.wpos) < 10.0:
			tm = main.boss
	target_box.visible = tm != null
	if tm:
		target_name.text = tm.display_name
		target_name.add_theme_color_override("font_color", GOLD if tm.is_boss or tm.champion else BONE)
		target_bar.max_value = tm.max_hp
		target_bar.value = maxi(0, tm.hp)
		var bits: Array = []
		if tm.is_boss:
			bits.append("Boss")
		elif tm.champion:
			bits.append("Unique " + Monster.type_name(tm.kind, tm.rank))
		elif tm.role == "minion":
			bits.append("Minion")
		bits.append("Rank %d" % tm.rank)
		for m in tm.mods:
			bits.append(Monster.MODS[m])
		target_sub.text = " · ".join(PackedStringArray(bits))
	if msg_timer > 0.0:
		msg_timer -= dt
		msg_box.modulate.a = clampf(msg_timer * 2.0, 0.0, 1.0)
	if tip.visible:
		var mp := root.get_global_mouse_position()
		var vs := root.get_viewport_rect().size
		var x := mp.x - tip.size.x - 18.0
		if x < 8.0:
			x = mp.x + 18.0
		tip.position = Vector2(clampf(x, 8.0, vs.x - tip.size.x - 8.0), clampf(mp.y - 10.0, 8.0, vs.y - tip.size.y - 8.0))
