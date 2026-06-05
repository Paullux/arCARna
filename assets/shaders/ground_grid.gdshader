shader_type spatial;
render_mode cull_back, diffuse_burley;

// Grille procédurale sur le sol — repère visuel pour la sensation de vitesse.
uniform vec3 base_color : source_color = vec3(0.08, 0.09, 0.12);
uniform vec3 line_color : source_color = vec3(0.20, 0.45, 0.65);
uniform float cell_size = 4.0;     // mètres par case
uniform float line_width = 0.04;   // épaisseur relative des lignes

void fragment() {
	// world position via INV_VIEW_MATRIX (Godot 4)
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 grid = abs(fract(world.xz / cell_size - 0.5) - 0.5) / fwidth(world.xz / cell_size);
	float line = min(grid.x, grid.y);
	float intensity = 1.0 - clamp(line - line_width, 0.0, 1.0);
	ALBEDO = mix(base_color, line_color, intensity);
	EMISSION = line_color * intensity * 0.4;
	ROUGHNESS = 0.8;
}
