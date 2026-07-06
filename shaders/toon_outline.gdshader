shader_type spatial;
render_mode unshaded, cull_front;

// Contorno de tinta: segunda pasada (next_pass del material toon) que infla
// la silueta en espacio de clip una cantidad fija de pixeles, asi el grosor
// no depende de la escala del modelo (los FBX llegan en escalas muy dispares).
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// Grosor en pixeles medidos a 720p de alto (se escala con la resolucion para
// que el trazo pese lo mismo en cualquier pantalla).
uniform float outline_width : hint_range(0.0, 12.0) = 1.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = mat3(MODELVIEW_MATRIX) * NORMAL;
	vec2 dir = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy;
	dir /= max(length(dir), 1e-4);
	float px = outline_width * VIEWPORT_SIZE.y / 720.0;
	clip.xy += dir * clip.w * px * 2.0 / VIEWPORT_SIZE;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
