shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

// Sprite de burst (explosion / étincelles) face caméra, additif.
// Le fond sombre de la texture est masqué par la luminosité.
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float brightness = 2.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.12;

void vertex() {
	// billboard (face caméra) en conservant l'échelle X/Y du node
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * sx,
		INV_VIEW_MATRIX[1] * sy,
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
}

void fragment() {
	vec4 t = texture(tex, UV);
	float lum = max(t.r, max(t.g, t.b));
	float mask = smoothstep(threshold, threshold + 0.18, lum);
	ALBEDO = t.rgb * brightness * fade * mask;
}
