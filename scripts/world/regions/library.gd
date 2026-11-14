## The Library: hub and main spawn. A library the size of a city, floating between
## stories; its rifts lead to Leonia (the main story) and four side realms.
extends "res://scripts/world/region.gd"

const SPINES := ["7d1733", "b3162f", "3a6a8c", "2f5a3d", "c97a2b", "5a3fa0", "9a8d9c", "5c1028"]
var _wood: Material
var _stone: Material
var _gold: Material


func _init() -> void:
	display_name = "THE LIBRARY"
	subtitle = "Every story begins between the shelves"
	kill_y = -30.0


func build() -> void:
	setup_env(Color("100610"), Color("b0661f"), Color("6e3c1a"), 0.0055, 0.95, Color("ffcf8a"), 1.05, Vector3(-40, -32, 0), 0.01)
	_wood = B.mat(Color("4a2c1c"), 0.8)
	_stone = B.mat(Color("5a4636"), 0.9)
	_gold = B.mat(Color("c97a2b"), 0.3, 0.85, Color("f0b04a"), 0.5)
	_platform(Vector3.ZERO, 18.0)
	for k in 4:
		var a := k * PI / 2
		var dir := Vector3(sin(a), 0, cos(a))
		_platform(dir * 46.0, 10.5)
		B.box(self, Vector3(4.2, 0.6, 20.0), dir * 27.0 + Vector3(0, -0.3, 0), _stone, true, Vector3(0, a, 0))
		for s: float in [-1.0, 1.0]:
			B.box(self, Vector3(0.25, 0.9, 20.0), dir * 27.0 + Vector3(cos(a), 0, -sin(a)) * s * 2.1 + Vector3(0, 0.45, 0), _gold, false, Vector3(0, a, 0))
	for i in 8:                                               # shelves ringing the plaza
		var a := i * PI / 4 + PI / 8
		_shelf(Vector3(sin(a) * 15.5, 0, cos(a) * 15.5), a, 7.0, 10.0 + (i % 2) * 3.0)
	_core()
	for r: float in [8.0, 12.5]:
		B.torus(self, r - 0.12, r + 0.12, Vector3(0, 0.03, 0), B.glow(Color("f0b04a"), 2.2), Vector3.ZERO, 40)
	# north wing: tall stacks; east: scriptorium; west: reading maze; south: arrival
	for x: float in [-6.0, 0.0, 6.0]:
		_shelf(Vector3(x, 0, -52.0), 0.0, 5.0, 14.0)
	_brazier(Vector3(-5, 0, -42)); _brazier(Vector3(5, 0, -42))
	for i in 4:
		var p := Vector3(41.0 + (i % 2) * 4.0, 0, -2.5 + (i / 2) * 5.0)
		B.box(self, Vector3(2.6, 0.2, 1.4), p + Vector3(0, 1.0, 0), _wood)
		for s: float in [-1.0, 1.0]:
			B.box(self, Vector3(0.2, 1.0, 1.2), p + Vector3(s * 1.1, 0.5, 0), _wood, false)
		B.box(self, Vector3(0.7, 0.03, 0.5), p + Vector3(-0.3, 1.12, 0), B.mat(Color("f4ead8"), 0.8), false)   # letter mid-write
		B.cyl(self, 0.04, 0.04, 0.3, p + Vector3(0.8, 1.25, 0.3), B.mat(Color("f4ead8")), false, 5)
		B.ball(self, 0.07, p + Vector3(0.8, 1.46, 0.3), B.glow(Color("ffe08a"), 4.0), Vector3(1, 1.6, 1), false, 5)
		B.omni(self, p + Vector3(0.8, 1.7, 0.3), Color("f0b04a"), 1.5, 7.0)
	_brazier(Vector3(-6, 0, 41)); _brazier(Vector3(6, 0, 41))
	for i in 18:                                              # book piles
		var a := rnd(0, TAU)
		var r := rnd(3, 13)
		for k in 3:
			B.box(self, Vector3(0.7, 0.14, 0.5), Vector3(cos(a) * r, 0.07 + k * 0.14, sin(a) * r), B.mat(Color(SPINES[(i + k) % 8]), 0.8), false, Vector3(0, rnd(0, 1.0), 0))
	var page := B.mat(Color("f4ead8"), 0.8, 0.0, Color("ffe08a"), 0.5)
	for i in 16:                                              # floating open tomes
		var n := Node3D.new()
		n.position = Vector3(rnd(-34, 34), rnd(2.5, 9), rnd(-34, 34))
		n.rotation = Vector3(rnd(-0.4, 0.4), rnd(0, TAU), rnd(-0.3, 0.3))
		add_child(n)
		for s: float in [-1.0, 1.0]:
			B.box(n, Vector3(0.7, 0.06, 1.0), Vector3(s * 0.33, 0, 0), page, false, Vector3(0, 0, s * 0.35))
		B.box(n, Vector3(1.5, 0.05, 1.08), Vector3(0, -0.12, 0), B.mat(Color(SPINES[i % 8]), 0.7), false)
		bob(n, 0.4, rnd(0.6, 1.2))
	var far := B.mat(Color("2a1810"), 0.9)
	var strip := B.glow(Color("f0b04a"), 1.6)
	for i in 70:                                              # the city of shelves, far away
		var a := rnd(0, TAU)
		var r := rnd(75, 290)
		var hh := rnd(18, 70)
		var w := rnd(8, 22)
		var n := Node3D.new()
		n.position = Vector3(cos(a) * r, rnd(-70, 60), sin(a) * r)
		n.rotation = Vector3(rnd(-0.15, 0.15), rnd(0, TAU), rnd(-0.15, 0.15))
		add_child(n)
		B.box(n, Vector3(w, hh, 3.0), Vector3.ZERO, far, false)
		for k in 4:
			B.box(n, Vector3(w * 0.9, 0.3, 3.1), Vector3(0, -hh * 0.4 + k * hh * 0.26, 0), strip, false)
		if i % 4 == 0:
			spin(n, Vector3.UP, rnd(-0.03, 0.03))
	B.motes(self, Vector3(0, 12, 0), Vector3(60, 26, 60), Color("ffe6b0"), 650, 9.0, Vector3(0.1, 1.3, 0.05), 0.13)
	B.motes(self, Vector3(0, 8, 0), Vector3(50, 14, 50), Color("ff9040"), 250, 6.0, Vector3(0.2, 0.9, 0.1), 0.07)
	portal(Vector3(0, 0, -45.5), &"leonia", &"start", Color(1.0, 0.75, 0.3), "LEONIA, NEW JERSEY\nThe Story")
	portal(Vector3(47, 0, -7), &"cinderwake", &"start", Color(1.0, 0.45, 0.2), "Cinderwake")
	portal(Vector3(47, 0, 7), &"glassfen", &"start", Color(0.3, 0.8, 1.0), "Glassfen")
	portal(Vector3(-47, 0, -7), &"grove", &"start", Color(0.5, 1.0, 0.6), "Hollow Grove")
	portal(Vector3(-47, 0, 7), &"spire", &"start", Color(0.65, 0.45, 1.0), "Hourglass Spire")
	portal(Vector3(8.5, 0, 50), &"arena", &"start", Color(1.0, 0.9, 0.4), "Vision Test Arena")
	spawns[&"start"] = [Vector3(0, 0.5, 46), 0.0]
	spawns[&"from_leonia"] = [Vector3(0, 0.5, -38), PI]
	spawns[&"from_cinderwake"] = [Vector3(40, 0.5, -7), PI / 2]
	spawns[&"from_glassfen"] = [Vector3(40, 0.5, 7), PI / 2]
	spawns[&"from_grove"] = [Vector3(-40, 0.5, -7), -PI / 2]
	spawns[&"from_spire"] = [Vector3(-40, 0.5, 7), -PI / 2]
	shots = [[Vector3(3, 4, 36), Vector3(0, 9, 0)], [Vector3(34, 24, 36), Vector3(0, 6, 0)]]


