## Leonia, New Jersey (stylized): the open-world town where the story plays.
## Broad Avenue runs north-south, Fort Lee Road east-west; Overpeck Park to the
## west, the cemetery in the south-east, Manhattan across the Hudson to the east.
extends "res://scripts/world/region.gd"

const DayNight := preload("res://scripts/leonia/day_night.gd")
const Car := preload("res://scripts/leonia/car.gd")
const TrafficCar := preload("res://scripts/leonia/traffic_car.gd")
const Citizen := preload("res://scripts/leonia/citizen.gd")
const Missions := preload("res://scripts/story/missions.gd")
const ROADS: Array[float] = [-160.0, -80.0, 0.0, 80.0, 160.0]
const CENTRES: Array[float] = [-120.0, -40.0, 40.0, 120.0]
const RW := 5.0                      # half road width
const WALLS := ["e8dcc4", "c9d6e0", "d8c8a8", "b8c8b0", "e0c0b0", "c8b8d0", "f0e0b8"]
const ROOFS := ["6a4038", "4a5568", "5a4a40", "3c4a3c", "704848"]
const SHOPS := ["BROAD AVE DELI", "LEONIA BOOKS", "MOORE'S HARDWARE", "PALISADE DINER", "OVERPECK RECORDS", "SAL'S PIZZA",
	"CORNER PHARMACY", "FORT LEE BAKERY", "HUDSON CLEANERS", "THE TOY CHEST", "LEONIA FLORIST", "BARBER SHOP"]
# landmarks other systems use
const P_SPAWN := Vector3(40, 0.3, -16)
const P_HALL := Vector3(-40, 0.2, -27)
const P_CAR := Vector3(24, 0.4, -2.6)
const P_HOME := Vector3(112, 0.2, -93)
const P_GATE := Vector3(92, 0.2, 120)
const P_CRYPT := Vector3(132, 0.2, 120)

var day: Node
var car: CharacterBody3D
var missions: Node
var life: Node3D
var folk: Node3D
var _win: ShaderMaterial
var _lamp: ShaderMaterial
var _shop_i := 0
var _blocks: Array = []
var _pois: Array = []


func _init() -> void:
	display_name = "LEONIA"
	subtitle = "New Jersey  ·  across the river from everything"


func build() -> void:
	var env := setup_env(DayNight.DAY_TOP, DayNight.DAY_HOR, Color("c8dcf0"), 0.0016, 1.0, Color("fff2d8"), 1.4, Vector3(-55, 40, 0))
	env.fog_sky_affect = 0.0
	_win = B.mat(Color("f8e0a0"), 0.5, 0.0, Color("ffd070"), 0.011)
	_lamp = B.mat(Color("fff0c0"), 0.5, 0.0, Color("ffe6a0"), 0.012)
	day = DayNight.new()
	day.env = env
	day.sky = (env.sky.sky_material as ProceduralSkyMaterial)
	for c in get_children():
		if c is DirectionalLight3D:
			day.sun = c
	day.glow_mats = [[_win, 2.4], [_lamp, 4.0]]
	add_child(day)
	_ground()
	_roads()
	for i in 4:
		for j in 4:
			_block(i, j)
	_lamps()
	_street_trees()
	_skyline()
	day.apply(Game.time_of_day)
	life = Node3D.new()
	add_child(life)
	folk = Node3D.new()
	add_child(folk)
	_traffic()
	_townspeople()
	car = Car.new()
	add_child(car)
	car.global_position = P_CAR
	car.rotation.y = -PI / 2
	portal(Vector3(40, 0, -24), &"library", &"from_leonia", Color(1.0, 0.75, 0.3), "The Library")
	spawns[&"start"] = [P_SPAWN, PI]
	shots = [[Vector3(8, 16, 30), Vector3(0, 2, -60)], [Vector3(96, 9, -78), Vector3(114, 3, -106)], [Vector3(78, 10, 104), P_CRYPT + Vector3(0, 3, 0)],
		[Vector3(190, 30, -40), Vector3(700, 60, 0)]]
	missions = Missions.new()
	missions.town = self
	add_child(missions)
	Game.missions = missions


