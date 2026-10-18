extends RefCounted
# بيانات وضع القرب: كلام كل حالة، وتأثير كل لمسة على العدادات (عدّل هنا بدون ما تلمس الكود)

# العدادات: comfort ارتياح، tickle دغدغة، shy خجل، annoy انزعاج (من 0 إلى 1)
# تأثير الضغطة السريعة (tap) لكل منطقة
const TAP := {
	"head":     {"comfort": 0.08, "shy": 0.02},
	"face":     {"shy": 0.14, "comfort": 0.03},
	"shoulder": {"comfort": 0.05, "tickle": 0.05},
	"arm":      {"comfort": 0.04},
	"hand":     {"comfort": 0.06, "shy": 0.05},
	"waist":    {"tickle": 0.20, "shy": 0.04},
	"body":     {"tickle": 0.20},
	"leg":      {"shy": 0.08, "tickle": 0.06},
	"feet":     {"tickle": 0.26},
}
# تأثير المسح البطيء (لكل ثانية)
const CARESS := {
	"head":     {"comfort": 0.30},
	"face":     {"comfort": 0.18, "shy": 0.22},
	"shoulder": {"comfort": 0.22},
	"arm":      {"comfort": 0.18, "shy": 0.05},
	"hand":     {"comfort": 0.22, "shy": 0.10},
	"waist":    {"tickle": 0.25, "shy": 0.12},
	"body":     {"tickle": 0.30},
	"leg":      {"shy": 0.25, "comfort": 0.05},
	"feet":     {"tickle": 0.45},
}
# المسح السريع (فرك) يدغدغ أكثر، وعلى الوجه يزعج
const RUB := {
	"head":     {"comfort": 0.10, "annoy": 0.15},
	"face":     {"annoy": 0.45},
	"shoulder": {"tickle": 0.35},
	"arm":      {"tickle": 0.30},
	"hand":     {"tickle": 0.25},
	"waist":    {"tickle": 0.80},
	"body":     {"tickle": 0.85},
	"leg":      {"tickle": 0.40, "shy": 0.10},
	"feet":     {"tickle": 1.00},
}
# الضغطة الطويلة (لكل ثانية): دفء وقرب
const HOLD := {
	"head":     {"comfort": 0.25},
	"face":     {"comfort": 0.15, "shy": 0.20},
	"shoulder": {"comfort": 0.20},
	"arm":      {"comfort": 0.15},
	"hand":     {"comfort": 0.25, "shy": 0.08},
	"waist":    {"comfort": 0.10, "shy": 0.18},
	"body":     {"comfort": 0.10, "tickle": 0.10},
	"leg":      {"shy": 0.20},
	"feet":     {"tickle": 0.25},
}
# كم ينقص كل عداد في الثانية لوحده
const DECAY := {"comfort": 0.025, "tickle": 0.30, "shy": 0.09, "annoy": 0.06}

# الحالات: تتغير حسب العدادات (الأعلى أولوية فوق)
const STATES := [
	["annoyed", "annoy", 0.5],
	["laughing", "tickle", 0.55],
	["shy", "shy", 0.5],
	["melting", "comfort", 0.72],
	["happy", "comfort", 0.35],
]

const LINES := {
	"calm": ["«هلا... وش فيك تطالعني كذا؟»", "«قرّب، ما أعض ههه»", "«وش ناوي عليه؟»"],
	"happy": ["«أحب لما تكون قريب مني.»", "«هممم... حلو كذا.»", "«كمّل، لا توقف.»"],
	"melting": ["«خلني كذا شوي... مرتاحة مرة.»", "«تعرف إنك أحلى شي صار لي؟»", "«ممم... لا تروح.»"],
	"shy": ["«بس! استحيت... ههه»", "«لا تطالعني كذا...»", "«خلاص وجهي صار أحمر!»"],
	"laughing": ["«ههههه وقّف! وقّف!»", "«لاا... تعرف إني ما أتحمل! ههههه»", "«بنتقم منك! ههههه»"],
	"annoyed": ["«خلاص عاد! يكفي.»", "«أوف... قلت لك لا.»", "«بزعل منك ترا.»"],
}
const NAMES := {"comfort": "ارتياح", "tickle": "دغدغة", "shy": "خجل", "annoy": "انزعاج"}
const COLORS := {"comfort": Color(1.0, 0.55, 0.7), "tickle": Color(1.0, 0.85, 0.35), "shy": Color(1.0, 0.45, 0.45), "annoy": Color(0.6, 0.6, 0.7)}