func on_enter() -> void:
	Game.hud.toast("Golden rift ahead: Leonia   ·   rift behind you: Vision Test Arena   ·   Tab switches hero   ·   I: 360° view", 8.0)


func _platform(pos: Vector3, r: float) -> void:
	B.cyl(self, r, r, 1.4, pos + Vector3(0, -0.7, 0), _stone, true, 16)
	B.cyl(self, r * 0.96, r * 0.2, r * 1.1, pos + Vector3(0, -1.4 - r * 0.55, 0), B.mat(Color("3a2a22"), 1.0), false, 9)
	B.torus(self, r - 0.35, r + 0.1, pos + Vector3(0, 0.02, 0), _gold, Vector3.ZERO, 32)


func _shelf(pos: Vector3, yaw: float, w: float, h: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	B.box(n, Vector3(w, h, 1.3), Vector3(0, h * 0.5, 0), _wood)
	B.box(n, Vector3(w + 0.5, 0.4, 1.7), Vector3(0, h + 0.2, 0), _gold, false)
	var rows := int(h / 1.35)
	for r in rows:
		var x := -w * 0.5 + 0.25
		while x < w * 0.5 - 0.4:
			var bw := minf(rnd(0.4, 1.3), w * 0.5 - 0.25 - x)
			var bh := rnd(0.7, 1.05)
			if rng.randf() > 0.12:
				for sz: float in [-1.0, 1.0]:
					B.box(n, Vector3(bw, bh, 0.12), Vector3(x + bw * 0.5, 0.35 + r * 1.35 + bh * 0.5, sz * 0.66), B.mat(Color(SPINES[rng.randi() % 8]), 0.75), false)
			x += bw + 0.06


func _brazier(pos: Vector3) -> void:
	B.cyl(self, 0.12, 0.3, 1.3, pos + Vector3(0, 0.65, 0), _gold, true, 6)
	B.cyl(self, 0.7, 0.25, 0.45, pos + Vector3(0, 1.5, 0), _gold, false, 8)
	B.ball(self, 0.42, pos + Vector3(0, 1.95, 0), B.glow(Color("ff9a30"), 4.0), Vector3(1, 1.5, 1), false, 6)
	B.omni(self, pos + Vector3(0, 2.3, 0), Color("ff9a40"), 3.0, 14.0)
	B.motes(self, pos + Vector3(0, 2.6, 0), Vector3(0.3, 0.5, 0.3), Color("ffb050"), 24, 1.6, Vector3(0, 1.4, 0), 0.07)


func _core() -> void:
	var c := Vector3(0, 10, 0)
	var orb := B.ball(self, 3.2, c, B.glow(Color("ffc050"), 2.6), Vector3.ONE, false, 10)
	spin(orb, Vector3(0.2, 1, 0.1), 0.25)
	for k in 3:
		var ring := B.torus(self, 4.6 + k * 1.2, 4.9 + k * 1.2, c, _gold, Vector3(k * 1.1, 0, k * 0.7), 36)
		spin(ring, Vector3(sin(k * 2.0), 0.4, cos(k * 2.0)), 0.35 + k * 0.12)
	for i in 6:
		var a := i * TAU / 6.0
		B.box(self, Vector3(0.12, 0.6, 0.12), Vector3(cos(a) * 2.2, 0.3, sin(a) * 2.2), B.glow(Color("e8374a"), 3.0), false)
	B.cyl(self, 1.2, 2.2, 1.6, Vector3(0, 0.8, 0), _stone, true, 8)
	B.omni(self, c, Color("ffc060"), 7.0, 46.0)
	B.motes(self, c, Vector3(7, 5, 7), Color("fff6e6"), 160, 4.0, Vector3(0.6, 0.5, 0.3), 0.14, 1.0)
