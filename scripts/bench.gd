extends Node
## Frame-rate benchmark, enabled with:  godot --path . -- --bench [--web] [--area=1] [--off=...]
## --off switches things off to see what they cost: shadows, pcf, lights, particles, occluders,
## post, viewport (draw at base size and scale up). --web uses the browser build's settings.
## Starts the game in an area, waits, counts frames for a few seconds, prints the result and quits.

var main
var area := 0
var off: PackedStringArray = []
var t := 0.0
var frames := 0
var t0 := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--area="):
			area = int(a.substr(7))
		if a.begins_with("--off="):
			off = a.substr(6).split(",")
	main.hud.title_screen.visible = false
	main.start_game()
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
			if "lights" in off:
				c.visible = false
		if c is CPUParticles2D and "particles" in off:
			c.emitting = false
			c.visible = false
		if c is LightOccluder2D and "occluders" in off:
			c.visible = false
		_apply(c)


func _process(dt: float) -> void:
	t += dt
	if t < 1.0:
		_apply(get_tree().root)
		if main.post and "post" in off:
			_hide_post(get_tree().root)
		return
	if t0 == 0:
		t0 = Time.get_ticks_usec()
		frames = 0
		return
	frames += 1
	var el := (Time.get_ticks_usec() - t0) / 1e6
	if el >= 6.0:
		print("BENCH area %d off=%s: %.1f fps" % [area, ",".join(off), frames / el])
		get_tree().quit()


func _hide_post(n: Node) -> void:
	for c in n.get_children():
		if c is ColorRect and c.material == main.post:
			c.visible = false
		_hide_post(c)
