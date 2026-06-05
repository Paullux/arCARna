shader_type spatial;

// Recolorie une voiture : désature la texture (niveaux de gris), éclaircit,
// puis multiplie par une teinte → voitures de couleurs variées depuis 1 texture.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform bool has_tex = true;
uniform vec3 tint : source_color = vec3(1.0, 0.2, 0.2);
uniform float lighten : hint_range(0.0, 1.0) = 0.25;
uniform float contrast : hint_range(0.0, 2.0) = 0.8;
uniform float metallic_v : hint_range(0.0, 1.0) = 0.4;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	float lum = 0.7;
	if (has_tex) {
		vec3 c = texture(albedo_tex, UV).rgb;
		lum = dot(c, vec3(0.299, 0.587, 0.114));
	}
	lum = clamp((lum - 0.5) * contrast + 0.5 + lighten, 0.08, 1.0);
	ALBEDO = tint * lum;
	METALLIC = metallic_v;
	ROUGHNESS = roughness_v;
}
