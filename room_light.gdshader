shader_type canvas_item;
// نفس إضاءة الغرفة للصور العادية (بدون جسم حي)
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
	c.rgb = room(c.rgb, UV);
	COLOR = c * COLOR;
}
