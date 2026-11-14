# Scarlet Witch: Chaos Reborn

3D third-person open-world action-adventure in Godot 4.7 (Forward+), cel-shaded anime style.
Fan project: the characters belong to Marvel, so keep it non-commercial.

## Run
    godot --path .

You start in **The Library** (hub). The golden rift leads to **Leonia, New Jersey**, where the story plays.
Four more rifts lead to side realms (Hollow Grove, Cinderwake, Glassfen, Hourglass Spire).

## Controls
| Key | Action |
|---|---|
| WASD / mouse | Move / look |
| Shift, Ctrl | Sprint, dash |
| Space | Wanda: jump, **hold in the air to levitate**. Vision: **toggle flight** |
| LMB (hold) | **Hex Bolt**: charges for up to 8 s, stronger the longer you hold, 1 s cooldown |
| RMB (hold) | **Hex Sphere**: grows while held. On the ground it disarms guns and slows enemies; aimed at one enemy it traps them in a bubble - click to throw |
| R | Hex Sphere on yourself: a shield |
| E | **Telekinesis** (ultimate): 18 s, 35 s cooldown. Seizes every enemy in range; LMB flings one, RMB turns an ordinary one to your side |
| F | Drive / leave the car, advance dialogue |
| M | Town map |
| Tab | Switch Wanda / Vision (outside missions) |
| T | Summon training enemies |
| 1-7 | Jump to a region (outside missions) |
| I | 360° character view |
| Esc, F11 | Free the mouse, fullscreen |

Vision: Space toggles flight, hold LMB for the Mind Stone beam, hold RMB to phase (bullets pass through), E Density Slam.

## Vision
Vision is built on Blender Studio's public-domain (CC0) realistic male base mesh (`tools/blender/base_meshes/`), reshaped to a
heroic build by `tools/blender/basemesh.py`, then dressed from the owner's turnaround sheet: painted suit, head and cape
textures (`paint_vision.py`), gauntlets, boots, gold yoke, chest diamond, ear discs and the Mind Stone.
His cape (and every other cape) moves with spring-bone physics.
- **Vision Test Arena**: rift behind the Library spawn, or key 7. Space toggles flight, hold left-click for the Mind Stone beam.
- **360° view**: press I anywhere outside a mission. Mouse orbits, wheel zooms, A/D change pose, Space pauses, Tab switches hero.

## Story
Chapter 1 adapts *Vision and the Scarlet Witch* (1985) #1 with newly written dialogue: The Hearing, A Place of Our Own,
The Dead Walk, Vision Alone (you play Vision), Graveyard of the Unliving. Then free roam, with a night-time cemetery side activity.

## Leonia
Stylized town: Broad Avenue shops, Fort Lee Road, Borough Hall, Public Library, church, Overpeck Park, cemetery, your house,
Manhattan and the bridge across the Hudson. Day/night cycle, drivable red convertible, traffic, townspeople who react to
Wanda or Vision and talk to each other, minimap and full map with mission markers.

## Characters
All built, rigged and animated by script in Blender: `tools/blender/build_characters.py` (run `tools/blender/build.sh`).
Wanda, Vision, Black Talon, Nekra, the Grim Reaper and two townspeople bases share one skeleton and 16 animation clips.
Previews: `documentation/character_preview/`.

## Not built yet
- Saving: story progress is lost when you quit.
- Audio (music, sound effects, voices).
- Menus (title, pause, settings).
- Enemy pathfinding: enemies walk straight at you and can snag on buildings.
- Issues #2-12 of the comic.

## Checks
    tools/validate_project.sh          # headless import + run, fails on script errors
    godot --path . -- --selftest       # exercises every power and plays Chapter 1 on autopilot
    godot --path . -- --shots          # re-captures documentation/screens/*.png
