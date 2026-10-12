extends SceneTree
## Renders every model in tools/models.gd into sprite sheets for the game.
##
##   godot --path . --rendering-driver opengl3 --script res://tools/bake_sprites.gd
##   add  -- --preview          to render stills of every model into sprites/preview.png instead
##   add  -- --only=hero,brute  to bake (or preview) just some models
##   add  -- --layers=base_ajani,boots  to bake just some hero layers
##   preview "hero:ajani+armor_heavy+weapon_axe" for one hero body with some gear on
##
## For each monster it writes three sheets into sprites/:
##   <type>_color.png   lit color
##   <type>_normal.png  view-space normals for Godot's 2D lights
##   <type>_glow.png    eyes, orbs and other glowing parts (drawn additively in game;
##                      tools/finish_glow.py turns its brightness into alpha afterwards)
## The hero is baked once per layer (hero_<layer>_color.png and _normal.png): a body for each
## hero class (base_ajani, ...), then each piece of gear. Each gear layer
## is rendered with a plain human body as a hold-out: wherever the body is in front of the gear,
## the gear is cut away, so the game can stack layers over the body in a fixed order.
## Layout: columns are frames, rows are (animation * 8 + direction). Direction d faces
## screen angle d * 45 degrees (0 = right, 2 = down/toward camera).

const Models := preload("res://tools/models.gd")
const PPM := 28.0          # final pixels per meter
const SS := 2              # supersampling factor
const ELEV := 30.0         # camera elevation; matches the game's 2:1 isometric tiles
const CELLS := {"hero": 112, "townsfolk": 96, "scrabbler": 80, "bonewalker": 112, "hexcaller": 112, "brute": 144,
	"warden": 160, "rotling": 112, "gloomhound": 112, "quillback": 96, "bone_archer": 112, "wraith": 112,
	"zealot": 128, "reaver": 128, "moonsister": 112, "spitter": 112, "thornback": 144}
const ANCHOR_Y := 0.8      # feet sit at this fraction of the cell height
## Gear that is held away from the body is also cut by the mid-weight armour, so a sword
## behind the back doesn't show through the torso.
const HOLDOUT := {"weapon": ["base", "human", "armor_medium"], "shield": ["base", "human", "armor_medium"]}

var models := Models.new()
var vp: SubViewport
var cam: Camera3D
var world: Node3D
var normal_mat: ShaderMaterial
var holdout_mat: ShaderMaterial
var right := Vector3.ZERO
var up := Vector3.ZERO
var toward := Vector3.ZERO   # horizontal direction toward the camera (screen down)


func _initialize() -> void:
	_setup()
	_run.call_deferred()


func _setup() -> void:
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.48, 0.46)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var az := deg_to_rad(45.0)
	var el := deg_to_rad(ELEV)
	cam.near = 1.0
	cam.far = 200.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az)) * 60.0, Vector3.ZERO, Vector3.UP)
	right = cam.transform.basis.x
	up = cam.transform.basis.y
	toward = Vector3(cam.position.x, 0, cam.position.z).normalized()
	# key light from the camera's upper left, a cool rim from behind
	var key := DirectionalLight3D.new()
	key.light_energy = 1.25
	key.light_color = Color(1.0, 0.95, 0.88)
	vp.add_child(key)
	key.look_at_from_position(cam.position - right * 40.0 + Vector3.UP * 50.0, Vector3.ZERO, Vector3.UP)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 0.6
	rim.light_color = Color(0.7, 0.8, 1.0)
	vp.add_child(rim)
	rim.look_at_from_position(-cam.position + Vector3.UP * 30.0, Vector3.ZERO, Vector3.UP)
	world = Node3D.new()
	vp.add_child(world)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
// the compatibility renderer writes unshaded albedo straight through, so no sRGB fix-up
void fragment() { ALBEDO = NORMAL * 0.5 + 0.5; }
"""
	normal_mat = ShaderMaterial.new()
	normal_mat.shader = sh
	# multiplies what is already drawn by zero wherever it is in front: a cut-out
	var ho := Shader.new()
	ho.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_always, cull_back;
void fragment() { ALBEDO = vec3(0.0); ALPHA = 0.0; }
"""
	holdout_mat = ShaderMaterial.new()
	holdout_mat.shader = ho


## World-space facing for screen angle theta (0 = right, PI/2 = down).
func _facing(theta: float) -> Vector3:
	var phi := atan2(sin(theta) / sin(deg_to_rad(ELEV)), cos(theta))
	return (right * cos(phi) + toward * sin(phi)).normalized()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://sprites"))
	var only: Array = []
	var layers: Array = Models.HERO_LAYERS
	for a in args:
		if a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
		if a.begins_with("--layers="):
			layers = Array(a.substr(9).split(","))
	if "--preview" in args:
		await _preview(only if not only.is_empty() else Models.TYPES)
	else:
		for type in Models.TYPES:
			if only.is_empty() or type in only:
				if type == "hero":
					for l in layers:
						await _bake(type, l)
				else:
					await _bake(type, "")
	quit()


func _clear() -> void:
	for c in world.get_children():
		world.remove_child(c)
		c.free()
	models.emissive.clear()
	models.layer_of.clear()
	_saved.clear()


