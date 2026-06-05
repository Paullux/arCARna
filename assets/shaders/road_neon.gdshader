shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Route arcade : asphalte sombre + bandes néon lumineuses sur les bords
// et ligne centrale pointillée. Utilise les UV générés par le CSGPolygon3D
// (U le long du tracé, V en travers de la largeur).
uniform vec3 road_color : source_color = vec3(0.03, 0.03, 0.05);
uniform vec3 neon_edge : source_color = vec3(0.10, 0.80, 1.0);
uniform vec3 neon_center : source_color = vec3(1.0, 0.25, 0.7);
uniform float edge_width = 0.06;      // largeur des bandes de bord (en V)
uniform float center_width = 0.025;   // demi-largeur de la ligne centrale
uniform float dash_freq = 40.0;       // densité des pointillés le long du tracé
uniform float emit_strength = 3.0;    // pousse le glow

void fragment() {
	float v = fract(UV.y);   // travers de la route 0..1
	float u = UV.x;          // le long du tracé

	// Bandes de bord (néon continu)
	float edge_l = smoothstep(edge_width, 0.0, v);
	float edge_r = smoothstep(1.0 - edge_width, 1.0, v);
	float edge = clamp(edge_l + edge_r, 0.0, 1.0);

	// Ligne centrale pointillée
	float center = smoothstep(center_width, 0.0, abs(v - 0.5));
	float dash = step(0.5, fract(u * dash_freq));
	center *= dash;

	vec3 emit = neon_edge * edge + neon_center * center;
	ALBEDO = road_color;
	EMISSION = emit * emit_strength;
	ROUGHNESS = 0.6;
	METALLIC = 0.0;
}
