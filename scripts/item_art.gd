class_name ItemArt
extends RefCounted
## Inventory pictures, painted in code. Every item has a seed, so two swords of the same kind
## still differ: blade width and tip, guard, grip wrap, pommel, gems, rivets, trim and so on.
## The item's tint colours its main material. Coordinates are in the unit box of the item's
## inventory cell block (0..1 across, 0..1 down).

var ci: CanvasItem
var r: Rect2
var it: Dictionary
var rng := RandomNumberGenerator.new()
var tint: Color

const GEMS := [Color("d8352a"), Color("3a7be0"), Color("40b860"), Color("e0c040"), Color("a050d0"), Color("e8e8f0"), Color("e07a20")]
const WOOD := Color(0.42, 0.28, 0.16)
const LEATHER := Color(0.36, 0.24, 0.15)


static func draw_item(canvas: CanvasItem, item: Dictionary, rect: Rect2) -> void:
	var a := ItemArt.new()
	a.ci = canvas
	a.it = item
	a.r = rect.grow(-rect.size.x * 0.06)
	a.tint = item.tint
	a.rng.seed = item.seed
	a.paint()


func P(x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)


## Filled polygon lit from the top left, with a dark outline.
func shape(pts: Array, col: Color, outline := true) -> void:
	var arr := PackedVector2Array()
	var c := Vector2.ZERO
	for p in pts:
		var v := P(p[0], p[1])
		arr.append(v)
		c += v
	c /= pts.size()
	var ext := maxf(4.0, r.size.length() * 0.35)
	var cols := PackedColorArray()
	for v in arr:
		var k := clampf((v - c).dot(Vector2(-0.6, -0.8)) / ext, -1.0, 1.0)
		var vc := col.lightened(k * 0.3) if k > 0.0 else col.darkened(-k * 0.35)
		cols.append(vc)
	if Geometry2D.triangulate_polygon(arr).is_empty():
		return
	ci.draw_polygon(arr, cols)
	if outline:
		var o := arr.duplicate()
		o.append(arr[0])
		ci.draw_polyline(o, col.darkened(0.65), 1.0, true)


func line(x1: float, y1: float, x2: float, y2: float, col: Color, w := 1.0) -> void:
	ci.draw_line(P(x1, y1), P(x2, y2), col, w, true)


func dot(x: float, y: float, rad: float, col: Color) -> void:
	ci.draw_circle(P(x, y), rad, col)


func gem(x: float, y: float, rad: float) -> void:
	var g: Color = GEMS[rng.randi() % GEMS.size()]
	var c := P(x, y)
	ci.draw_circle(c, rad + 1.0, g.darkened(0.6))
	ci.draw_circle(c, rad, g)
	ci.draw_circle(c - Vector2(rad, rad) * 0.35, rad * 0.35, g.lightened(0.6))


func ellipse_pts(cx: float, cy: float, rx: float, ry: float, n := 20, a0 := 0.0, a1 := TAU) -> Array:
	var out := []
	for i in n + 1:
		var a := a0 + (a1 - a0) * i / n
		out.append([cx + cos(a) * rx, cy + sin(a) * ry])
	return out


func paint() -> void:
	match it.art:
		"sword": _sword()
		"axe": _axe()
		"club": _club()
		"mace": _mace()
		"pick": _pick()
		"flail": _flail()
		"hammer": _hammer()
		"round": _round_shield()
		"heater", "kite", "tower": _shield(it.art)
		"quilted", "leather", "studded", "mail", "scale", "plate": _armor(it.art)
		"hood", "skullcap", "nasal", "full", "crown": _helm(it.art)
		"gloves", "gauntlets": _gloves(it.art == "gauntlets")
		"sash", "belt", "plated_belt": _belt(it.art)
		"boots", "greaves": _boots(it.art == "greaves")
		"amulet": _amulet()
		"ring": _ring()
		"charm_small", "charm_large", "charm_grand": _charm(it.art)
		"potion_hp", "potion_mp": _potion()


# ---------- weapons ----------

