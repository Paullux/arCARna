shader_type spatial;
render_mode cull_disabled;

// Barrière néon : seules les zones vives de la texture émettent (courbe de
// contraste), le corps gris du mur reste sombre. Évite les murs "tout blancs".
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float emit_strength = 2.5;
uniform float contrast = 3.5;     // plus haut = seuls les pixels très vifs glow
uniform float albedo_mul = 0.2;   // assombrit le corps du mur

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	ALBEDO = c * albedo_mul;
	// crush des gris vers le noir, conserve les néons proches de 1
	vec3 neon = pow(clamp(c, 0.0, 1.0), vec3(contrast));
	EMISSION = neon * emit_strength;
	ROUGHNESS = 0.7;
	METALLIC = 0.0;
}
