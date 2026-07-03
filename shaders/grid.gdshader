shader_type spatial;
render_mode cull_back;

// Terreno verde con lineas de grilla cada 1 unidad de mundo.
uniform vec3 base_color: source_color = vec3(0.47, 0.65, 0.36);
uniform vec3 line_color: source_color = vec3(0.32, 0.46, 0.25);
uniform float line_width: hint_range(0.0, 0.2) = 0.025;

// Mascara de basura (1 pixel = 1 tile): r=1 tile sucio, r=0 tile limpio.
// Por defecto negra: el mapa arranca limpio.
uniform sampler2D dirt_mask: filter_nearest, hint_default_black;
uniform vec3 dirt_color: source_color = vec3(0.23, 0.2, 0.16);
uniform float dirt_strength: hint_range(0.0, 1.0) = 0.7;
uniform float grid_extent = 20.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = fract(world_pos.xz);
	vec2 dist_to_line = min(cell, 1.0 - cell);
	float d = min(dist_to_line.x, dist_to_line.y);
	float aa = fwidth(d);
	float line = 1.0 - smoothstep(line_width - aa, line_width + aa, d);
	vec3 col = mix(base_color, line_color, line);
	float dirty = texture(dirt_mask, world_pos.xz / grid_extent).r;
	col = mix(col, dirt_color, dirty * dirt_strength);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