func _exit_tree() -> void:
	if Game.missions == missions:
		Game.missions = null


func on_enter() -> void:
	var roads: Array = []
	for r in ROADS:
		roads.append(Rect2(r - RW, -210, RW * 2, 420))
		roads.append(Rect2(-210, r - RW, 420, RW * 2))
	Game.hud.map_data = {"half": 215.0, "roads": roads, "blocks": _blocks, "pois": _pois}
	Game.hud.clock_on = true
	missions.begin()


# ------------------------------------------------------------------ ground & roads
func _ground() -> void:
	B.box(self, Vector3(430, 2, 430), Vector3(0, -1, 0), B.mat(Color("4f8a4a"), 1.0))
	for s: float in [-1.0, 1.0]:
		B.wall(self, Vector3(2, 80, 440), Vector3(s * 213, 30, 0))
		B.wall(self, Vector3(440, 80, 2), Vector3(0, 30, s * 213))
	B.box(self, Vector3(40, 60, 430), Vector3(235, -31, 0), B.mat(Color("6a5d52"), 1.0), false)          # the Palisades
	var water := PlaneMesh.new()
	water.size = Vector2(900, 1400)
	var wm := MeshInstance3D.new()
	wm.mesh = water
	wm.material_override = B.glass(Color("1c4a6a"))
	wm.position = Vector3(680, -34, 0)
	add_child(wm)
	for i in 60:                                              # woods ringing the town
		var a := i * TAU / 60.0
		var p := Vector3(cos(a) * 205.0, 0, sin(a) * 205.0)
		if p.x < 195.0:
			tree(Vector3(clampf(p.x, -209, 209), -0.2, clampf(p.z, -209, 209)), rnd(9, 15), B.mat(Color("5a4636")), [B.mat(Color("3a7a40")), B.mat(Color("2f6838"))], i % 3 == 0)


func _roads() -> void:
	var asphalt := B.mat(Color("3c3a44"), 0.95)
	var walk := B.mat(Color("b4b0b8"), 0.9)
	var line := B.mat(Color("e8c84a"), 0.8)
	for r in ROADS:
		B.box(self, Vector3(RW * 2, 0.04, 420), Vector3(r, 0.02, 0), asphalt, false)
		B.box(self, Vector3(420, 0.04, RW * 2), Vector3(0, 0.025, r), asphalt, false)
		B.box(self, Vector3(0.25, 0.02, 420), Vector3(r, 0.05, 0), line, false)
		B.box(self, Vector3(420, 0.02, 0.25), Vector3(0, 0.055, r), line, false)
	for cx in CENTRES:                                        # sidewalks frame every block
		for cz in CENTRES:
			for s: float in [-1.0, 1.0]:
				B.box(self, Vector3(70, 0.08, 3), Vector3(cx, 0.04, cz + s * 33.5), walk, false)
				B.box(self, Vector3(3, 0.08, 70), Vector3(cx + s * 33.5, 0.04, cz), walk, false)


func _lamps() -> void:
	var post := B.mat(Color("2c3038"), 0.6, 0.5)
	for r in ROADS:
		for k in range(-4, 5):
			var t := k * 40.0 + 20.0
			if absf(t) > 190.0:
				continue
			for horizontal in [true, false]:
				var p := Vector3(t, 0, r + 6.6) if horizontal else Vector3(r + 6.6, 0, t)
				B.cyl(self, 0.07, 0.1, 5.0, p + Vector3(0, 2.5, 0), post, false, 6)
				var arm_off := Vector3(0, 0, -1.0) if horizontal else Vector3(-1.0, 0, 0)
				B.box(self, Vector3(0.5, 0.16, 0.5) + arm_off.abs() * 1.0, p + Vector3(0, 5.0, 0) + arm_off * 0.6, post, false)
				B.box(self, Vector3(0.36, 0.1, 0.36), p + Vector3(0, 4.9, 0) + arm_off * 1.0, _lamp, false)
				var l := B.omni(self, p + Vector3(0, 4.6, 0) + arm_off * 1.0, Color("ffe2a0"), 2.6, 15.0)
				l.distance_fade_enabled = true
				l.distance_fade_begin = 70.0
				l.distance_fade_length = 25.0
				day.lights.append(l)


