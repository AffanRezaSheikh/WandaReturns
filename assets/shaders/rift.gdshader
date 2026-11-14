// Swirling chaos rift used for region portals.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;
uniform vec3 tint : source_color = vec3(1.0, 0.15, 0.25);
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = atan(p.y, p.x);
	float swirl = sin(a * 5.0 + r * 9.0 - TIME * 3.0) * 0.5 + 0.5;
	float core = smoothstep(1.0, 0.0, r);
	float ring = smoothstep(0.25, 0.0, abs(r - 0.78));
	ALBEDO = tint * (core * (0.35 + swirl * 0.9) + ring * 2.2) + vec3(1.0, 0.8, 0.8) * pow(core, 6.0);
	ALPHA = clamp(core * 1.4 + ring, 0.0, 1.0) * step(r, 1.0);
}
