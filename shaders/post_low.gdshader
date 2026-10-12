// Low quality version of post.gdshader: vignette and the red hurt pulse drawn over the picture,
// without reading the screen back (no grade, grain or bloom), for slow computers.
shader_type canvas_item;

uniform float vignette = 0.6;
uniform float hurt = 0.0;

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(d);
	float v = vignette * smoothstep(0.35, 0.95, r);
	float h = hurt * smoothstep(0.25, 0.85, r) * 0.75;
	vec3 red = vec3(0.5, 0.02, 0.02);
	COLOR = vec4(red * (h / max(h + v, 0.0001)), clamp(v + h, 0.0, 1.0));
}
