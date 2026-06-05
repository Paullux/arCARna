shader_type spatial;
render_mode cull_disabled;

// Boudin néon animé : glow de base + bandes lumineuses qui défilent le long
// du tube (UV.x = distance le long du boudin, en mètres).
uniform vec3 neon_color : source_color = vec3(1.0, 0.1, 0.1);
uniform float base_glow = 1.2;       // intensité de fond
uniform float pulse_strength = 3.0;  // éclat des bandes qui défilent
uniform float pulse_freq = 0.06;     // bandes par mètre
uniform float pulse_speed = 9.0;     // m/s de défilement
uniform float pulse_width = 0.25;    // largeur relative des bandes (0..1)

void fragment() {
	float wave = fract(UV.x * pulse_freq - TIME * pulse_speed * pulse_freq);
	// bande douce
	float band = smoothstep(1.0 - pulse_width, 1.0, wave);
	band += smoothstep(pulse_width, 0.0, wave); // tête de bande nette
	float e = base_glow + band * pulse_strength;
	ALBEDO = neon_color * 0.08;
	EMISSION = neon_color * e;
	ROUGHNESS = 0.4;
}
