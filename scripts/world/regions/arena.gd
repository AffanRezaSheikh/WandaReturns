## Vision Test Arena: an open floating platform for trying Vision out -
## pillars to land on, rings to fly through, drones to beam, and the 360° view.
extends "res://scripts/world/region.gd"

const Dummy := preload("res://scripts/combat/target_dummy.gd")


func _init() -> void:
	display_name = "VISION TEST ARENA"
	subtitle = "Space: flight   ·   Left-click: Mind Stone beam   ·   I: 360° view"
	kill_y = -30.0


func build() -> void:
	var env := setup_env(Color("2c5ea8"), Color("f4dcc4"), Color("dfe6f2"), 0.0012, 0.75, Color("fff0dc"), 1.05, Vector3(-42, 35, 0))
	env.fog_sky_affect = 0.0
	var floor_m := B.mat(Color("a8a296"), 0.85)
	var teal := B.mat(Color("56807e"), 0.6)
	var crim := B.mat(Color("a03a56"), 0.6)
	var gold := B.mat(Color("d8ce8c"), 0.4, 0.5, Color("f0b04a"), 0.3)
	B.cyl(self, 46.0, 46.0, 2.0, Vector3(0, -1.0, 0), floor_m, true, 48)
	B.cyl(self, 44.0, 6.0, 30.0, Vector3(0, -17.0, 0), B.mat(Color("8a8478"), 1.0), false, 24)
	for r: float in [8.0, 18.0, 28.0, 38.0]:
		B.torus(self, r - 0.12, r + 0.12, Vector3(0, 0.02, 0), teal, Vector3.ZERO, 64)
	B.torus(self, 45.3, 46.0, Vector3(0, 0.03, 0), gold, Vector3.ZERO, 64)
	for i in 12:
		B.box(self, Vector3(0.2, 0.04, 36.0), Vector3(sin(i * TAU / 12) * 26.0, 0.02, cos(i * TAU / 12) * 26.0), teal, false, Vector3(0, i * TAU / 12, 0))
	for i in 8:                                               # pillars of rising height to land on
		var a := i * TAU / 8 + 0.4
		var h := 4.0 + i * 2.2
		var p := Vector3(cos(a) * 30.0, 0, sin(a) * 30.0)
		B.cyl(self, 2.2, 2.6, h, p + Vector3(0, h * 0.5, 0), floor_m, true, 6)
		B.cyl(self, 2.6, 2.6, 0.4, p + Vector3(0, h + 0.2, 0), crim, true, 6)
	for i in 7:                                               # rings to fly through
		var a := i * TAU / 7
		var ring := B.torus(self, 2.6, 3.0, Vector3(cos(a) * 20.0, 9.0 + i * 2.0, sin(a) * 20.0), B.glow(Color("f0b04a"), 1.8), Vector3(PI / 2, -a, 0), 32)
		bob(ring, 0.5, 0.6)
	for i in 3:
		B.cyl(self, 4.0, 4.0, 0.6, Vector3(cos(i * 2.1) * 12.0, 12.0 + i * 6.0, sin(i * 2.1) * 12.0), teal, true, 12)
	for i in 6:                                               # standing drones
		var d := Dummy.new()
		add_child(d)
		d.global_position = Vector3(cos(i * TAU / 6 + 0.5) * 14.0, 0.0, sin(i * TAU / 6 + 0.5) * 14.0)
		d.centre = d.global_position
	for i in 4:                                               # flying drones
		var d2 := Dummy.new()
		d2.orbit_radius = 9.0 + i * 5.0
		d2.orbit_speed = 0.5 - i * 0.07
		add_child(d2)
		d2.global_position = Vector3(0, 6.0 + i * 4.0, 0)
		d2.centre = d2.global_position
	B.motes(self, Vector3(0, 14, 0), Vector3(45, 16, 45), Color("fff2c0"), 220, 9.0, Vector3(0.2, 0.15, 0.1), 0.08)
	portal(Vector3(0, 0, 41), &"library", &"start", Color(1.0, 0.7, 0.25), "The Library")
	spawns[&"start"] = [Vector3(0, 0.4, 34), 0.0]
	shots = [[Vector3(6, 3, 44), Vector3(0, 8, 0)], [Vector3(40, 30, 40), Vector3(0, 6, 0)]]


func on_enter() -> void:
	if Game.player.character != &"vision":
		Game.player.set_character(&"vision")
	Game.hud.toast("WASD run  ·  Space toggles flight  ·  hold left-click: Mind Stone beam  ·  I: 360° view  ·  Tab: Wanda", 9.0)