## Place a fresh model so its feet land on pixel (px, py) of the viewport.
func _place(type: String, px: float, py: float, theta: float, anim: String, p: float) -> Dictionary:
	var r: Dictionary = models.build(type)
	var node: Node3D = r.root
	var s: float = r.scale
	node.scale = Vector3(s, s, s)
	world.add_child(node)
	var ppm := PPM * SS
	var w := float(vp.size.x)
	var h := float(vp.size.y)
	node.position = right * ((px - w * 0.5) / ppm) - up * ((py - h * 0.5) / ppm)
	var f := _facing(theta)
	node.rotation.y = atan2(-f.x, -f.z)
	models.pose(type, r, anim, p)
	return r


func _render(pass_name: String, rigs: Array, layer: String) -> Image:
	for r in rigs:
		_apply_pass(r.root, pass_name, layer)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


var _saved := {}
func _apply_pass(n: Node, pass_name: String, layer: String) -> void:
	if n is MeshInstance3D:
		if not _saved.has(n):
			_saved[n] = n.material_override
		var mine := true
		n.visible = true
		if layer != "":
			var lay: String = models.layer_of.get(n, "base")
			# a hero body (base_<class>) is drawn over the shared limbs; gear is cut by the
			# plain human body so it stacks the same way on every hero
			var body := layer.begins_with("base")
			var cut: Array = [] if body else HOLDOUT.get(layer.split("_")[0], ["base", "human"])
			if lay != layer and not (body and lay == "base"):
				mine = false
				if lay in cut:
					n.material_override = holdout_mat
				else:
					n.visible = false
		if mine:
			match pass_name:
				"color":
					n.material_override = _saved[n]
				"normal":
					n.material_override = normal_mat
				"glow":
					var m := StandardMaterial3D.new()
					m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					m.albedo_color = models.emissive.get(n, Color(0, 0, 0, 1))
					m.albedo_color.a = 1.0
					n.material_override = m
	for c in n.get_children():
		_apply_pass(c, pass_name, layer)


func _bake(type: String, layer: String) -> void:
	var cell: int = CELLS[type]
	var rc := cell * SS
	var frames: int = Models.FRAMES
	var anims: Array = Models.ANIMS if type == "hero" else Models.ANIMS.slice(0, 4)
	var rows := anims.size() * 8
	vp.size = Vector2i(frames * rc, rc)
	cam.size = vp.size.y / (PPM * SS)
	var passes := ["color", "normal"] if type == "hero" else ["color", "normal", "glow"]
	var sheets := {}
	for pass_name in passes:
		sheets[pass_name] = Image.create(frames * cell, rows * cell, false, Image.FORMAT_RGBA8)
	for row in rows:
		_clear()
		var rigs := []
		var anim: String = anims[row / 8]
		var dir := row % 8
		for fi in frames:
			var p := float(fi) / frames if anim in ["idle", "walk"] else float(fi) / (frames - 1)
			rigs.append(_place(type, (fi + 0.5) * rc, ANCHOR_Y * rc, dir * PI / 4.0, anim, p))
		for pass_name in passes:
			var img: Image = await _render(pass_name, rigs, layer)
			img.convert(Image.FORMAT_RGBA8)
			img.resize(img.get_width() / SS, img.get_height() / SS, Image.INTERPOLATE_LANCZOS)
			sheets[pass_name].blit_rect(img, Rect2i(0, 0, frames * cell, cell), Vector2i(0, row * cell))
	var name := type if layer == "" else "%s_%s" % [type, layer]
	for pass_name in sheets:
		sheets[pass_name].save_png("res://sprites/%s_%s.png" % [name, pass_name])
	print("baked %s: %d x %d, %d rows" % [name, frames * cell, rows * cell, rows])


func _show_layers(n: Node, show: Array) -> void:
	if n is MeshInstance3D:
		n.visible = models.layer_of.get(n, "base") in show
	for c in n.get_children():
		_show_layers(c, show)


## One still per model (idle, attack, walk) on a grey ground, for checking models quickly.
func _preview(types: Array) -> void:
	var cell := 176 * SS
	vp.size = Vector2i(cell * types.size(), cell * 3)
	cam.size = vp.size.y / (PPM * SS)
	_clear()
	var i := 0
	for type in types:
		# "hero:ajani+boots+weapon_axe" previews one hero body with some gear on
		var parts: Array = Array(type.split(":"))
		var model: String = parts[0]
		var show: Array = []
		if parts.size() > 1:
			show = Array(parts[1].split("+"))
			show[0] = "base_" + show[0]
			show.append("base")
		for row in [[0.85, PI / 2 - PI / 4, "idle", 0.0], [1.85, PI / 4, "attack", 0.45], [2.85, 0.0, "walk", 0.25]]:
			var r := _place(model, (i + 0.5) * cell, row[0] * cell, row[1], row[2], row[3])
			if not show.is_empty():
				_show_layers(r.root, show)
		i += 1
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var bg := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.22, 0.2, 0.18))
	bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	bg.resize(bg.get_width() / SS, bg.get_height() / SS, Image.INTERPOLATE_LANCZOS)
	bg.save_png("res://sprites/preview.png")
	print("preview written")
