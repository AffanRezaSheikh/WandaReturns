# Scarlet Witch: Chaos Reborn

3D third-person action RPG prototype in Godot 4.7 (Forward+). Fan project: the character belongs to Marvel, so keep it non-commercial.

## Run
Open the folder in Godot and press Play, or from a terminal:

    godot --path .

## Controls
WASD move · mouse look · Shift sprint · Space jump · Ctrl dash · 1-5 jump to a region · Esc free the mouse · F11 fullscreen

## What is built (world pass)
Five connected regions, each with its landmark, lighting, fog, particles and chaos-rift portals:
Hollow Grove (Root Bell) -> Cinderwake (stopped clock tower) -> Glassfen (Mirror Loom) -> Ember Archive (library core) -> Hourglass Spire (great hourglass, spiral climb).

## Wanda
Modelled, rigged and animated by script in Blender (`tools/blender/build_wanda.py`), exported to `assets/models/wanda.glb`.
Clips: idle, walk, run, air, dash, cast. Rebuild with `tools/blender/build.sh`; previews land in `documentation/wanda_preview/`.

## Not built yet
- Combat, spells, instability, enemies, bosses, dialogue, quests, saves, audio, menus.
- Story and extra characters (waiting on the storyline).

## Checks
    tools/validate_project.sh          # headless import + run, fails on script errors
    godot --path . -- --shots          # re-captures documentation/screens/*.png
