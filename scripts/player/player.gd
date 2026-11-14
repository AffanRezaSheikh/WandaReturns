## Player: third-person CharacterBody3D controller for Wanda.
## Owns the orbit camera (SpringArm3D), movement, jump, dash and the model.
extends CharacterBody3D

const WandaModel := preload("res://scripts/player/wanda_model.gd")   # code-built fallback
const WandaRig := preload("res://scripts/player/wanda_rig.gd")
const WALK := 3.4
const RUN := 7.2
const JUMP := 7.0
const GRAVITY := 19.0
const DASH_SPEED := 16.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.7
const MOUSE_SENS := 0.0028

var control := true
var model: Node3D
var cam_pivot: Node3D
var arm: SpringArm3D
var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.22
var _dash := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.ZERO


func _ready() -> void:
	add_to_group(&"player")
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.72
	cs.shape = cap
	cs.position.y = 0.86
	add_child(cs)
	model = WandaRig.new() if ResourceLoader.exists(WandaRig.MODEL) else WandaModel.new()
	add_child(model)
	cam_pivot = Node3D.new()
	cam_pivot.top_level = true
	add_child(cam_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 4.6
	arm.margin = 0.25
	arm.add_excluded_object(get_rid())
	cam_pivot.add_child(arm)
	cam = Camera3D.new()
	cam.fov = 68.0
	cam.h_offset = 0.55
	cam.far = 900.0
	arm.add_child(cam)
	cam.make_current()


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	cam_yaw = yaw
	cam_pitch = -0.2
	model.rotation.y = yaw
	cam_pivot.global_position = pos + Vector3(0, 1.5, 0)
	_update_camera()
	reset_physics_interpolation()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := e as InputEventMouseMotion
		cam_yaw -= m.relative.x * MOUSE_SENS
		cam_pitch = clampf(cam_pitch - m.relative.y * MOUSE_SENS, -1.2, 0.6)
	elif e.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var iv := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down") if control else Vector2.ZERO
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(iv.x, 0, iv.y)
	var top := RUN if Input.is_action_pressed(&"sprint") else WALK
	_dash_cd -= delta
	if control and Input.is_action_just_pressed(&"dash") and _dash_cd <= 0.0:
		_dash = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		_dash_dir = dir.normalized() if dir.length() > 0.1 else Basis(Vector3.UP, model.rotation.y) * Vector3.FORWARD
		FeelDirector.shake(0.05, 0.15)
	if _dash > 0.0:
		_dash -= delta
		velocity = _dash_dir * DASH_SPEED
	else:
		var accel := 14.0 if is_on_floor() else 5.0
		velocity.x = move_toward(velocity.x, dir.x * top, accel * top * delta / 2.0)
		velocity.z = move_toward(velocity.z, dir.z * top, accel * top * delta / 2.0)
		velocity.y -= GRAVITY * delta
		if control and is_on_floor() and Input.is_action_just_pressed(&"jump"):
			velocity.y = JUMP
	move_and_slide()
	var h := Vector2(velocity.x, velocity.z)
	if h.length() > 0.3:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-h.x, -h.y), 1.0 - exp(-12.0 * delta))
	model.animate(delta, h.length(), is_on_floor(), _dash > 0.0)
	var region := SceneManager.current
	if region and global_position.y < region.kill_y and not SceneManager.busy:
		SceneManager.respawn()
		EventBus.player_respawned.emit()


func _process(delta: float) -> void:
	cam_pivot.global_position = cam_pivot.global_position.lerp(global_position + Vector3(0, 1.5, 0), 1.0 - exp(-14.0 * delta))
	_update_camera()


func _update_camera() -> void:
	cam_pivot.rotation = Vector3(0, cam_yaw, 0)
	arm.rotation.x = cam_pitch
	var o := FeelDirector.offset()
	cam.h_offset = 0.55 + o.x
	cam.v_offset = o.y