func _street_trees() -> void:
	var trunk := B.mat(Color("5a4636"), 1.0)
	var greens := [B.mat(Color("4a9a50")), B.mat(Color("3a8444")), B.mat(Color("62b060")), B.mat(Color("e8a040"))]
	for cx in CENTRES:
		for cz in CENTRES:
			for s: float in [-1.0, 1.0]:
				for k: float in [-20.0, 4.0, 24.0]:
					tree(Vector3(cx + k + 6.0, 0, cz + s * 30.5), rnd(5.5, 8.0), trunk, greens)


# ------------------------------------------------------------------ blocks
func _block(i: int, j: int) -> void:
	var c := Vector3(CENTRES[i], 0, CENTRES[j])
	var rect := Rect2(c.x - 32, c.z - 32, 64, 64)
	if i == 0 and j <= 1:
		_blocks.append([rect, Color(0.2, 0.42, 0.24)])
		_park(c, j)
	elif i == 3 and j == 3:
		_blocks.append([rect, Color(0.3, 0.33, 0.36)])
		_cemetery(c)
	else:
		_blocks.append([rect, Color(0.24, 0.3, 0.26) if (i == 0 or i == 3) else Color(0.36, 0.32, 0.27)])
		var skip: Array = []
		if i == 1 and j == 1:
			_civic(c + Vector3(0, 0, -8), "LEONIA BOROUGH HALL", Color("ece4d4"), true)
			_pois.append([Vector2(c.x, c.z), "Borough Hall", Color("f4ead8")])
			skip = [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0)]
		elif i == 2 and j == 1:
			_civic(c + Vector3(6, 0, -8), "LEONIA PUBLIC LIBRARY", Color("a8523c"), false)
			_pois.append([Vector2(c.x, c.z), "Public Library", Color("f0b04a")])
			skip = [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0)]
		elif i == 3 and j == 0:
			_home(Vector3(112, 0, -108))
			_pois.append([Vector2(112, -108), "Home", Color("e8374a")])
			skip = [Vector2(0, 1)]
		elif i == 1 and j == 2:
			_church(c + Vector3(-4, 0, 6))
			skip = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0)]
		for f: Vector2 in [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)]:
			if skip.has(f):
				continue
			var t := Vector2(-f.y, f.x)
			var on_broad := (i == 1 and f.x > 0.5) or (i == 2 and f.x < -0.5)
			var offs: Array = [-21.0, 0.0, 21.0] if (absf(f.y) > 0.5 or on_broad) else [0.0]
			for o: float in offs:
				var p2 := Vector2(c.x, c.z) + f * (20.0 if not on_broad else 23.0) + t * o
				if on_broad:
					_shop(Vector3(p2.x, 0, p2.y), atan2(-f.x, -f.y))
				else:
					_house(Vector3(p2.x, 0, p2.y), atan2(-f.x, -f.y))


