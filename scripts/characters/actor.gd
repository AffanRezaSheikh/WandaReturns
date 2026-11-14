## Actor: any AI fighter (zombies, gunmen, bosses, allied Vision/Wanda).
## States: normal (AI), held (Telekinesis), bubbled (Hex Sphere), thrown, down.
extends CharacterBody3D

signal died(actor: Node)

const Rig := preload("res://scripts/characters/character_rig.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")
const Fx := preload("res://scripts/combat/fx.gd")
const B := preload("res://scripts/world/builder.gd")
const GRAVITY := 19.0

var type: StringName
var cfg: Dictionary = {}
var hp := 50.0
var max_hp := 50.0
var team: StringName = &"enemy"
var state: StringName = &"normal"
var is_boss := false
var armed := false
var charmed := false
var disarmed_t := 0.0
var slow_t := 0.0
var rig: Node3D
var display_name := ""
var bubble: Node3D
var passive := false            # stands still (cutscenes)
var _target: Node3D
var _scan := 0.0
var _atk_cd := 1.0
var _hit_t := -1.0
var _shot_cd := 1.5
var _summon_cd := 8.0
var _held_y := 0.0
var _throw_dmg := 0.0
var _bar: MeshInstance3D


func _ready() -> void:
	hp = cfg.get("hp", 50.0)
	max_hp = hp
	is_boss = cfg.get("boss", false)
	armed = cfg.get("armed", false)
	team = cfg.get("team", &"enemy")
	display_name = cfg.get("name", "")
	add_to_group(team)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.88
	add_child(cs)
	var models: Array = cfg["model"]
	rig = Rig.make(models[randi() % models.size()], cfg.get("colors", {}))
	rig.scale = Vector3.ONE * cfg.get("scale", 1.0)
	add_child(rig)
	if team == &"enemy":
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.09)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color("e8374a")
		m.no_depth_test = true
		_bar = MeshInstance3D.new()
		_bar.mesh = q
		_bar.material_override = m
		_bar.position.y = 2.25 * cfg.get("scale", 1.0)
		_bar.visible = false
		add_child(_bar)
	_atk_cd = randf_range(0.4, 1.4)


func is_alive() -> bool:
	return state != &"down"


func _opponents() -> Array:
	return get_tree().get_nodes_in_group(&"ally" if _side() == &"enemy" else &"enemy")


func _side() -> StringName:
	return &"ally" if (charmed or team == &"ally") else &"enemy"


func _find_target() -> void:
	_target = null
	var best := 60.0
	for o: Node3D in _opponents():
		if o == self or not o.has_method(&"is_alive") or not o.is_alive():
			continue
		var d := o.global_position.distance_to(global_position)
		if d < best:
			best = d
			_target = o


func _physics_process(delta: float) -> void:
	disarmed_t = maxf(0.0, disarmed_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	match state:
		&"down":
			return
		&"held":
			velocity = Vector3.ZERO
			global_position.y = lerpf(global_position.y, _held_y + sin(Time.get_ticks_msec() * 0.002 + _held_y) * 0.2, 1.0 - exp(-4.0 * delta))
			rig.play("held", 0.25)
			return
		&"bubbled":
			if bubble and is_instance_valid(bubble):
				global_position = global_position.lerp(bubble.global_position - Vector3(0, 0.9, 0), 1.0 - exp(-14.0 * delta))
			rig.play("held", 0.2)
			return
		&"thrown":
			velocity.y -= GRAVITY * 0.5 * delta
			rig.rotate_x(delta * 9.0)
			move_and_slide()
			if get_slide_collision_count() > 0:
				_crash()
			return
	velocity.y -= GRAVITY * delta
	var hv := Vector3.ZERO
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.4
		_find_target()
	_atk_cd -= delta
	_shot_cd -= delta
	var moving := false
	if passive:
		pass
	elif _target and is_instance_valid(_target):
		var to := _target.global_position - global_position
		to.y = 0.0
		var d := to.length()
		var dir := to / maxf(d, 0.01)
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * delta))
		var can_shoot := armed and disarmed_t <= 0.0
		var hold := 9.0 if can_shoot else 1.5
		if d > hold:
			hv = dir * cfg.get("speed", 2.0) * (0.55 if slow_t > 0.0 else 1.0)
			moving = true
		if can_shoot and d < 22.0 and _shot_cd <= 0.0:
			_shot_cd = 1.5 if not is_boss else 1.1
			rig.play("cast", 0.1, 1.6, true)
			var from := global_position + Vector3(0, 1.3, 0) + dir * 0.6
			var aim := (_target.global_position + Vector3(0, 1.0, 0) - from).normalized()
			Projectile.fire(get_parent(), from, aim * 20.0, cfg.get("shot_dmg", 6.0), _side(), self, cfg.get("shot_col", Color.WHITE), 0.14)
		elif d <= 1.9 and _atk_cd <= 0.0:
			_atk_cd = 1.5
			_hit_t = 0.32
			rig.play("attack", 0.1, 1.2, true)
		if cfg.get("summon", false) and not charmed:
			_summon_cd -= delta
			if _summon_cd <= 0.0 and get_tree().get_nodes_in_group(&"enemy").size() < 8:
				_summon_cd = 13.0
				rig.play("cast", 0.1, 1.0, true)
				for i in 2:
					var p := global_position + Vector3(randf_range(-4, 4), 0.3, randf_range(-4, 4))
					Fx.burst(get_parent(), p, Color("60ff80"), 20, 3.0)
					load("res://scripts/characters/roster.gd").spawn(get_parent(), &"zombie", p)
	elif team == &"ally" and Game.player and global_position.distance_to(Game.player.global_position) > 5.0:
		var to2 := Game.player.global_position - global_position
		to2.y = 0.0
		hv = to2.normalized() * cfg.get("speed", 4.0)
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-hv.x, -hv.z), 1.0 - exp(-8.0 * delta))
		moving = true
	if _hit_t >= 0.0:
		_hit_t -= delta
		hv = Vector3.ZERO
		if _hit_t < 0.0 and _target and is_instance_valid(_target) and _target.global_position.distance_to(global_position) < 2.6:
			_target.take_damage(cfg.get("dmg", 8.0), self)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	if not ["attack", "cast", "hit"].has(rig.current()) or not rig.anim.is_playing():
		rig.play(cfg.get("walk", "walk") if moving else "idle", 0.2)
	if global_position.y < -60.0:
		queue_free()


