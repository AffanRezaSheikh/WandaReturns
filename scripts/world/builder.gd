## Builder: static helpers that assemble low-poly world geometry in code
## (materials, primitive meshes with colliders, lights, particles, terrain).
extends RefCounted

const SHADER := preload("res://assets/shaders/lowpoly.gdshader")
static var _cache: Dictionary = {}


static func mat(color: Color, rough := 0.9, metal := 0.0, emit := Color.BLACK, energy := 0.0, flat := true) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f|%s|%.2f|%s" % [color.to_html(), rough, metal, emit.to_html(), energy, flat]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("emission", emit)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("flat_shade", flat)
	_cache[key] = m
	return m


static func glow(color: Color, energy := 2.0) -> ShaderMaterial:
	return mat(color, 0.6, 0.0, color, energy)


static func glass(color: Color, alpha := 1.0, emit := 0.0) -> StandardMaterial3D:
	var key := "glass|%s|%.2f|%.2f" % [color.to_html(), alpha, emit]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.metallic = 0.85
	m.roughness = 0.08
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	_cache[key] = m
	return m


static func _place(p: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func _body(mi: Node3D, shape: Shape3D) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	mi.add_child(b)


static func box(p: Node3D, size: Vector3, pos: Vector3, m: Material, solid := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _place(p, bm, m, pos, rot)
	if solid:
		var s := BoxShape3D.new()
		s.size = size
		_body(mi, s)
	return mi


static func cyl(p: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, solid := false, sides := 7, rot := Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	var mi := _place(p, cm, m, pos, rot)
	if solid:
		var s := CylinderShape3D.new()
		s.radius = maxf(r_top, r_bot)
		s.height = h
		_body(mi, s)
	return mi


static func ball(p: Node3D, r: float, pos: Vector3, m: Material, scl := Vector3.ONE, solid := false, segs := 7) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = maxi(3, segs / 2)
	var mi := _place(p, sm, m, pos, Vector3.ZERO)
	mi.scale = scl
	if solid:
		var s := SphereShape3D.new()
		s.radius = r
		_body(mi, s)
	return mi


static func prism(p: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var pm := PrismMesh.new()
	pm.size = size
	return _place(p, pm, m, pos, rot)


static func torus(p: Node3D, inner: float, outer: float, pos: Vector3, m: Material, rot := Vector3.ZERO, segs := 24) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = segs
	tm.ring_segments = 6
	return _place(p, tm, m, pos, rot)


static func wall(p: Node3D, size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	b.add_child(cs)
	b.position = pos
	p.add_child(b)


static func omni(p: Node3D, pos: Vector3, color: Color, energy := 1.5, rng := 8.0, shadows := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.position = pos
	p.add_child(l)
	return l


## Drifting glowing motes (embers, spores, pages, sand). vel = base drift.
static func motes(p: Node3D, pos: Vector3, extents: Vector3, color: Color, amount: int, life: float, vel: Vector3, size := 0.08, spread := 0.5) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.amount = amount
	c.lifetime = life
	c.preprocess = life
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	c.emission_box_extents = extents
	c.direction = vel.normalized() if vel.length() > 0.001 else Vector3.UP
	c.spread = 25.0
	c.initial_velocity_min = vel.length() * (1.0 - spread)
	c.initial_velocity_max = vel.length() * (1.0 + spread)
	c.gravity = Vector3.ZERO
	c.scale_amount_min = 0.5
	c.scale_amount_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.0))
	g.add_point(0.2, color)
	g.add_point(0.8, color)
	g.set_color(g.get_point_count() - 1, Color(color.r, color.g, color.b, 0.0))
	c.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(size, size) * 2.2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.6, 1.6, 1.6)
	m.albedo_texture = _dot()
	q.material = m
	c.mesh = q
	c.position = pos
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(c)
	return c


static func _dot() -> GradientTexture2D:
	if _cache.has("dot"):
		return _cache["dot"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	_cache["dot"] = t
	return t


## Flat-shaded heightfield with vertex colours + trimesh collision.
static func terrain(p: Node3D, half: float, cells: int, hfn: Callable, cfn: Callable) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := half * 2.0 / cells
	for iz in cells:
		for ix in cells:
			var x0 := -half + ix * step
			var z0 := -half + iz * step
			var a := Vector3(x0, hfn.call(x0, z0), z0)
			var b := Vector3(x0 + step, hfn.call(x0 + step, z0), z0)
			var c := Vector3(x0, hfn.call(x0, z0 + step), z0 + step)
			var d := Vector3(x0 + step, hfn.call(x0 + step, z0 + step), z0 + step)
			var tris := [a, b, c, b, d, c] if (ix + iz) % 2 == 0 else [a, b, d, a, d, c]
			for t in 2:
				var v0: Vector3 = tris[t * 3]
				var v1: Vector3 = tris[t * 3 + 1]
				var v2: Vector3 = tris[t * 3 + 2]
				var col: Color = cfn.call((v0 + v1 + v2) / 3.0)
				for v: Vector3 in [v0, v1, v2]:
					st.set_color(col)
					st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(Color.WHITE, 1.0)
	p.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	mi.add_child(body)
	return mi
