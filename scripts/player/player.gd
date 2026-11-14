## Player: third-person controller shared by Wanda and Vision (GTA-style switch).
## Owns the orbit camera, movement, levitation/flight, health and the power set.
extends CharacterBody3D

const Rig := preload("res://scripts/characters/character_rig.gd")
const POWERS := {&"wanda": preload("res://scripts/player/wanda_powers.gd"), &"vision": preload("res://scripts/player/vision_powers.gd")}
const WALK := 3.4
const RUN := 7.2
const JUMP := 7.0
const GRAVITY := 19.0
const DASH_SPEED := 16.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.7
const MOUSE_SENS := 0.0028

var control := true
var character: StringName = &""
var rig: Node3D
var model: Node3D              # yaw pivot that holds the rig
var powers: Node
var hp := 100.0
var max_hp := 100.0
var shield_hp := 0.0
var invulnerable := false
var driving: Node3D            # the car she is in, if any
var rooted := false            # bound in place (story), powers still work
var cam_pivot: Node3D
var arm: SpringArm3D
var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.22
var _dash := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.ZERO
var _since_jump := 9.0
var _since_hit := 9.0
var _lock := 0.0
var _dead := false


func _ready() -> void:
	add_to_group(&"player")
	add_to_group(&"ally")
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.72
	cs.shape = cap
	cs.position.y = 0.86
	add_child(cs)
	model = Node3D.new()
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
	cam.far = 1500.0
	arm.add_child(cam)
	cam.make_current()
	var key := OmniLight3D.new()                # soft key light so the hero always reads
	key.light_color = Color("fff0e8")
	key.light_energy = 0.7
	key.omni_range = 5.0
	key.position = Vector3(0, 2.4, 1.6)
	model.add_child(key)
	set_character(&"wanda")


func set_character(who: StringName) -> void:
	if who == character:
		return
	if powers:
		powers.cleanup()
		powers.queue_free()
	if rig:
		rig.queue_free()
	character = who
	rig = Rig.make(String(who))
	model.add_child(rig)
	powers = (POWERS[who] as GDScript).new()
	powers.player = self
	add_child(powers)
	hp = max_hp
	invulnerable = false


func is_alive() -> bool:
	return not _dead


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	cam_yaw = yaw
	cam_pitch = -0.2
	model.rotation.y = yaw
	cam_pivot.global_position = pos + Vector3(0, 1.5, 0)
	_update_camera()
	reset_physics_interpolation()


func play_once(clip: String, lock: float, speed := 1.0) -> void:
	rig.play(clip, 0.08, speed, true)
	_lock = lock


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := e as InputEventMouseMotion
		cam_yaw -= m.relative.x * MOUSE_SENS
		cam_pitch = clampf(cam_pitch - m.relative.y * MOUSE_SENS, -1.25, 0.9)
	elif e.is_action_pressed(&"pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_since_hit += delta
	_since_jump += delta
	_lock -= delta
	if not _dead and _since_hit > 5.0:
		hp = minf(max_hp, hp + 6.0 * delta)
	if driving:
		global_position = driving.global_position + Vector3(0, 0.35, 0)
		model.rotation.y = driving.rotation.y
		rig.play("sit", 0.1)
		velocity = Vector3.ZERO
		return
	powers.tick(delta)
	var iv := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down") if (control and not rooted) else Vector2.ZERO
	var dir := Basis(Vector3.UP, cam_yaw) * Vector3(iv.x, 0, iv.y)
	var aiming: bool = powers.aiming()
	var top := RUN if (Input.is_action_pressed(&"sprint") and not aiming) else WALK
	var jump_held := control and Input.is_action_pressed(&"jump")
	var lev: bool = powers.levitate(delta, jump_held, is_on_floor(), _since_jump)
	_dash_cd -= delta
	if control and not rooted and Input.is_action_just_pressed(&"dash") and _dash_cd <= 0.0:
		_dash = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		_dash_dir = dir.normalized() if dir.length() > 0.1 else Basis(Vector3.UP, model.rotation.y) * Vector3.FORWARD
		FeelDirector.shake(0.05, 0.15)
	if _dash > 0.0:
		_dash -= delta
		velocity = _dash_dir * DASH_SPEED
	elif lev and character == &"vision":
		var fdir := (Basis(Vector3.UP, cam_yaw) * Basis(Vector3.RIGHT, cam_pitch)) * Vector3(iv.x, 0, iv.y)
		var sp := 22.0 if Input.is_action_pressed(&"sprint") else 12.0
		velocity = velocity.move_toward(fdir * sp + Vector3(0, 3.0 if iv.length() < 0.1 else 0.0, 0), 40.0 * delta)
	else:
		if lev:
			top = 6.0
		var accel := 14.0 if is_on_floor() else (9.0 if lev else 5.0)
		velocity.x = move_toward(velocity.x, dir.x * top, accel * top * delta / 2.0)
		velocity.z = move_toward(velocity.z, dir.z * top, accel * top * delta / 2.0)
		if lev:
			velocity.y = move_toward(velocity.y, 2.4, 30.0 * delta)
		else:
			velocity.y -= GRAVITY * delta
		if control and not rooted and is_on_floor() and Input.is_action_just_pressed(&"jump"):
			velocity.y = JUMP
			_since_jump = 0.0
	move_and_slide()
	var h := Vector2(velocity.x, velocity.z)
	var k := 1.0 - exp(-12.0 * delta)
	if aiming:
		model.rotation.y = lerp_angle(model.rotation.y, cam_yaw, k)
	elif h.length() > 0.3:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-h.x, -h.y), k)
	_animate(h.length(), lev)
	var region := SceneManager.current
	if region and global_position.y < region.kill_y and not SceneManager.busy:
		SceneManager.respawn()
		EventBus.player_respawned.emit()


