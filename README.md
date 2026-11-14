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
| Space | Jump; **hold in the air to levitate** (Vision: fly) |
| LMB (hold) | **Hex Bolt**: charges for up to 8 s, stronger the longer you hold, 1 s cooldown |
| RMB (hold) | **Hex Sphere**: grows while held. On the ground it disarms guns and slows enemies; aimed at one enemy it traps them in a bubble - click to throw |
| R | Hex Sphere on yourself: a shield |
| E | **Telekinesis** (ultimate): 18 s, 35 s cooldown. Seizes every enemy in range; LMB flings one, RMB turns an ordinary one to your side |
| F | Drive / leave the car, advance dialogue |
| M | Town map |
| Tab | Switch Wanda / Vision (outside missions) |
| T | Summon training enemies |
| 1-6 | Jump to a region (outside missions) |
| Esc, F11 | Free the mouse, fullscreen |

Vision: hold Space to fly, LMB Solar Beam, hold RMB to phase (bullets pass through), E Density Slam.

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
