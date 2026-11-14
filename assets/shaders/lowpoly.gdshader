// Flat-shaded low-poly surface used by almost every world mesh.
shader_type spatial;
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform float roughness = 0.9;
uniform float metallic = 0.0;
uniform bool flat_shade = true;
void fragment() {
	ALBEDO = albedo.rgb * COLOR.rgb;
	if (flat_shade) {
		NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	}
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission * emission_energy;
}

// Cel-shaded world: three light bands instead of a smooth falloff.
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float t = smoothstep(0.0, 0.06, ndl) * 0.5 + smoothstep(0.42, 0.5, ndl) * 0.5;
	DIFFUSE_LIGHT += t * ATTENUATION * LIGHT_COLOR / PI;
}