func _grip(x: float, y0: float, y1: float, w: float) -> void:
	var wrap := LEATHER.lerp(Color(0.5, 0.15, 0.1), rng.randf() * 0.6) if rng.randf() < 0.7 else WOOD
	shape([[x - w, y0], [x + w, y0], [x + w, y1], [x - w, y1]], wrap)
	var n := rng.randi_range(3, 6)
	for i in n:
		var y := lerpf(y0, y1, (i + 0.5) / n)
		line(x - w, y, x + w, y + 0.012, wrap.darkened(0.5), 1.0)


func _pommel(x: float, y: float) -> void:
	var metal := tint.lightened(0.1)
	match rng.randi() % 3:
		0: dot(x, y, r.size.x * 0.11, metal.darkened(0.3)); dot(x, y, r.size.x * 0.08, metal)
		1: shape([[x, y - 0.035], [x + 0.16, y], [x, y + 0.035], [x - 0.16, y]], metal)
		2: dot(x, y, r.size.x * 0.1, metal); gem(x, y, r.size.x * 0.05)


func _sword() -> void:
	var curved: bool = it.base in ["Scimitar", "Sabre", "Falchion"]
	var bw: float = rng.randf_range(0.09, 0.15) * (1.3 if it.w > 1 else 1.0) / it.w * 1.0
	var x := 0.5
	var top := rng.randf_range(0.03, 0.08)
	var gy := rng.randf_range(0.64, 0.7)
	var steel := tint.lightened(0.15)
	if curved:
		var bend := rng.randf_range(0.06, 0.14)
		var pts := [[x - bw * 0.2 + bend, top], [x + bw + bend * 0.6, top + 0.12], [x + bw, gy], [x - bw, gy], [x - bw + bend * 0.5, top + 0.2]]
		shape(pts, steel)
		line(x, gy - 0.02, x + bend * 0.5, top + 0.18, steel.darkened(0.3), 1.0)
	else:
		var tip := rng.randf_range(0.06, 0.12)
		shape([[x, top], [x + bw, top + tip], [x + bw * rng.randf_range(0.8, 1.0), gy], [x - bw * rng.randf_range(0.8, 1.0), gy], [x - bw, top + tip]], steel)
		# fuller
		line(x, top + tip + 0.02, x, gy - 0.04, steel.darkened(0.35), maxf(1.0, r.size.x * 0.04))
	var gw := rng.randf_range(0.3, 0.46)
	var gc := tint.lerp(Color(0.75, 0.6, 0.3), rng.randf() * 0.8)
	match rng.randi() % 3:
		0: shape([[x - gw, gy], [x + gw, gy], [x + gw, gy + 0.03], [x - gw, gy + 0.03]], gc)
		1: shape([[x - gw, gy - 0.03], [x - gw * 0.3, gy], [x + gw * 0.3, gy], [x + gw, gy - 0.03], [x + gw * 0.8, gy + 0.035], [x - gw * 0.8, gy + 0.035]], gc)
		2: shape([[x - gw, gy + 0.02], [x, gy - 0.01], [x + gw, gy + 0.02], [x, gy + 0.045]], gc)
	if rng.randf() < 0.35:
		gem(x, gy + 0.015, r.size.x * 0.06)
	_grip(x, gy + 0.035, 0.9, 0.07)
	_pommel(x, 0.93)


func _haft(x: float, y0: float, y1: float, w := 0.07) -> void:
	var wood := WOOD.lerp(Color(0.3, 0.2, 0.12), rng.randf())
	shape([[x - w, y0], [x + w, y0], [x + w * 1.1, y1], [x - w * 1.1, y1]], wood)
	if rng.randf() < 0.6:
		_grip(x, y1 - 0.2, y1 - 0.03, w * 1.15)


