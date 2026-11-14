## TrafficCar: an AI car that loops a rectangle of streets and brakes for the player.
extends AnimatableBody3D

const B := preload("res://scripts/world/builder.gd")

var path: Array[Vector3] = []
var idx := 0
var speed := 0.0
var cruise := 9.0
var color := Color("3a6a8c")


func _ready() -> void:
	sync_to_physics = false
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(1.9, 1.3, 4.2)
	cs.shape = s
	cs.position.y = 0.8
	add_child(cs)
	var paint := B.mat(color, 0.35, 0.3)
	B.box(self, Vector3(1.9, 0.6, 4.2), Vector3(0, 0.62, 0), paint, false)
	B.box(self, Vector3(1.7, 0.6, 2.2), Vector3(0, 1.2, 0.2), B.glass(Color("9ad0e8"), 0.6), false)
	B.box(self, Vector3(1.72, 0.08, 2.24), Vector3(0, 1.52, 0.2), paint, false)
	var dark := B.mat(Color("1c1c22"), 0.6)
	for sx: float in [-0.95, 0.95]:
		for sz: float in [-1.35, 1.35]:
			B.cyl(self, 0.34, 0.34, 0.22, Vector3(sx, 0.34, sz), dark, false, 10, Vector3(0, 0, PI / 2))
		B.ball(self, 0.12, Vector3(sx * 0.7, 0.72, -2.1), B.glow(Color("fff2c0"), 2.0), Vector3(1, 1, 0.4), false, 6)
		B.box(self, Vector3(0.3, 0.12, 0.06), Vector3(sx * 0.7, 0.72, 2.1), B.glow(Color("ff2020"), 1.2), false)
	global_position = path[0]
	idx = 1
	look_at(path[1], Vector3.UP)


func _physics_process(delta: float) -> void:
	var target := path[idx]
	var to := target - global_position
	to.y = 0.0
	if to.length() < 1.2:
		idx = (idx + 1) % path.size()
		return
	var fwd := to.normalized()
	var want := cruise
	if to.length() < 9.0:
		want = 4.0
	for o: Node3D in get_tree().get_nodes_in_group(&"player") + get_tree().get_nodes_in_group(&"car") + get_tree().get_nodes_in_group(&"traffic"):
		if o == self:
			continue
		var d := o.global_position - global_position
		d.y = 0.0
		if d.length() < 11.0 and d.normalized().dot(fwd) > 0.75:
			want = 0.0
	speed = move_toward(speed, want, (16.0 if want < speed else 5.0) * delta)
	global_position += fwd * speed * delta
	var yaw := atan2(-fwd.x, -fwd.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-6.0 * delta))
