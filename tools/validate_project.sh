#!/bin/sh
# Imports the project headlessly and fails if Godot reports any script/resource error.
cd "$(dirname "$0")/.." || exit 1
OUT=$( (godot --headless --path . --import 2>&1; godot --headless --path . --quit-after 120 2>&1) | grep -vE "at exit|leaked")
if echo "$OUT" | grep -qiE "SCRIPT ERROR|Parse Error|ERROR:"; then
	echo "$OUT" | grep -iE "SCRIPT ERROR|Parse Error|ERROR:" | head -40
	echo "VALIDATION FAILED"; exit 1
fi
echo "VALIDATION OK"