func _axe() -> void:
	var double: bool = it.base in ["Double Axe"]
	var x := 0.5 if double else (0.62 if it.w > 1 else 0.58)
	_haft(x, 0.06, 0.97, 0.06 if it.w > 1 else 0.08)
	var steel := tint.lightened(0.1)
	var y := rng.randf_range(0.08, 0.14)
	var h := rng.randf_range(0.2, 0.28)
	var reach := 0.45 if it.w > 1 else 0.5
	var flare := rng.randf_range(0.0, 0.08)
	shape([[x - 0.05, y + 0.03], [x - reach * 0.55, y - flare], [x - reach, y - flare - 0.02], [x - reach * 0.92, y + h * 0.5], [x - reach, y + h + flare], [x - reach * 0.55, y + h + flare * 0.5], [x - 0.05, y + h - 0.03]], steel)
	line(x - reach * 0.95, y, x - reach * 0.9, y + h, steel.lightened(0.4), 1.0)
	if double:
		shape([[x + 0.05, y + 0.03], [x + reach * 0.55, y - flare], [x + reach, y - flare - 0.02], [x + reach * 0.92, y + h * 0.5], [x + reach, y + h + flare], [x + reach * 0.55, y + h + flare * 0.5], [x + 0.05, y + h - 0.03]], steel)
	elif rng.randf() < 0.5:
		shape([[x + 0.05, y + 0.06], [x + 0.25, y + h * 0.4], [x + 0.05, y + h * 0.6]], steel.darkened(0.15))
	shape([[x - 0.09, y], [x + 0.09, y], [x + 0.09, y + h], [x - 0.09, y + h]], steel.darkened(0.25))


func _club() -> void:
	var spiked: bool = it.base == "Spiked Club"
	var wood := WOOD.lerp(tint, 0.5)
	var tw := rng.randf_range(0.28, 0.38)
	shape([[0.5 - tw, 0.08], [0.5 - tw * 0.6, 0.02], [0.5 + tw * 0.6, 0.02], [0.5 + tw, 0.1], [0.58, 0.75], [0.6, 0.97], [0.4, 0.97], [0.42, 0.75]], wood)
	for i in rng.randi_range(2, 4):
		var y := rng.randf_range(0.1, 0.5)
		dot(rng.randf_range(0.4, 0.6), y, r.size.x * 0.06, wood.darkened(0.45))
	if spiked:
		for i in 7:
			var y := 0.06 + i * 0.07
			var s := 1 if i % 2 == 0 else -1
			var w := lerpf(tw, 0.12, (y - 0.06) / 0.6)
			shape([[0.5 + s * w, y], [0.5 + s * (w + 0.18), y + 0.015], [0.5 + s * w, y + 0.035]], Color(0.7, 0.7, 0.72))
	_grip(0.5, 0.78, 0.96, 0.09)


func _mace() -> void:
	_haft(0.5, 0.2, 0.97)
	var steel := tint.lightened(0.1)
	var star: bool = it.base == "Morning Star"
	var cy := rng.randf_range(0.13, 0.16)
	if star:
		for i in 10:
			var a := TAU * i / 10.0
			shape([[0.5 + cos(a) * 0.2, cy + sin(a) * 0.05], [0.5 + cos(a) * 0.48, cy + sin(a) * 0.12], [0.5 + cos(a + 0.3) * 0.2, cy + sin(a + 0.3) * 0.05]], steel.darkened(0.1))
		shape(ellipse_pts(0.5, cy, 0.3, 0.075, 16), steel)
	else:
		var n := rng.randi_range(4, 7)
		shape(ellipse_pts(0.5, cy, 0.28, 0.08, 16), steel.darkened(0.2))
		for i in n:
			var f := (i + 0.5) / n
			var x := lerpf(0.2, 0.8, f)
			shape([[x - 0.06, cy - 0.09], [x + 0.06, cy - 0.09], [x + 0.04, cy + 0.09], [x - 0.04, cy + 0.09]], steel)
	shape([[0.4, cy + 0.08], [0.6, cy + 0.08], [0.56, cy + 0.12], [0.44, cy + 0.12]], steel.darkened(0.3))


func _pick() -> void:
	_haft(0.55, 0.08, 0.97, 0.06)
	var steel := tint.lightened(0.1)
	var y := rng.randf_range(0.1, 0.14)
	shape([[0.08, y + rng.randf_range(0.02, 0.06)], [0.5, y - 0.02], [0.62, y - 0.01], [0.62, y + 0.05], [0.5, y + 0.05]], steel)
	shape([[0.62, y - 0.01], [0.9, y + 0.0], [0.62, y + 0.05]], steel.darkened(0.15))


