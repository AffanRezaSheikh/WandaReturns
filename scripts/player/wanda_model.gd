## WandaModel: code-built stand-in for Wanda (faces -Z) with procedural
## idle / walk / run / air animation and a shader-driven cape.
## Built from the character profile: long auburn-red hair, green eyes, fair skin,
## deep-crimson bodysuit, gloves, boots, red cape, two-pointed crimson headpiece.
## Replaced by the rigged Higgsfield GLB (assets/models/wanda.glb) once it exists.
extends Node3D

const B := preload("res://scripts/world/builder.gd")
const CAPE := preload("res://assets/shaders/cape.gdshader")

var hips: Node3D
var chest: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var arms: Array[Node3D] = []
var elbows: Array[Node3D] = []
var cape_mat: ShaderMaterial
var aura: OmniLight3D
var _phase := 0.0
var _t := 0.0
var _move := 0.0
var _run := 0.0
var _air := 0.0


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _ready() -> void:
	var skin := B.mat(Color("f0c8b0"), 0.7, 0.0, Color.BLACK, 0.0, false)
	var hair := B.mat(Color("a8451f"), 0.5, 0.0, Color("7a2c10"), 0.12, false)
	var suit := B.mat(Color("6e1230"), 0.5, 0.1, Color("7d1733"), 0.04, false)
	var dark := B.mat(Color("3b0a1c"), 0.45, 0.2, Color("4a0c1c"), 0.03, false)
	var crown := B.mat(Color("e02a40"), 0.35, 0.3, Color("e02a40"), 0.5)
	var eye := B.glow(Color("3fd070"), 1.6)
	hips = _pivot(self, Vector3(0, 0.9, 0))
	B.ball(hips, 0.13, Vector3.ZERO, suit, Vector3(1.0, 0.8, 0.8), false, 12)
	chest = _pivot(hips, Vector3(0, 0.05, 0))
	B.cyl(chest, 0.15, 0.105, 0.46, Vector3(0, 0.25, 0), suit, false, 12)
	B.ball(chest, 0.16, Vector3(0, 0.45, 0), suit, Vector3(1.15, 0.55, 0.75), false, 12)
	B.cyl(chest, 0.04, 0.045, 0.1, Vector3(0, 0.56, 0), skin, false, 8)
	B.cyl(chest, 0.085, 0.17, 0.07, Vector3(0, 0.5, 0.02), crown, false, 10)       # cape collar
	B.prism(chest, Vector3(0.1, 0.12, 0.02), Vector3(0, 0.4, -0.115), skin, Vector3(0, 0, PI))  # neckline
	# --- head
	head = _pivot(chest, Vector3(0, 0.63, 0))
	B.ball(head, 0.105, Vector3(0, 0.07, 0), skin, Vector3(0.95, 1.1, 1.0), false, 14)
	for sx: float in [-1.0, 1.0]:
		B.ball(head, 0.015, Vector3(sx * 0.038, 0.082, -0.096), eye, Vector3.ONE, false, 6)
		B.ball(head, 0.04, Vector3(sx * 0.105, -0.07, 0.01), hair, Vector3(0.9, 4.6, 1.1), false, 8)      # side locks
		B.cyl(head, 0.0, 0.034, 0.21, Vector3(sx * 0.088, 0.26, -0.045), crown, false, 5, Vector3(0.12, 0, -sx * 0.32))  # points
		B.box(head, Vector3(0.02, 0.1, 0.045), Vector3(sx * 0.1, 0.095, -0.03), crown, false)          # cheek guards
	B.ball(head, 0.12, Vector3(0, 0.095, 0.035), hair, Vector3(1.0, 1.02, 1.0), false, 12)                # hair cap
	for i in 5:                                                                                             # long hair down the back
		var x := (i - 2) * 0.045
		B.ball(head, 0.05, Vector3(x, -0.2, 0.1 - absf(x) * 0.25), hair, Vector3(1.0, 6.4 - absf(x) * 14.0, 0.85), false, 8)
	B.box(head, Vector3(0.2, 0.034, 0.03), Vector3(0, 0.138, -0.092), crown, false)                       # band
	B.prism(head, Vector3(0.07, 0.06, 0.025), Vector3(0, 0.105, -0.103), crown, Vector3(0, 0, PI))        # centre peak
	# --- arms
	for sx: float in [-1.0, 1.0]:
		var sh := _pivot(chest, Vector3(sx * 0.2, 0.46, 0))
		sh.rotation.z = sx * 0.12
		B.cyl(sh, 0.045, 0.04, 0.27, Vector3(0, -0.135, 0), suit, false, 8)
		var el := _pivot(sh, Vector3(0, -0.27, 0))
		B.cyl(el, 0.04, 0.034, 0.25, Vector3(0, -0.125, 0), dark, false, 8)
		B.ball(el, 0.045, Vector3(0, -0.27, 0), dark, Vector3.ONE, false, 8)
		B.ball(el, 0.028, Vector3(0, -0.32, 0), B.glow(Color("ff4055"), 3.0), Vector3.ONE, false, 6)
		arms.append(sh)
		elbows.append(el)
	# --- legs
	for sx: float in [-1.0, 1.0]:
		var th := _pivot(hips, Vector3(sx * 0.085, -0.04, 0))
		B.cyl(th, 0.078, 0.06, 0.42, Vector3(0, -0.21, 0), suit, false, 8)
		var kn := _pivot(th, Vector3(0, -0.42, 0))
		B.cyl(kn, 0.06, 0.045, 0.42, Vector3(0, -0.21, 0), dark, false, 8)
		B.box(kn, Vector3(0.085, 0.06, 0.2), Vector3(0, -0.41, -0.045), dark, false)
		legs.append(th)
		knees.append(kn)
	_build_cape()
	aura = B.omni(self, Vector3(0, 1.2, -0.5), Color("ff5060"), 0.25, 3.0)
	B.omni(self, Vector3(0, 2.4, 1.6), Color("fff0e8"), 0.8, 5.0)      # soft key light so she always reads


