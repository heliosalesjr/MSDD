shader_type canvas_item;

uniform vec4 hint_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 hint_tint = vec4(1.0, 1.0, 1.0, 1.0);

// COLOR já chega como texture(TEXTURE, UV) multiplicado pelo modulate do nó,
// então o hint é aplicado POR CIMA dele. Sobrescrever COLOR com um texture()
// cru (o que este shader fazia antes) descartava o modulate silenciosamente —
// e com ele o tingimento de zona do protótipo 4 e o clarão de abertura do §18.
void fragment() {
	if (UV.x >= hint_rect.x
		&& UV.x < hint_rect.x + hint_rect.z
		&& UV.y >= hint_rect.y
		&& UV.y < hint_rect.y + hint_rect.w) {
		COLOR.rgb *= hint_tint.rgb;
	}
}
