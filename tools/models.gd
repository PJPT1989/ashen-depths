extends RefCounted
## Procedural low-poly 3D models for the hero and monsters, built from primitive meshes on a
## simple joint hierarchy, plus the poses for each animation. Used only by bake_sprites.gd.
##
## Models face -Z, stand on y = 0, and are about 1.8 m tall at scale 1.
## The hero is built in layers (bare body, then each piece of gear) so the game can show
## what he wears; every mesh is tagged with its layer in `layer_of`.

const MONSTERS := ["scrabbler", "bonewalker", "hexcaller", "brute", "warden", "rotling", "gloomhound",
	"quillback", "bone_archer", "wraith", "zealot", "reaver", "moonsister", "spitter", "thornback"]
const TYPES := ["hero", "townsfolk", "scrabbler", "bonewalker", "hexcaller", "brute", "warden", "rotling", "gloomhound",
	"quillback", "bone_archer", "wraith", "zealot", "reaver", "moonsister", "spitter", "thornback"]
## Hero gear layers, in the order the game draws them over the bare body.
const HERO_LAYERS := ["base", "boots", "armor_light", "armor_medium", "armor_heavy", "belt", "gloves",
	"helm_hood", "helm_cap", "helm_great", "shield_buckler", "shield_kite", "weapon_sword", "weapon_axe", "weapon_mace"]
## Attack animation per model.
const STYLE := {"hero": "swing", "townsfolk": "swing", "scrabbler": "claw", "bonewalker": "swing", "hexcaller": "staff",
	"brute": "swing", "warden": "swing", "rotling": "claw", "gloomhound": "bite", "quillback": "rear",
	"bone_archer": "bow", "wraith": "claw", "zealot": "thrust", "reaver": "swing", "moonsister": "bow",
	"spitter": "spit", "thornback": "slam"}

## Every MeshInstance3D that glows gets an entry: mesh -> emission color (for the glow pass).
var emissive := {}
## Hero only: mesh -> layer name.
var layer_of := {}
var layer := ""


# ---------- small builders ----------

func mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.4
	return m


func glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func part(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO, scl := Vector3.ONE, glow := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if glow.a > 0.0:
		emissive[mi] = glow
	if layer != "":
		layer_of[mi] = layer
	return mi


func eye(parent: Node3D, pos: Vector3, r: float, c: Color) -> void:
	part(parent, sphere(r), pos, glow_mat(c), Vector3.ZERO, Vector3.ONE, Color(c, 1.0))


func capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return m


func sphere(r: float, squash := 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * squash
	m.radial_segments = 16
	m.rings = 10
	return m


func box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


func cyl(top: float, bottom: float, h: float, seg := 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 8
	return m


# ---------- skeletons ----------

## Builds the joint hierarchy and plain limbs. o: proportions and colors.
func humanoid(o: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var r := {"root": root}
	var limb_r: float = o.get("limb", 0.06)
	var leg_r: float = o.get("leg", 0.07)
	var hip_h: float = o.get("hip_h", 0.95)
	var arm_mat: Material = o.arm_mat
	var leg_mat: Material = o.leg_mat
	var hand_mat: Material = o.get("hand_mat", arm_mat)
	var body := joint(root, Vector3.ZERO)        # whole-body pivot at the feet (death falls)
	r.body = body
	var hips := joint(body, Vector3(0, hip_h, 0))
	r.hips = hips
	r.thigh_len = hip_h * 0.5
	for side in [-1, 1]:
		var key := "l" if side < 0 else "r"
		var hip := joint(hips, Vector3(0.11 * side, 0, 0))
		var thigh_len := hip_h * 0.5
		if not o.get("hide_legs", false):
			part(hip, capsule(leg_r, thigh_len + leg_r), Vector3(0, -thigh_len * 0.5, 0), leg_mat)
		var knee := joint(hip, Vector3(0, -thigh_len, 0))
		if not o.get("hide_legs", false):
			part(knee, capsule(leg_r * 0.85, thigh_len + leg_r), Vector3(0, -thigh_len * 0.5, 0), leg_mat)
			part(knee, box(leg_r * 2.2, 0.06, leg_r * 3.6), Vector3(0, -thigh_len + 0.02, -leg_r * 0.8), o.get("foot_mat", leg_mat))
		r["hip_" + key] = hip
		r["knee_" + key] = knee
	var torso := joint(hips, Vector3.ZERO)
	r.torso = torso
	var chest_h: float = o.get("chest_h", 0.62)
	var sw: float = o.get("shoulders", 0.22)
	var neck := joint(torso, Vector3(0, chest_h, 0))
	r.neck = neck
	for side in [-1, 1]:
		var key := "l" if side < 0 else "r"
		var sh := joint(torso, Vector3(sw * side, chest_h - 0.08, 0))
		var up_len: float = o.get("arm_len", 0.3)
		part(sh, capsule(limb_r, up_len + limb_r), Vector3(0, -up_len * 0.5, 0), arm_mat)
		var el := joint(sh, Vector3(0, -up_len, 0))
		part(el, capsule(limb_r * 0.85, up_len + limb_r), Vector3(0, -up_len * 0.5, 0), o.get("fore_mat", arm_mat))
		var hand := joint(el, Vector3(0, -up_len - 0.02, 0))
		part(hand, sphere(limb_r * 1.05), Vector3.ZERO, hand_mat)
		r["sh_" + key] = sh
		r["el_" + key] = el
		r["hand_" + key] = hand
	return r


## Four-legged body: legs at the corners of a horizontal torso, neck in front, tail behind.
func quad(o: Dictionary) -> Dictionary:
	var root := Node3D.new()
	var r := {"root": root, "quad": true}
	var body := joint(root, Vector3.ZERO)
	r.body = body
	var hh: float = o.get("hip_h", 0.5)
	var blen: float = o.get("len", 0.8)
	var leg_r: float = o.get("leg", 0.05)
	var lm: Material = o.leg_mat
	var hips := joint(body, Vector3(0, hh, 0))
	r.hips = hips
	for fb in [["f", -blen * 0.4], ["b", blen * 0.4]]:
		for side in [-1, 1]:
			var key: String = fb[0] + ("l" if side < 0 else "r")
			var hip := joint(hips, Vector3(o.get("width", 0.13) * side, 0, fb[1]))
			var up := hh * 0.5
			part(hip, capsule(leg_r, up + leg_r), Vector3(0, -up * 0.5, 0), lm)
			var knee := joint(hip, Vector3(0, -up, 0))
			part(knee, capsule(leg_r * 0.8, up + leg_r), Vector3(0, -up * 0.5, 0), lm)
			part(knee, box(leg_r * 2.2, 0.04, leg_r * 3.0), Vector3(0, -up + 0.02, -leg_r * 0.6), o.get("foot_mat", lm))
			r["leg_" + key] = hip
			r["knee_" + key] = knee
	var torso := joint(hips, Vector3.ZERO)
	r.torso = torso
	r.neck = joint(torso, Vector3(0, 0.06, -blen * 0.5))
	r.tail = joint(torso, Vector3(0, 0.04, blen * 0.5))
	return r


## Hand-held items point forward (-Z) when the arm hangs down; build them along +Y and
## parent them to this grip node.
func grip(hand: Node3D) -> Node3D:
	var g := joint(hand, Vector3.ZERO)
	g.rotation.x = -PI / 2 - 0.3
	return g


## A held item that stands upright while the forearm is bent forward (staffs, bows).
func upright(hand: Node3D) -> Node3D:
	var g := joint(hand, Vector3.ZERO)
	g.rotation.x = -1.4
	return g


func bow(hand: Node3D, wood: Material) -> void:
	var g := upright(hand)
	part(g, cyl(0.016, 0.02, 0.18), Vector3.ZERO, wood)
	part(g, cyl(0.01, 0.018, 0.5), Vector3(0, 0.3, -0.07), wood, Vector3(-0.35, 0, 0))
	part(g, cyl(0.018, 0.01, 0.5), Vector3(0, -0.3, -0.07), wood, Vector3(0.35, 0, 0))
	part(g, cyl(0.004, 0.004, 1.0), Vector3(0, 0, 0.02), mat(Color(0.85, 0.82, 0.7)))


# ---------- models ----------

## Callers clear `emissive` and `layer_of` between batches; several rigs share them.
func build(type: String) -> Dictionary:
	layer = ""
	var r: Dictionary
	match type:
		"hero": r = _hero()
		"townsfolk": r = _townsfolk()
		"scrabbler": r = _scrabbler()
		"bonewalker": r = _bonewalker()
		"hexcaller": r = _hexcaller()
		"brute": r = _brute()
		"warden": r = _warden()
		"rotling": r = _rotling()
		"gloomhound": r = _gloomhound()
		"quillback": r = _quillback()
		"bone_archer": r = _bone_archer()
		"wraith": r = _wraith()
		"zealot": r = _zealot()
		"reaver": r = _reaver()
		"moonsister": r = _moonsister()
		"spitter": r = _spitter()
		_: r = _thornback()
	r.type = type
	layer = ""
	return r


func _hero() -> Dictionary:
	var skin := mat(Color(0.78, 0.6, 0.47), 0.7)
	var shirt := mat(Color(0.6, 0.54, 0.43), 0.95)
	var pants := mat(Color(0.3, 0.24, 0.18), 0.95)
	var hair := mat(Color(0.22, 0.14, 0.08), 0.9)
	layer = "base"
	var r := humanoid({"arm_mat": shirt, "fore_mat": skin, "leg_mat": pants, "hand_mat": skin, "foot_mat": mat(Color(0.28, 0.2, 0.13))})
	var t: Node3D = r.torso
	var n: Node3D = r.neck
	part(t, capsule(0.155, 0.62), Vector3(0, 0.3, 0), shirt)
	part(n, sphere(0.11), Vector3(0, 0.13, -0.01), skin)
	part(n, sphere(0.116, 0.85), Vector3(0, 0.17, 0.02), hair)
	part(n, box(0.12, 0.02, 0.02), Vector3(0, 0.15, -0.115), mat(Color(0.12, 0.07, 0.05)))  # brow shadow
	part(n, box(0.1, 0.05, 0.06), Vector3(0, 0.05, -0.08), hair)                             # beard
	var thigh: float = r.thigh_len
	# light neutral materials: the game tints each layer with the item's colour
	var cloth := mat(Color(0.86, 0.84, 0.8), 0.95)
	var cloth_d := mat(Color(0.6, 0.58, 0.55), 0.95)
	var leath := mat(Color(0.82, 0.78, 0.72), 0.75)
	var metal := mat(Color(0.85, 0.86, 0.88), 0.35, 0.7)
	var metal_d := mat(Color(0.55, 0.56, 0.58), 0.4, 0.7)
	var accent := mat(Color(0.7, 0.62, 0.45), 0.4, 0.6)

	layer = "boots"
	for k in ["l", "r"]:
		part(r["knee_" + k], cyl(0.078, 0.088, 0.22), Vector3(0, -thigh + 0.13, 0), leath)
		part(r["knee_" + k], box(0.17, 0.075, 0.27), Vector3(0, -thigh + 0.025, -0.05), leath)
		part(r["knee_" + k], torus(0.07, 0.095), Vector3(0, -thigh + 0.24, 0), cloth_d)

	layer = "armor_light"
	part(t, capsule(0.172, 0.6), Vector3(0, 0.31, 0), cloth)
	part(t, cyl(0.18, 0.25, 0.32), Vector3(0, -0.08, 0), cloth)
	for k in ["l", "r"]:
		part(r["sh_" + k], capsule(0.078, 0.2), Vector3(0, -0.08, 0), cloth)
	for i in 4:
		part(t, box(0.36, 0.015, 0.36), Vector3(0, 0.12 + i * 0.12, 0), cloth_d, Vector3.ZERO, Vector3(0.95, 1, 0.95))

	layer = "armor_medium"
	part(t, capsule(0.18, 0.62), Vector3(0, 0.31, 0), metal)
	part(t, cyl(0.19, 0.28, 0.45), Vector3(0, -0.15, 0), metal)
	part(t, torus(0.1, 0.16), Vector3(0, 0.6, 0), leath, Vector3.ZERO, Vector3(1, 0.6, 1))
	for k in ["l", "r"]:
		part(r["sh_" + k], capsule(0.082, 0.3), Vector3(0, -0.13, 0), metal)
		part(r["sh_" + k], sphere(0.11, 0.75), Vector3.ZERO, leath)

	layer = "armor_heavy"
	part(t, capsule(0.18, 0.62), Vector3(0, 0.31, 0), metal_d)
	part(t, box(0.4, 0.38, 0.27), Vector3(0, 0.42, -0.01), metal)
	part(t, box(0.06, 0.34, 0.02), Vector3(0, 0.42, -0.15), accent)
	part(t, cyl(0.2, 0.27, 0.32), Vector3(0, -0.08, 0), metal_d)
	for s in [-1, 1]:
		var k := "l" if s < 0 else "r"
		part(r["sh_" + k], sphere(0.135, 0.8), Vector3(0.02 * s, 0.01, 0), metal)
		part(r["sh_" + k], torus(0.11, 0.14), Vector3(0.02 * s, -0.04, 0), accent, Vector3(0, 0, 0.3 * s), Vector3(1, 0.5, 1))
		part(r["el_" + k], cyl(0.07, 0.065, 0.24), Vector3(0, -0.15, 0), metal)
		part(r["hip_" + k], box(0.17, 0.3, 0.17), Vector3(0, -0.17, -0.01), metal)
		part(t, box(0.15, 0.2, 0.2), Vector3(0.13 * s, -0.12, 0), metal, Vector3(0, 0, 0.15 * s))

	layer = "belt"
	part(t, torus(0.16, 0.21), Vector3(0, 0.07, 0), leath, Vector3.ZERO, Vector3(1, 0.55, 0.9))
	part(t, box(0.08, 0.07, 0.03), Vector3(0, 0.07, -0.19), accent)
	part(t, box(0.07, 0.1, 0.05), Vector3(0.15, 0.03, -0.1), leath, Vector3(0, -0.6, 0))

	layer = "gloves"
	for k in ["l", "r"]:
		part(r["hand_" + k], sphere(0.075), Vector3.ZERO, leath)
		part(r["el_" + k], cyl(0.075, 0.068, 0.11), Vector3(0, -0.27, 0), leath)

	layer = "helm_hood"
	part(n, sphere(0.138), Vector3(0, 0.15, 0.03), cloth, Vector3.ZERO, Vector3(1, 1.05, 1))
	part(n, cyl(0.0, 0.14, 0.2), Vector3(0, 0.3, 0.07), cloth, Vector3(0.4, 0, 0))
	part(n, cyl(0.17, 0.22, 0.12), Vector3(0, 0.0, 0.02), cloth)

	layer = "helm_cap"
	part(n, sphere(0.13, 0.9), Vector3(0, 0.19, 0.0), metal)
	part(n, torus(0.115, 0.14), Vector3(0, 0.15, 0.0), accent, Vector3.ZERO, Vector3(1, 0.6, 1))
	part(n, box(0.025, 0.1, 0.02), Vector3(0, 0.1, -0.13), metal)
	for s in [-1, 1]:
		part(n, box(0.02, 0.12, 0.09), Vector3(0.12 * s, 0.07, -0.02), metal)

	layer = "helm_great"
	part(n, cyl(0.135, 0.14, 0.27), Vector3(0, 0.14, 0), metal)
	part(n, sphere(0.135, 0.6), Vector3(0, 0.28, 0), metal)
	part(n, box(0.2, 0.025, 0.02), Vector3(0, 0.16, -0.14), mat(Color(0.05, 0.05, 0.05)))
	part(n, box(0.025, 0.12, 0.02), Vector3(0, 0.08, -0.14), mat(Color(0.05, 0.05, 0.05)))
	for s in [-1, 1]:
		part(n, cyl(0.0, 0.04, 0.26), Vector3(0.16 * s, 0.32, 0), accent, Vector3(0, 0, -0.75 * s))

	layer = "shield_buckler"
	part(r.el_l, cyl(0.17, 0.17, 0.035, 18), Vector3(-0.07, -0.16, 0), leath, Vector3(0, 0, PI / 2))
	part(r.el_l, torus(0.15, 0.175), Vector3(-0.075, -0.16, 0), metal, Vector3(0, 0, PI / 2))
	part(r.el_l, sphere(0.05, 0.6), Vector3(-0.095, -0.16, 0), metal, Vector3(0, 0, PI / 2))

	layer = "shield_kite"
	part(r.el_l, box(0.035, 0.42, 0.36), Vector3(-0.08, -0.08, 0), leath)
	part(r.el_l, cyl(0.0, 0.25, 0.28, 4), Vector3(-0.08, -0.43, 0), leath, Vector3(PI, PI / 4, 0), Vector3(0.14, 1, 1))
	part(r.el_l, box(0.045, 0.44, 0.04), Vector3(-0.09, -0.12, 0), accent)
	part(r.el_l, box(0.045, 0.04, 0.3), Vector3(-0.09, 0.02, 0), accent)

	layer = "weapon_sword"
	var g := grip(r.hand_r)
	part(g, cyl(0.022, 0.022, 0.16), Vector3.ZERO, mat(Color(0.35, 0.25, 0.16)))
	part(g, box(0.26, 0.04, 0.05), Vector3(0, 0.09, 0), accent)
	part(g, box(0.06, 0.85, 0.015), Vector3(0, 0.53, 0), metal)
	part(g, sphere(0.035), Vector3(0, -0.09, 0), accent)

	layer = "weapon_axe"
	part(g, cyl(0.022, 0.026, 0.8), Vector3(0, 0.28, 0), mat(Color(0.45, 0.33, 0.22)))
	part(g, box(0.03, 0.2, 0.2), Vector3(0, 0.6, -0.1), metal)
	part(g, cyl(0.13, 0.13, 0.03, 14), Vector3(0, 0.6, -0.2), metal, Vector3(0, 0, PI / 2), Vector3(1, 1, 0.6))
	part(g, box(0.035, 0.08, 0.08), Vector3(0, 0.6, 0.05), metal_d)

	layer = "weapon_mace"
	part(g, cyl(0.024, 0.024, 0.62), Vector3(0, 0.22, 0), mat(Color(0.4, 0.3, 0.2)))
	part(g, sphere(0.085), Vector3(0, 0.58, 0), metal)
	for k in 6:
		var a := k * PI / 3.0
		part(g, box(0.02, 0.16, 0.06), Vector3(cos(a) * 0.08, 0.58, sin(a) * 0.08), metal_d, Vector3(0, -a, 0))
	part(g, cyl(0.0, 0.03, 0.08), Vector3(0, 0.7, 0), metal)

	layer = ""
	r.scale = 1.0
	return r


## Plain villager for the town: a long coat and a hood, tinted per person in game.
func _townsfolk() -> Dictionary:
	var skin := mat(Color(0.74, 0.58, 0.46), 0.7)
	var coat := mat(Color(0.82, 0.8, 0.76), 0.95)
	var r := humanoid({"arm_mat": coat, "fore_mat": coat, "leg_mat": mat(Color(0.3, 0.25, 0.2)), "hand_mat": skin})
	var t: Node3D = r.torso
	part(t, capsule(0.17, 0.62), Vector3(0, 0.3, 0), coat)
	part(t, cyl(0.18, 0.3, 0.7), Vector3(0, -0.25, 0), coat)
	part(t, torus(0.16, 0.2), Vector3(0, 0.07, 0), mat(Color(0.3, 0.2, 0.12)), Vector3.ZERO, Vector3(1, 0.55, 0.9))
	var n: Node3D = r.neck
	part(n, sphere(0.11), Vector3(0, 0.13, -0.01), skin)
	part(n, sphere(0.136), Vector3(0, 0.15, 0.03), coat)
	part(n, box(0.1, 0.06, 0.06), Vector3(0, 0.05, -0.08), mat(Color(0.75, 0.73, 0.7)))
	r.scale = 1.0
	return r


func _scrabbler() -> Dictionary:
	var hide := mat(Color(0.55, 0.16, 0.1), 0.75)
	var dark := mat(Color(0.25, 0.07, 0.05), 0.8)
	var horn := mat(Color(0.85, 0.78, 0.6), 0.5)
	var r := humanoid({"arm_mat": hide, "leg_mat": hide, "limb": 0.05, "leg": 0.065, "hip_h": 0.7, "chest_h": 0.45, "shoulders": 0.17, "arm_len": 0.27, "foot_mat": dark})
	var t: Node3D = r.torso
	t.rotation.x = 0.55
	part(t, sphere(0.2, 1.25), Vector3(0, 0.25, 0), hide)
	part(t, sphere(0.15), Vector3(0, 0.38, 0.06), dark)
	for i in 3:
		part(t, cyl(0.0, 0.035, 0.12), Vector3(0, 0.3 + i * 0.09, 0.17 - i * 0.02), horn, Vector3(-0.9, 0, 0))
	var tail := joint(r.hips, Vector3(0, -0.02, 0.14))
	r.tail = tail
	part(tail, cyl(0.015, 0.045, 0.5), Vector3(0, -0.12, 0.2), hide, Vector3(1.1, 0, 0))
	var n: Node3D = r.neck
	n.rotation.x = -0.45
	part(n, sphere(0.16, 0.95), Vector3(0, 0.1, -0.05), hide)
	part(n, sphere(0.1, 0.7), Vector3(0, 0.04, -0.17), dark)
	for s in [-1, 1]:
		part(n, cyl(0.0, 0.04, 0.22), Vector3(0.09 * s, 0.25, -0.02), horn, Vector3(-0.3, 0, -0.45 * s))
		part(n, cyl(0.0, 0.05, 0.16), Vector3(0.16 * s, 0.12, 0.0), hide, Vector3(0, 0, -1.3 * s))
		eye(n, Vector3(0.065 * s, 0.13, -0.17), 0.032, Color(1, 0.8, 0.15))
	for side in ["l", "r"]:
		for k in 3:
			part(r["hand_" + side], cyl(0.0, 0.018, 0.12), Vector3((k - 1) * 0.03, -0.06, -0.03), horn, Vector3(0.4, 0, 0))
	r.scale = 0.72
	return r


func _skeleton(bone: Material, old: Material) -> Dictionary:
	var r := humanoid({"arm_mat": bone, "leg_mat": bone, "limb": 0.032, "leg": 0.036, "foot_mat": bone})
	var t: Node3D = r.torso
	part(t, cyl(0.03, 0.03, 0.62), Vector3(0, 0.3, 0.04), old)
	for i in 4:
		var w := 0.15 - i * 0.012
		part(t, torus(w - 0.025, w), Vector3(0, 0.5 - i * 0.075, 0), bone, Vector3.ZERO, Vector3(1, 0.6, 0.8))
	part(t, box(0.26, 0.1, 0.14), Vector3.ZERO, old)
	part(t, box(0.4, 0.035, 0.08), Vector3(0, 0.56, 0), bone)
	var n: Node3D = r.neck
	part(n, sphere(0.115, 1.05), Vector3(0, 0.14, 0), bone)
	part(n, box(0.12, 0.05, 0.1), Vector3(0, 0.04, -0.05), bone)
	return r


func _bonewalker() -> Dictionary:
	var bone := mat(Color(0.86, 0.82, 0.7), 0.65)
	var old := mat(Color(0.6, 0.55, 0.45), 0.8)
	var rust := mat(Color(0.45, 0.25, 0.12), 0.6, 0.5)
	var r := _skeleton(bone, old)
	var t: Node3D = r.torso
	part(t, box(0.3, 0.3, 0.02), Vector3(0, -0.12, 0.08), mat(Color(0.22, 0.18, 0.12), 1.0), Vector3(-0.1, 0, 0))
	for s in [-1, 1]:
		eye(r.neck, Vector3(0.045 * s, 0.15, -0.095), 0.033, Color(1, 0.22, 0.12))
	var g := grip(r.hand_r)
	part(g, cyl(0.02, 0.02, 0.14), Vector3.ZERO, mat(Color(0.2, 0.12, 0.06)))
	part(g, box(0.2, 0.035, 0.04), Vector3(0, 0.08, 0), rust)
	part(g, box(0.055, 0.7, 0.012), Vector3(0, 0.45, 0), rust)
	part(r.el_l, cyl(0.15, 0.15, 0.03, 10), Vector3(-0.06, -0.16, 0), mat(Color(0.35, 0.27, 0.18)), Vector3(0, 0, PI / 2))
	r.scale = 1.0
	return r


func _bone_archer() -> Dictionary:
	var bone := mat(Color(0.8, 0.8, 0.74), 0.65)
	var old := mat(Color(0.5, 0.5, 0.45), 0.8)
	var r := _skeleton(bone, old)
	var t: Node3D = r.torso
	part(t, cyl(0.06, 0.05, 0.42), Vector3(0.1, 0.38, 0.12), mat(Color(0.3, 0.2, 0.12)), Vector3(0.2, 0, -0.35))   # quiver
	for k in 3:
		part(t, cyl(0.008, 0.008, 0.2), Vector3(0.16 + k * 0.02, 0.64, 0.14), mat(Color(0.8, 0.75, 0.6)), Vector3(0.2, 0, -0.35))
	part(r.neck, cyl(0.14, 0.15, 0.08), Vector3(0, 0.22, 0), mat(Color(0.3, 0.32, 0.3), 0.6, 0.5))       # rusty cap
	for s in [-1, 1]:
		eye(r.neck, Vector3(0.045 * s, 0.15, -0.095), 0.03, Color(0.5, 0.85, 1.0))
	bow(r.hand_l, mat(Color(0.35, 0.24, 0.14)))
	r.scale = 1.0
	return r


func _hexcaller() -> Dictionary:
	var robe := mat(Color(0.28, 0.1, 0.38), 0.95)
	var trim := mat(Color(0.55, 0.42, 0.18), 0.5, 0.6)
	var wood := mat(Color(0.3, 0.2, 0.12), 0.8)
	var r := humanoid({"arm_mat": robe, "leg_mat": robe, "hide_legs": true, "hand_mat": mat(Color(0.5, 0.55, 0.45))})
	var hips: Node3D = r.hips
	part(hips, cyl(0.15, 0.4, 0.98), Vector3(0, -0.47, 0), robe)
	part(hips, torus(0.36, 0.41), Vector3(0, -0.93, 0), trim, Vector3.ZERO, Vector3(1, 0.4, 1))
	var t: Node3D = r.torso
	t.rotation.x = 0.15
	part(t, capsule(0.17, 0.6), Vector3(0, 0.3, 0), robe)
	part(t, box(0.08, 0.6, 0.02), Vector3(0, 0.25, -0.17), trim)
	for s in [-1, 1]:
		part(r["el_" + ("l" if s < 0 else "r")], cyl(0.09, 0.06, 0.22), Vector3(0, -0.2, 0), robe)
	var n: Node3D = r.neck
	part(n, sphere(0.1), Vector3(0, 0.12, 0), mat(Color(0.05, 0.03, 0.06)))
	part(n, cyl(0.0, 0.17, 0.42), Vector3(0, 0.2, 0.03), robe, Vector3(0.2, 0, 0))
	for s in [-1, 1]:
		eye(n, Vector3(0.04 * s, 0.12, -0.09), 0.022, Color(0.5, 1, 0.6))
	var staff := upright(r.hand_l)
	part(staff, cyl(0.025, 0.03, 1.7), Vector3(0, 0.35, 0), wood)
	part(staff, torus(0.05, 0.08), Vector3(0, 1.2, 0), trim, Vector3(PI / 2, 0, 0))
	part(staff, sphere(0.075), Vector3(0, 1.22, 0), glow_mat(Color(0.55, 1, 0.65)), Vector3.ZERO, Vector3.ONE, Color(0.35, 1, 0.5, 1))
	r.staff = staff
	r.scale = 1.0
	return r


func _brute() -> Dictionary:
	var skin := mat(Color(0.42, 0.47, 0.25), 0.75)
	var dark := mat(Color(0.28, 0.3, 0.16), 0.8)
	var fur := mat(Color(0.3, 0.2, 0.12), 1.0)
	var tusk := mat(Color(0.92, 0.88, 0.75), 0.45)
	var r := humanoid({"arm_mat": skin, "leg_mat": dark, "limb": 0.1, "leg": 0.11, "hip_h": 0.85, "chest_h": 0.7, "shoulders": 0.36, "arm_len": 0.36, "foot_mat": fur})
	var t: Node3D = r.torso
	t.rotation.x = 0.3
	part(t, sphere(0.36, 1.15), Vector3(0, 0.38, 0), skin)
	part(t, sphere(0.3), Vector3(0, 0.12, -0.05), dark)
	part(t, cyl(0.3, 0.36, 0.25), Vector3(0, -0.05, 0), fur)
	for s in [-1, 1]:
		part(t, sphere(0.16), Vector3(0.33 * s, 0.6, 0.02), skin)
		part(t, cyl(0.0, 0.05, 0.14), Vector3(0.36 * s, 0.73, 0.02), tusk, Vector3(0, 0, -0.3 * s))
	var n: Node3D = r.neck
	n.position = Vector3(0, 0.62, -0.18)
	part(n, sphere(0.14, 0.95), Vector3(0, 0.08, -0.04), skin)
	part(n, box(0.2, 0.08, 0.12), Vector3(0, 0.02, -0.12), dark)
	for s in [-1, 1]:
		part(n, cyl(0.0, 0.03, 0.14), Vector3(0.07 * s, 0.1, -0.17), tusk, Vector3(0.3, 0, 0.25 * s))
		eye(n, Vector3(0.05 * s, 0.13, -0.15), 0.022, Color(1, 0.55, 0.1))
	var g := grip(r.hand_r)
	part(g, cyl(0.07, 0.035, 0.9), Vector3(0, 0.4, 0), mat(Color(0.35, 0.24, 0.14), 0.9))
	for k in 4:
		var a := k * PI / 2
		part(g, cyl(0.0, 0.025, 0.1), Vector3(cos(a) * 0.07, 0.72, sin(a) * 0.07), tusk, Vector3(sin(a) * 1.3, a, -cos(a) * 1.3))
	r.scale = 1.3
	return r


func _warden() -> Dictionary:
	var plate := mat(Color(0.3, 0.42, 0.45), 0.4, 0.75)
	var dark := mat(Color(0.12, 0.16, 0.18), 0.6, 0.5)
	var cloth := mat(Color(0.12, 0.22, 0.24), 0.95)
	var bone := mat(Color(0.82, 0.86, 0.85), 0.5)
	var r := humanoid({"arm_mat": dark, "leg_mat": dark, "limb": 0.07, "leg": 0.08, "shoulders": 0.25, "foot_mat": plate})
	var t: Node3D = r.torso
	part(t, box(0.42, 0.5, 0.28), Vector3(0, 0.38, 0), plate)
	part(t, box(0.3, 0.22, 0.24), Vector3(0, 0.08, 0), dark)
	part(t, box(0.3, 0.7, 0.03), Vector3(0, -0.12, -0.15), cloth)
	part(t, box(0.5, 0.9, 0.03), Vector3(0, 0.05, 0.17), cloth, Vector3(-0.1, 0, 0))
	for s in [-1, 1]:
		part(t, sphere(0.16, 0.75), Vector3(0.3 * s, 0.58, 0), plate)
		part(t, cyl(0.0, 0.04, 0.16), Vector3(0.36 * s, 0.68, 0), bone, Vector3(0, 0, -0.5 * s))
		part(r["knee_" + ("l" if s < 0 else "r")], box(0.15, 0.3, 0.16), Vector3(0, -0.2, -0.01), plate)
		part(r["el_" + ("l" if s < 0 else "r")], cyl(0.09, 0.07, 0.2), Vector3(0, -0.17, 0), plate)
	var n: Node3D = r.neck
	part(n, sphere(0.14, 1.1), Vector3(0, 0.15, 0), plate)
	part(n, box(0.2, 0.03, 0.04), Vector3(0, 0.15, -0.13), dark)
	for s in [-1, 1]:
		eye(n, Vector3(0.045 * s, 0.155, -0.14), 0.022, Color(0.4, 1, 1))
		part(n, cyl(0.0, 0.045, 0.3), Vector3(0.14 * s, 0.32, 0), bone, Vector3(0, 0, -0.7 * s))
	var g := grip(r.hand_r)
	part(g, cyl(0.025, 0.025, 2.0), Vector3(0, 0.5, 0), mat(Color(0.3, 0.22, 0.15)))
	part(g, box(0.035, 0.32, 0.26), Vector3(0, 1.3, -0.13), mat(Color(0.7, 0.74, 0.76), 0.3, 0.85))
	part(g, cyl(0.0, 0.03, 0.3), Vector3(0, 1.62, 0), mat(Color(0.7, 0.74, 0.76), 0.3, 0.85))
	r.scale = 1.25
	return r


## Shambling corpse: grey-green, torn rags, arms reaching forward.
func _rotling() -> Dictionary:
	var skin := mat(Color(0.45, 0.5, 0.4), 0.8)
	var rot := mat(Color(0.32, 0.3, 0.22), 0.9)
	var rag := mat(Color(0.3, 0.25, 0.2), 1.0)
	var r := humanoid({"arm_mat": skin, "leg_mat": rag, "limb": 0.055, "leg": 0.065, "hand_mat": skin, "foot_mat": rot})
	var t: Node3D = r.torso
	t.rotation.x = 0.3
	part(t, capsule(0.16, 0.6), Vector3(0, 0.3, 0), skin)
	part(t, cyl(0.17, 0.24, 0.35), Vector3(0, -0.06, 0), rag)
	part(t, box(0.3, 0.3, 0.02), Vector3(0.03, 0.35, -0.16), rag, Vector3(0, 0, 0.2))
	part(t, sphere(0.06), Vector3(-0.08, 0.42, -0.14), mat(Color(0.5, 0.12, 0.1)))     # open wound
	part(t, box(0.04, 0.2, 0.04), Vector3(0, 0.2, 0.15), mat(Color(0.75, 0.72, 0.62)))  # exposed spine
	var n: Node3D = r.neck
	n.rotation = Vector3(-0.3, 0, 0.35)
	part(n, sphere(0.11, 1.05), Vector3(0, 0.12, -0.02), skin)
	part(n, box(0.1, 0.05, 0.08), Vector3(0, 0.03, -0.07), rot)
	for s in [-1, 1]:
		eye(n, Vector3(0.04 * s, 0.14, -0.1), 0.02, Color(0.9, 0.85, 0.35))
	r.scale = 1.0
	return r


func _gloomhound() -> Dictionary:
	var fur := mat(Color(0.24, 0.22, 0.24), 0.95)
	var belly := mat(Color(0.4, 0.37, 0.36), 0.95)
	var fang := mat(Color(0.9, 0.86, 0.75), 0.4)
	var r := quad({"leg_mat": fur, "hip_h": 0.5, "len": 0.8, "leg": 0.045, "width": 0.12})
	var t: Node3D = r.torso
	part(t, capsule(0.17, 0.85), Vector3(0, 0.02, 0), fur, Vector3(PI / 2, 0, 0))
	part(t, capsule(0.12, 0.5), Vector3(0, -0.06, -0.05), belly, Vector3(PI / 2, 0, 0))
	part(t, sphere(0.2, 0.8), Vector3(0, 0.08, -0.25), fur)                                    # shoulders and mane
	for i in 5:
		part(t, cyl(0.0, 0.035, 0.14), Vector3(0, 0.2, -0.3 + i * 0.12), fur, Vector3(0.5, 0, 0))
	var n: Node3D = r.neck
	n.rotation.x = -0.3
	part(n, sphere(0.13), Vector3(0, 0.12, -0.08), fur)
	part(n, cyl(0.05, 0.085, 0.22), Vector3(0, 0.09, -0.24), fur, Vector3(PI / 2, 0, 0))     # snout
	part(n, box(0.1, 0.035, 0.18), Vector3(0, 0.03, -0.22), belly)                            # jaw
	for s in [-1, 1]:
		part(n, cyl(0.0, 0.045, 0.13), Vector3(0.07 * s, 0.25, -0.05), fur, Vector3(0, 0, -0.3 * s))
		eye(n, Vector3(0.06 * s, 0.16, -0.18), 0.022, Color(1, 0.4, 0.15))
		part(n, cyl(0.0, 0.012, 0.05), Vector3(0.035 * s, 0.03, -0.32), fang, Vector3(PI, 0, 0))
	part(r.tail, cyl(0.02, 0.05, 0.42), Vector3(0, 0.05, 0.2), fur, Vector3(1.0, 0, 0))
	r.scale = 1.0
	return r


func _quillback() -> Dictionary:
	var hide := mat(Color(0.42, 0.32, 0.22), 0.9)
	var quill := mat(Color(0.86, 0.8, 0.62), 0.5)
	var tip := mat(Color(0.25, 0.12, 0.1), 0.6)
	var r := quad({"leg_mat": hide, "hip_h": 0.36, "len": 0.7, "leg": 0.05, "width": 0.16})
	var t: Node3D = r.torso
	part(t, sphere(0.3, 0.75), Vector3(0, 0.06, 0), hide, Vector3.ZERO, Vector3(1, 1, 1.35))
	for i in 22:
		var a := i * 2.4
		var row := float(i % 6) / 5.0
		var pos := Vector3(cos(a) * 0.2 * (0.4 + row * 0.6), 0.2 + row * 0.05, -0.25 + float(i) / 22.0 * 0.5)
		var rot := Vector3(0.9 + sin(i * 1.7) * 0.2, 0, cos(a) * 0.6)
		part(t, cyl(0.0, 0.022, 0.32), pos, quill, rot)
	var n: Node3D = r.neck
	part(n, sphere(0.13, 0.85), Vector3(0, 0.02, -0.08), hide)
	part(n, sphere(0.06), Vector3(0, -0.02, -0.2), tip)
	for s in [-1, 1]:
		eye(n, Vector3(0.06 * s, 0.06, -0.17), 0.02, Color(1, 0.7, 0.2))
	part(r.tail, cyl(0.01, 0.04, 0.2), Vector3(0, 0, 0.1), hide, Vector3(1.2, 0, 0))
	r.scale = 1.0
	return r


func _wraith() -> Dictionary:
	var shroud := mat(Color(0.32, 0.38, 0.45), 0.95)
	var dark := mat(Color(0.12, 0.14, 0.18), 0.95)
	var claw := mat(Color(0.72, 0.78, 0.82), 0.5)
	var r := humanoid({"arm_mat": shroud, "leg_mat": shroud, "hide_legs": true, "limb": 0.05, "hand_mat": claw})
	var hips: Node3D = r.hips
	part(hips, cyl(0.17, 0.05, 0.85), Vector3(0, -0.4, 0.04), shroud)
	for i in 6:
		var a := i * TAU / 6.0
		part(hips, box(0.07, 0.4, 0.015), Vector3(cos(a) * 0.12, -0.6, sin(a) * 0.12), dark, Vector3(0, -a, 0.15))
	var t: Node3D = r.torso
	t.rotation.x = 0.2
	part(t, capsule(0.17, 0.6), Vector3(0, 0.3, 0), shroud)
	for s in [-1, 1]:
		var k := "l" if s < 0 else "r"
		part(r["el_" + k], cyl(0.1, 0.06, 0.25), Vector3(0, -0.2, 0), shroud)
		for c in 3:
			part(r["hand_" + k], cyl(0.0, 0.014, 0.16), Vector3((c - 1) * 0.025, -0.08, -0.03), claw, Vector3(0.3, 0, 0))
	var n: Node3D = r.neck
	part(n, sphere(0.1), Vector3(0, 0.12, 0), mat(Color(0.02, 0.02, 0.03)))
	part(n, sphere(0.15), Vector3(0, 0.15, 0.03), shroud, Vector3.ZERO, Vector3(1, 1.15, 1))
	part(n, cyl(0.0, 0.1, 0.2), Vector3(0, 0.32, 0.1), shroud, Vector3(0.7, 0, 0))
	for s in [-1, 1]:
		eye(n, Vector3(0.042 * s, 0.13, -0.09), 0.026, Color(0.6, 0.9, 1.0))
	r.float = true
	r.scale = 1.05
	return r


## Masked cultist with a long spear.
func _zealot() -> Dictionary:
	var robe := mat(Color(0.45, 0.08, 0.06), 0.95)
	var black := mat(Color(0.1, 0.08, 0.08), 0.9)
	var mask := mat(Color(0.85, 0.8, 0.68), 0.5)
	var r := humanoid({"arm_mat": robe, "fore_mat": black, "leg_mat": black, "hand_mat": black, "foot_mat": black})
	var t: Node3D = r.torso
	part(t, capsule(0.165, 0.62), Vector3(0, 0.3, 0), robe)
	part(t, cyl(0.17, 0.28, 0.55), Vector3(0, -0.2, 0), robe)
	part(t, box(0.1, 0.62, 0.02), Vector3(0, 0.15, -0.17), black)
	part(t, torus(0.16, 0.2), Vector3(0, 0.07, 0), black, Vector3.ZERO, Vector3(1, 0.55, 0.9))
	var n: Node3D = r.neck
	part(n, sphere(0.14), Vector3(0, 0.15, 0.02), robe)
	part(n, cyl(0.0, 0.13, 0.3), Vector3(0, 0.33, 0.05), robe, Vector3(0.25, 0, 0))
	part(n, box(0.15, 0.17, 0.04), Vector3(0, 0.13, -0.11), mask)
	for s in [-1, 1]:
		eye(n, Vector3(0.035 * s, 0.15, -0.135), 0.018, Color(1, 0.35, 0.2))
	var g := grip(r.hand_r)
	part(g, cyl(0.02, 0.02, 1.9), Vector3(0, 0.45, 0), mat(Color(0.3, 0.22, 0.14)))
	part(g, cyl(0.0, 0.045, 0.28), Vector3(0, 1.52, 0), mat(Color(0.7, 0.7, 0.72), 0.3, 0.8))
	part(g, box(0.1, 0.12, 0.01), Vector3(0, 1.32, 0), robe)
	r.scale = 1.0
	return r


## Goat-headed raider with an axe.
func _reaver() -> Dictionary:
	var fur := mat(Color(0.38, 0.28, 0.2), 1.0)
	var dark := mat(Color(0.2, 0.15, 0.11), 0.95)
	var horn := mat(Color(0.75, 0.68, 0.55), 0.5)
	var hide := mat(Color(0.55, 0.45, 0.35), 0.85)
	var r := humanoid({"arm_mat": fur, "leg_mat": dark, "limb": 0.065, "leg": 0.075, "shoulders": 0.25, "foot_mat": mat(Color(0.12, 0.1, 0.08))})
	var t: Node3D = r.torso
	t.rotation.x = 0.15
	part(t, capsule(0.19, 0.64), Vector3(0, 0.3, 0), fur)
	part(t, box(0.36, 0.3, 0.1), Vector3(0, 0.4, -0.14), hide)
	part(t, cyl(0.2, 0.27, 0.3), Vector3(0, -0.07, 0), dark)
	for s in [-1, 1]:
		part(t, sphere(0.11, 0.8), Vector3(0.24 * s, 0.56, 0), hide)
	var n: Node3D = r.neck
	n.rotation.x = -0.2
	part(n, sphere(0.12, 1.1), Vector3(0, 0.14, 0), fur)
	part(n, cyl(0.045, 0.08, 0.2), Vector3(0, 0.08, -0.13), fur, Vector3(PI / 2 + 0.4, 0, 0))
	part(n, box(0.06, 0.08, 0.04), Vector3(0, -0.02, -0.12), dark)                          # beard
	for s in [-1, 1]:
		var h := joint(n, Vector3(0.08 * s, 0.24, 0.0))
		part(h, cyl(0.02, 0.04, 0.2), Vector3(0.04 * s, 0.06, 0.06), horn, Vector3(0.7, 0, -0.5 * s))
		part(h, cyl(0.0, 0.02, 0.16), Vector3(0.09 * s, 0.05, 0.19), horn, Vector3(1.9, 0, -0.4 * s))
		part(n, cyl(0.0, 0.035, 0.12), Vector3(0.12 * s, 0.14, 0.0), fur, Vector3(0, 0, -1.4 * s))
		eye(n, Vector3(0.05 * s, 0.17, -0.09), 0.02, Color(1, 0.85, 0.3))
	var g := grip(r.hand_r)
	part(g, cyl(0.022, 0.026, 0.85), Vector3(0, 0.3, 0), mat(Color(0.3, 0.22, 0.14)))
	part(g, cyl(0.17, 0.17, 0.03, 12), Vector3(0, 0.65, -0.16), mat(Color(0.5, 0.48, 0.45), 0.4, 0.7), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.55))
	r.scale = 1.1
	return r


## Fallen huntress with a bow.
func _moonsister() -> Dictionary:
	var cloak := mat(Color(0.2, 0.22, 0.3), 0.95)
	var leather := mat(Color(0.32, 0.25, 0.22), 0.8)
	var skin := mat(Color(0.62, 0.62, 0.7), 0.7)
	var hair := mat(Color(0.85, 0.85, 0.9), 0.8)
	var r := humanoid({"arm_mat": leather, "fore_mat": skin, "leg_mat": leather, "hand_mat": skin, "limb": 0.05, "leg": 0.06, "shoulders": 0.19, "foot_mat": mat(Color(0.15, 0.12, 0.12))})
	var t: Node3D = r.torso
	part(t, capsule(0.14, 0.58), Vector3(0, 0.3, 0), leather)
	part(t, cyl(0.15, 0.22, 0.3), Vector3(0, -0.08, 0), cloak)
	part(t, box(0.44, 0.9, 0.03), Vector3(0, 0.08, 0.16), cloak, Vector3(-0.12, 0, 0))
	part(t, cyl(0.05, 0.045, 0.4), Vector3(-0.09, 0.4, 0.12), leather, Vector3(0.2, 0, 0.35))
	var n: Node3D = r.neck
	part(n, sphere(0.1), Vector3(0, 0.13, -0.01), skin)
	part(n, sphere(0.106, 0.9), Vector3(0, 0.16, 0.02), hair)
	part(n, box(0.08, 0.3, 0.04), Vector3(0, 0.0, 0.08), hair, Vector3(0.2, 0, 0))
	part(n, sphere(0.13), Vector3(0, 0.15, 0.04), cloak, Vector3.ZERO, Vector3(1, 1.05, 1.05))
	for s in [-1, 1]:
		eye(n, Vector3(0.04 * s, 0.14, -0.095), 0.018, Color(0.75, 0.6, 1.0))
	bow(r.hand_l, mat(Color(0.25, 0.2, 0.3)))
	r.scale = 0.98
	return r


## Bloated thing that spits bile.
func _spitter() -> Dictionary:
	var skin := mat(Color(0.55, 0.58, 0.3), 0.6)
	var dark := mat(Color(0.32, 0.35, 0.16), 0.75)
	var r := humanoid({"arm_mat": skin, "leg_mat": dark, "limb": 0.05, "leg": 0.085, "hip_h": 0.5, "chest_h": 0.5, "shoulders": 0.32, "arm_len": 0.24, "foot_mat": dark})
	var t: Node3D = r.torso
	part(t, sphere(0.42), Vector3(0, 0.22, 0), skin, Vector3.ZERO, Vector3(1, 0.95, 1.05))
	for i in 7:
		var a := i * 1.7
		part(t, sphere(0.07), Vector3(cos(a) * 0.36, 0.2 + sin(i * 2.3) * 0.18, sin(a) * 0.36), mat(Color(0.75, 0.7, 0.25), 0.4), Vector3.ZERO, Vector3.ONE, Color(0.55, 0.65, 0.1, 1))
	var n: Node3D = r.neck
	n.position = Vector3(0, 0.5, -0.24)
	part(n, sphere(0.15, 0.85), Vector3(0, 0.06, -0.04), skin)
	part(n, sphere(0.1, 0.5), Vector3(0, 0.0, -0.15), mat(Color(0.2, 0.06, 0.04)))           # gaping mouth
	for s in [-1, 1]:
		eye(n, Vector3(0.07 * s, 0.13, -0.13), 0.024, Color(0.8, 1.0, 0.25))
	r.scale = 1.05
	return r


## Walking deadwood: bark, moss, thorns, ember eyes.
func _thornback() -> Dictionary:
	var bark := mat(Color(0.3, 0.22, 0.15), 1.0)
	var moss := mat(Color(0.22, 0.32, 0.14), 1.0)
	var thorn := mat(Color(0.5, 0.42, 0.3), 0.7)
	var r := humanoid({"arm_mat": bark, "leg_mat": bark, "limb": 0.1, "leg": 0.12, "hip_h": 0.85, "chest_h": 0.75, "shoulders": 0.36, "arm_len": 0.42, "foot_mat": bark})
	var t: Node3D = r.torso
	t.rotation.x = 0.25
	part(t, cyl(0.28, 0.24, 0.85), Vector3(0, 0.38, 0), bark, Vector3.ZERO, Vector3(1, 1, 0.8))
	part(t, sphere(0.22), Vector3(0.1, 0.72, 0.05), moss)
	part(t, sphere(0.16), Vector3(-0.15, 0.3, -0.12), moss)
	for i in 10:
		var a := i * 2.1
		part(t, cyl(0.0, 0.04, 0.24), Vector3(cos(a) * 0.25, 0.15 + i * 0.07, sin(a) * 0.2), thorn, Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2))
	for s in [-1, 1]:
		var k := "l" if s < 0 else "r"
		part(r["hand_" + k], sphere(0.14, 0.9), Vector3(0, -0.05, 0), bark)
		for c in 3:
			part(r["hand_" + k], cyl(0.0, 0.03, 0.2), Vector3((c - 1) * 0.06, -0.18, -0.02), thorn, Vector3(0.3, 0, 0))
		part(t, cyl(0.02, 0.05, 0.45), Vector3(0.22 * s, 0.95, 0.05), bark, Vector3(0, 0, -0.45 * s))  # antler branches
	var n: Node3D = r.neck
	part(n, sphere(0.15, 1.1), Vector3(0, 0.1, -0.06), bark)
	for s in [-1, 1]:
		eye(n, Vector3(0.06 * s, 0.13, -0.19), 0.03, Color(1, 0.6, 0.15))
	r.scale = 1.35
	return r


# ---------- animation ----------

const ANIMS := ["idle", "walk", "attack", "death", "cast"]
const FRAMES := 8


func _reset(r: Dictionary) -> void:
	for k in ["hip_l", "hip_r", "knee_l", "knee_r", "sh_l", "sh_r", "el_l", "el_r",
			"leg_fl", "leg_fr", "leg_bl", "leg_br", "knee_fl", "knee_fr", "knee_bl", "knee_br"]:
		if r.has(k):
			r[k].rotation = Vector3.ZERO
	r.body.rotation = Vector3.ZERO
	r.body.position = Vector3.ZERO
	r.body.scale = Vector3.ONE
	r.hips.rotation = Vector3.ZERO


## Pose rig r for animation anim at progress p (0..1). Loops use p as phase.
func pose(type: String, r: Dictionary, anim: String, p: float) -> void:
	if not r.has("base_hips_y"):
		r.base_hips_y = r.hips.position.y
		r.base_neck_rot = r.neck.rotation
		r.base_torso_rot = r.torso.rotation
	_reset(r)
	r.hips.position.y = r.base_hips_y
	r.neck.rotation = r.base_neck_rot
	r.torso.rotation = r.base_torso_rot
	r.torso.scale = Vector3.ONE
	if r.get("quad", false):
		_pose_quad(type, r, anim, p)
		return
	var base_hips_y: float = r.base_hips_y
	var ph := p * TAU
	var style: String = STYLE[type]
	# resting arm angles: slightly forward and out
	r.sh_l.rotation = Vector3(0.15, 0, -0.12)
	r.sh_r.rotation = Vector3(0.15, 0, 0.12)
	r.el_l.rotation.x = 0.35
	r.el_r.rotation.x = 0.35
	if style in ["staff", "bow"]:
		r.sh_l.rotation = Vector3(0.5, 0, -0.15)
		r.el_l.rotation.x = 0.9
	if type == "rotling":
		r.sh_l.rotation = Vector3(1.25, 0, -0.05)
		r.sh_r.rotation = Vector3(1.1, 0, 0.1)
		r.el_l.rotation.x = 0.15
		r.el_r.rotation.x = 0.25
	if r.get("float", false):
		r.body.position.y = 0.22 + sin(ph) * 0.04
	match anim:
		"idle":
			var b := sin(ph)
			r.hips.position.y = base_hips_y + b * 0.01
			r.sh_l.rotation.z += b * 0.03
			r.sh_r.rotation.z -= b * 0.03
			r.el_r.rotation.x += b * 0.05
			if r.has("tail"):
				r.tail.rotation.y = sin(ph) * 0.3
			if type == "spitter":
				r.torso.scale = Vector3.ONE * (1.0 + b * 0.03)
		"walk":
			var s := sin(ph)
			var c := cos(ph)
			var stride := 0.38 if type in ["brute", "thornback", "spitter"] else 0.55
			if type == "rotling":
				stride = 0.35
			if not r.get("float", false):
				r.hip_l.rotation.x = s * stride
				r.hip_r.rotation.x = -s * stride
				r.knee_l.rotation.x = -maxf(0.0, -s) * 0.9 - 0.1
				r.knee_r.rotation.x = -maxf(0.0, s) * 0.9 - 0.1
				r.hips.position.y = base_hips_y + absf(c) * 0.04 - 0.02
			else:
				r.body.rotation.x = 0.15
			if type != "rotling":
				if not style in ["staff", "bow"]:
					r.sh_l.rotation.x = -s * 0.5 + 0.15
				r.sh_r.rotation.x = s * 0.5 + 0.15
			else:
				r.sh_l.rotation.x += s * 0.12
				r.sh_r.rotation.x -= s * 0.12
				r.body.rotation.z = s * 0.06
			r.hips.rotation.y = s * 0.08
			if r.has("tail"):
				r.tail.rotation.y = s * 0.5
		"attack":
			_pose_attack(style, r, p)
		"cast":
			var a := _ease(minf(1.0, p * 2.2))
			var thrust := clampf((p - 0.45) / 0.25, 0.0, 1.0)
			r.sh_l.rotation.x = lerpf(0.15, 1.5, a) - thrust * 0.1
			r.sh_r.rotation.x = lerpf(0.15, 1.3, a)
			r.el_l.rotation.x = lerpf(0.35, 0.05, thrust)
			r.el_r.rotation.x = lerpf(0.35, 0.6, a)
			r.hips.rotation.y = -0.15 * a
			r.hip_l.rotation.x = 0.25 * thrust
			r.hip_r.rotation.x = -0.2 * thrust
		"death":
			var f := _ease(minf(1.0, p * 1.25))
			if r.get("float", false):
				r.body.position.y = lerpf(0.22, -0.3, f)
				r.body.rotation.x = -f * 0.6
				r.body.scale = Vector3.ONE * (1.0 - f * 0.4)
				return
			r.body.rotation.x = -f * 1.45
			r.body.position.y = -f * 0.05
			r.knee_l.rotation.x = -f * 0.8
			r.knee_r.rotation.x = -f * 0.5
			r.hip_l.rotation.x = f * 0.5
			r.sh_l.rotation = Vector3(f * 2.2, 0, -0.3 - f * 0.5)
			r.sh_r.rotation = Vector3(f * 2.4, 0, 0.3 + f * 0.6)


func _pose_attack(style: String, r: Dictionary, p: float) -> void:
	var raise := 0.0
	var swing_t := clampf((p - 0.35) / 0.3, 0.0, 1.0)
	if p < 0.35:
		raise = p / 0.35
	match style:
		"staff":
			r.sh_l.rotation.x = lerpf(0.5, 1.6, _ease(minf(1.0, p * 2.0))) - (0.4 if p > 0.6 else 0.0)
			r.el_l.rotation.x = lerpf(0.9, 0.2, minf(1.0, p * 2.0))
			r.sh_r.rotation.x = lerpf(0.15, 1.2, _ease(minf(1.0, p * 2.0)))
		"claw":
			var a := sin(p * PI)
			r.sh_l.rotation.x = 0.4 + a * 1.4
			r.sh_r.rotation.x = 0.4 + sin(clampf(p * 1.4 - 0.2, 0.0, 1.0) * PI) * 1.4
			r.body.position.z = -a * 0.18
		"bow":
			# raise the bow, draw the string back to the cheek, loose
			var up := _ease(minf(1.0, p * 2.5))
			var loose := p > 0.7
			r.sh_l.rotation = Vector3(lerpf(0.5, 1.5, up), 0, -0.1)
			r.el_l.rotation.x = lerpf(0.9, 0.05, up)
			r.sh_r.rotation = Vector3(lerpf(0.15, 1.45, up), 0, 0.2)
			r.el_r.rotation.x = lerpf(0.35, 1.2 if loose else 2.0, up)
			r.hips.rotation.y = lerpf(0.0, 0.5, up)
		"thrust":
			var back := _ease(minf(1.0, p / 0.4))
			var fwd := _ease(clampf((p - 0.4) / 0.2, 0.0, 1.0))
			var rec := clampf((p - 0.75) / 0.25, 0.0, 1.0)
			var arm := lerpf(lerpf(0.3, -0.2, back), 1.3, fwd)
			arm = lerpf(arm, 0.5, rec)
			r.sh_r.rotation.x = arm
			r.el_r.rotation.x = lerpf(0.9, 0.1, fwd)
			r.sh_l.rotation.x = arm * 0.8
			r.el_l.rotation.x = 0.6
			r.body.position.z = -fwd * 0.15 * (1.0 - rec)
			r.hip_l.rotation.x = 0.35 * fwd
			r.hip_r.rotation.x = -0.25 * fwd
		"spit":
			var back := _ease(minf(1.0, p / 0.45))
			var fwd := _ease(clampf((p - 0.45) / 0.2, 0.0, 1.0))
			r.torso.rotation.x = lerpf(0.0, -0.35, back) + fwd * 0.6
			r.neck.rotation.x = -fwd * 0.5
			r.sh_l.rotation.x = 0.6 * back
			r.sh_r.rotation.x = 0.6 * back
		"slam":
			var up := _ease(minf(1.0, p / 0.4))
			var down := _ease(clampf((p - 0.4) / 0.2, 0.0, 1.0))
			var a := lerpf(lerpf(0.15, 2.8, up), 0.6, down)
			r.sh_l.rotation.x = a
			r.sh_r.rotation.x = a
			r.el_l.rotation.x = 0.4
			r.el_r.rotation.x = 0.4
			r.torso.rotation.x = 0.25 - up * 0.2 + down * 0.45
			r.knee_l.rotation.x = -0.3 * down
			r.knee_r.rotation.x = -0.3 * down
		_:
			# wind up overhead, strike forward and down, recover
			var ang := lerpf(0.15, 2.7, _ease(raise))
			if p >= 0.35:
				ang = lerpf(2.7, 0.5, _ease(swing_t))
			if p > 0.75:
				ang = lerpf(0.5, 0.2, (p - 0.75) / 0.25)
			r.sh_r.rotation.x = ang
			r.el_r.rotation.x = 0.25 if p < 0.35 else 0.1
			r.sh_l.rotation.x = 0.3 + _ease(raise) * 0.4
			r.hips.rotation.y = lerpf(0.0, -0.35, _ease(raise)) if p < 0.35 else lerpf(-0.35, 0.3, _ease(swing_t))
			r.hip_l.rotation.x = 0.3 * swing_t
			r.hip_r.rotation.x = -0.25 * swing_t
			r.knee_r.rotation.x = -0.3 * swing_t


func _pose_quad(type: String, r: Dictionary, anim: String, p: float) -> void:
	var ph := p * TAU
	var base_y: float = r.base_hips_y
	var neck0: Vector3 = r.base_neck_rot
	match anim:
		"idle":
			r.hips.position.y = base_y + sin(ph) * 0.008
			r.neck.rotation.y = sin(ph) * 0.15
			r.tail.rotation.y = sin(ph * 2.0) * 0.4
		"walk":
			var s := sin(ph)
			var stride := 0.6
			r.leg_fl.rotation.x = s * stride
			r.leg_br.rotation.x = s * stride
			r.leg_fr.rotation.x = -s * stride
			r.leg_bl.rotation.x = -s * stride
			r.knee_fl.rotation.x = -maxf(0.0, -s) * 0.8
			r.knee_br.rotation.x = maxf(0.0, -s) * 0.8
			r.knee_fr.rotation.x = -maxf(0.0, s) * 0.8
			r.knee_bl.rotation.x = maxf(0.0, s) * 0.8
			r.hips.position.y = base_y + absf(cos(ph)) * 0.03
			r.tail.rotation.y = s * 0.4
			r.neck.rotation.x = neck0.x + cos(ph * 2.0) * 0.05
		"attack":
			if STYLE[type] == "rear":
				# bristle and flick the quills
				var a := sin(minf(1.0, p * 1.3) * PI)
				r.hips.rotation.x = -a * 0.35
				r.torso.rotation.z = sin(p * TAU * 3.0) * 0.12 * a
				r.leg_fl.rotation.x = -a * 0.5
				r.leg_fr.rotation.x = -a * 0.5
			else:
				var a := sin(p * PI)
				r.body.position.z = -a * 0.35
				r.hips.rotation.x = a * 0.15
				r.neck.rotation.x = neck0.x - 0.3 + a * 0.6
				r.leg_fl.rotation.x = -a * 0.7
				r.leg_fr.rotation.x = -a * 0.6
				r.leg_bl.rotation.x = a * 0.4
				r.leg_br.rotation.x = a * 0.5
		"death":
			var f := _ease(minf(1.0, p * 1.25))
			r.body.rotation.z = f * 1.5
			r.body.position.y = -f * 0.04
			for k in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
				r[k].rotation.x = f * 0.4 * (1.0 if k.ends_with("l") else -1.0)
			r.neck.rotation.x = neck0.x + f * 0.5


func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
