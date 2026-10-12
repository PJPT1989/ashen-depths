// High quality in the browser: post.gdshader's bloom without screen mipmaps (WebGL cannot build
// them), sampled in a wide ring instead. Costly; for fast computers.
// vignette, film grain, and a red pulse at the edges when the hero is hurt.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float bloom = 0.55;
uniform float threshold = 0.5;
uniform float vignette = 0.6;
uniform float grain = 0.035;
uniform float hurt = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 b = vec3(0.0);
	// cheap wide blur: mip samples in a small ring
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 o = vec2(cos(a), sin(a));
		b += texture(screen_tex, uv + o * px * 10.0).rgb;
		b += texture(screen_tex, uv + o * px * 26.0).rgb;
	}
	b /= 16.0;
	b = max(b - threshold, vec3(0.0)) / (1.0 - threshold);
	c += b * bloom * vec3(1.0, 0.85, 0.7);
	// grade: a touch more contrast, warm highlights, cool deep shadows
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, 0.95);
	c = mix(c * vec3(0.92, 0.95, 1.08), c * vec3(1.06, 0.98, 0.9), smoothstep(0.05, 0.5, l));
	c = (c - 0.5) * 1.06 + 0.5;
	// vignette
	vec2 d = uv - 0.5;
	d.x *= px.y / px.x;
	float r = length(d);
	c *= mix(1.0, 1.0 - vignette, smoothstep(0.35, 0.95, r));
	// hurt: red bleeding in from the edges
	c = mix(c, vec3(0.5, 0.02, 0.02), hurt * smoothstep(0.25, 0.85, r) * 0.75);
	float n = fract(sin(dot(FRAGCOORD.xy + vec2(TIME * 61.0, TIME * 37.0), vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