func _root(pos: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	return n


func _sign(parent: Node3D, text: String, pos: Vector3, size := 48, col := Color("fff6e6")) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 12
	l.pixel_size = 0.012
	l.modulate = col
	l.position = pos
	l.rotation.y = PI
	parent.add_child(l)


func _house(pos: Vector3, yaw: float, wall_col := "", roof_col := "", scale_ := 1.0) -> Node3D:
	var n := _root(pos, yaw)
	var w := 9.0 * scale_
	var d := 8.0 * scale_
	var h := 5.4 * scale_
	var wall := B.mat(Color(wall_col if wall_col != "" else WALLS[rng.randi() % WALLS.size()]), 0.9)
	var roof := B.mat(Color(roof_col if roof_col != "" else ROOFS[rng.randi() % ROOFS.size()]), 0.85)
	var trim := B.mat(Color("f4f0e8"), 0.8)
	B.box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall)
	B.prism(n, Vector3(w + 1.0, 2.8 * scale_, d + 1.0), Vector3(0, h + 1.4 * scale_, 0), roof)
	B.box(n, Vector3(0.9, 2.2, 0.9), Vector3(w * 0.28, h + 1.9 * scale_, 1.0), B.mat(Color("8a4a3a"), 0.9), false)
	B.box(n, Vector3(1.15, 2.15, 0.16), Vector3(-1.6, 1.08, -d * 0.5 - 0.04), B.mat(Color("5a3020"), 0.7), false)
	B.box(n, Vector3(4.2, 0.3, 1.8), Vector3(-1.6, 0.15, -d * 0.5 - 0.9), trim, false)
	B.box(n, Vector3(4.4, 0.16, 2.0), Vector3(-1.6, 2.7, -d * 0.5 - 0.9), roof, false)
	for sx: float in [-3.5, 0.3]:
		B.cyl(n, 0.08, 0.08, 2.5, Vector3(sx, 1.4, -d * 0.5 - 1.7), trim, false, 6)
	for wy: float in [1.6, 4.0]:
		for wx: float in [1.2, 3.1, -3.3]:
			if wy < 2.0 and wx < 0.0:
				continue
			B.box(n, Vector3(1.2, 1.25, 0.12), Vector3(wx, wy * scale_, -d * 0.5 - 0.03), _win, false)
			B.box(n, Vector3(1.4, 0.12, 0.16), Vector3(wx, wy * scale_ - 0.7, -d * 0.5 - 0.05), trim, false)
	B.box(n, Vector3(1.4, 0.05, 9.0), Vector3(-1.6, 0.03, -d * 0.5 - 6.0), B.mat(Color("b4b0b8"), 0.9), false)
	B.box(n, Vector3(0.12, 1.0, 0.12), Vector3(0.6, 0.5, -d * 0.5 - 9.6), trim, false)
	B.box(n, Vector3(0.5, 0.3, 0.3), Vector3(0.6, 1.1, -d * 0.5 - 9.6), B.mat(Color("3a5a8a"), 0.6), false)
	if rng.randf() < 0.6:
		B.ball(n, 0.9, Vector3(3.4, 0.6, -d * 0.5 - 1.2), B.mat(Color("3f8a48")), Vector3(1.3, 0.8, 1.0), false, 6)
	return n


func _shop(pos: Vector3, yaw: float) -> void:
	var n := _root(pos, yaw)
	var cols := ["b86a50", "c8b490", "8a9aa8", "a85a48", "d0c0a0", "7a8a6a"]
	var awn := ["c8102e", "2a6a4a", "2a4a8a", "d0a020", "7a2a6a", "d06020"]
	var k := _shop_i % SHOPS.size()
	_shop_i += 1
	B.box(n, Vector3(18, 7.5, 12), Vector3(0, 3.75, 2), B.mat(Color(cols[k % cols.size()]), 0.9))
	B.box(n, Vector3(18.4, 0.5, 12.4), Vector3(0, 7.7, 2), B.mat(Color("5a504a"), 0.9), false)
	B.box(n, Vector3(14, 2.6, 0.12), Vector3(0, 1.7, -4.03), _win, false)
	B.box(n, Vector3(1.3, 2.3, 0.14), Vector3(7.6, 1.15, -4.04), B.mat(Color("3a2a22"), 0.7), false)
	B.box(n, Vector3(17, 0.25, 2.2), Vector3(0, 3.5, -5.0), B.mat(Color(awn[k % awn.size()]), 0.8), false, Vector3(0.22, 0, 0))
	for wx: float in [-6.0, -2.0, 2.0, 6.0]:
		B.box(n, Vector3(1.6, 1.5, 0.12), Vector3(wx, 5.9, -4.03), _win, false)
	_sign(n, SHOPS[k], Vector3(0, 4.55, -4.2), 42)


