#!/usr/bin/env bash
# اختبار ذاتي لمحرك المشاهد التفاعلية: يولّد مقاطع تجريبية بـ ffmpeg ويشغّل Godot (يحاكي اللمس والحركات والاختيارات).
# الاستخدام:  GODOT=/path/to/godot tools/ivg/run_selftest.sh        (يحتاج ffmpeg مع libtheora، وعلى لينكس xvfb-run)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
OUT="$(pwd)/tools/ivg/.clips"
mkdir -p "$OUT"
i=0
for n in idle happy laugh laugh2 shy annoyed talk jump catch fall; do
  dur=1.6; [ "$n" = idle ] && dur=4; [ "$n" = talk ] && dur=3.5; [ "$n" = jump ] && dur=3
  ffmpeg -y -loglevel error -f lavfi -i "testsrc2=s=480x270:r=24:d=$dur" -vf "hue=h=$((i*36))" -c:v libtheora -q:v 6 -pix_fmt yuv420p "$OUT/$n.ogv"
  i=$((i+1))
done
cp tools/ivg/test_scene.json "$OUT/scene.json"
RUN=("$GODOT" --rendering-driver opengl3 --audio-driver Dummy --path . -s tools/ivg/selftest.gd)
if command -v xvfb-run >/dev/null && [ -z "${DISPLAY:-}" ]; then
  IVG_DIR="$OUT/" xvfb-run -a -s "-screen 0 1280x720x24" "${RUN[@]}"
else
  IVG_DIR="$OUT/" "${RUN[@]}"
fi
