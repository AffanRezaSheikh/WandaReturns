## Cinderwake: the ash village frozen in one hour, around the stopped clock tower.
extends "res://scripts/world/region.gd"

const TOWER := Vector3(0, 0, -30)


func _init() -> void:
	display_name = "CINDERWAKE"
	subtitle = "The hour that will not pass"


func height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var road := minf(absf(x), absf(z))
	var h := noise.get_noise_2d(x * 2.0, z * 2.0) * 0.9 * smoothstep(15.0, 26.0, r) * smoothstep(2.0, 5.0, road)
	return h + smoothstep(48.0, 64.0, r) * 11.0


func _color(p: Vector3) -> Color:
	var n := noise.get_noise_2d(p.x * 5.0, p.z * 5.0) * 0.5 + 0.5
	var r := Vector2(p.x, p.z).length()
	if r < 16.0 or minf(absf(p.x), absf(p.z)) < 2.2:
		var chk := (int(floor(p.x / 2.0)) + int(floor(p.z / 2.0))) % 2 == 0
		return (Color("6a5d72") if chk else Color("5a4e64")).lerp(Color("463b52"), n * 0.6)
	return Color("3a3038").lerp(Color("5c4a48"), n)


func at(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, height(x, z) + lift, z)


func build() -> void:
	var env := setup_env(Color("241436"), Color("c4683c"), Color("5a4048"), 0.006, 0.7, Color("ffb070"), 1.6, Vector3(-14, -152, 0), 0.008)
	env.ambient_light_color = Color("a89aa8")
	env.fog_sky_affect = 0.1
	B.terrain(self, 66.0, 66, height, _color)
	for s: float in [-1.0, 1.0]:
		B.wall(self, Vector3(2, 60, 140), Vector3(s * 62, 20, 0))
		B.wall(self, Vector3(140, 60, 2), Vector3(0, 20, s * 62))
	var n := 0
	for i in 12:                                              # ring around the square
		var a := i * TAU / 12.0 + 0.26
		if absf(cos(a)) < 0.22 or absf(sin(a)) < 0.22 or (sin(a) < -0.8):
			continue
		_house(at(cos(a) * 25.0, sin(a) * 25.0), a, n)
		n += 1
	for s: float in [-1.0, 1.0]:                              # along the four roads
		for d: float in [30.0, 40.0]:
			_house(at(s * d, 8.5), 0.0, n, PI)
			_house(at(s * d, -8.5), 0.0, n + 1, 0.0)
			_house(at(s * 9.0, d), 0.0, n + 2, -s * PI / 2)
			n += 3
	_clock_tower()
	var ash := B.mat(Color("8a7e8c"), 1.0)
	for i in 14:                                              # villagers frozen mid-gesture
		var a := rnd(0, TAU)
		var r := rnd(4, 14)
		figure(at(cos(a) * r, sin(a) * r), ash, rnd(0, TAU), i % 3)
	for i in 8:
		var a := i * TAU / 8.0 + 0.39
		lantern(at(cos(a) * 15.5, sin(a) * 15.5), i % 3 == 0)
	for s: float in [-1.0, 1.0]:
		for k in 4:
			lantern(at(s * (22.0 + k * 8.0), 3.2), k == 2)
			lantern(at(3.2, s * (22.0 + k * 8.0)), k == 1 and s > 0)
	# well, crates, banners
	var stone := B.mat(Color("6a5d72"), 0.95)
	var wood := B.mat(Color("4a3430"), 0.9)
	B.cyl(self, 1.5, 1.6, 1.0, Vector3(6, 0.5, 5), stone, true, 10)
	B.cyl(self, 1.2, 1.2, 0.1, Vector3(6, 0.95, 5), B.mat(Color("0d0612"), 0.2), false, 10)
	for s: float in [-1.0, 1.0]:
		B.cyl(self, 0.09, 0.09, 2.4, Vector3(6 + s * 1.4, 1.7, 5), wood, false, 5)
	B.prism(self, Vector3(3.6, 0.9, 2.2), Vector3(6, 3.3, 5), wood)
	for i in 16:
		var a := rnd(0, TAU)
		var r := rnd(8, 40)
		var p := at(cos(a) * r, sin(a) * r)
		if minf(absf(p.x), absf(p.z)) < 3.0:
			continue
		B.box(self, Vector3.ONE * rnd(0.7, 1.1), p + Vector3(0, 0.45, 0), wood, true, Vector3(0, rnd(0, 1.5), 0))
	var cloth := B.mat(Color("7d1733"), 0.9, 0.0, Color("5c1028"), 0.3)
	for i in 8:
		var a := i * TAU / 8.0
		var p := at(cos(a) * 17.5, sin(a) * 17.5)
		B.cyl(self, 0.07, 0.07, 6.0, p + Vector3(0, 3, 0), wood, true, 5)
		B.box(self, Vector3(1.1, 3.0, 0.05), p + Vector3(0, 4.2, 0) + Vector3(-sin(a), 0, cos(a)) * 0.6, cloth, false, Vector3(0, -a + PI / 2, 0))
	var char_m := B.mat(Color("1a0b22"), 1.0)
	for i in 34:
		var a := rnd(0, TAU)
		var r := rnd(34, 56)
		var p := at(cos(a) * r, sin(a) * r, -0.2)
		if minf(absf(p.x), absf(p.z)) > 4.0:
			bare_tree(p, rnd(5, 9), char_m)
	B.motes(self, Vector3(0, 9, 0), Vector3(55, 10, 55), Color("ffb060"), 450, 7.0, Vector3(0.15, 0.75, 0.1), 0.09)
	B.motes(self, Vector3(0, 10, 0), Vector3(55, 10, 55), Color("9a8d9c"), 220, 10.0, Vector3(0.2, -0.3, 0.1), 0.06)
	portal(at(0, 47), &"grove", &"from_cinderwake")
	portal(at(47, 0), &"glassfen", &"from_cinderwake", Color(0.3, 0.8, 1.0))
	spawns[&"start"] = [at(0, 40, 0.4), 0.0]
	spawns[&"from_grove"] = [at(0, 40, 0.4), 0.0]
	spawns[&"from_glassfen"] = [at(40, 0, 0.4), PI / 2]
	shots = [[at(4, 15, 2.2), TOWER + Vector3(0, 19, 0)], [at(-24, 6, 13.0), TOWER + Vector3(0, 12, 0)]]


