shader_type canvas_item;
// جسم حي عام: يقص كل جزء (جسم/ذراع) من نفس الصورة بقناع، وظل ضغطة الإصبع (الحفرة تغمق وحوافها تفتح)
uniform sampler2D part_mask : filter_nearest;
uniform bool use_mask = false;
uniform int part = 0;   // 0 جسم، 1 ذراع يسار، 2 ذراع يمين
uniform vec2 press_c = vec2(-9999.0);
uniform float press_r = 24.0;
uniform float press_d = 0.0;
uniform vec2 fig_size = vec2(1024.0, 1536.0);
// تشويه الجلد والوجه (كرت الشاشة يسويه، والعظام يحركها Skeleton2D)
uniform vec2 drag = vec2(0.0);
uniform float K = 1.0;
uniform float suck = 0.0;
uniform float mid_x = 0.0;
uniform float belly_y = 0.0;
uniform bool has_face = false;
uniform vec2 eyeA; uniform vec2 eyeB; uniform vec2 rA; uniform vec2 rB;
uniform vec2 mL; uniform vec2 mR; uniform vec2 chA; uniform vec2 chB;
uniform vec2 face_c; uniform float face_r = 0.0; uniform float fs = 1.0;
uniform float blink = 0.0; uniform float smile = 0.0; uniform float turn = 0.0;

float eye_d(vec2 p, vec2 c, vec2 r, float b) {
	float dx = abs(p.x - c.x);
	if (dx > r.x * 1.5) return 0.0;
	float wx = 1.0 - smoothstep(r.x, r.x * 1.5, dx);
	float lid = c.y + r.y * 0.35;
	float wv;
	if (p.y < lid) wv = p.y >= c.y - r.y ? 1.0 : clamp(1.0 - (c.y - r.y - p.y) / (r.y * 1.3), 0.0, 1.0);
	else wv = p.y <= c.y + r.y ? 1.0 : clamp(1.0 - (p.y - c.y - r.y) / (r.y * 0.8), 0.0, 1.0);
	return b * 0.95 * (lid - p.y) * wv * wx;
}
vec2 bump(vec2 p, vec2 c, vec2 off, float r) {
	vec2 d = p - c;
	return off * exp(-dot(d, d) / (r * r));
}
void vertex() {
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	vec2 dsp = vec2(0.0);
	if (press_d > 0.003) {
		vec2 d = press_c - p;
		float r = length(d);
		float f = exp(-(r * r) / (press_r * press_r));
		float g = exp(-pow((r - press_r * 1.5) / (press_r * 0.55), 2.0));
		dsp += d * 0.17 * press_d * f - d / max(r, 1.0) * 2.4 * K * press_d * g + drag * f * press_d;
	}
	float bh = 50.0 * K;
	if (suck > 0.003 && abs(p.y - belly_y) < bh) {
		float wy = 1.0 - smoothstep(bh * 0.4, bh, abs(p.y - belly_y));
		dsp += vec2((mid_x - p.x) * 0.07 * suck * wy, -3.0 * K * suck * wy);
	}
	if (has_face && part == 0 && distance(p, face_c) < face_r) {
		if (blink > 0.01) dsp.y += eye_d(p, eyeA, rA, blink) + eye_d(p, eyeB, rB, blink);
		if (abs(smile) > 0.01) {
			dsp += bump(p, mL, vec2(-1.5, -4.0) * smile * fs, 10.0 * fs) + bump(p, mR, vec2(1.5, -4.5) * smile * fs, 10.0 * fs);
			dsp += bump(p, chA, vec2(0.0, -2.2) * smile * fs, 17.0 * fs) + bump(p, chB, vec2(0.0, -2.2) * smile * fs, 17.0 * fs);
		}
		float rr = distance(p, face_c) / face_r;
		dsp.x += turn * 9.0 * fs * (1.0 - rr * rr);
	}
	VERTEX += dsp;
}

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
	vec2 rp = UV / TEXTURE_PIXEL_SIZE;
	if (use_mask) {
		vec3 mk = texture(part_mask, UV).rgb;
		if (part == 0 && mk.b > 0.5) discard;
		if (part == 1 && mk.r < 0.5) discard;
		if (part == 2 && mk.g < 0.5) discard;
	}
	if (press_d > 0.002) {
		float r = distance(rp, press_c);
		float dark = press_d * 0.24 * exp(-(r * r) / (press_r * press_r * 0.8));
		float rim = press_d * 0.06 * exp(-pow((r - press_r * 1.45) / (press_r * 0.45), 2.0));
		c.rgb = c.rgb * (1.0 - dark) + vec3(rim);
	}
	c.rgb = room(c.rgb, rp / fig_size);
	COLOR = c * COLOR;
}