func _flail() -> void:
	_haft(0.62, 0.45, 0.97, 0.06)
	var steel := tint.lightened(0.1)
	var bx := rng.randf_range(0.28, 0.4)
	var by := rng.randf_range(0.14, 0.2)
	var links := 6
	for i in links:
		var f := float(i) / links
		var p := Vector2(0.62, 0.45).lerp(Vector2(bx, by + 0.06), f)
		ci.draw_arc(P(p.x, p.y), r.size.x * 0.03, 0, TAU, 8, steel.darkened(0.2), 1.2)
	for i in 8:
		var a := TAU * i / 8.0
		shape([[bx + cos(a) * 0.14, by + sin(a) * 0.035], [bx + cos(a) * 0.3, by + sin(a) * 0.075], [bx + cos(a + 0.35) * 0.14, by + sin(a + 0.35) * 0.035]], steel)
	shape(ellipse_pts(bx, by, 0.18, 0.045, 14), steel.darkened(0.1))


func _hammer() -> void:
	_haft(0.5, 0.1, 0.97, 0.06)
	var steel := tint.lightened(0.05)
	var w := rng.randf_range(0.36, 0.44)
	shape([[0.5 - w, 0.06], [0.5 + w, 0.06], [0.5 + w, 0.2], [0.5 - w, 0.2]], steel)
	shape([[0.5 - w - 0.04, 0.05], [0.5 - w + 0.06, 0.05], [0.5 - w + 0.06, 0.21], [0.5 - w - 0.04, 0.21]], steel.darkened(0.2))
	shape([[0.5 + w - 0.06, 0.05], [0.5 + w + 0.04, 0.05], [0.5 + w + 0.04, 0.21], [0.5 + w - 0.06, 0.21]], steel.darkened(0.2))
	if rng.randf() < 0.5:
		gem(0.5, 0.13, r.size.x * 0.05)


# ---------- shields ----------

func _round_shield() -> void:
	var wood := tint
	shape(ellipse_pts(0.5, 0.5, 0.46, 0.46, 28), wood)
	var rim := Color(0.55, 0.55, 0.58).lerp(Color(0.7, 0.55, 0.3), rng.randf())
	ci.draw_arc(P(0.5, 0.5), r.size.x * 0.44, 0, TAU, 32, rim, maxf(1.5, r.size.x * 0.05), true)
	match rng.randi() % 3:
		0:
			for i in rng.randi_range(4, 7):
				line(0.12 + i * 0.13, 0.12, 0.12 + i * 0.13, 0.88, wood.darkened(0.3), 1.0)
		1:
			line(0.5, 0.06, 0.5, 0.94, rim, maxf(1.5, r.size.x * 0.06))
			line(0.06, 0.5, 0.94, 0.5, rim, maxf(1.5, r.size.x * 0.06))
		2:
			ci.draw_arc(P(0.5, 0.5), r.size.x * 0.28, 0, TAU, 24, wood.lightened(0.25), 2.0, true)
	var n := rng.randi_range(6, 10)
	for i in n:
		var a := TAU * i / n
		dot(0.5 + cos(a) * 0.38, 0.5 + sin(a) * 0.38, maxf(1.0, r.size.x * 0.025), rim.lightened(0.3))
	shape(ellipse_pts(0.5, 0.5, 0.13, 0.13, 14), rim.lightened(0.1))
	if rng.randf() < 0.3:
		gem(0.5, 0.5, r.size.x * 0.05)


