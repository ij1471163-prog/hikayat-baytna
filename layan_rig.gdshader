shader_type canvas_item;
// ظل ضغطة الإصبع على أجزاء ليان (الحفرة تغمق وحوافها تفتح)
uniform vec2 tex_off = vec2(0.0);
uniform vec2 press_c = vec2(-9999.0);
uniform float press_r = 24.0;
uniform float press_d = 0.0;
uniform vec2 fig_size = vec2(1024.0, 1536.0);

// إضاءة الغرفة: لون الغرفة على الجسم، الضوء جاي من جهة اللمبة، والرجول أغمق من الراس
uniform vec3 amb = vec3(1.0);
uniform float side = 0.0;
uniform float lit = 0.0;
vec3 room(vec3 c, vec2 u) {
	if (lit < 0.01) return c;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 o = mix(vec3(l), c, 0.88);
	o *= amb;
	o *= mix(1.04, 0.80, smoothstep(0.30, 1.0, u.y));
	o *= 1.0 + side * (u.x - 0.5) * 0.30;
	float edge = smoothstep(0.25, 0.5, abs(u.x - 0.5)) * 0.05 * abs(side);
	o += amb * edge * step(0.0, side * (u.x - 0.5));
	return mix(c, o, lit);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 rp = UV / TEXTURE_PIXEL_SIZE + tex_off;
	if (press_d > 0.002) {
		float r = distance(rp, press_c);
		float dark = press_d * 0.24 * exp(-(r * r) / (press_r * press_r * 0.8));
		float rim = press_d * 0.06 * exp(-pow((r - press_r * 1.45) / (press_r * 0.45), 2.0));
		c.rgb = c.rgb * (1.0 - dark) + vec3(rim);
	}
	c.rgb = room(c.rgb, rp / fig_size);
	COLOR = c * COLOR;
}
