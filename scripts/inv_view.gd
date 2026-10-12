class_name InvView
extends Control
## The hero's paper doll and 10 x 4 inventory grid, or a trader's stock, drawn in code.
## Items are picked up onto the cursor and put down Diablo II style; right-click wears an
## item (or, while trading, sells it). Charms work anywhere in the grid.

const C := 29.0
const SLOT_RECTS := {
	"mainhand": Rect2(8, 40, 58, 116), "helm": Rect2(116, 4, 58, 58), "amulet": Rect2(186, 33, 29, 29),
	"armor": Rect2(116, 70, 58, 87), "offhand": Rect2(224, 40, 58, 116), "gloves": Rect2(8, 166, 58, 58),
	"ring1": Rect2(78, 166, 29, 29), "belt": Rect2(116, 166, 58, 29), "ring2": Rect2(183, 166, 29, 29),
	"boots": Rect2(224, 166, 58, 58),
}
const GRID_Y := 236.0

var hud
var mode := "player"        # player | trade
var role := ""              # trade: which trader
var hover_item = null
var hover_cell := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(C * 10, GRID_Y + C * 4) if mode == "player" else Vector2(C * 10, C * 10)
	mouse_exited.connect(func():
		hover_item = null
		hover_cell = Vector2i(-1, -1)
		hud.hide_tip()
		queue_redraw())


func _player() -> Player:
	return hud.main.player


func _grid_origin() -> Vector2:
	return Vector2(0, GRID_Y) if mode == "player" else Vector2.ZERO


func _grid_size() -> Vector2i:
	return Vector2i(10, 4) if mode == "player" else Vector2i(10, 10)


func _items() -> Array:
	return _player().inv if mode == "player" else hud.main.stock.get(role, [])


func _slot_at(p: Vector2) -> String:
	if mode != "player":
		return ""
	for s in SLOT_RECTS:
		if SLOT_RECTS[s].has_point(p):
			return s
	return ""


func _cell_at(p: Vector2) -> Vector2i:
	var g := (p - _grid_origin()) / C
	var gs := _grid_size()
	if g.x < 0 or g.y < 0 or g.x >= gs.x or g.y >= gs.y:
		return Vector2i(-1, -1)
	return Vector2i(floori(g.x), floori(g.y))


func _item_at(cell: Vector2i):
	for o in _items():
		if Rect2i(o.gx, o.gy, o.w, o.h).has_point(cell):
			return o
	return null


## Where the held item would land: centred on the mouse.
func _drop_cell(p: Vector2, it: Dictionary) -> Vector2i:
	var g := (p - _grid_origin()) / C - Vector2(it.w, it.h) / 2.0 + Vector2(0.5, 0.5)
	return Vector2i(clampi(floori(g.x), 0, 10 - it.w), clampi(floori(g.y), 0, _grid_size().y - it.h))


func _gui_input(e: InputEvent) -> void:
	var p := _player()
	if e is InputEventMouseMotion:
		_update_hover(e.position)
		return
	if not (e is InputEventMouseButton and e.pressed):
		return
	accept_event()
	var pos: Vector2 = e.position
	var slot := _slot_at(pos)
	var cell := _cell_at(pos)
	if mode == "trade":
		if e.button_index == MOUSE_BUTTON_LEFT and p.held != null:
			var it: Dictionary = p.held
			p.held = null
			p.gold += it.value
			Game.play("coin")
		elif cell.x >= 0:
			var it = _item_at(cell)
			if it != null:
				hud.main.buy(role, it)
		hud.refresh()
		_update_hover(pos)
		return
	if e.button_index == MOUSE_BUTTON_LEFT:
		if slot != "":
			p.click_slot(slot)
		elif cell.x >= 0:
			if p.held != null:
				var dc := _drop_cell(pos, p.held)
				if not p.place_held(dc.x, dc.y):
					Game.play("hurt")
			else:
				var it = _item_at(cell)
				if it != null:
					p.remove_from_grid(it)
					p.held = it
					Game.play("pick")
	elif e.button_index == MOUSE_BUTTON_RIGHT and p.held == null:
		if slot != "":
			p.quick_unequip(slot)
		elif cell.x >= 0:
			var it = _item_at(cell)
			if it != null:
				if hud.trading():
					hud.main.sell(it)
				else:
					p.quick_equip(it)
	hud.refresh()
	_update_hover(pos)


func _update_hover(pos: Vector2) -> void:
	var p := _player()
	var it = null
	var slot := _slot_at(pos)
	if slot != "":
		it = p.equip[slot]
	else:
		hover_cell = _cell_at(pos)
		if hover_cell.x >= 0:
			it = _item_at(hover_cell)
	if p.held != null:
		it = null
	if it != hover_item:
		hover_item = it
		if it == null:
			hud.hide_tip()
		else:
			hud.item_tip(it, mode == "trade")
	queue_redraw()


func _draw() -> void:
	var p := _player()
	var edge := Color("4a3f33")
	var cell_bg := Color(0.05, 0.045, 0.04, 0.9)
	if mode == "player":
		for s in SLOT_RECTS:
			var r: Rect2 = SLOT_RECTS[s]
			var it = p.equip[s]
			var bg := cell_bg
			if p.held != null and p.slot_accepts(s, p.held):
				bg = Color(0.1, 0.22, 0.1, 0.9) if p.can_use(p.held) else Color(0.3, 0.06, 0.05, 0.9)
			elif it != null and not p.can_use(it):
				bg = Color(0.3, 0.06, 0.05, 0.9)
			draw_rect(r, bg)
			draw_rect(r, edge, false, 1.0)
			if it != null:
				_draw_item(it, r)
			else:
				var f: Font = Game.font_body
				var label: String = Items.SLOT_NAMES[s]
				var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				draw_string(f, r.get_center() + Vector2(-w / 2.0, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("5c5246"))
	var o := _grid_origin()
	var gs := _grid_size()
	for y in gs.y:
		for x in gs.x:
			var r := Rect2(o + Vector2(x, y) * C, Vector2(C, C))
			draw_rect(r, cell_bg)
			draw_rect(r, Color("2a241e"), false, 1.0)
	# where the held item would go
	if p.held != null and mode == "player" and hover_cell.x >= 0:
		var mp := get_local_mouse_position()
		if _cell_at(mp).x >= 0:
			var dc := _drop_cell(mp, p.held)
			var under := p.items_in(dc.x, dc.y, p.held.w, p.held.h)
			var col := Color(0.15, 0.4, 0.15, 0.5) if under.size() <= 1 else Color(0.5, 0.1, 0.1, 0.5)
			draw_rect(Rect2(o + Vector2(dc) * C, Vector2(p.held.w, p.held.h) * C), col)
	for it in _items():
		var r := Rect2(o + Vector2(it.gx, it.gy) * C, Vector2(it.w, it.h) * C)
		var bg := Color(0.12, 0.1, 0.14, 0.9) if it.rarity != "normal" else Color(0.09, 0.08, 0.07, 0.9)
		if it.get("type", "") != "potion" and not p.can_use(it):
			bg = Color(0.3, 0.06, 0.05, 0.9)
		if it == hover_item:
			bg = bg.lightened(0.12)
		draw_rect(r.grow(-1), bg)
		_draw_item(it, r)


func _draw_item(it: Dictionary, r: Rect2) -> void:
	ItemArt.draw_item(self, it, r)
	if it.rarity != "normal":
		var col: Color = Game.RARITY_COLORS[it.rarity]
		draw_rect(r.grow(-1.5), Color(col, 0.55), false, 1.0)