func _shield(kind: String) -> void:
	var base := tint
	var pts: Array
	match kind:
		"heater":
			pts = [[0.08, 0.06], [0.92, 0.06], [0.9, 0.5], [0.72, 0.8], [0.5, 0.96], [0.28, 0.8], [0.1, 0.5]]
		"kite":
			pts = [[0.5, 0.03], [0.82, 0.08], [0.92, 0.28], [0.8, 0.6], [0.5, 0.98], [0.2, 0.6], [0.08, 0.28], [0.18, 0.08]]
		_:
			pts = [[0.06, 0.04], [0.94, 0.04], [0.94, 0.78], [0.5, 0.97], [0.06, 0.78]]
	var trim := Color(0.62, 0.62, 0.66).lerp(Color(0.8, 0.65, 0.3), rng.randf())
	shape(pts, trim)
	var inner := []
	for p in pts:
		inner.append([lerpf(p[0], 0.5, 0.1), lerpf(p[1], 0.5, 0.08)])
	shape(inner, base, false)
	var device: Color = GEMS[rng.randi() % GEMS.size()].darkened(0.25)
	match rng.randi() % 4:
		0: line(0.5, 0.1, 0.5, 0.9, device, maxf(2.0, r.size.x * 0.1)); line(0.15, 0.35, 0.85, 0.35, device, maxf(2.0, r.size.x * 0.1))
		1: shape([[0.5, 0.2], [0.72, 0.45], [0.5, 0.7], [0.28, 0.45]], device)
		2:
			for i in 3:
				line(0.12, 0.2 + i * 0.18, 0.88, 0.32 + i * 0.18, device, maxf(2.0, r.size.x * 0.06))
		3: shape(ellipse_pts(0.5, 0.42, 0.18, 0.13, 16), device); line(0.5, 0.55, 0.5, 0.85, device, 2.0)
	if kind == "tower":
		for x in [0.25, 0.75]:
			line(x, 0.08, x, 0.8, trim.darkened(0.2), 1.5)


# ---------- armor ----------

func _torso(col: Color) -> Array:
	var sh := rng.randf_range(0.0, 0.05)
	var pts := [[0.18, 0.08 + sh], [0.36, 0.03], [0.5, 0.1], [0.64, 0.03], [0.82, 0.08 + sh], [0.98, 0.28], [0.86, 0.36], [0.8, 0.3],
		[0.78, 0.95], [0.22, 0.95], [0.2, 0.3], [0.14, 0.36], [0.02, 0.28]]
	shape(pts, col)
	return pts


func _armor(kind: String) -> void:
	var col := tint
	_torso(col)
	var trim: Color = GEMS[rng.randi() % GEMS.size()].darkened(0.35).lerp(col, 0.3)
	if rng.randf() < 0.45:
		# a coloured hem
		shape([[0.22, 0.88], [0.78, 0.88], [0.78, 0.95], [0.22, 0.95]], trim, false)
	match kind:
		"quilted":
			for i in 6:
				line(0.24, 0.2 + i * 0.13, 0.76, 0.2 + i * 0.13, col.darkened(0.3), 1.0)
			for i in 4:
				line(0.3 + i * 0.13, 0.12, 0.3 + i * 0.13, 0.92, col.darkened(0.3), 1.0)
		"leather":
			line(0.5, 0.12, 0.5, 0.92, col.darkened(0.4), 1.5)
			for i in 5:
				var y := 0.2 + i * 0.13
				line(0.45, y, 0.55, y + 0.04, col.lightened(0.3), 1.0)
		"studded":
			for j in 6:
				for i in 4:
					dot(0.3 + i * 0.13 + (0.065 if j % 2 else 0.0), 0.18 + j * 0.13, maxf(1.0, r.size.x * 0.022), Color(0.75, 0.72, 0.65))
		"mail":
			for j in 12:
				for i in 7:
					var p := P(0.25 + i * 0.08 + (0.04 if j % 2 else 0.0), 0.14 + j * 0.065)
					ci.draw_arc(p, maxf(1.2, r.size.x * 0.025), 0, PI, 6, col.lightened(0.3), 1.0)
		"scale":
			for j in 9:
				for i in 5:
					var cx := 0.27 + i * 0.115 + (0.057 if j % 2 else 0.0)
					var cy := 0.14 + j * 0.088
					shape(ellipse_pts(cx, cy, 0.06, 0.04, 8, 0.0, PI), col.lightened(0.1 + 0.05 * (j % 2)), false)
		"plate":
			for i in 4:
				var y := 0.32 + i * 0.15
				line(0.22, y, 0.78, y + 0.02, col.darkened(0.35), 1.5)
			shape([[0.36, 0.12], [0.64, 0.12], [0.6, 0.3], [0.4, 0.3]], col.lightened(0.2))
			dot(0.2, 0.2, maxf(1.0, r.size.x * 0.03), col.lightened(0.4))
			dot(0.8, 0.2, maxf(1.0, r.size.x * 0.03), col.lightened(0.4))
	match rng.randi() % 3:
		1:
			shape([[0.38, 0.06], [0.5, 0.22], [0.62, 0.06], [0.56, 0.05], [0.5, 0.13], [0.44, 0.05]], trim)
		2:
			shape([[0.34, 0.04], [0.66, 0.04], [0.62, 0.12], [0.38, 0.12]], col.darkened(0.3))
	if rng.randf() < 0.55:
		# shoulder guards
		var pc := col.lightened(0.15) if kind in ["plate", "scale", "mail"] else LEATHER.lerp(col, 0.4)
		shape(ellipse_pts(0.17, 0.14, 0.13, 0.08, 12, PI, TAU) + [[0.3, 0.2], [0.04, 0.2]], pc)
		shape(ellipse_pts(0.83, 0.14, 0.13, 0.08, 12, PI, TAU) + [[0.96, 0.2], [0.7, 0.2]], pc)
	if rng.randf() < 0.5:
		# a belt across the waist, sometimes with a trim colour
		var tc: Color = LEATHER if rng.randf() < 0.6 else GEMS[rng.randi() % GEMS.size()].darkened(0.3)
		shape([[0.21, 0.72], [0.79, 0.72], [0.79, 0.78], [0.21, 0.78]], tc)
		shape([[0.45, 0.705], [0.55, 0.705], [0.55, 0.795], [0.45, 0.795]], Color(0.75, 0.65, 0.35))


