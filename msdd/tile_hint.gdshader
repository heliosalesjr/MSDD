shader_type canvas_item;

uniform vec4 hint_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 hint_tint = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (UV.x >= hint_rect.x
		&& UV.x < hint_rect.x + hint_rect.z
		&& UV.y >= hint_rect.y
		&& UV.y < hint_rect.y + hint_rect.w) {
		tex.rgb *= hint_tint.rgb;
	}
	COLOR = tex;
}
