#!/bin/sh
# Rebuilds characters with Blender and stitches a preview sheet per character.
# Usage: build.sh [preview_dir] [names...]   (no names = all characters)
cd "$(dirname "$0")/../.." || exit 1
S="${1:-$PWD/documentation/character_preview}"
[ $# -gt 0 ] && shift
mkdir -p "$S"
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/build_characters.py -- "$PWD" "$S" "$@" 2>&1 | grep -E "BUILT|EXPORTED|Error|error:|Traceback|File \"|line [0-9]+"
python3 - "$S" <<'PY'
import sys, glob, os
from PIL import Image
S = sys.argv[1]
for f in sorted(glob.glob(f"{S}/*_front.png")):
    n = os.path.basename(f)[:-10]
    ims = [Image.open(f"{S}/{n}_{k}.png") for k in ("front", "q", "face", "act")]
    o = Image.new("RGB", (sum(i.width for i in ims), ims[0].height))
    x = 0
    for i in ims:
        o.paste(i, (x, 0)); x += i.width
    o.save(f"{S}/sheet_{n}.png")
PY
