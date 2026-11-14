#!/bin/sh
# Rebuilds Wanda with Blender and stitches preview sheets. Usage: build.sh [preview_dir]
cd "$(dirname "$0")/../.." || exit 1
S="${1:-$PWD/documentation/wanda_preview}"
mkdir -p "$S"
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/build_wanda.py -- "$PWD" "$S" 2>&1 | grep -E "WANDA|Error|error|Traceback|line [0-9]+" 
python3 - "$S" <<'PY'
import sys
from PIL import Image
S = sys.argv[1]
for name, files in (("sheet_a", ["front", "three_q", "side", "back"]), ("sheet_b", ["face", "pose_walk", "pose_run", "pose_cast"])):
    ims = [Image.open(f"{S}/{f}.png") for f in files]
    o = Image.new("RGB", (sum(i.width for i in ims), ims[0].height))
    x = 0
    for i in ims:
        o.paste(i, (x, 0)); x += i.width
    o.save(f"{S}/{name}.png")
PY