func _house(pos: Vector3, a: float, i: int, yaw_override := 99.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw_override if yaw_override < 90.0 else atan2(pos.x, pos.z)
	add_child(root)
	var w := 6.0 + (i % 3) * 1.2
	var d := 6.0 + ((i + 1) % 2) * 1.5
	var h := 3.6 + (i % 2) * 1.6
	var lit := i % 5 == 1
	var wallm := B.mat(Color("4a3a3c") if i % 2 == 0 else Color("3a2c34"), 1.0)
	var beam := B.mat(Color("1a0b22"), 1.0)
	var roof := B.mat(Color("463b52") if i % 3 else Color("2d2538"), 0.9)
	B.box(root, Vector3(w, h, d), Vector3(0, h * 0.5 - 0.3, 0), wallm)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			B.box(root, Vector3(0.3, h, 0.3), Vector3(sx * w * 0.5, h * 0.5 - 0.3, sz * d * 0.5), beam, false)
	B.box(root, Vector3(w + 0.2, 0.3, d + 0.2), Vector3(0, h - 0.3, 0), beam, false)
	var broken := i % 4 == 2
	var rf := B.prism(root, Vector3(w + 1.0, h * 0.75, d + 1.0), Vector3(0, h + h * 0.36 - 0.3, 0), roof)
	if broken:
		rf.scale = Vector3(1.0, 0.55, 0.6)
		rf.rotation = Vector3(0.12, 0, 0.1)
		rf.position += Vector3(0.6, -0.5, 1.0)
	B.box(root, Vector3(0.8, 1.6 + h * 0.5, 0.8), Vector3(w * 0.3, h + 0.8, 0), wallm, false)
	B.box(root, Vector3(1.2, 2.1, 0.12), Vector3(-w * 0.15, 0.85, -d * 0.5 - 0.03), beam, false)
	var win := B.glow(Color("f0b04a"), 3.0) if lit else B.mat(Color("0d0612"), 0.3)
	for wx: float in [0.22, -0.38]:
		B.box(root, Vector3(1.0, 1.0, 0.1), Vector3(w * wx, 1.7, -d * 0.5 - 0.03), win, false)
	if lit:
		B.omni(root, Vector3(w * 0.22, 1.7, -d * 0.5 - 1.2), Color("f0b04a"), 2.5, 10.0)


func _clock_tower() -> void:
	var c := TOWER
	var stone := B.mat(Color("6a5d72"), 0.95)
	var dk := B.mat(Color("463b52"), 0.95)
	var slate := B.mat(Color("2d2538"), 0.85)
	B.box(self, Vector3(8, 4, 8), c + Vector3(0, 2, 0), dk)
	B.box(self, Vector3(5.6, 24, 5.6), c + Vector3(0, 16, 0), stone)
	for y: float in [4.2, 12.0, 20.0, 28.0]:
		B.box(self, Vector3(6.3, 0.5, 6.3), c + Vector3(0, y, 0), dk, false)
	B.box(self, Vector3(6.8, 5, 6.8), c + Vector3(0, 30.5, 0), stone, false)
	B.cyl(self, 0.0, 5.4, 9.0, c + Vector3(0, 37.5, 0), slate, false, 4, Vector3(0, PI / 4, 0))
	B.cyl(self, 0.0, 0.25, 4.0, c + Vector3(0, 43.5, 0), B.mat(Color("c97a2b"), 0.3, 0.8, Color("f0b04a"), 0.8), false, 5)
	var face := B.mat(Color("f4ead8"), 0.6, 0.0, Color("f4ead8"), 0.9)
	var hand := B.mat(Color("1a0b22"), 0.5)
	for k in 4:
		var a := k * PI / 2
		var nrm := Vector3(sin(a), 0, cos(a))
		var f := B.cyl(self, 2.5, 2.5, 0.25, c + Vector3(0, 30.5, 0) + nrm * 3.45, face, false, 16, Vector3(PI / 2, a, 0))
		B.torus(self, 2.4, 2.8, f.position, dk, Vector3(PI / 2, a, 0), 16)
		var h1 := B.box(self, Vector3(0.16, 2.0, 0.1), f.position + nrm * 0.2, hand, false, Vector3(0, a, 0.0))
		h1.position += Vector3(0, 0.9, 0)
		var h2 := B.box(self, Vector3(0.2, 1.4, 0.1), f.position + nrm * 0.2, hand, false, Vector3(0, a, -1.9))
		h2.position += h2.basis.y * 0.6
	for i in 7:                                               # the crack
		B.box(self, Vector3(0.14, 3.2, 0.1), c + Vector3(1.2 + (i % 2) * 0.5 - i * 0.12, 7.0 + i * 2.7, 2.83), hand, false, Vector3(0, 0, (0.35 if i % 2 == 0 else -0.3)))
	B.box(self, Vector3(2.2, 3.4, 0.2), c + Vector3(0, 1.7, 4.02), hand, false)
	B.omni(self, c + Vector3(0, 30.5, 7.0), Color("ffe6c0"), 4.0, 30.0)
