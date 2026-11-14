## Hourglass Spire: a spiral climb around the great hourglass in a frozen sky.
extends "res://scripts/world/region.gd"

var _ivory: Material
var _gold: Material


func _init() -> void:
	display_name = "HOURGLASS SPIRE"
	subtitle = "Where time was told to stop"
	kill_y = -45.0


func build() -> void:
	setup_env(Color("05020e"), Color("5e44a8"), Color("2c2060"), 0.0035, 1.05, Color("dccfff"), 0.95, Vector3(-48, 22, 0), 0.008)
	_ivory = B.mat(Color("d8ccc4"), 0.8)
	_gold = B.mat(Color("c97a2b"), 0.3, 0.85, Color("f0b04a"), 0.55)
	_hourglass()
	_disc(Vector3(0, 0, 40), 9.0)
	# the spiral ramp: 1.6 turns, radius 36 -> 20, climbing 30 m
	var n := 72
	var prev := Vector3(0, 0, 36)
	var top := prev
	for i in range(1, n + 1):
		var t := float(i) / n
		var a := PI / 2 + t * 10.0
		var r := lerpf(36.0, 20.0, t)
		var p := Vector3(cos(a) * r, t * 30.0, sin(a) * r)
		var mid := (prev + p) * 0.5
		var seg := p - prev
		var flat := Vector2(seg.x, seg.z).length()
		var m := _ivory if i % 2 == 0 else B.mat(Color("c4b8bd"), 0.8)
		B.box(self, Vector3(3.4, 0.5, flat + 0.7), mid + Vector3(0, -0.25, 0), m, true, Vector3(-atan2(seg.y, flat), atan2(seg.x, seg.z), 0))
		if i % 6 == 0:
			var out := Vector3(cos(a), 0, sin(a))
			crystal(self, p + out * 2.3, rnd(1.5, 3.2), B.glow(Color("9a7ae0"), 1.6), 3)
			B.omni(self, p + out * 1.8 + Vector3(0, 1.5, 0), Color("9a7ae0"), 1.8, 9.0)
		if i % 18 == 0 and i < n:
			_disc(p + Vector3(cos(a), 0, sin(a)) * 4.5, 4.5)
			_pillar(p + Vector3(cos(a), 0, sin(a)) * 6.5, i % 36 == 0)
		prev = p
		top = p
	# the summit dais, an anchor and a tear in reality
	var out := Vector3(top.x, 0, top.z).normalized()
	var dais := top - out * 3.0
	_disc(dais, 8.0)
	B.cyl(self, 1.0, 1.6, 1.2, dais + Vector3(4, 0.6, 2), _ivory, true, 8)
	var orb := B.ball(self, 0.7, dais + Vector3(4, 2.3, 2), B.glow(Color("d8c8ff"), 3.0), Vector3.ONE, false, 8)
	bob(orb, 0.2, 1.4)
	B.torus(self, 1.1, 1.2, dais + Vector3(4, 2.3, 2), _gold, Vector3(0.6, 0, 0.3), 20)
	B.omni(self, dais + Vector3(4, 2.5, 2), Color("9a7ae0"), 4.0, 16.0)
	_tear(dais + Vector3(-4, 3.0, -2), 1.0)
	for i in 4:
		_tear(Vector3(rnd(-34, 34), rnd(8, 34), rnd(-34, 34)), rnd(0.6, 1.6))
	var shard := [B.glow(Color("9a7ae0"), 1.5), B.glow(Color("5a3fa0"), 1.2), B.glow(Color("ffe08a"), 1.6)]
	for i in 90:                                              # suspended time shards
		var a := rnd(0, TAU)
		var r := rnd(24, 80)
		var c := crystal(self, Vector3(cos(a) * r, rnd(-20, 56), sin(a) * r), rnd(1.0, 5.0), shard[i % 3], 2)
		c.rotation = Vector3(rnd(0, TAU), rnd(0, TAU), rnd(0, TAU))
		bob(c, rnd(0.2, 0.8), rnd(0.3, 0.9))
	for i in 18:
		var a := rnd(0, TAU)
		var r := rnd(42, 90)
		_pillar(Vector3(cos(a) * r, rnd(-25, 45), sin(a) * r), i % 2 == 0, true)
	for i in 9:                                               # impossible stair fragments
		var s := Node3D.new()
		s.position = Vector3(rnd(-60, 60), rnd(-10, 44), rnd(-60, 60))
		if Vector2(s.position.x, s.position.z).length() < 40.0:
			s.position *= 1.8
		s.rotation = Vector3(rnd(0, TAU), rnd(0, TAU), rnd(0, TAU))
		add_child(s)
		for k in 6:
			B.box(s, Vector3(3.0, 0.4, 1.1), Vector3(0, k * 0.5, k * 1.0), _ivory, false)
		spin(s, Vector3(rnd(-1, 1), 1, rnd(-1, 1)), rnd(-0.05, 0.05))
	B.motes(self, Vector3(0, 16, 0), Vector3(46, 30, 46), Color("ffd070"), 700, 8.0, Vector3(0.05, 1.6, 0.05), 0.09)
	B.motes(self, Vector3(0, 40, 0), Vector3(280, 150, 280), Color("fff6e6"), 600, 30.0, Vector3(0, 0.02, 0), 1.1, 1.0)   # frozen stars
	portal(Vector3(5.5, 0, 44.5), &"library", &"from_spire", Color(1.0, 0.7, 0.25), "The Library")
	spawns[&"start"] = [Vector3(-2, 0.5, 45), 0.0]
	spawns[&"from_archive"] = [Vector3(-2, 0.5, 45), 0.0]
	shots = [[Vector3(7, 5, 58), Vector3(0, 22, 0)], [Vector3(52, 36, 34), Vector3(0, 16, 0)]]


