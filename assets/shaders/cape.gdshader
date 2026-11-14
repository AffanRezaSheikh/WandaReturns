// Wanda's cape: waves at rest, streams out behind her with speed.
shader_type spatial;
render_mode cull_disabled;
uniform vec3 color_out : source_color = vec3(0.78, 0.09, 0.18);
uniform vec3 color_in : source_color = vec3(0.30, 0.03, 0.09);
uniform float stream = 0.0;
void vertex() {
	float w = UV.y;
	VERTEX.z += w * stream * 0.85 + sin(TIME * 3.0 + UV.y * 6.0 + UV.x * 3.0) * 0.035 * w * (1.0 + stream * 2.5);
	VERTEX.y += w * w * stream * 0.5;
	VERTEX.x += sin(TIME * 2.3 + UV.y * 5.0) * 0.03 * w;
}
void fragment() {
	vec3 c = FRONT_FACING ? color_in : color_out;
	ALBEDO = c * (0.82 + 0.18 * sin(UV.x * 22.0));
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
	ROUGHNESS = 0.7;
	EMISSION = c * 0.22;
}