func _civic(pos: Vector3, title_: String, col: Color, columns: bool) -> void:
	var n := _root(pos, 0.0)                                  # front faces +Z (south), so flip the root
	n.rotation.y = PI
	var wall := B.mat(col, 0.85)
	var trim := B.mat(Color("f4ecdc"), 0.8)
	B.box(n, Vector3(26, 9, 14), Vector3(0, 4.5, 0), wall)
	B.box(n, Vector3(27, 0.6, 15), Vector3(0, 9.3, 0), trim, false)
	B.box(n, Vector3(12, 0.5, 5), Vector3(0, 0.25, -9.0), trim, false)
	B.box(n, Vector3(10, 1.0, 3), Vector3(0, 0.5, -8.2), trim)
	if columns:
		for k in 6:
			B.cyl(n, 0.4, 0.45, 7.6, Vector3(-6.25 + k * 2.5, 4.8, -8.4), trim, false, 10)
		B.box(n, Vector3(15, 0.7, 3.4), Vector3(0, 8.9, -8.4), trim, false)
		B.prism(n, Vector3(15, 2.6, 3.4), Vector3(0, 10.5, -8.4), trim)
		B.cyl(n, 0.06, 0.06, 9.0, Vector3(11, 4.5, -12), B.mat(Color("d8dce4"), 0.3, 0.8), false, 6)
		B.box(n, Vector3(1.8, 1.1, 0.05), Vector3(11.95, 8.3, -12), B.mat(Color("b02030"), 0.8), false)
	else:
		B.prism(n, Vector3(27, 3.0, 15), Vector3(0, 11.1, 0), B.mat(Color("4a5568"), 0.85))
	B.box(n, Vector3(2.6, 3.4, 0.2), Vector3(0, 2.7, -7.05), B.mat(Color("4a3020"), 0.7), false)
	for wx: float in [-10.0, -6.5, 6.5, 10.0]:
		for wy: float in [2.6, 6.4]:
			B.box(n, Vector3(1.6, 2.2, 0.14), Vector3(wx, wy, -7.04), _win, false)
	_sign(n, title_, Vector3(0, 7.6 if not columns else 9.0, -7.3 if not columns else -10.2), 44, Color("3a2a22") if columns else Color("fff6e6"))


func _church(pos: Vector3) -> void:
	var n := _root(pos, 0.0)
	var white := B.mat(Color("f0ece4"), 0.85)
	B.box(n, Vector3(12, 8, 22), Vector3(0, 4, 0), white)
	B.prism(n, Vector3(13, 4.5, 23), Vector3(0, 10.2, 0), B.mat(Color("4a5568"), 0.85))
	B.box(n, Vector3(5, 16, 5), Vector3(0, 8, -12.5), white)
	B.cyl(n, 0.0, 3.6, 9.0, Vector3(0, 20.5, -12.5), B.mat(Color("4a5568"), 0.85), false, 4, Vector3(0, PI / 4, 0))
	B.box(n, Vector3(2.2, 3.4, 0.2), Vector3(0, 1.7, -15.05), B.mat(Color("5a3020"), 0.7), false)
	B.box(n, Vector3(1.6, 2.6, 0.14), Vector3(0, 11.5, -15.04), _win, false)
	_pois.append([Vector2(pos.x, pos.z), "Church", Color("c4b8bd")])


func _home(pos: Vector3) -> void:
	# Wanda and Vision's house: yellow walls, red roof, picket fence (front faces south).
	var n := _house(pos, PI, "f0d060", "b02a2a", 1.25)
	var fence := B.mat(Color("f8f4ec"), 0.8)
	for k in 14:
		for s: float in [-1.0, 1.0]:
			if absf(k - 6.5) < 1.5 and s < 0.0:
				continue
			B.box(self, Vector3(0.16, 1.0, 0.16), pos + Vector3(-13 + k * 2.0, 0.5, 15.0 * s if s < 0 else -9.0), fence, false)
	B.box(self, Vector3(27, 0.12, 0.1), pos + Vector3(0, 0.75, -9.0), fence, false)
	tree(pos + Vector3(-9, 0, 9), 9.0, B.mat(Color("5a4636")), [B.mat(Color("4a9a50")), B.mat(Color("e8a040"))])
	var sign_ := _root(pos + Vector3(8, 0, 12.5), PI)
	B.box(sign_, Vector3(0.12, 1.6, 0.12), Vector3(0, 0.8, 0), fence, false)
	B.box(sign_, Vector3(1.6, 0.9, 0.08), Vector3(0, 1.5, 0), B.mat(Color("f4ead8"), 0.8), false)
	_sign(sign_, "FOR SALE", Vector3(0, 1.5, -0.06), 26, Color("b02030"))
	n.set_meta(&"home", true)