func _animate(speed: float, lev: bool) -> void:
	if _dead or _lock > 0.0:
		return
	var o: String = powers.anim_override()
	if o == "charge":
		rig.play("charge", 0.15)
	elif o == "cast_hold":
		if rig.current() != "cast" or rig.anim.current_animation_position < 0.4:
			rig.play("cast", 0.15)
		else:
			rig.anim.speed_scale = 0.0
	elif _dash > 0.0:
		rig.play("dash", 0.06)
	elif lev:
		rig.play("fly" if (character == &"vision" and velocity.length() > 5.0) else "hover", 0.2)
	elif not is_on_floor():
		rig.play("air", 0.15)
	elif speed > 4.6:
		rig.play("run", 0.18, clampf(speed / 6.6, 0.8, 1.4))
	elif speed > 0.35:
		rig.play("walk", 0.2, clampf(speed / 2.6, 0.6, 1.5))
	else:
		rig.play("idle", 0.25)


func take_damage(amount: float, _source: Node = null) -> void:
	if _dead or invulnerable or SceneManager.busy:
		return
	if shield_hp > 0.0:
		shield_hp -= amount
		return
	hp -= amount
	_since_hit = 0.0
	rig.flash(Color(1, 0.3, 0.3))
	FeelDirector.shake(0.06, 0.2)
	if Game.hud:
		Game.hud.hurt()
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	control = false
	powers.cleanup()
	rig.play("down", 0.1, 1.0, true)
	await get_tree().create_timer(1.6).timeout
	var t := create_tween()
	t.tween_property(SceneManager.fade, "color:a", 1.0, 0.5)
	await t.finished
	hp = max_hp
	_dead = false
	if Game.missions and Game.missions.has_checkpoint():
		Game.missions.restore_checkpoint()
	else:
		SceneManager.respawn()
	Game.hud.toast("Chaos magic knits you back together")
	var t2 := create_tween()
	t2.tween_property(SceneManager.fade, "color:a", 0.0, 0.6)
	control = true


func _process(delta: float) -> void:
	cam_pivot.global_position = cam_pivot.global_position.lerp(global_position + Vector3(0, 1.5, 0), 1.0 - exp(-14.0 * delta))
	_update_camera()


func _update_camera() -> void:
	cam_pivot.rotation = Vector3(0, cam_yaw, 0)
	arm.rotation.x = cam_pitch
	arm.spring_length = lerpf(arm.spring_length, 8.5 if driving else 4.6, 0.1)
	var o := FeelDirector.offset()
	cam.h_offset = (0.0 if driving else 0.55) + o.x
	cam.v_offset = o.y
