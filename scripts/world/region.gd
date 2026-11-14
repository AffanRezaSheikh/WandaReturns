## Region: base class for every 3D region. Subclasses override build() and use
## the helpers here for sky/fog/sun, portals and shared prop recipes.
extends Node3D

const B := preload("res://scripts/world/builder.gd")
const RIFT := preload("res://assets/shaders/rift.gdshader")

var region_id: StringName
var display_name := ""
var subtitle := ""
var spawns: Dictionary = {}     # id -> [Vector3 position, float yaw]
var shots: Array = []           # [[camera position, look-at target], ...]
var kill_y := -40.0
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var _spinners: Array = []       # [[node, axis, speed], ...]
var _floaters: Array = []       # [[node, base_y, amp, speed, phase], ...]
var _t := 0.0


func _ready() -> void:
	rng.seed = hash(String(region_id))
	noise.seed = int(rng.seed % 100000)
	noise.frequency = 0.02
	build()


func build() -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	for s: Array in _spinners:
		(s[0] as Node3D).rotate(s[1], s[2] * delta)
	for f: Array in _floaters:
		(f[0] as Node3D).position.y = f[1] + sin(_t * f[3] + f[4]) * f[2]


func spin(n: Node3D, axis: Vector3, speed: float) -> void:
	_spinners.append([n, axis.normalized(), speed])


func bob(n: Node3D, amp := 0.3, speed := 1.0) -> void:
	_floaters.append([n, n.position.y, amp, speed, rng.randf() * TAU])


func rnd(a: float, b: float) -> float:
	return rng.randf_range(a, b)


func setup_env(top: Color, horizon: Color, fog: Color, fog_density: float, ambient: float,
		sun_col: Color, sun_energy: float, sun_deg: Vector3, vol := 0.0, ssr := false) -> Environment:
	var env := Environment.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = top
	sm.sky_horizon_color = horizon
	sm.sky_curve = 0.1
	sm.ground_bottom_color = top.darkened(0.4)
	sm.ground_horizon_color = horizon
	sm.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = horizon.lerp(Color.WHITE, 0.45)
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.95
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = fog_density
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.2
	env.ssao_enabled = true
	env.ssr_enabled = ssr
	if vol > 0.0:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = vol
		env.volumetric_fog_albedo = fog
		env.volumetric_fog_length = 90.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = sun_col
	sun.light_energy = sun_energy
	sun.rotation_degrees = sun_deg
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.light_volumetric_fog_energy = 2.0
	add_child(sun)
	return env


## A chaos rift the player walks into to travel to another region.
func portal(pos: Vector3, target: StringName, target_spawn: StringName, tint := Color(1.0, 0.15, 0.25), label := "") -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var q := QuadMesh.new()
	q.size = Vector2(4.2, 5.4)
	var m := ShaderMaterial.new()
	m.shader = RIFT
	m.set_shader_parameter("tint", tint)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position.y = 2.6
	root.add_child(mi)
	_billboards.append(mi)
	for i in 5:
		var a := i * TAU / 5.0
		var shard := B.cyl(root, 0.0, 0.22, 1.1, Vector3(cos(a) * 2.2, 0.55, sin(a) * 2.2), B.glow(Color(tint.r, tint.g, tint.b), 2.5), false, 4)
		shard.rotation = Vector3(rnd(-0.3, 0.3), rnd(0, TAU), rnd(-0.3, 0.3))
	B.omni(root, Vector3(0, 2.4, 0), Color(tint.r, tint.g, tint.b), 3.0, 12.0)
	B.motes(root, Vector3(0, 2.5, 0), Vector3(1.6, 2.4, 1.6), Color(tint.r, tint.g, tint.b), 40, 2.0, Vector3(0, 0.8, 0), 0.1)
	if label != "":
		var l := Label3D.new()
		l.text = label
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 64
		l.outline_size = 16
		l.pixel_size = 0.008
		l.modulate = Color(1.0, 0.92, 0.85)
		l.position.y = 6.2
		root.add_child(l)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.5
	cs.shape = s
	cs.position.y = 1.4
	area.add_child(cs)
	root.add_child(area)
	area.body_entered.connect(func(body: Node) -> void:
		if body.is_in_group(&"player") and (Game.missions == null or not Game.missions.active):
			SceneManager.go_to(target, target_spawn))


var _billboards: Array[MeshInstance3D] = []