func _helm(kind: String) -> void:
	var col := tint
	match kind:
		"hood":
			shape([[0.5, 0.06], [0.82, 0.25], [0.92, 0.7], [0.78, 0.95], [0.22, 0.95], [0.08, 0.7], [0.18, 0.25]], col)
			shape(ellipse_pts(0.5, 0.58, 0.2, 0.24, 16), col.darkened(0.75), false)
			line(0.3, 0.3, 0.2, 0.9, col.darkened(0.35), 1.0)
			line(0.7, 0.3, 0.8, 0.9, col.darkened(0.35), 1.0)
			if rng.randf() < 0.5:
				shape([[0.14, 0.82], [0.86, 0.82], [0.84, 0.95], [0.16, 0.95]], LEATHER.lerp(col, 0.5))
		_:
			shape(ellipse_pts(0.5, 0.58, 0.4, 0.46, 20, PI, TAU) + [[0.9, 0.8], [0.1, 0.8]], col)
			shape([[0.08, 0.72], [0.92, 0.72], [0.92, 0.84], [0.08, 0.84]], col.darkened(0.15))
			if rng.randf() < 0.6:
				line(0.5, 0.14, 0.5, 0.72, col.lightened(0.3), maxf(1.5, r.size.x * 0.05))
			var n := rng.randi_range(4, 8)
			for i in n:
				dot(0.12 + i * 0.76 / (n - 1), 0.78, maxf(1.0, r.size.x * 0.02), col.lightened(0.45))
			match kind:
				"nasal":
					shape([[0.45, 0.72], [0.55, 0.72], [0.53, 0.98], [0.47, 0.98]], col.lightened(0.1))
				"full":
					shape([[0.12, 0.8], [0.88, 0.8], [0.84, 0.98], [0.16, 0.98]], col)
					line(0.2, 0.86, 0.44, 0.86, Color(0.05, 0.04, 0.04), maxf(1.5, r.size.x * 0.04))
					line(0.56, 0.86, 0.8, 0.86, Color(0.05, 0.04, 0.04), maxf(1.5, r.size.x * 0.04))
					if rng.randf() < 0.5:
						shape([[0.47, 0.02], [0.53, 0.02], [0.6, 0.18], [0.4, 0.18]], GEMS[0].darkened(0.3))
				"crown":
					for i in 5:
						var x := 0.14 + i * 0.18
						shape([[x - 0.06, 0.72], [x, 0.3 + rng.randf_range(0.0, 0.1)], [x + 0.06, 0.72]], col.lightened(0.15))
						gem(x, 0.62, r.size.x * 0.04)


