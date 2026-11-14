## Glassfen: a mirror-still fen of glass shards leading to the Mirror Loom.
extends "res://scripts/world/region.gd"

const LOOM := Vector3(0, 0, -46)


func _init() -> void:
	display_name = "GLASSFEN"
	subtitle = "Every reflection remembers a different you"


func build() -> void:
	setup_env(Color("081420"), Color("3f86a0"), Color("2a5c6c"), 0.009, 0.95, Color("c8ecff"), 0.95, Vector3(-28, 30, 0), 0.012, true)
	var water := PlaneMesh.new()
	water.size = Vector2(700, 700)
	var wm := MeshInstance3D.new()
	wm.mesh = water
	wm.material_override = B.glass(Color("123848"))
	add_child(wm)
	B.wall(self, Vector3(300, 1, 300), Vector3(0, -0.5, 0))
	for s: float in [-1.0, 1.0]:
		B.wall(self, Vector3(2, 60, 150), Vector3(s * 70, 20, 0))
		B.wall(self, Vector3(150, 60, 2), Vector3(0, 20, s * 70))
	var isle := B.mat(Color("8fb0bc"), 0.5, 0.2)
	var isle2 := B.mat(Color("6a8c9c"), 0.5, 0.2)
	for i in 22:
		var p := Vector3(rnd(-60, 60), 0.0, rnd(-60, 56))
		var r := rnd(3, 9)
		B.cyl(self, r, r + 1.0, 0.12, p + Vector3(0, 0.0, 0), isle if i % 2 == 0 else isle2, false, 9)
	B.box(self, Vector3(5.0, 0.1, 84), Vector3(0, 0.01, 0), isle, false)           # causeway to the Loom
	# avenue of mirror pillars
	var frame := B.mat(Color("6a5d72"), 0.8)
	var mirror := B.glass(Color("bfe4ee"), 1.0, 0.12)
	for k in 8:
		for s: float in [-1.0, 1.0]:
			var p := Vector3(s * 6.5, 0, 34.0 - k * 9.0)
			B.box(self, Vector3(0.7, 7.6, 2.4), p + Vector3(0, 3.8, 0), frame, true, Vector3(0, s * 0.35, 0))
			B.box(self, Vector3(0.75, 6.4, 1.9), p + Vector3(-s * 0.03, 3.9, 0), mirror, false, Vector3(0, s * 0.35, 0))
			B.box(self, Vector3(0.12, 3.2, 0.7), p + Vector3(-s * 0.42, 2.6, 0), B.glow(Color("b3162f"), 0.9), false, Vector3(0, s * 0.35, 0))   # a reflection that is not hers
			if k % 2 == 0:
				B.omni(self, p + Vector3(-s * 1.5, 3.5, 0), Color("7ab0c8"), 1.3, 9.0)
	_loom()
	var shard := [B.glass(Color("7ab0c8"), 1.0, 0.5), B.glass(Color("c4e4ee"), 1.0, 0.7), B.glass(Color("3a6a8c"), 1.0, 0.4)]
	var lit := 0
	for i in 80:
		var p := Vector3(rnd(-64, 64), 0, rnd(-64, 60))
		if absf(p.x) < 9.0 and p.z > -40.0:
			continue
		if p.distance_to(LOOM) < 16.0:
			continue
		var big := i % 6 == 0
		crystal(self, p, rnd(3.5, 8.0) if big else rnd(0.8, 2.4), shard[i % 3], 4 if big else 3, big)
		if big and lit < 10:
			lit += 1
			B.omni(self, p + Vector3(0, 2.0, 0), Color("7ab0c8"), 2.0, 12.0)
	var reed := B.mat(Color("4a7a4c"), 0.9)
	var tip := B.mat(Color("8a4b1c"), 0.9)
	for i in 46:
		var p := Vector3(rnd(-62, 62), 0, rnd(-62, 58))
		if absf(p.x) < 5.0:
			continue
		for k in 5:
			var q := p + Vector3(rnd(-0.6, 0.6), 0, rnd(-0.6, 0.6))
			var hh := rnd(1.0, 2.2)
			B.cyl(self, 0.02, 0.035, hh, q + Vector3(0, hh * 0.5, 0), reed, false, 4, Vector3(rnd(-0.12, 0.12), 0, rnd(-0.12, 0.12)))
			B.cyl(self, 0.05, 0.05, 0.3, q + Vector3(0, hh, 0), tip, false, 5)
	for i in 44:                                              # infinite mirrors on the horizon
		var a := i * TAU / 44.0 + rnd(-0.05, 0.05)
		var r := rnd(110, 190)
		var hh := rnd(30, 90)
		B.box(self, Vector3(rnd(6, 16), hh, 1.0), Vector3(cos(a) * r, hh * 0.5 - 2.0, sin(a) * r), mirror, false, Vector3(0, -a + PI / 2 + rnd(-0.4, 0.4), rnd(-0.06, 0.06)))
	B.motes(self, Vector3(0, 3, 0), Vector3(60, 3.5, 60), Color("c4e4ee"), 420, 8.0, Vector3(0.12, 0.06, 0.1), 0.07, 0.9)
	portal(Vector3(-47, 0, 0), &"cinderwake", &"from_glassfen")
	portal(Vector3(8, 0, 52), &"library", &"from_glassfen", Color(1.0, 0.7, 0.25), "The Library")
	spawns[&"start"] = [Vector3(0, 0.4, 46), 0.0]
	spawns[&"from_cinderwake"] = [Vector3(-40, 0.4, 0), -PI / 2]
	spawns[&"from_archive"] = [Vector3(0, 0.4, 46), 0.0]
	shots = [[Vector3(3.5, 2.6, 30), LOOM + Vector3(0, 11, 0)], [Vector3(-24, 9, -14), LOOM + Vector3(0, 10, 0)]]


func _loom() -> void:
	var c := LOOM + Vector3(0, 12.5, 0)
	var silver := B.mat(Color("9a8d9c"), 0.35, 0.7)
	B.torus(self, 9.4, 11.0, c, silver, Vector3(PI / 2, 0, 0), 32)
	B.cyl(self, 9.4, 9.4, 0.12, c, B.glass(Color("c4e4ee"), 1.0, 0.35), false, 32, Vector3(PI / 2, 0, 0))
	for i in 10:
		var a := i * PI / 10.0 + 0.15
		var m := B.glow(Color("e8374a"), 3.0) if i % 3 == 0 else B.glow(Color("fff6e6"), 1.4)
		B.cyl(self, 0.035, 0.035, 18.6, c + Vector3(0, 0, 0.12), m, false, 4, Vector3(0, 0, a))
	for i in 12:
		var a := i * TAU / 12.0
		B.ball(self, 0.35, c + Vector3(cos(a) * 10.2, sin(a) * 10.2, 0.9), B.glow(Color("f0b04a"), 2.5), Vector3.ONE, false, 6)
	B.box(self, Vector3(12, 1.6, 5), LOOM + Vector3(0, 0.8, 0), B.mat(Color("6a5d72"), 0.8))
	B.box(self, Vector3(16, 0.6, 8), LOOM + Vector3(0, 0.3, 0), B.mat(Color("463b52"), 0.8))
	B.omni(self, c + Vector3(0, 0, 5), Color("c4e4ee"), 6.0, 40.0)
