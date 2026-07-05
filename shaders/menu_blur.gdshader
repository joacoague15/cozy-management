shader_type canvas_item;
// Blur gaussiano simple para el fondo del menu. blur_size en pixeles;
// con 0 devuelve la textura intacta (pantalla de portada).

uniform float blur_size : hint_range(0.0, 16.0) = 0.0;

void fragment() {
	if (blur_size < 0.01) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE * blur_size * 0.5;
		vec4 sum = vec4(0.0);
		float total = 0.0;
		for (int x = -3; x <= 3; x++) {
			for (int y = -3; y <= 3; y++) {
				vec2 off = vec2(float(x), float(y));
				float weight = exp(-dot(off, off) / 6.0);
				sum += texture(TEXTURE, UV + off * px) * weight;
				total += weight;
			}
		}
		COLOR = sum / total;
	}
}