func _physics_process(_d: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for b in _billboards:
		var to := cam.global_position - b.global_position
		b.rotation.y = atan2(to.x, to.z)


# ------------------------------------------------------------- shared recipes
func tree(pos: Vector3, h: float, trunk: Material, leaves: Array, conifer := false, glint: Material = null) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rnd(0, TAU)
	add_child(n)
	var r := h * 0.055 + 0.08
	B.cyl(n, r * 0.6, r * 1.25, h * 0.6, Vector3(0, h * 0.3, 0), trunk, true, 6)
	if conifer:
		for i in 3:
			var cr := h * (0.3 - i * 0.07)
			B.cyl(n, 0.0, cr, h * 0.36, Vector3(0, h * (0.5 + i * 0.2), 0), leaves[i % leaves.size()], false, 7)
	else:
		for i in 4:
			var cr := h * rnd(0.16, 0.26)
			var off := Vector3(rnd(-1, 1), rnd(-0.3, 0.6), rnd(-1, 1)) * h * 0.14
			B.ball(n, cr, Vector3(0, h * 0.72, 0) + off, leaves[i % leaves.size()], Vector3(1, rnd(0.65, 0.9), 1), false, 7)
			if glint and rng.randf() < 0.5:
				B.ball(n, 0.12, Vector3(0, h * 0.72, 0) + off + Vector3(rnd(-1, 1), rnd(-0.5, 0.5), rnd(-1, 1)).normalized() * cr * 0.95, glint, Vector3.ONE, false, 5)
	return n


func bare_tree(pos: Vector3, h: float, m: Material) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rnd(0, TAU)
	add_child(n)
	B.cyl(n, h * 0.03, h * 0.07, h * 0.6, Vector3(0, h * 0.3, 0), m, true, 5)
	for i in 5:
		var br := B.cyl(n, 0.02, h * 0.03, h * 0.45, Vector3.ZERO, m, false, 4)
		br.rotation = Vector3(rnd(0.5, 1.1), i * TAU / 5.0 + rnd(-0.3, 0.3), 0)
		br.position = Vector3(0, h * rnd(0.45, 0.62), 0) + br.basis.y * h * 0.2


func rock(pos: Vector3, r: float, m: Material, solid := true) -> MeshInstance3D:
	var mi := B.ball(self, r, pos + Vector3(0, r * 0.3, 0), m, Vector3.ONE, solid, 6)
	mi.rotation = Vector3(rnd(0, TAU), rnd(0, TAU), rnd(0, TAU))
	return mi


func crystal(parent: Node3D, pos: Vector3, h: float, m: Material, n := 3, solid := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	for i in n:
		var hh := h * (1.0 if i == 0 else rnd(0.4, 0.75))
		var c := B.cyl(root, 0.0, hh * 0.16, hh, Vector3.ZERO, m, solid and i == 0, 5)
		var tilt := Vector3(rnd(-0.35, 0.35), rnd(0, TAU), rnd(-0.35, 0.35)) if i > 0 else Vector3(rnd(-0.1, 0.1), rnd(0, TAU), rnd(-0.1, 0.1))
		c.rotation = tilt
		c.position = (Vector3(rnd(-1, 1), 0, rnd(-1, 1)) * h * 0.18 if i > 0 else Vector3.ZERO) + c.basis.y * hh * 0.5
	return root


func lantern(pos: Vector3, lit: bool, col := Color("f0b04a"), post := Color("463b52")) -> void:
	var pm := B.mat(post, 0.8)
	B.cyl(self, 0.06, 0.09, 2.6, pos + Vector3(0, 1.3, 0), pm, true, 6)
	B.box(self, Vector3(0.42, 0.5, 0.42), pos + Vector3(0, 2.85, 0), B.glow(col, 3.5) if lit else B.mat(Color("1a0b22"), 0.5), false)
	B.cyl(self, 0.0, 0.36, 0.3, pos + Vector3(0, 3.25, 0), pm, false, 4)
	if lit:
		B.omni(self, pos + Vector3(0, 2.9, 0), col, 2.2, 11.0)


func figure(pos: Vector3, m: Material, yaw: float, pose := 0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	B.cyl(n, 0.2, 0.34, 1.25, Vector3(0, 0.62, 0), m, true, 7)
	B.ball(n, 0.17, Vector3(0, 1.48, 0), m, Vector3.ONE, false, 7)
	for sx: float in [-1.0, 1.0]:
		var a := B.cyl(n, 0.055, 0.05, 0.62, Vector3.ZERO, m, false, 5)
		var raise := (2.4 if pose == 2 else (1.5 if (pose == 0 and sx > 0) else 0.25))
		a.rotation = Vector3(-0.3 if pose == 1 else 0.0, 0, sx * raise)
		a.position = Vector3(sx * 0.24, 1.2, 0) - a.basis.y * 0.3