func _park(c: Vector3, j: int) -> void:
	var trunk := B.mat(Color("5a4636"), 1.0)
	var greens := [B.mat(Color("4a9a50")), B.mat(Color("3a8444")), B.mat(Color("62b060")), B.mat(Color("d87a30"))]
	B.box(self, Vector3(64, 0.06, 64), c + Vector3(0, 0.03, 0), B.mat(Color("5aa054"), 1.0), false)
	B.box(self, Vector3(3, 0.05, 60), c + Vector3(6, 0.07, 0), B.mat(Color("c8b89a"), 0.95), false)
	B.box(self, Vector3(60, 0.05, 3), c + Vector3(0, 0.07, 8), B.mat(Color("c8b89a"), 0.95), false)
	if j == 0:
		B.cyl(self, 13.0, 13.0, 0.1, c + Vector3(-12, 0.06, -8), B.glass(Color("2a6a8a")), false, 20)
		_pois.append([Vector2(c.x, c.z + 40), "Overpeck Park", Color("7ad080")])
		var g := _root(c + Vector3(16, 0, -14), 0.0)        # bandstand
		B.cyl(g, 4.5, 4.5, 0.5, Vector3(0, 0.25, 0), B.mat(Color("e8e0d0"), 0.9), true, 8)
		for k in 8:
			B.cyl(g, 0.12, 0.12, 3.2, Vector3(cos(k * TAU / 8) * 4.0, 2.1, sin(k * TAU / 8) * 4.0), B.mat(Color("f4f0e8")), false, 6)
		B.cyl(g, 0.0, 5.2, 2.2, Vector3(0, 4.8, 0), B.mat(Color("b02a2a"), 0.85), false, 8)
	for k in 26:
		var p := c + Vector3(rnd(-29, 29), 0, rnd(-29, 29))
		if absf(p.x - c.x - 6) < 3.0 or absf(p.z - c.z - 8) < 3.0 or (j == 0 and p.distance_to(c + Vector3(-12, 0, -8)) < 15.0):
			continue
		tree(p, rnd(6, 11), trunk, greens, k % 5 == 0)
	for k in 5:
		var b := _root(c + Vector3(8.2, 0, -24 + k * 12.0), PI / 2)
		B.box(b, Vector3(2.2, 0.12, 0.6), Vector3(0, 0.5, 0), B.mat(Color("7a5a3a"), 0.9))
		B.box(b, Vector3(2.2, 0.6, 0.1), Vector3(0, 0.85, 0.3), B.mat(Color("7a5a3a"), 0.9), false)


