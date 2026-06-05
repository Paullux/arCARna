shader_type spatial;
render_mode cull_back;

// Pad de recharge des stands : fond sombre + barres d'énergie qui défilent
// dans le sens de la piste (symbolise la charge). Lumière modérée.
uniform vec3 col : source_color = vec3(0.15, 1.0, 0.55);
uniform vec2 flow_axis = vec2(1.0, 0.0);  // sens d'écoulement des barres (x,z monde)
uniform float spacing_m = 5.0;     // espacement des barres (m)
uniform float speed = 6.0;         // m/s de défilement
uniform float base_glow = 0.18;
uniform float bar_glow = 0.7;
uniform float active = 0.0;        // 0..1 : intensifie quand on recharge

void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float along = dot(w.xz, normalize(flow_axis));
	float phase = along / spacing_m - TIME * speed / spacing_m;
	float band = fract(phase);
	// barre nette
	float bar = smoothstep(0.62, 0.74, band) - smoothstep(0.74, 0.86, band);
	float g = base_glow + bar * (bar_glow + active * 0.8);
	ALBEDO = col * 0.04;
	EMISSION = col * g;
	ROUGHNESS = 0.6;
}
