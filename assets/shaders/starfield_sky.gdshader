shader_type sky;

// Ciel étoilé procédural — fond sombre dégradé + deux couches d'étoiles
// (proches/lointaines) avec une légère teinte de nébuleuse.
uniform vec3 horizon_color : source_color = vec3(0.06, 0.05, 0.12);
uniform vec3 zenith_color : source_color = vec3(0.01, 0.01, 0.04);
uniform vec3 nebula_color : source_color = vec3(0.15, 0.05, 0.25);
uniform float nebula_amount = 0.0;
uniform float star_density = 60.0;
uniform float star_brightness = 1.4;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// Étoiles : grille en espace direction, une étoile possible par cellule.
float star_layer(vec3 dir, float density, float threshold, float size) {
	vec3 sp = dir * density;
	vec3 id = floor(sp);
	vec3 f = fract(sp) - 0.5;
	float h = hash13(id);
	if (h < threshold) {
		return 0.0;
	}
	vec3 off = (hash33(id) - 0.5) * 0.6;
	float d = length(f - off);
	float bright = 0.4 + 0.6 * hash13(id + 7.0);
	return smoothstep(size, 0.0, d) * bright;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float t = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 base = mix(horizon_color, zenith_color, t);

	// Nébuleuse douce (bruit basse fréquence)
	float neb = hash13(floor(dir * 6.0));
	neb = smoothstep(0.55, 1.0, neb) * nebula_amount;
	base += nebula_color * neb;

	// Deux couches d'étoiles
	float s = star_layer(dir, star_density, 0.88, 0.24);
	s += star_layer(dir, star_density * 2.3, 0.94, 0.17) * 0.7;

	COLOR = base + vec3(s) * star_brightness;
}