func _disc(pos: Vector3, r: float) -> void:
	B.cyl(self, r, r, 1.0, pos + Vector3(0, -0.5, 0), _ivory, true, 14)
	B.cyl(self, r * 0.95, 0.0, r * 0.9, pos + Vector3(0, -1.0 - r * 0.45, 0), B.mat(Color("6a5d72"), 1.0), false, 8)
	B.torus(self, r - 0.3, r + 0.08, pos + Vector3(0, 0.02, 0), _gold, Vector3.ZERO, 28)


func _pillar(pos: Vector3, broken: bool, floating := false) -> void:
	var n := Node3D.new()
	n.position = pos
	if floating:
		n.rotation = Vector3(rnd(-0.6, 0.6), rnd(0, TAU), rnd(-0.6, 0.6))
	add_child(n)
	var h := 3.2 if broken else 6.5
	B.cyl(n, 0.45, 0.5, h, Vector3(0, h * 0.5, 0), _ivory, not floating, 10)
	B.box(n, Vector3(1.4, 0.4, 1.4), Vector3(0, 0.2, 0), _ivory, false)
	if not broken:
		B.box(n, Vector3(1.4, 0.4, 1.4), Vector3(0, h, 0), _ivory, false)
	if floating:
		bob(n, 0.5, rnd(0.3, 0.7))


func _tear(pos: Vector3, s: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 5.0) * s
	var m := ShaderMaterial.new()
	m.shader = RIFT
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	_billboards.append(mi)
	B.omni(self, pos, Color("e8374a"), 2.5, 10.0)


func _hourglass() -> void:
	var glass_m := B.glass(Color("9a7ae0"), 0.38, 0.25)
	var sand := B.glow(Color("f0b04a"), 1.3)
	B.cyl(self, 1.4, 13.0, 28.0, Vector3(0, 0, 0), glass_m, false, 18)          # lower bulb
	B.cyl(self, 13.0, 1.4, 28.0, Vector3(0, 28, 0), glass_m, false, 18)         # upper bulb
	B.cyl(self, 9.5, 1.2, 15.0, Vector3(0, 22.5, 0), sand, false, 14)           # sand that never falls
	B.cyl(self, 0.0, 10.5, 9.0, Vector3(0, -9.5, 0), sand, false, 14)
	for y in 9:
		if y % 3 != 1:
			B.cyl(self, 0.22, 0.22, 1.6, Vector3(0, -3.0 + y * 2.0, 0), B.glow(Color("ffe08a"), 3.0), false, 5)
	for y: float in [-15.0, 43.0]:
		B.cyl(self, 15.0, 15.0, 1.8, Vector3(0, y, 0), _gold, true, 20)
	for i in 4:
		var a := i * PI / 2 + PI / 4
		B.cyl(self, 0.55, 0.55, 58.0, Vector3(cos(a) * 14.2, 14, sin(a) * 14.2), _gold, true, 8)
	var halo := B.torus(self, 20.0, 20.6, Vector3(0, 52, 0), B.glow(Color("d8c8ff"), 2.2), Vector3.ZERO, 48)
	spin(halo, Vector3.UP, 0.08)
	var halo2 := B.torus(self, 25.0, 25.4, Vector3(0, 52, 0), B.glow(Color("9a7ae0"), 1.6), Vector3(0.35, 0, 0.2), 48)
	spin(halo2, Vector3(0.3, 1, 0.1), -0.05)
	B.omni(self, Vector3(0, 14, 0), Color("ffd070"), 6.0, 50.0)
	B.omni(self, Vector3(0, 46, 0), Color("d8c8ff"), 5.0, 60.0)
