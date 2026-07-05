shader_type spatial;
render_mode cull_back;

// Agua sencilla del estanque del palacio: dos tonos de azul verdoso mezclados
// por ruido que deriva lento (ondas suaves), superficie brillante y un poco
// translucida. Sin reflexiones ni profundidad: barato y cozy.
uniform vec3 deep_color: source_color = vec3(0.15, 0.34, 0.42);
uniform vec3 light_color: source_color = vec3(0.36, 0.6, 0.66);

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float a = vnoise(p * 2.2 + vec2(TIME * 0.12, TIME * 0.09));
	float b = vnoise(p * 4.5 - vec2(TIME * 0.1, -TIME * 0.07));
	float ripple = smoothstep(0.3, 0.8, a * 0.65 + b * 0.45);
	ALBEDO = mix(deep_color, light_color, ripple);
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	ALPHA = 0.92;
}
