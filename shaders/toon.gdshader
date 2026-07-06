shader_type spatial;
render_mode cull_back, ambient_light_disabled;

// Cel shading exagerado: albedo saturado y posterizado, luz difusa en tres
// bandas duras, brillo especular de caricatura y rim escalonado. Reemplaza en
// runtime a los StandardMaterial3D del juego (ver scripts/cel_shading.gd),
// asi que replica lo que esos materiales usan: color plano, textura por UV o
// triplanar en mundo, y colores de vertice.
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform bool use_vertex_color = false;
uniform bool triplanar = false;
uniform vec3 uv1_scale = vec3(1.0);

uniform float saturation_boost : hint_range(0.5, 2.5) = 1.15;
uniform float posterize_levels : hint_range(2.0, 16.0) = 8.0;
// Cuanto pesa el color posterizado sobre el original. A 1.0 las texturas con
// grano se parten en manchones que se despegan del modelo; parcial mantiene
// el tinte plano de dibujo sin romper el detalle.
uniform float posterize_mix : hint_range(0.0, 1.0) = 0.35;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.25;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.18;
// 1.0 = bandas duras puras; 0.0 = luz suave clasica (mismo rango de brillo).
uniform float band_mix : hint_range(0.0, 1.0) = 1.0;

varying vec3 tri_pos;
varying vec3 tri_blend;

void vertex() {
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 blend = pow(abs(world_normal), vec3(4.0));
	tri_blend = blend / (blend.x + blend.y + blend.z);
	tri_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * uv1_scale;
}

void fragment() {
	vec3 tex;
	if (triplanar) {
		tex = texture(albedo_texture, tri_pos.zy).rgb * tri_blend.x
			+ texture(albedo_texture, tri_pos.xz).rgb * tri_blend.y
			+ texture(albedo_texture, tri_pos.xy).rgb * tri_blend.z;
	} else {
		tex = texture(albedo_texture, UV).rgb;
	}
	vec3 col = albedo_color.rgb * tex;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	// Paleta de dibujo animado: un toque mas saturada y apenas aplanada. El
	// look toon fuerte lo ponen las bandas de luz y el contorno, no el albedo.
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	col = clamp(mix(vec3(grey), col, saturation_boost), vec3(0.0), vec3(1.0));
	col = mix(col, floor(col * posterize_levels + 0.5) / posterize_levels, posterize_mix);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// Rim escalonado: un filo de luz duro en el contorno contra camara.
	float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	EMISSION = col * step(0.72, rim) * rim_strength;
}

void light() {
	// Tres bandas duras (sombra / media / luz); ATTENUATION mete la sombra
	// proyectada dentro del mismo bandeo, asi las sombras cortan a filo.
	// La banda de sombra multiplica hacia negro (bien oscura y neutra), no
	// hacia un gris lavado.
	float d = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float banded = 0.16
		+ 0.49 * smoothstep(0.24, 0.27, d)
		+ 0.45 * smoothstep(0.62, 0.65, d);
	float lit = mix(0.16 + 0.94 * d, banded, band_mix);
	DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
	// Brillo especular de caricatura: un disco recortado, sin degrade.
	vec3 h = normalize(VIEW + LIGHT);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 42.0);
	SPECULAR_LIGHT += smoothstep(0.5, 0.55, spec * ATTENUATION) * specular_strength * LIGHT_COLOR / PI;
}
