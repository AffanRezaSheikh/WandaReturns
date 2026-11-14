// Hex Sphere: translucent chaos bubble with a bright rim and drifting hex bands.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec3 tint : source_color = vec3(1.0, 0.18, 0.3);
uniform float power = 1.0;
void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	float bands = 0.5 + 0.5 * sin(UV.y * 40.0 + TIME * 2.0 + sin(UV.x * 30.0 + TIME) * 1.5);
	ALBEDO = tint * (fres * 1.6 + bands * 0.12 + 0.06) * power;
	ALPHA = clamp(fres + 0.05 + bands * 0.06, 0.0, 1.0) * clamp(power, 0.0, 1.0);
}
