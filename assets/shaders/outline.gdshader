// Inverted-hull ink outline for cel-shaded characters.
shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 color : source_color = vec4(0.13, 0.04, 0.1, 1.0);
uniform float width = 0.011;
void vertex() {
	VERTEX += NORMAL * width;
}
void fragment() {
	ALBEDO = color.rgb;
}
