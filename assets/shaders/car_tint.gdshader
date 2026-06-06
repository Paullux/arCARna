shader_type spatial;

// Recolorie une voiture : désature la texture (niveaux de gris), éclaircit,
// puis multiplie par une teinte. Les parties très sombres (vitres noires)
// sont conservées telles quelles → voitures colorées avec vitres réalistes.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform bool has_tex = true;
uniform vec3 tint : source_color = vec3(1.0, 0.2, 0.2);
uniform float lighten : hint_range(0.0, 1.0) = 0.25;
uniform float contrast : hint_range(0.0, 2.0) = 0.9;
uniform float dark_keep : hint_range(0.0, 0.5) = 0.20;  // noir SI sombre ET désaturé
uniform float sat_keep : hint_range(0.0, 0.5) = 0.10;   // saturation max pour être "noir"
uniform float metallic_v : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec3 c = vec3(0.7);
	if (has_tex) {
		c = texture(albedo_tex, UV).rgb;
	}
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx - mn;                // 0 = gris/noir, élevé = couleur vive
	// vitres = sombre ET peu saturé (le rouge foncé est saturé → teinté)
	if (lum < dark_keep && sat < sat_keep) {
		ALBEDO = c;                    // vitres / parties noires conservées
	} else {
		float l = clamp((lum - 0.5) * contrast + 0.5 + lighten, 0.08, 1.0);
		ALBEDO = tint * l;             // carrosserie teintée
	}
	METALLIC = metallic_v;
	ROUGHNESS = roughness_v;
}