func _gloves(gauntlet: bool) -> void:
	var col := tint
	var cuff: Color = col.lightened(0.15) if gauntlet else (col.darkened(0.25) if rng.randf() < 0.5 else GEMS[rng.randi() % GEMS.size()].darkened(0.4))
	var studs := rng.randf() < 0.45
	for side in [0, 1]:
		var ox := 0.0 if side == 0 else 0.42
		var oy := 0.0 if side == 0 else 0.1
		var pts := [[ox + 0.08, oy + 0.55], [ox + 0.1, oy + 0.18], [ox + 0.16, oy + 0.08], [ox + 0.22, oy + 0.2], [ox + 0.26, oy + 0.05],
			[ox + 0.32, oy + 0.2], [ox + 0.38, oy + 0.08], [ox + 0.44, oy + 0.25], [ox + 0.54, oy + 0.32], [ox + 0.5, oy + 0.55], [ox + 0.5, oy + 0.85], [ox + 0.08, oy + 0.85]]
		shape(pts, col.darkened(0.1 * side))
		shape([[ox + 0.06, oy + 0.65], [ox + 0.52, oy + 0.65], [ox + 0.54, oy + 0.88], [ox + 0.04, oy + 0.88]], cuff)
		if studs:
			for i in 3:
				dot(ox + 0.14 + i * 0.13, oy + 0.45, maxf(1.0, r.size.x * 0.02), Color(0.75, 0.72, 0.65))
		if gauntlet:
			for i in 3:
				line(ox + 0.1, oy + 0.3 + i * 0.1, ox + 0.48, oy + 0.32 + i * 0.1, col.darkened(0.35), 1.0)


func _belt(kind: String) -> void:
	var col := tint
	var h := 0.36 if kind != "sash" else 0.3
	var y0 := 0.5 - h / 2.0
	shape([[0.02, y0 + 0.05], [0.98, y0], [0.98, y0 + h], [0.02, y0 + h + 0.05]], col)
	if kind == "plated_belt":
		for i in 5:
			var x := 0.1 + i * 0.18
			shape([[x, y0 + 0.02], [x + 0.13, y0 + 0.01], [x + 0.13, y0 + h - 0.01], [x, y0 + h]], Color(0.65, 0.65, 0.7))
	elif kind == "belt":
		for i in rng.randi_range(2, 4):
			var x := 0.6 + i * 0.1
			shape([[x, y0 - 0.08], [x + 0.07, y0 - 0.08], [x + 0.07, y0 + h + 0.12], [x, y0 + h + 0.12]], LEATHER.darkened(0.2))
	var bx := rng.randf_range(0.3, 0.45)
	var bc := Color(0.75, 0.65, 0.35) if rng.randf() < 0.6 else Color(0.7, 0.7, 0.74)
	shape([[bx, y0 - 0.06], [bx + 0.14, y0 - 0.06], [bx + 0.14, y0 + h + 0.08], [bx, y0 + h + 0.08]], bc)
	shape([[bx + 0.035, y0 + 0.06], [bx + 0.105, y0 + 0.06], [bx + 0.105, y0 + h - 0.04], [bx + 0.035, y0 + h - 0.04]], col.darkened(0.4), false)
	if kind == "sash":
		shape([[bx + 0.1, y0 + h], [bx + 0.2, 0.95], [bx + 0.05, 0.95]], col.darkened(0.1))


func _boots(greave: bool) -> void:
	var col := tint
	for side in [0, 1]:
		var ox := 0.0 if side == 0 else 0.34
		var oy := 0.02 if side == 0 else 0.0
		var top := oy + rng.randf_range(0.04, 0.12)
		shape([[ox + 0.14, top], [ox + 0.44, top], [ox + 0.44, oy + 0.72], [ox + 0.62, oy + 0.8], [ox + 0.62, oy + 0.95], [ox + 0.1, oy + 0.95], [ox + 0.1, oy + 0.7]], col.darkened(0.12 * side))
		shape([[ox + 0.1, oy + 0.88], [ox + 0.62, oy + 0.88], [ox + 0.62, oy + 0.96], [ox + 0.1, oy + 0.96]], col.darkened(0.5), false)
		if greave:
			for i in 3:
				line(ox + 0.14, top + 0.15 + i * 0.16, ox + 0.44, top + 0.17 + i * 0.16, col.lightened(0.3), 1.2)
		else:
			shape([[ox + 0.12, top], [ox + 0.46, top], [ox + 0.46, top + 0.1], [ox + 0.12, top + 0.1]], col.lightened(0.15))


# ---------- jewelry, charms, potions ----------

