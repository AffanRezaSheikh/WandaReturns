## Car: the drivable red convertible (arcade handling). F to get in and out.
extends CharacterBody3D

const B := preload("res://scripts/world/builder.gd")
const MAX_SPEED := 26.0

var speed := 0.0
var driver: CharacterBody3D
var body_color := Color("c8102e")
var _prompt_cd := 0.0
var _wheels: Array[Node3D] = []


func _ready() -> void:
	add_to_group(&"car")
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(1.9, 1.0, 4.3)
	cs.shape = s
	cs.position.y = 0.75
	add_child(cs)
	var paint := B.mat(body_color, 0.3, 0.4)
	var dark := B.mat(Color("1c1c22"), 0.6)
	var chrome := B.mat(Color("d8dce4"), 0.2, 0.9)
	B.box(self, Vector3(1.9, 0.55, 4.3), Vector3(0, 0.62, 0), paint, false)
	B.box(self, Vector3(1.8, 0.3, 1.5), Vector3(0, 1.0, -1.35), paint, false)            # bonnet
	B.box(self, Vector3(1.8, 0.28, 0.9), Vector3(0, 0.98, 1.7), paint, false)             # boot
	B.box(self, Vector3(1.7, 0.5, 0.08), Vector3(0, 1.25, -0.55), B.glass(Color("9ad0e8"), 0.45), false, Vector3(-0.35, 0, 0))
	B.box(self, Vector3(1.5, 0.35, 1.5), Vector3(0, 0.8, 0.6), dark, false)               # seats well
	for sx: float in [-0.45, 0.45]:
		B.box(self, Vector3(0.6, 0.6, 0.18), Vector3(sx, 1.05, 0.95), B.mat(Color("f4ead8"), 0.8), false)
	B.box(self, Vector3(1.95, 0.14, 0.12), Vector3(0, 0.5, -2.2), chrome, false)
	B.box(self, Vector3(1.95, 0.14, 0.12), Vector3(0, 0.5, 2.2), chrome, false)
	for sx: float in [-0.7, 0.7]:
		B.ball(self, 0.13, Vector3(sx, 0.75, -2.17), B.glow(Color("fff2c0"), 2.5), Vector3(1, 1, 0.4), false, 8)
		B.box(self, Vector3(0.3, 0.12, 0.06), Vector3(sx, 0.75, 2.17), B.glow(Color("ff2020"), 1.5), false)
		for sz: float in [-1.4, 1.4]:
			var w := B.cyl(self, 0.36, 0.36, 0.26, Vector3(sx * 1.36, 0.36, sz), dark, false, 12, Vector3(0, 0, PI / 2))
			B.cyl(w, 0.18, 0.18, 0.28, Vector3.ZERO, chrome, false, 8)
			_wheels.append(w)
	var l := SpotLight3D.new()
	l.position = Vector3(0, 0.8, -2.3)
	l.spot_range = 30.0
	l.spot_angle = 32.0
	l.light_energy = 3.0
	l.light_color = Color("fff2c0")
	add_child(l)


func _physics_process(delta: float) -> void:
	_prompt_cd -= delta
	var p := Game.player
	if driver == null:
		speed = move_toward(speed, 0.0, 12.0 * delta)
		if p and p.driving == null and p.control and p.global_position.distance_to(global_position) < 3.6:
			if _prompt_cd <= 0.0:
				_prompt_cd = 4.0
				Game.hud.toast("F  -  drive", 2.0)
			if Input.is_action_just_pressed(&"interact") and not Game.hud.talking():
				enter(p)
	else:
		var iv := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down") if p.control else Vector2.ZERO
		if iv.y < -0.1:
			speed = move_toward(speed, MAX_SPEED, 13.0 * delta)
		elif iv.y > 0.1:
			speed = move_toward(speed, -8.0, 22.0 * delta)
		else:
			speed = move_toward(speed, 0.0, 5.0 * delta)
		rotation.y -= iv.x * clampf(speed / 8.0, -1.0, 1.0) * 1.5 * delta
		if Input.is_action_just_pressed(&"interact") and absf(speed) < 4.0 and not Game.hud.talking():
			leave()
	velocity = -global_transform.basis.z * speed + Vector3(0, velocity.y - 19.0 * delta, 0)
	move_and_slide()
	if get_slide_collision_count() > 0 and is_on_wall():
		speed *= 0.5
	for w in _wheels:
		w.rotate_object_local(Vector3.UP, speed * delta * 2.5)
	if absf(speed) > 7.0:
		for e: Node3D in Game.enemies():
			if e.global_position.distance_to(global_position) < 2.4:
				e.take_damage(absf(speed) * 2.0, self)
				speed *= 0.7


func enter(p: CharacterBody3D) -> void:
	driver = p
	p.driving = self
	p.collision_layer = 0
	p.collision_mask = 0
	p.powers.cleanup()
	p.cam_yaw = rotation.y
	Game.hud.toast("W/S drive   ·   A/D steer   ·   F get out", 4.0)


func leave() -> void:
	var p := driver
	driver = null
	p.driving = null
	p.collision_layer = 1
	p.collision_mask = 1
	p.global_position = global_position - global_transform.basis.x * 2.0 + Vector3(0, 0.3, 0)
	p.velocity = Vector3.ZERO
