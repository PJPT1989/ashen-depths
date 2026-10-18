class_name SaveGame
extends Node
## Saved heroes, one per planeswalker. On the desktop they are files in user://. In the browser
## they belong to the shop account logged in on the page around the game: the page offers
## window.tomanoGames (shop repo js/game-saves.js), which keeps them in its database. Without a
## login, or outside the shop, the browser game does not save.
## A save is the hero (stats, skills, items, gold) and what he opened in the act (waypoints, ways
## past slain area bosses). Loading starts a new game, like Diablo II: fresh area layouts, monsters
## back, nothing left on the ground, and the hero wakes in Mirewatch.

signal changed   # the list of saves or the login state changed

const GAME := "innistrad-horrors"
const VERSION := 1
const AUTOSAVE_EVERY := 60.0   # seconds of play between autosaves

enum { LOCAL, SHOP, NONE }
var mode := NONE
var listed := false            # the list of saves is known
var signed_in := false
var email := ""
var saves := {}                # class -> {"data": Dictionary, "time": String}
var last_saved := ""           # "" or the time of the last save, for the HUD
var error := ""
var dir := "user://"           # the smoke test points this elsewhere
var _api: JavaScriptObject
var _cbs: Array = []           # JavaScript callbacks must stay referenced until they run
var _timer := AUTOSAVE_EVERY
var main


func _ready() -> void:
	if OS.has_feature("web"):
		var found = JavaScriptBridge.eval("window.tomanoGames = (window.parent !== window && window.parent.tomanoGames) || null; !!window.tomanoGames", true)
		if found:
			_api = JavaScriptBridge.get_interface("tomanoGames")
			mode = SHOP
			refresh()
			return
		mode = NONE
		listed = true
		return
	mode = LOCAL
	refresh()


func can_save() -> bool:
	return mode == LOCAL or (mode == SHOP and signed_in)


## Read the list of saves again (also picks up a login made in another tab).
func refresh() -> void:
	if mode == LOCAL:
		saves.clear()
		for c in Player.CLASS_ORDER:
			if not FileAccess.file_exists(_path(c)):
				continue
			var f := FileAccess.open(_path(c), FileAccess.READ)
			if f == null:
				continue
			var d = decode(f.get_as_text())
			if d is Dictionary:
				saves[c] = {"data": d, "time": Time.get_datetime_string_from_unix_time(f.get_modified_time(_path(c)))}
		listed = true
		changed.emit()
	elif mode == SHOP:
		_api.list(GAME, _callback(_on_list))


func _on_list(args: Array) -> void:
	var r = JSON.parse_string(str(args[0]))
	if not r is Dictionary:
		return
	signed_in = r.get("signed_in", false)
	email = r.get("email", "")
	error = r.get("error", "")
	saves.clear()
	var list: Dictionary = r.get("saves", {})
	for c in list:
		var d = decode(str(list[c].data))
		if d is Dictionary and c in Player.CLASS_ORDER:
			saves[c] = {"data": d, "time": str(list[c].get("updated_at", ""))}
	listed = true
	changed.emit()


## Save the hero now. Only while playing and alive.
func save_now() -> void:
	if main == null or main.state != "play" or main.player.dead or not can_save():
		return
	_timer = AUTOSAVE_EVERY
	var d := snapshot(main)
	var text := encode(d)
	var c: String = d.cls
	saves[c] = {"data": d, "time": Time.get_datetime_string_from_system()}
	if mode == LOCAL:
		var f := FileAccess.open(_path(c), FileAccess.WRITE)
		if f == null:
			error = "Could not write the save file."
			return
		f.store_string(text)
		f.close()
		_saved()
	else:
		_api.save(GAME, c, text, _callback(_on_saved))


func _on_saved(args: Array) -> void:
	var r = JSON.parse_string(str(args[0]))
	if r is Dictionary and r.get("ok", false):
		_saved()
	else:
		error = r.get("error", "Saving failed.") if r is Dictionary else "Saving failed."
		if r is Dictionary and not r.get("signed_in", true):
			signed_in = false
		changed.emit()


func _saved() -> void:
	error = ""
	last_saved = Time.get_time_string_from_system().substr(0, 5)
	changed.emit()


## Throw away the saved hero of class c.
func remove(c: String) -> void:
	saves.erase(c)
	if mode == LOCAL:
		DirAccess.remove_absolute(_path(c))
	elif mode == SHOP and signed_in:
		_api.remove(GAME, c, _callback(func(_a): pass))
	changed.emit()


