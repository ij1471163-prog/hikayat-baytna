shader_type canvas_item;
// جسم حي: أي صورة شخصية تتنفس وتتمايل، والجلد ينضغط تحت الإصبع بظل حقيقي
uniform vec2 size = vec2(500.0, 1000.0);   // مقاس الصورة بالبكسل
uniform float wide = 0.0;                   // 1 = منسدحة
uniform vec2 neck = vec2(0.5, 0.2);         // مكان الرقبة (نسبة)
uniform float breath = 0.0;
uniform float sway = 0.0;                   // راديان
uniform float head = 0.0;                   // راديان
uniform float sh_l = 0.0;                   // رفع الكتف اليسار (من جهة الشاشة)
uniform float sh_r = 0.0;
uniform float suck = 0.0;                   // البطن ينقبض
uniform float bounce = 0.0;
uniform vec2 press_c = vec2(-9999.0);       // مكان الإصبع (بكسل الصورة)
uniform float press_r = 30.0;
uniform float press_d = 0.0;
uniform vec2 drag = vec2(0.0);

varying vec2 rest;

vec2 rot(vec2 p, vec2 c, float a) {
	float s = sin(a), k = cos(a);
	p -= c;
	return c + vec2(p.x * k - p.y * s, p.x * s + p.y * k);
}

void vertex() {
	rest = VERTEX;
	vec2 p = VERTEX;
	vec2 uv = p / size;
	if (wide < 0.5) {
		// تنفس: الجزء الفوقي يرتفع ويتسع شوي
		float up = smoothstep(neck.y + 0.45, neck.y - 0.05, uv.y);
		p.y -= breath * up * size.y * 0.008;
		p.x += breath * (uv.x - neck.x) * up * size.x * 0.010;
		// الكتوف
		float sy = neck.y + 0.07;
		vec2 cl = vec2(neck.x - 0.2, sy), cr = vec2(neck.x + 0.2, sy);
		float rr = 0.012;
		p.y -= sh_l * size.y * 0.022 * exp(-dot(uv - cl, uv - cl) / rr);
		p.y -= sh_r * size.y * 0.022 * exp(-dot(uv - cr, uv - cr) / rr);
		// البطن
		float by = neck.y + 0.21;
		float wb = exp(-pow((uv.y - by) / 0.06, 2.0));
		p.x += (neck.x - uv.x) * size.x * 0.06 * suck * wb;
		p.y -= suck * wb * size.y * 0.004;
		// تمايل حول الوسط، والراس حول الرقبة
		float w = smoothstep(neck.y + 0.48, neck.y - 0.08, uv.y);
		p = mix(p, rot(p, vec2(0.5, neck.y + 0.46) * size, sway), w);
		float wh = smoothstep(neck.y + 0.03, neck.y - 0.05, uv.y);
		p = mix(p, rot(p, neck * size, head), wh);
	} else {
		float up = smoothstep(0.9, 0.2, uv.y);
		p.y -= breath * up * size.y * 0.016;
		float wh = neck.x > 0.5 ? smoothstep(neck.x - 0.12, neck.x + 0.02, uv.x) : smoothstep(neck.x + 0.12, neck.x - 0.02, uv.x);
		p = mix(p, rot(p, neck * size, head), wh);
		p = mix(p, rot(p, vec2(0.5, 1.0) * size, sway * 0.4), 1.0);
	}
	// ضغطة الإصبع: حفرة ناعمة + انتفاخ حولها + الجلد ينسحب مع الإصبع
	if (press_d > 0.002) {
		vec2 d = press_c - rest;
		float r = length(d);
		float f = exp(-(r * r) / (press_r * press_r));
		float g = exp(-pow((r - press_r * 1.5) / (press_r * 0.55), 2.0));
		vec2 dir = -d / max(r, 1.0);
		p += d * 0.17 * press_d * f + dir * press_r * 0.09 * press_d * g + drag * f * press_d;
	}
	// ارتداد خفيف من القدمين
	p.y = size.y + (p.y - size.y) * (1.0 + bounce);
	p.x = size.x * 0.5 + (p.x - size.x * 0.5) * (1.0 - bounce * 0.5);
	VERTEX = p;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (press_d > 0.002) {
		float r = distance(rest, press_c);
		float dark = press_d * 0.22 * exp(-(r * r) / (press_r * press_r * 0.8));
		float rim = press_d * 0.05 * exp(-pow((r - press_r * 1.45) / (press_r * 0.45), 2.0));
		c.rgb = c.rgb * (1.0 - dark) + vec3(rim);
	}
	COLOR = c * COLOR;
}
