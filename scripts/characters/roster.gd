## Roster: stats and looks for every non-player fighter, plus a spawn helper.
extends RefCounted

const ZOMBIE := {"skin": Color("7f9a82"), "torso": Color("5a4a3a"), "sleeve": Color("5a4a3a"), "forearm": Color("7f9a82"),
	"hands": Color("7f9a82"), "legs": Color("38383a"), "trunks": Color("38383a"), "boots": Color("38383a"), "shoes": Color("202020"),
	"hair": Color("26262a"), "hair2": Color("34343a"), "iris": Color("e8e060"), "lips": Color("4a5a4c")}
const GUNMAN := {"torso": Color("23232c"), "sleeve": Color("23232c"), "forearm": Color("23232c"), "hands": Color("111118"),
	"legs": Color("1a1a22"), "trunks": Color("1a1a22"), "boots": Color("1a1a22"), "shoes": Color("0c0c10"), "hair": Color("101014"), "hair2": Color("1c1c22")}
const TYPES := {
	&"zombie": {"name": "Risen Dead", "model": ["citizen_m", "citizen_f"], "colors": ZOMBIE, "hp": 45.0, "speed": 1.8, "walk": "shamble", "dmg": 9.0},
	&"gunman": {"name": "Reaper's Gunman", "model": ["citizen_m"], "colors": GUNMAN, "hp": 55.0, "speed": 3.2, "walk": "run", "dmg": 6.0,
		"armed": true, "shot_dmg": 7.0, "shot_col": Color("ffd060")},
	&"black_talon": {"name": "Black Talon", "model": ["black_talon"], "hp": 380.0, "speed": 3.0, "walk": "walk", "dmg": 14.0, "boss": true,
		"armed": true, "shot_dmg": 11.0, "shot_col": Color("ff7a20"), "summon": true, "scale": 1.12},
	&"nekra": {"name": "Nekra", "model": ["nekra"], "hp": 300.0, "speed": 5.0, "walk": "run", "dmg": 16.0, "boss": true, "scale": 1.05},
	&"grim_reaper": {"name": "The Grim Reaper", "model": ["grim_reaper"], "hp": 520.0, "speed": 3.4, "walk": "walk", "dmg": 20.0, "boss": true,
		"armed": true, "shot_dmg": 13.0, "shot_col": Color("b070ff"), "scale": 1.15},
	&"vision_ally": {"name": "Vision", "model": ["vision"], "hp": 600.0, "speed": 5.0, "walk": "run", "dmg": 14.0, "team": &"ally",
		"armed": true, "shot_dmg": 12.0, "shot_col": Color("ffe060")},
	&"wanda_ally": {"name": "Wanda", "model": ["wanda"], "hp": 600.0, "speed": 5.0, "walk": "run", "dmg": 14.0, "team": &"ally",
		"armed": true, "shot_dmg": 14.0, "shot_col": Color("ff3048")},
}


static func spawn(parent: Node, type: StringName, pos: Vector3) -> CharacterBody3D:
	var a: CharacterBody3D = load("res://scripts/characters/actor.gd").new()
	a.type = type
	a.cfg = TYPES[type]
	parent.add_child(a)
	a.global_position = pos
	return a
