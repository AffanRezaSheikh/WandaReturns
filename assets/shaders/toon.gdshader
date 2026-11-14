// Anime cel-shading for characters: hard two-tone bands on skin and hair
// (softness ~0.02), softer painterly gradients on cloth (softness ~0.25).
shader_type spatial;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 shade_tint : source_color = vec3(0.6, 0.48, 0.62);
uniform float band = 0.5;
uniform float softness = 0.03;
uniform float rim = 0.25;
uniform float glow = 0.0;
uniform float self_light = 0.16;
uniform float grad = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
uniform bool ghost = false;
varying float h;
void vertex() {
	h = VERTEX.y;
}
void fragment() {
	vec3 c = albedo.rgb * mix(1.0, 0.62 + 0.5 * smoothstep(0.0, 1.7, h), grad);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * (self_light + glow) + vec3(1.0, 0.9, 0.92) * step(0.55, fres) * rim * 0.35 + flash_color * flash;
	if (ghost) {
		ivec2 p = ivec2(FRAGCOORD.xy);
		if ((p.x + p.y) % 2 == 0) { discard; }
	}
}
void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float t = smoothstep(band - softness, band + softness, ndl);
	DIFFUSE_LIGHT += mix(shade_tint, vec3(1.0), t) * ATTENUATION * LIGHT_COLOR / PI * 0.85;
}
