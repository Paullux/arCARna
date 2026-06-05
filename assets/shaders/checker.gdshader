shader_type spatial;
render_mode cull_back;

// Damier noir/blanc (ligne de départ/arrivée), basé sur la position monde.
uniform float square_size = 4.0;
uniform vec3 col_a : source_color = vec3(0.95, 0.95, 0.95);
uniform vec3 col_b : source_color = vec3(0.02, 0.02, 0.02);
uniform float emit : hint_range(0.0, 3.0) = 0.5;

void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float cx = floor(w.x / square_size);
	float cz = floor(w.z / square_size);
	float check = mod(cx + cz, 2.0);
	vec3 c = mix(col_b, col_a, check);
	ALBEDO = c;
	EMISSION = c * emit;
	ROUGHNESS = 0.7;
}