func take_damage(amount: float, _source: Node = null) -> void:
	if state == &"down":
		return
	hp -= amount
	rig.flash()
	Fx.text(get_parent(), global_position + Vector3(randf_range(-0.3, 0.3), 2.0, 0), str(int(amount)), Color("ffd0d0"), 34 + int(amount * 0.4))
	if _bar:
		_bar.visible = true
		_bar.scale.x = clampf(hp / max_hp, 0.0, 1.0)
	if hp <= 0.0:
		_die()
	elif state == &"normal" and not is_boss and _hit_t < 0.0:
		rig.play("hit", 0.05, 1.4, true)


func _die() -> void:
	state = &"down"
	remove_from_group(&"enemy")
	remove_from_group(&"ally")
	if _bar:
		_bar.visible = false
	rig.rotation.x = 0.0
	rig.play("down", 0.1, 1.0, true)
	collision_layer = 0
	collision_mask = 1
	velocity = Vector3.ZERO
	died.emit(self)
	var t := create_tween()
	t.tween_interval(4.0)
	t.tween_property(self, "position:y", position.y - 1.6, 1.5)
	t.tween_callback(queue_free)


# --- Wanda's powers act on actors through these -------------------------------
func hold() -> void:
	if state == &"normal":
		state = &"held"
		_held_y = global_position.y + (2.2 if not is_boss else 1.2)


func release() -> void:
	if state == &"held" or state == &"bubbled":
		state = &"normal"
		bubble = null
		rig.rotation.x = 0.0


func bubble_on(b: Node3D) -> void:
	state = &"bubbled"
	bubble = b


func throw(vel: Vector3, dmg: float) -> void:
	state = &"thrown"
	bubble = null
	velocity = vel
	_throw_dmg = dmg
	global_position.y += 0.2


func _crash() -> void:
	state = &"normal"
	rig.rotation.x = 0.0
	Fx.burst(get_parent(), global_position + Vector3(0, 0.8, 0), Color("ff5060"), 26, 6.0)
	FeelDirector.shake(0.1, 0.25)
	for e: Node3D in get_tree().get_nodes_in_group(&"enemy"):
		if e != self and e.global_position.distance_to(global_position) < 3.2:
			e.take_damage(_throw_dmg * 0.6, self)
	take_damage(_throw_dmg, null)


func charm(on: bool) -> void:
	if is_boss or state == &"down":
		return
	charmed = on
	remove_from_group(&"enemy" if on else &"ally")
	add_to_group(&"ally" if on else &"enemy")
	rig.set_param("glow", 0.5 if on else 0.0)
	_target = null
	_scan = 0.0
	if on:
		Fx.text(get_parent(), global_position + Vector3(0, 2.3, 0), "TURNED", Color("ff8090"), 40)


func disarm(t: float) -> void:
	if armed and disarmed_t <= 0.0:
		Fx.text(get_parent(), global_position + Vector3(0, 2.3, 0), "DISARMED", Color("ffd060"), 40)
	disarmed_t = maxf(disarmed_t, t)
	slow_t = maxf(slow_t, t)