func _cemetery(c: Vector3) -> void:
	B.box(self, Vector3(64, 0.06, 64), c + Vector3(0, 0.03, 0), B.mat(Color("3e5a44"), 1.0), false)
	B.box(self, Vector3(36, 0.05, 4), c + Vector3(-12, 0.07, 0), B.mat(Color("8a8478"), 0.95), false)
	var iron := B.mat(Color("1c1c24"), 0.5, 0.6)
	var stone := B.mat(Color("9a96a0"), 0.95)
	for k in 33:                                              # iron fence with a west gate
		var t := -32.0 + k * 2.0
		for s: float in [-1.0, 1.0]:
			B.box(self, Vector3(0.14, 2.2, 0.14), c + Vector3(t, 1.1, s * 32.0), iron, false)
			if not (s < 0.0 and absf(t) < 4.0):
				B.box(self, Vector3(0.14, 2.2, 0.14), c + Vector3(s * 32.0, 1.1, t), iron, false)
	for s: float in [-1.0, 1.0]:
		B.box(self, Vector3(64, 0.12, 0.1), c + Vector3(0, 1.9, s * 32.0), iron, false)
		B.wall(self, Vector3(64, 4, 0.4), c + Vector3(0, 2, s * 32.0))
		B.wall(self, Vector3(0.4, 4, 26), c + Vector3(-32, 2, s * 19.0))
		B.box(self, Vector3(1.0, 3.6, 1.0), c + Vector3(-32, 1.8, s * 4.6), stone)
	B.wall(self, Vector3(0.4, 4, 64), c + Vector3(32, 2, 0))
	for gx in 6:
		for gz in 6:
			if absf(gz - 2.5) < 1.0:
				continue
			var p := c + Vector3(-24 + gx * 6.0 + rnd(-0.6, 0.6), 0, -27 + gz * 10.5 + rnd(-0.8, 0.8))
			if p.x > c.x + 2.0 and absf(p.z - c.z) < 14.0:
				continue                                      # keep the arena before the crypt clear
			if (gx + gz) % 3 == 0:
				B.box(self, Vector3(0.25, 1.6, 0.2), p + Vector3(0, 0.8, 0), stone, true, Vector3(0, 0, rnd(-0.08, 0.08)))
				B.box(self, Vector3(0.9, 0.22, 0.2), p + Vector3(0, 1.15, 0), stone, false)
			else:
				B.box(self, Vector3(0.9, 1.1, 0.25), p + Vector3(0, 0.55, 0), stone, true, Vector3(rnd(-0.06, 0.06), PI / 2, 0))
	var char_m := B.mat(Color("2a2430"), 1.0)
	for k in 7:
		bare_tree(c + Vector3(rnd(-28, 28), 0, (-1.0 if k % 2 == 0 else 1.0) * rnd(18, 29)), rnd(6, 9), char_m)
	var cr := _root(c + Vector3(22, 0, 0), -PI / 2)          # the crypt, door facing west
	var dark := B.mat(Color("6a6672"), 0.95)
	B.box(cr, Vector3(12, 6.5, 9), Vector3(0, 3.25, 0), dark)
	B.prism(cr, Vector3(13, 3.0, 10), Vector3(0, 8.0, 0), B.mat(Color("4a4652"), 0.9))
	for sx: float in [-4.5, -1.8, 1.8, 4.5]:
		B.cyl(cr, 0.4, 0.45, 5.6, Vector3(sx, 2.8, -5.3), stone, false, 8)
	B.box(cr, Vector3(11, 0.6, 2.4), Vector3(0, 5.9, -5.3), stone, false)
	B.box(cr, Vector3(2.4, 3.6, 0.2), Vector3(0, 1.8, -4.55), B.mat(Color("0d0612"), 0.4), false)
	B.omni(cr, Vector3(0, 2.5, -6.5), Color("60ff90"), 2.5, 14.0)
	B.motes(self, c + Vector3(0, 1.0, 0), Vector3(30, 1.0, 30), Color("a0ffc0"), 120, 6.0, Vector3(0.2, 0.1, 0.1), 0.1)
	_pois.append([Vector2(c.x, c.z), "Cemetery", Color("a0ffc0")])


