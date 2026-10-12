// Monster rank colour: keeps the sprite's light and shade but pulls its hue toward a tint.
shader_type canvas_item;

uniform vec3 tint = vec3(1.0);
uniform float amount = 0.0;

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 coloured = l * tint * 1.45;
	COLOR = vec4(mix(c.rgb, coloured, amount), c.a);
}