func _amulet() -> void:
	var metal := tint
	var pts := []
	for i in 13:
		var f := i / 12.0
		pts.append(P(lerpf(0.12, 0.88, f), 0.08 + sin(f * PI) * 0.45))
	ci.draw_polyline(PackedVector2Array(pts), metal.darkened(0.2), 1.5, true)
	var cy := 0.68
	match rng.randi() % 3:
		0: shape(ellipse_pts(0.5, cy, 0.24, 0.24, 16), metal)
		1: shape([[0.5, cy - 0.28], [0.74, cy], [0.5, cy + 0.28], [0.26, cy]], metal)
		2: shape([[0.5, cy - 0.24], [0.72, cy - 0.08], [0.64, cy + 0.24], [0.36, cy + 0.24], [0.28, cy - 0.08]], metal)
	gem(0.5, cy, r.size.x * 0.13)


func _ring() -> void:
	var metal := tint
	ci.draw_arc(P(0.5, 0.6), r.size.x * 0.3, 0, TAU, 24, metal.darkened(0.4), maxf(2.0, r.size.x * 0.13), true)
	ci.draw_arc(P(0.5, 0.6), r.size.x * 0.3, PI * 1.1, PI * 1.9, 12, metal.lightened(0.3), maxf(1.0, r.size.x * 0.05), true)
	if rng.randf() < 0.75:
		shape([[0.36, 0.3], [0.64, 0.3], [0.58, 0.4], [0.42, 0.4]], metal)
		gem(0.5, 0.25, r.size.x * 0.13)


func _charm(kind: String) -> void:
	var col := tint
	match kind:
		"charm_small":
			shape([[0.5, 0.08], [0.85, 0.35], [0.78, 0.82], [0.5, 0.95], [0.2, 0.8], [0.15, 0.38]], col)
			var rune := col.lightened(0.55)
			match rng.randi() % 3:
				0: line(0.5, 0.25, 0.5, 0.75, rune, 1.5); line(0.32, 0.4, 0.68, 0.6, rune, 1.5)
				1: ci.draw_arc(P(0.5, 0.5), r.size.x * 0.18, 0, TAU, 12, rune, 1.5, true)
				2: line(0.32, 0.3, 0.68, 0.7, rune, 1.5); line(0.68, 0.3, 0.32, 0.7, rune, 1.5)
		"charm_large":
			# a carved horn on a cord
			shape([[0.3, 0.04], [0.62, 0.08], [0.8, 0.4], [0.72, 0.75], [0.5, 0.97], [0.42, 0.7], [0.48, 0.4]], col)
			for i in 4:
				line(0.45, 0.2 + i * 0.16, 0.75, 0.24 + i * 0.15, col.darkened(0.4), 1.0)
			gem(0.6, 0.45, r.size.x * 0.1)
		_:
			# a bone idol
			shape(ellipse_pts(0.5, 0.14, 0.28, 0.1, 14), col.lightened(0.1))
			shape([[0.3, 0.2], [0.7, 0.2], [0.66, 0.6], [0.78, 0.92], [0.22, 0.92], [0.34, 0.6]], col)
			dot(0.4, 0.13, maxf(1.0, r.size.x * 0.05), Color(0.08, 0.05, 0.05))
			dot(0.6, 0.13, maxf(1.0, r.size.x * 0.05), Color(0.08, 0.05, 0.05))
			for i in 4:
				line(0.36, 0.3 + i * 0.14, 0.64, 0.3 + i * 0.14, col.darkened(0.35), 1.0)
			gem(0.5, 0.5, r.size.x * 0.1)


func _potion() -> void:
	var glass := Color(0.75, 0.8, 0.85, 0.5)
	shape(ellipse_pts(0.5, 0.64, 0.36, 0.32, 18), glass)
	shape(ellipse_pts(0.5, 0.68, 0.3, 0.26, 18), tint)
	shape([[0.4, 0.12], [0.6, 0.12], [0.6, 0.36], [0.4, 0.36]], glass)
	shape([[0.37, 0.04], [0.63, 0.04], [0.63, 0.14], [0.37, 0.14]], WOOD)
	dot(0.38, 0.56, r.size.x * 0.06, Color(1, 1, 1, 0.6))
