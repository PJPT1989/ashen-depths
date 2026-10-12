extends Node
## Frame-rate benchmark, enabled with:  godot --path . -- --bench [--web] [--quality=0|1|2] [--area=1] [--off=...]
## --off switches things off to see what they cost: shadows, pcf, lights, particles, occluders,
## post, viewport (draw at base size and scale up). --web uses the browser build's settings;
## --quality 0 is low, 1 medium (the browser's default), 2 high (the desktop default).
## --shot=file.png saves the last frame; --seed=N gives the same area layouts every run.
## Starts the game in an area, waits, counts frames for a few seconds, prints the result and quits.

var main
var area := 0
var off: PackedStringArray = []
var t := 0.0
var frames := 0
var t0 := 0
var proc_ms := 0.0
var draws := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--area="):
			area = int(a.substr(7))
		if a.begins_with("--off="):
			off = a.substr(6).split(",")
	Game.save_settings = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			Game.set_quality(int(a.substr(10)))
	main.hud.title_screen.visible = false
	main.start_game()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			# same area layouts every run, to compare screenshots
			for i in main.area_seeds.size():
				main.area_seeds[i] = hash(a + str(i))
	if area > 0:
		main.load_area(area, "start")
	if "viewport" in off:
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT


func _apply(n: Node) -> void:
	for c in n.get_children():
		if c is PointLight2D:
			if "shadows" in off:
				c.shadow_enabled = false
			if "pcf" in off:
				c.shadow_filter = Light2D.SHADOW_FILTER_NONE
			if "monsterlights" in off and n is Monster:
				c.visible = false
			if "twins" in off and c.range_item_cull_mask == 2:
				c.visible = false
			if "lights" in off:
				c.visible = false
		if c is CPUParticles2D and "particles" in off:
			c.emitting = false
			c.visible = false
		if c is Prop and "props" in off:
			c.visible = false
		if c is Prop and "proplight" in off:
			c.light_mask = 0
		if c is LightOccluder2D and "occluders" in off:
			c.visible = false
		_apply(c)


func _process(dt: float) -> void:
	t += dt
	if t < 1.0:
		if "normals" in off:
			for d in Game._sheets.values():
				d.tex.normal_texture = null
			for x in Game._tex_cache.values():
				x.normal_texture = null
		_apply(get_tree().root)
		if main.post and "post" in off:
			_hide_post(get_tree().root)
		return
	if t0 == 0:
		t0 = Time.get_ticks_usec()
		frames = 0
		return
	frames += 1
	proc_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var el := (Time.get_ticks_usec() - t0) / 1e6
	if el >= 6.0:
		var counts := {}
		for l in get_tree().root.find_children("*", "PointLight2D", true, false):
			var k: String = l.get_parent().get_script().resource_path.get_file() if l.get_parent().get_script() else l.get_parent().get_class()
			counts[k] = counts.get(k, 0) + (1 if l.visible else 0)
		print("BENCH lights ", counts)
		var kinds := {}
		for n in get_tree().root.find_children("*", "CanvasItem", true, false):
			if n.is_visible_in_tree():
				var k: String = n.get_script().resource_path.get_file() if n.get_script() else n.get_class()
				kinds[k] = kinds.get(k, 0) + 1
		print("BENCH items ", kinds)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--shot="):
				get_viewport().get_texture().get_image().save_png(a.substr(7))
		print("BENCH area %d off=%s: %.1f fps (scripts %.1f ms, %d draw calls a frame)" % [area, ",".join(off), frames / el, proc_ms / frames, draws / frames])
		get_tree().quit()


func _hide_post(n: Node) -> void:
	for c in n.get_children():
		if c is ColorRect and c.material == main.post:
			c.visible = false
		_hide_post(c)
