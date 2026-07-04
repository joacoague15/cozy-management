shader_type spatial;
render_mode cull_back;

// Terreno por tiles (cajas via MultiMesh): la cara superior lleva la grilla
// cada 1 unidad de mundo y la basura; los costados van de un color tierra.
uniform vec3 base_color: source_color = vec3(0.47, 0.65, 0.36);
uniform vec3 line_color: source_color = vec3(0.32, 0.46, 0.25);
uniform float line_width: hint_range(0.0, 0.2) = 0.025;
uniform vec3 side_color: source_color = vec3(0.37, 0.28, 0.2);

// Mascara de basura (1 pixel = 1 tile): r=1 tile sucio, r=0 tile limpio.
// Por defecto negra: el mapa arranca limpio.
uniform sampler2D dirt_mask: filter_nearest, hint_default_black;
uniform vec3 dirt_color: source_color = vec3(0.23, 0.2, 0.16);
// Color de las manchas mas oscuras dentro de la zona sucia.
uniform vec3 dirt_stain_color: source_color = vec3(0.15, 0.13, 0.09);
uniform float dirt_strength: hint_range(0.0, 1.0) = 0.7;
uniform float grid_extent = 20.0;

varying vec3 world_pos;
varying vec3 world_normal;

// Ruido de valor barato para dar forma organica a la suciedad.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// Valor de la mascara en el centro de una tile (la mascara es 1 px = 1 tile).
float dirt_at(vec2 tile) {
	return texture(dirt_mask, (tile + 0.5) / grid_extent).r;
}

// Campo de suciedad suavizado: bilineal manual entre centros de tile, con
// ruido empujando el umbral. La mancha deja de ser un cuadrado exacto y toma
// un contorno ondulado organico que se derrama apenas sobre el pasto vecino.
float dirt_field(vec2 pos) {
	vec2 g = pos - 0.5;
	vec2 i = floor(g);
	vec2 f = fract(g);
	f = f * f * (3.0 - 2.0 * f);
	float d = mix(
		mix(dirt_at(i), dirt_at(i + vec2(1.0, 0.0)), f.x),
		mix(dirt_at(i + vec2(0.0, 1.0)), dirt_at(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
	float edge = vnoise(pos * 2.9) - 0.5;
	return smoothstep(0.3, 0.65, d + edge * 0.4);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (world_normal.y < 0.7) {
		// Costados y base de la tile: tierra uniforme.
		ALBEDO = side_color;
	} else {
		vec2 cell = fract(world_pos.xz);
		vec2 dist_to_line = min(cell, 1.0 - cell);
		float d = min(dist_to_line.x, dist_to_line.y);
		float aa = fwidth(d);
		float line = 1.0 - smoothstep(line_width - aa, line_width + aa, d);
		vec3 col = mix(base_color, line_color, line);
		float dirty = dirt_field(world_pos.xz);
		if (dirty > 0.001) {
			// Pasto enfermo: desaturado y amarronado, mas fuerte hacia el
			// centro de la mancha (el borde ondulado hace el degrade solo).
			vec3 sick = mix(vec3(dot(col, vec3(0.333))), col, 0.3) * vec3(0.85, 0.78, 0.62);
			col = mix(col, sick, dirty * 0.9);
			// Manchas oscuras organicas que "respiran" muy despacio.
			float stains = vnoise(world_pos.xz * 2.2 + 13.0);
			float breath = 0.06 * sin(TIME * 0.7 + world_pos.x + world_pos.z);
			float blob = smoothstep(0.45 + breath, 0.85, stains);
			col = mix(col, dirt_color, dirty * dirt_strength * blob);
			// Vaho oscuro que deriva lento sobre la zona.
			float haze = vnoise(world_pos.xz * 1.2 + vec2(TIME * 0.15, -TIME * 0.1));
			col = mix(col, dirt_stain_color, dirty * dirt_strength * smoothstep(0.55, 0.95, haze) * 0.55);
			// Motitas de basura desperdigadas.
			float specks = step(0.94, vnoise(world_pos.xz * 16.0));
			col = mix(col, dirt_stain_color, dirty * specks * 0.8);
		}
		ALBEDO = col;
	}
	ROUGHNESS = 1.0;
}
