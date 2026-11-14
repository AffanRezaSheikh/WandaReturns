## TargetDummy: a training drone for the test arena. Takes damage, bursts,
## and rebuilds itself a few seconds later. Can hover on a circular path.
extends AnimatableBody3D

const B := preload("res://scripts/world/builder.gd")
const Fx := preload("res://scripts/combat/fx.gd")

var hp := 60.0
var max_hp := 60.0
var orbit_radius := 0.0
var orbit_speed := 0.0
var centre := Vector3.ZERO
var _t := 0.0
var _alive := true
var _body: Node3D
var _bar: MeshInstance3D


func _ready() -> void:
	add_to_group(&"enemy")
	sync_to_physics = false
	centre = global_position
	_t = randf() * TAU
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.75
	cs.shape = s
	cs.position.y = 1.0
	add_child(cs)
	_body = Node3D.new()
	add_child(_body)
	B.ball(_body, 0.7, Vector3(0, 1.0, 0), B.mat(Color("ece4d4"), 0.5), Vector3.ONE, false, 14)
	B.torus(_body, 0.72, 0.86, Vector3(0, 1.0, 0), B.mat(Color("a03a56"), 0.5), Vector3(PI / 2, 0, 0), 24)
	B.ball(_body, 0.26, Vector3(0, 1.0, -0.6), B.glow(Color("ffe37a"), 2.5), Vector3.ONE, false, 10)
	if orbit_radius <= 0.0:
		B.cyl(_body, 0.1, 0.35, 0.5, Vector3(0, 0.25, 0), B.mat(Color("56807e"), 0.6), false, 8)
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color("ffe37a")
	_bar = MeshInstance3D.new()
	_bar.mesh = q
	_bar.material_override = m
	_bar.position.y = 2.1
	_bar.visible = false
	add_child(_bar)


func is_alive() -> bool:
	return _alive


func _physics_process(delta: float) -> void:
	_t += delta * orbit_speed
	if orbit_radius > 0.0:
		global_position = centre + Vector3(cos(_t) * orbit_radius, sin(_t * 2.0) * 1.2, sin(_t) * orbit_radius)
	_body.rotation.y += delta * 0.8


func take_damage(amount: float, _source: Node = null) -> void:
	if not _alive:
		return
	hp -= amount
	_bar.visible = true
	_bar.scale.x = clampf(hp / max_hp, 0.0, 1.0)
	Fx.text(get_parent(), global_position + Vector3(0, 2.3, 0), str(int(amount)), Color("fff2c0"), 34)
	if hp <= 0.0:
		_alive = false
		remove_from_group(&"enemy")
		_body.visible = false
		_bar.visible = false
		collision_layer = 0
		Fx.burst(get_parent(), global_position + Vector3(0, 1, 0), Color("ffe37a"), 50, 8.0, 0.14)
		FeelDirector.shake(0.08, 0.2)
		await get_tree().create_timer(4.0).timeout
		hp = max_hp
		_alive = true
		add_to_group(&"enemy")
		_body.visible = true
		collision_layer = 1