func _build_cape() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 8
	var rows := 12
	for r in rows + 1:
		for c in cols + 1:
			var u := float(c) / cols
			var v := float(r) / rows
			var w := lerpf(0.36, 0.95, v)
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3((u - 0.5) * w, -v * 1.2, 0.03 + v * 0.16 - cos((u - 0.5) * PI) * 0.06 * v))
	for r in rows:
		for c in cols:
			var i := r * (cols + 1) + c
			for k: int in [i, i + 1, i + cols + 1, i + 1, i + cols + 2, i + cols + 1]:
				st.add_index(k)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	cape_mat = ShaderMaterial.new()
	cape_mat.shader = CAPE
	mi.material_override = cape_mat
	mi.position = Vector3(0, 0.5, 0.1)
	chest.add_child(mi)


func animate(delta: float, speed: float, on_floor: bool, _dashing := false) -> void:
	_t += delta
	var k := 1.0 - exp(-10.0 * delta)
	_move = lerpf(_move, clampf(speed / 3.0, 0.0, 1.0), k)
	_run = lerpf(_run, clampf((speed - 3.6) / 3.0, 0.0, 1.0), k)
	_air = lerpf(_air, 0.0 if on_floor else 1.0, k)
	_phase += delta * (7.0 + _run * 4.5) * _move
	var s := sin(_phase)
	var amp := (0.5 + _run * 0.4) * _move * (1.0 - _air)
	for i in 2:
		var d := 1.0 if i == 0 else -1.0
		legs[i].rotation.x = lerpf(s * d * amp, 0.55 if i == 0 else -0.25, _air)
		knees[i].rotation.x = lerpf(-clampf(sin(_phase * 1.0 - d * 1.3) * d, 0.0, 1.0) * 1.2 * amp, -0.9 if i == 0 else -0.3, _air)
		arms[i].rotation.x = lerpf(-s * d * amp * 0.8 + sin(_t * 1.3) * 0.03, -0.5, _air)
		arms[i].rotation.z = (-1.0 if i == 0 else 1.0) * lerpf(0.12, 0.7, _air)
		elbows[i].rotation.x = 0.15 + 0.5 * _move + 0.3 * _run
	hips.position.y = 0.9 - absf(s) * 0.035 * _move + sin(_t * 1.7) * 0.006
	hips.rotation.x = -(0.05 * _move + 0.2 * _run)
	chest.rotation.y = s * 0.1 * amp
	chest.scale = Vector3.ONE * (1.0 + sin(_t * 1.7) * 0.008)
	head.rotation.x = 0.05 * _move + 0.15 * _run
	cape_mat.set_shader_parameter("stream", clampf(speed / 7.0, 0.0, 1.0) * 0.9 + _air * 0.4)
	aura.light_energy = 0.25 + sin(_t * 2.2) * 0.06 + _run * 0.3