func _skyline() -> void:
	var tower := B.mat(Color("2a3450"), 0.8)
	var tower2 := B.mat(Color("3a4666"), 0.8)
	for i in 70:
		var z := rnd(-620, 620)
		var hgt := rnd(60, 190) * (1.6 if absf(z) < 180.0 and i % 4 == 0 else 1.0)
		var w := rnd(18, 38)
		var p := Vector3(rnd(880, 1060), hgt * 0.5 - 34.0, z)
		B.box(self, Vector3(w, hgt, w), p, tower if i % 2 == 0 else tower2, false)
		B.box(self, Vector3(0.6, hgt * 0.8, w * 0.7), p + Vector3(-w * 0.5 - 0.4, 0, 0), _win, false)
		if i % 9 == 0:
			B.cyl(self, 0.0, w * 0.25, hgt * 0.3, p + Vector3(0, hgt * 0.65, 0), tower2, false, 4)
	var steel := B.mat(Color("7a8a9a"), 0.5, 0.6)             # the bridge to the north-east
	B.box(self, Vector3(700, 3, 16), Vector3(560, 6, -330), steel, false)
	for bx: float in [380.0, 720.0]:
		B.box(self, Vector3(8, 130, 20), Vector3(bx, 30, -330), steel, false)
	for k in 24:
		B.box(self, Vector3(0.5, 60 - absf(k - 11.5) * 4.0, 0.5), Vector3(390 + k * 14.0, 36 - absf(k - 11.5) * 2.0, -330), steel, false)


# ------------------------------------------------------------------ life
func _loop(x0: float, z0: float, x1: float, z1: float, inset: float) -> Array[Vector3]:
	var a: Array[Vector3] = [Vector3(x0 + inset, 0.06, z0 + inset), Vector3(x1 - inset, 0.06, z0 + inset),
		Vector3(x1 - inset, 0.06, z1 - inset), Vector3(x0 + inset, 0.06, z1 - inset)]
	return a


func _traffic() -> void:
	var cols := ["3a6a8c", "d8d0c0", "2f5a3d", "8a8d9c", "d0a020", "20242c", "7a2a2a", "4a7aa8"]
	var loops := [[-80, -80, 80, 80], [-160, -160, 0, 0], [0, -160, 160, 0], [-160, 0, 0, 160], [0, 0, 160, 160], [-80, -160, 80, -80], [-160, -80, 160, 80], [-80, 0, 80, 160]]
	for k in loops.size():
		var l: Array = loops[k]
		var t := TrafficCar.new()
		t.path = _loop(l[0], l[1], l[2], l[3], 2.5)
		for q in t.path.size():
			t.path[q].y = 0.05
		t.color = Color(cols[k % cols.size()])
		t.cruise = rnd(7.5, 11.0)
		t.add_to_group(&"traffic")
		life.add_child(t)
		t.global_position = t.path[0].lerp(t.path[1], rnd(0.1, 0.9))


func _townspeople() -> void:
	var moods := ["fan", "wary", "kid", "calm", "calm", "fan", "wary", "calm"]
	var n := 0
	for i in 4:
		for j in 4:
			if i == 3 and j == 3:
				continue
			var cx := CENTRES[i]
			var cz := CENTRES[j]
			for k in (3 if (i == 1 or i == 2) else 2):
				var c := Citizen.new()
				c.path = _loop(cx - 40, cz - 40, cx + 40, cz + 40, 6.5)
				c.dir = 1 if k % 2 == 0 else -1
				c.mood = moods[n % moods.size()]
				n += 1
				folk.add_child(c)
	var spots := [Vector3(8.5, 0.06, -52), Vector3(-8.5, 0.06, 30), Vector3(34, 0.06, -12), Vector3(-34, 0.1, -20), Vector3(-111, 0.1, -32), Vector3(8.5, 0.06, 62)]
	for k in spots.size():
		var a := Citizen.new()
		var b := Citizen.new()
		a.mood = "calm"
		b.mood = "wary" if k % 2 == 0 else "fan"
		folk.add_child(a)
		folk.add_child(b)
		a.global_position = spots[k]
		b.global_position = spots[k] + Vector3(1.5, 0, 0.4)
		a.partner = b
		b.partner = a
		a.chat_lead = true
		a.chat = Citizen.CHATS[k % Citizen.CHATS.size()]


func _process(delta: float) -> void:
	super(delta)
	if folk:                                                  # the town goes indoors at night
		var home: bool = day.night > 0.7
		if folk.visible == home:
			folk.visible = not home
			folk.process_mode = Node.PROCESS_MODE_DISABLED if home else Node.PROCESS_MODE_INHERIT
