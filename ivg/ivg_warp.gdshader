shader_type canvas_item;
// لمس حي على الفيديو نفسه: الصورة تنبعج تحت الإصبع، تتبع السحب، وتتموّج لما تفك.
// يتفعّل من ivg_engine.gd وقت اللمس وبعده بلحظة فقط (باقي الوقت مطفي لتوفير البطارية).
// كل الإحداثيات بالبكسل داخل مستطيل الفيديو (مو الشاشة كلها).

uniform vec2 u_size = vec2(1280.0, 720.0); // مقاس مستطيل الفيديو بالبكسل
uniform vec2 u_p = vec2(0.0);              // مكان الإصبع
uniform float u_r = 60.0;                  // نصف قطر الأثر
uniform float u_depth = 0.0;               // عمق الضغطة 0..1
uniform vec2 u_pull = vec2(0.0);           // سحب الجلد مع الإصبع
uniform float u_rt = 9.0;                  // وقت من بعد الفك (للموجة)
uniform float u_ramp = 0.0;                // قوة الموجة
uniform vec2 u_shake = vec2(0.0);
uniform float u_pulse = 0.0;
uniform float u_alpha = 1.0;               // شفافية الفيديو (التلاشي بين المقاطع)

void fragment() {
	vec2 p = UV * u_size;
	vec2 d = p - u_p;
	float dist = length(d);
	float fall = exp(-(dist * dist) / (u_r * u_r));
	vec2 q = p;
	q += d * fall * u_depth * 0.32;   // ينبعج لداخل
	q -= u_pull * fall;               // الجلد يلحق الإصبع
	float w = sin(dist * 0.09 - u_rt * 16.0) * u_ramp * exp(-u_rt * 3.2) * exp(-dist / (u_r * 2.4));
	q += (dist > 0.001 ? d / dist : vec2(0.0)) * w;   // موجة بعد الفك
	vec2 c = u_size * 0.5;
	q = c + (q - c) * (1.0 - u_pulse * 0.03) + u_shake;   // نبضة/اهتزاز للجسم كله
	vec2 uv = q / u_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		vec4 col = texture(TEXTURE, uv);
		col.rgb *= 1.0 - 0.13 * fall * u_depth;   // ظل خفيف داخل الضغطة
		float rim = exp(-pow((dist - u_r * 0.9) / (u_r * 0.25), 2.0)) * u_depth;
		col.rgb += 0.05 * rim;                    // حافة فيها لمعة
		COLOR = vec4(col.rgb, col.a * u_alpha);
	}
}