## Open the shop's login in a new tab; the next save or refresh picks the login up.
func open_login() -> void:
	if mode == SHOP:
		_api.login()


func _process(dt: float) -> void:
	if main == null or main.state != "play":
		return
	_timer -= dt
	if _timer <= 0.0:
		if mode == SHOP and not signed_in:
			_timer = AUTOSAVE_EVERY
			refresh()   # logged in meanwhile in another tab?
		else:
			save_now()


func _path(c: String) -> String:
	return dir.path_join("hero_%s.save" % c)


func _callback(f: Callable) -> JavaScriptObject:
	var cb := JavaScriptBridge.create_callback(f)
	_cbs.append(cb)
	if _cbs.size() > 40:
		_cbs.pop_front()
	return cb


# ---------- what goes into a save ----------

## Everything worth keeping about the hero and the act, as plain data.
static func snapshot(m) -> Dictionary:
	var p: Player = m.player
	var inv: Array = p.inv.duplicate(true)
	if p.held != null:
		inv.append(p.held.duplicate(true))   # put back in the bag on load
	# only what outlasts a game: waypoints and opened ways (like Diablo II, a new game has fresh maps,
	# monsters and an empty floor)
	var areas: Array = []
	for s in m.area_state:
		areas.append({"visited": s.visited, "waypoint": s.waypoint, "opened": s.opened})
	return {"v": VERSION, "cls": p.cls, "level": p.level, "xp": p.xp, "gold": p.gold, "base": p.base.duplicate(),
		"stat_points": p.stat_points, "skill_points": p.skill_points, "skills": p.skills.duplicate(),
		"bar": p.bar.duplicate(), "keys": p.keys.duplicate(), "equip": p.equip.duplicate(true), "inv": inv,
		"belt": p.belt.duplicate(), "hp": p.hp, "mp": p.mp, "area": m.area, "bosses_killed": m.bosses_killed,
		"areas": areas}


## Put a snapshot back: the hero, then the act, then wake in town.
static func restore(m, d: Dictionary) -> void:
	var p: Player = m.player
	p.set_class(d.cls)
	Game.hero_class = d.cls
	p.level = d.level
	p.xp = d.xp
	p.gold = d.gold
	p.base = d.base
	p.stat_points = d.stat_points
	p.skill_points = d.skill_points
	p.skills = d.skills
	p.bar = d.bar
	p.keys = d.keys
	for s in Items.EQUIP_SLOTS:
		p.equip[s] = d.equip.get(s)
	p.inv.clear()
	p.held = null
	for it in d.inv:
		if it.has("gx") and p.grid_fits(it, it.gx, it.gy):
			p.inv.append(it)
		else:
			p.auto_place(it)
	p.belt = d.belt
	p.recalc()
	p.hp = clampf(d.hp, 1.0, p.st.max_hp)
	p.mp = clampf(d.mp, 0.0, p.st.max_mp)
	m.bosses_killed = d.bosses_killed
	m.reset_act()
	if d.areas.size() == Act.count():
		for i in d.areas.size():
			var a: Dictionary = d.areas[i]
			m.area_state[i].visited = a.visited
			m.area_state[i].waypoint = a.waypoint or i == 0
			# saves from before "opened" kept the list of slain bosses instead
			m.area_state[i].opened = a.get("opened", a.has("killed") and a.killed.has("boss"))
	m.dungeon.seen = PackedByteArray()   # so load_area doesn't file the old town over the restored one
	m.state = "play"
	m.load_area(0, "waypoint")


## A save as text. var_to_str keeps Godot's types (whole numbers, colours, positions) exactly.
static func encode(d: Dictionary) -> String:
	return var_to_str(d)


## Text back into a save, or null when it isn't one. Saves only ever hold plain data, so
## anything naming an object or resource is refused before parsing.
static func decode(text: String):
	if text.length() > 4000000 or "Object(" in text or "Resource(" in text:
		return null
	var d = str_to_var(text)
	if not d is Dictionary or d.get("v", 0) != VERSION or not d.get("cls", "") in Player.CLASS_ORDER:
		return null
	for k in ["level", "xp", "gold", "base", "skills", "bar", "keys", "equip", "inv", "belt", "areas"]:
		if not d.has(k):
			return null
	return d


## One line about a saved hero for the title screen: level and the furthest area reached.
static func summary(d: Dictionary) -> String:
	var far := 0
	for i in d.areas.size():
		if d.areas[i].visited:
			far = i
	return "Level %d · %s" % [d.level, Act.area(clampi(far, 0, Act.count() - 1)).name]
