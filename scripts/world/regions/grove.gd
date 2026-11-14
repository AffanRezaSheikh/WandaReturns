## Hollow Grove: violet pre-dawn forest bowl, glowing fungi, the Root Bell on its hill.
extends "res://scripts/world/region.gd"

const HALF := 72.0
const BELL := Vector3(0, 0, -34)
var _path: Array[Vector2] = [Vector2(0, 52), Vector2(-8, 32), Vector2(6, 14), Vector2(-5, -6), Vector2(0, -34)]


func _init() -> void:
	display_name = "HOLLOW GROVE"
	subtitle = "Where the dawn never comes"


func _path_d(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 1e9
	for i in _path.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, _path[i], _path[i + 1])))
	return best


func height(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * 3.2 + noise.get_noise_2d(x * 3.0, z * 3.0) * 0.7
	h *= 0.2 + 0.8 * smoothstep(1.5, 7.0, _path_d(x, z))
	h += 4.5 * smoothstep(24.0, 7.0, Vector2(x, z - BELL.z).length())
	h += smoothstep(56.0, 72.0, Vector2(x, z).length()) * 15.0
	return h


func _color(p: Vector3) -> Color:
	var n := noise.get_noise_2d(p.x * 4.0, p.z * 4.0) * 0.5 + 0.5
	var g := Color("1f3a2c").lerp(Color("3a6a44"), n)
	var d := _path_d(p.x, p.z)
	if d < 2.4:
		g = Color("4a3b3a").lerp(Color("6a5648"), n)
	elif d < 3.6:
		g = g.lerp(Color("4a3b3a"), 0.5)
	return g


func at(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, height(x, z) + lift, z)


func build() -> void:
	setup_env(Color("120a2a"), Color("5a3a78"), Color("2c2a52"), 0.012, 0.55, Color("b8acff"), 1.0, Vector3(-36, 38, 0), 0.02)
	B.terrain(self, HALF, 72, height, _color)
	for s: float in [-1.0, 1.0]:
		B.wall(self, Vector3(2, 60, 150), Vector3(s * 70, 20, 0))
		B.wall(self, Vector3(150, 60, 2), Vector3(0, 20, s * 70))
	var trunk := B.mat(Color("3a2a3c"), 1.0)
	var leaves := [B.mat(Color("1f3a2c")), B.mat(Color("2f5a3d")), B.mat(Color("264a36")), B.mat(Color("4a7a4c"))]
	var dark := [B.mat(Color("16241f")), B.mat(Color("1f3a2c"))]
	var glint := B.glow(Color("e8374a"), 2.5)
	for i in 190:
		var x := rnd(-66, 66)
		var z := rnd(-66, 66)
		if _path_d(x, z) < 4.0 or Vector2(x, z - BELL.z).length() < 11.0 or Vector2(x, z).length() > 68.0:
			continue
		var giant := rng.randf() < 0.1
		tree(at(x, z, -0.3), rnd(16, 24) if giant else rnd(6, 11), trunk, leaves, rng.randf() < 0.3, glint)
	for i in 72:                                              # dark wall of trees on the rim
		var a := i * TAU / 72.0
		tree(at(cos(a) * rnd(60, 66), sin(a) * rnd(60, 66), -0.5), rnd(14, 22), trunk, dark, i % 2 == 0)
	var stone := B.mat(Color("6a5d72"), 0.95)
	for i in 34:
		var x := rnd(-58, 58)
		var z := rnd(-58, 58)
		if _path_d(x, z) > 2.5:
			rock(at(x, z), rnd(0.4, 1.5), stone)
	var bush := [B.mat(Color("2f5a3d")), B.mat(Color("4a7a4c"))]
	for i in 90:
		var x := rnd(-56, 56)
		var z := rnd(-56, 56)
		if _path_d(x, z) > 2.6:
			B.ball(self, rnd(0.3, 0.7), at(x, z, 0.15), bush[i % 2], Vector3(1.3, 0.7, 1.3), false, 6)
	# glowing fungi along the path
	var stem := B.mat(Color("f4ead8"), 0.8)
	var caps := [B.glow(Color("f0a3b8"), 1.8), B.glow(Color("e07a98"), 1.6), B.glow(Color("ff8a7a"), 1.8)]
	var lit := 0
	for i in 60:
		var x := rnd(-50, 50)
		var z := rnd(-50, 54)
		var d := _path_d(x, z)
		if d < 2.6 or d > 11.0:
			continue
		for k in 3:
			var p := at(x + rnd(-0.7, 0.7), z + rnd(-0.7, 0.7))
			var hh := rnd(0.3, 1.1)
			B.cyl(self, 0.05, 0.08, hh, p + Vector3(0, hh * 0.5, 0), stem, false, 5)
			B.ball(self, hh * 0.45, p + Vector3(0, hh, 0), caps[(i + k) % 3], Vector3(1, 0.5, 1), false, 7)
		if lit < 14:
			lit += 1
			B.omni(self, at(x, z, 1.0), Color("f0a3b8"), 1.6, 7.0)
	_root_bell()
	# rune shrine by the spawn
	var sp := at(5, 46)
	B.ball(self, 0.9, sp + Vector3(0, 0.9, 0), stone, Vector3(0.7, 1.5, 0.6), true, 6)
	B.box(self, Vector3(0.12, 0.9, 0.05), sp + Vector3(0, 1.2, -0.52), B.glow(Color("e8374a"), 3.0), false)
	B.box(self, Vector3(0.5, 0.12, 0.05), sp + Vector3(0, 1.4, -0.52), B.glow(Color("e8374a"), 3.0), false)
	B.omni(self, sp + Vector3(0, 1.4, -1.0), Color("e8374a"), 2.0, 8.0)
	B.motes(self, Vector3(0, 6, 0), Vector3(60, 6, 60), Color("f8c8d2"), 500, 9.0, Vector3(0.1, 0.12, 0.05), 0.09)
	B.motes(self, Vector3(0, 3, 0), Vector3(55, 3, 55), Color("ffe08a"), 160, 6.0, Vector3(0.3, 0.05, 0.2), 0.07, 0.9)
	portal(at(18, -49), &"cinderwake", &"from_grove")
	portal(at(-7, 50), &"library", &"from_grove", Color(1.0, 0.7, 0.25), "The Library")
	spawns[&"start"] = [at(0, 54, 0.4), 0.0]
	spawns[&"from_cinderwake"] = [at(13, -44, 0.4), PI]
	shots = [[at(9, 22, 5.0), at(0, -34, 7.0)], [at(-10, -14, 3.0), at(0, -34, 7.0)]]


func _root_bell() -> void:
	var c := at(BELL.x, BELL.z)
	var root := B.mat(Color("46364a"), 1.0)
	var gold := B.mat(Color("c97a2b"), 0.35, 0.8, Color("f0b04a"), 0.6)
	for s: float in [-1.0, 1.0]:
		B.cyl(self, 0.45, 1.1, 10.5, c + Vector3(s * 3.6, 5.0, 0), root, true, 7, Vector3(0, 0, s * 0.2))
		B.cyl(self, 0.2, 0.5, 5.0, c + Vector3(s * 4.6, 1.5, 1.2), root, false, 6, Vector3(0.5, 0, s * 0.7))
	B.cyl(self, 0.5, 0.6, 8.6, c + Vector3(0, 10.0, 0), root, false, 7, Vector3(0, 0, PI / 2))
	B.cyl(self, 0.12, 0.12, 1.6, c + Vector3(0, 9.0, 0), gold, false, 6)
	B.cyl(self, 0.55, 1.7, 2.8, c + Vector3(0, 6.9, 0), gold, false, 12)
	B.cyl(self, 1.8, 1.9, 0.3, c + Vector3(0, 5.4, 0), gold, false, 12)
	B.ball(self, 0.35, c + Vector3(0, 5.0, 0), B.glow(Color("e8374a"), 3.0), Vector3.ONE, false, 8)
	B.omni(self, c + Vector3(0, 5.5, 2.0), Color("f0b04a"), 5.0, 26.0)
	var stone := B.mat(Color("6a5d72"), 0.95)
	for i in 7:
		var a := i * TAU / 7.0 + 0.45
		var p := at(c.x + cos(a) * 9.0, c.z + sin(a) * 9.0)
		B.box(self, Vector3(1.0, 3.2, 0.7), p + Vector3(0, 1.5, 0), stone, true, Vector3(rnd(-0.1, 0.1), -a + PI / 2, rnd(-0.1, 0.1)))
		B.ball(self, 0.14, p + Vector3(-cos(a) * 0.45, 2.2, -sin(a) * 0.45), B.glow(Color("e8374a"), 3.0), Vector3.ONE, false, 5)
