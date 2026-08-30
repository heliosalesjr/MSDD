shader_type canvas_item;

uniform vec4 gold_rect = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 gold_tint = vec4(1.3, 1.1, 0.6, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (UV.x >= gold_rect.x
		&& UV.x < gold_rect.x + gold_rect.z
		&& UV.y >= gold_rect.y
		&& UV.y < gold_rect.y + gold_rect.w) {
		tex.rgb *= gold_tint.rgb;
	}
	COLOR = tex;
}
