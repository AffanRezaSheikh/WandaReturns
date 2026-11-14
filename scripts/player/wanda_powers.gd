## WandaPowers: Hex Bolt (hold to charge, max 8 s, 1 s cooldown), Hex Sphere
## (hold to grow; zone disarms, direct hit bubbles and throws, R = self shield),
## Telekinesis ultimate (18 s, 35 s cooldown) and Levitation (hold jump).
extends Node

const B := preload("res://scripts/world/builder.gd")
const Fx := preload("res://scripts/combat/fx.gd")
const Projectile := preload("res://scripts/combat/projectile.gd")
const BUBBLE := preload("res://assets/shaders/bubble.gdshader")
const BOLT_MAX := 8.0
const BOLT_CD := 1.0
const SPHERE_CD := 6.0
const ULT_TIME := 18.0
const ULT_CD := 35.0
const ULT_RANGE := 20.0
const CRIMSON := Color("ff3048")

var player: CharacterBody3D
var charge := -1.0
var bolt_cd := 0.0
var grow := -1.0
var sphere_cd := 0.0
var shield_t := 0.0
var ult_t := 0.0
var ult_cd := 0.0
var lev := 1.0
var levitating := false
var _orb: MeshInstance3D
var _orb_light: OmniLight3D
var _preview: MeshInstance3D
var _shield: MeshInstance3D
var _bubble: MeshInstance3D
var _bubble_enemy: Node3D
var _bubble_t := 0.0
var _zones: Array = []          # [[node, radius, time_left], ...]
var _charmed: Array = []
var _zone_tick := 0.0


func _ready() -> void:
	_orb = B.ball(player, 0.12, Vector3(0, 1.25, -0.6), B.glow(CRIMSON, 5.0), Vector3.ONE, false, 10)
	_orb.visible = false
	_orb_light = B.omni(player, Vector3(0, 1.3, -0.6), CRIMSON, 0.0, 6.0)
	_preview = _sphere_mesh(1.0, 0.7)
	_preview.visible = false
	_shield = _sphere_mesh(1.3, 0.4)
	_shield.visible = false
	player.add_child(_shield)
	_shield.position.y = 0.95


func _exit_tree() -> void:
	for n: Node in [_orb, _orb_light, _shield]:               # these hang off the player, not this node
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(_preview) and not _preview.is_inside_tree():
		_preview.free()


func _sphere_mesh(r: float, power: float) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	var m := ShaderMaterial.new()
	m.shader = BUBBLE
	m.set_shader_parameter("power", power)
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _world() -> Node:
	return SceneManager.current if SceneManager.current else player.get_parent()


func aiming() -> bool:
	return charge >= 0.0 or grow >= 0.0 or _bubble_enemy != null or ult_t > 0.0


func anim_override() -> String:
	if charge >= 0.0 or grow >= 0.0:
		return "charge"
	if ult_t > 0.0 or _bubble_enemy != null:
		return "cast_hold"
	return ""


func tick(delta: float) -> void:
	bolt_cd = maxf(0.0, bolt_cd - delta)
	sphere_cd = maxf(0.0, sphere_cd - delta)
	ult_cd = maxf(0.0, ult_cd - delta)
	var live: bool = player.control and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var lmb: bool = live and Input.is_action_pressed(&"bolt")
	var rmb: bool = live and Input.is_action_pressed(&"sphere")
	var lmb_now: bool = live and Input.is_action_just_pressed(&"bolt")
	var rmb_now: bool = live and Input.is_action_just_pressed(&"sphere")
	if ult_t > 0.0:
		_tick_ult(delta, lmb_now, rmb_now)
	elif _bubble_enemy != null:
		_tick_bubble(delta, lmb_now or rmb_now)
	else:
		_tick_bolt(delta, lmb)
		_tick_sphere(delta, rmb)
		if live and Input.is_action_just_pressed(&"shield") and sphere_cd <= 0.0:
			_cast_shield()
		if live and Input.is_action_just_pressed(&"ult") and ult_cd <= 0.0:
			_start_ult()
	_tick_shield(delta)
	_tick_zones(delta)


# ---------------------------------------------------------------- Hex Bolt
func _tick_bolt(delta: float, held: bool) -> void:
	if charge < 0.0:
		if held and bolt_cd <= 0.0 and grow < 0.0:
			charge = 0.0
	else:
		charge = minf(charge + delta, BOLT_MAX)
		var k := charge / BOLT_MAX
		_orb.visible = true
		_orb.scale = Vector3.ONE * (1.0 + k * 4.5 + sin(Time.get_ticks_msec() * 0.03) * 0.08)
		_orb_light.light_energy = 1.0 + k * 5.0
		if k >= 1.0:
			FeelDirector.shake(0.012, 0.1)
		if not held:
			_fire_bolt(k)
	if charge < 0.0:
		_orb.visible = false
		_orb_light.light_energy = 0.0


func _fire_bolt(k: float) -> void:
	charge = -1.0
	bolt_cd = BOLT_CD
	var from := _orb.global_position
	var a := Game.aim(80.0)
	var dir: Vector3 = (a.pos - from).normalized()
	Projectile.fire(_world(), from, dir * 40.0, 12.0 + 108.0 * pow(k, 1.3), &"ally", player, CRIMSON, 0.14 + 0.5 * k, 1.2 + 3.6 * k)
	player.play_once("cast", 0.4, 2.2)
	FeelDirector.shake(0.03 + 0.12 * k, 0.2)


# ---------------------------------------------------------------- Hex Sphere
func _tick_sphere(delta: float, held: bool) -> void:
	if grow < 0.0:
		if held and sphere_cd <= 0.0 and charge < 0.0:
			grow = 0.0
			_world().add_child(_preview)
			_preview.visible = true
		return
	grow = minf(grow + delta, 3.0)
	var r := lerpf(2.0, 7.5, grow / 3.0)
	var a := Game.aim(30.0)
	_preview.global_position = a.pos
	_preview.scale = Vector3.ONE * r
	if not held:
		_preview.visible = false
		_preview.get_parent().remove_child(_preview)
		grow = -1.0
		sphere_cd = SPHERE_CD
		player.play_once("cast", 0.4, 2.0)
		var body: Node = a.body
		if body and body.is_in_group(&"enemy") and body.has_method(&"bubble_on") and not body.is_boss and body.is_alive():
			_bubble_enemy = body
			_bubble_t = 7.0
			_bubble = _sphere_mesh(1.35, 1.0)
			_world().add_child(_bubble)
			_bubble.global_position = body.global_position + Vector3(0, 1.0, 0)
			body.bubble_on(_bubble)
			Fx.text(_world(), body.global_position + Vector3(0, 2.4, 0), "TRAPPED", Color("ff8090"), 40)
		else:
			var z := _sphere_mesh(1.0, 0.8)
			_world().add_child(z)
			z.global_position = a.pos
			z.scale = Vector3.ONE * r
			_zones.append([z, r, 8.0])
			Fx.burst(_world(), a.pos + Vector3(0, 0.5, 0), CRIMSON, 30, 5.0)


func _tick_bubble(delta: float, throw_now: bool) -> void:
	_bubble_t -= delta
	if not is_instance_valid(_bubble_enemy) or not _bubble_enemy.is_alive():
		_end_bubble()
		return
	var cam := player.get_viewport().get_camera_3d()
	var target := cam.global_position - cam.global_transform.basis.z * 10.0
	target.y = maxf(target.y, player.global_position.y + 1.6)
	_bubble.global_position = _bubble.global_position.lerp(target, 1.0 - exp(-6.0 * delta))
	if throw_now:
		var dir := -cam.global_transform.basis.z
		_bubble_enemy.throw(dir * 27.0 + Vector3(0, 2.0, 0), 45.0)
		player.play_once("cast", 0.4, 2.2)
		FeelDirector.shake(0.08, 0.2)
		_end_bubble(false)
	elif _bubble_t <= 0.0:
		_end_bubble()


func _end_bubble(release := true) -> void:
	if release and is_instance_valid(_bubble_enemy):
		_bubble_enemy.release()
	_bubble_enemy = null
	if is_instance_valid(_bubble):
		_bubble.queue_free()


func _cast_shield() -> void:
	sphere_cd = SPHERE_CD
	shield_t = 6.0
	player.shield_hp = 70.0
	player.play_once("cast", 0.35, 2.2)
	Fx.burst(_world(), player.global_position + Vector3(0, 1.0, 0), CRIMSON, 24, 4.0)


func _tick_shield(delta: float) -> void:
	if shield_t > 0.0:
		shield_t -= delta
		if shield_t <= 0.0 or player.shield_hp <= 0.0:
			shield_t = 0.0
			player.shield_hp = 0.0
	_shield.visible = shield_t > 0.0
	if _shield.visible:
		_shield.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.03)


func _tick_zones(delta: float) -> void:
	_zone_tick -= delta
	var pulse := _zone_tick <= 0.0
	if pulse:
		_zone_tick = 0.25
	for z: Array in _zones.duplicate():
		z[2] -= delta
		if z[2] <= 0.0:
			(z[0] as Node).queue_free()
			_zones.erase(z)
		elif pulse:
			for e: Node3D in Game.enemies():
				if e.has_method(&"disarm") and e.global_position.distance_to((z[0] as Node3D).global_position) < z[1]:
					e.disarm(1.0)


# ---------------------------------------------------------------- Telekinesis (ultimate)
func _start_ult() -> void:
	ult_t = ULT_TIME
	player.play_once("cast", 0.6, 1.4)
	FeelDirector.shake(0.2, 0.5)
	Fx.burst(_world(), player.global_position + Vector3(0, 1.2, 0), CRIMSON, 80, 10.0, 0.16, 0.9)
	var n := 0
	for e: Node3D in Game.enemies():
		if e.has_method(&"hold") and e.is_alive() and e.global_position.distance_to(player.global_position) < ULT_RANGE:
			e.hold()
			n += 1
	Game.hud.toast("TELEKINESIS  -  %d seized" % n)


func _tick_ult(delta: float, fling_now: bool, charm_now: bool) -> void:
	ult_t -= delta
	if fling_now:
		var e := Game.enemy_near_crosshair(func(x: Node) -> bool: return x.has_method(&"hold") and x.state == &"held")
		if e:
			var cam := player.get_viewport().get_camera_3d()
			e.throw(-cam.global_transform.basis.z * 28.0 + Vector3(0, 3.0, 0), 55.0)
			player.play_once("cast", 0.35, 2.4)
			FeelDirector.shake(0.1, 0.2)
	if charm_now:
		var e2 := Game.enemy_near_crosshair(func(x: Node) -> bool: return x.has_method(&"hold") and x.state == &"held" and not x.is_boss)
		if e2:
			e2.release()
			e2.charm(true)
			_charmed.append(e2)
	if ult_t <= 0.0:
		end_ult()


func end_ult() -> void:
	ult_t = 0.0
	ult_cd = ULT_CD
	for e: Node3D in Game.enemies():
		if e.has_method(&"release") and e.state == &"held":
			e.release()
			e.take_damage(15.0, player)
	for c in _charmed:                                       # untyped: a turned enemy may have died and been freed
		if is_instance_valid(c) and c.is_alive():
			c.charm(false)
	_charmed.clear()


# ---------------------------------------------------------------- Levitation
## Called by the player's movement. Returns true while she is levitating.
func levitate(delta: float, jump_held: bool, on_floor: bool, since_jump: float) -> bool:
	if on_floor:
		lev = minf(1.0, lev + delta / 3.0)
		levitating = false
	elif jump_held and lev > 0.0 and since_jump > 0.22:
		lev -= delta / 6.0
		levitating = true
	else:
		levitating = false
	return levitating


func hud_info() -> Dictionary:
	var k := charge / BOLT_MAX if charge >= 0.0 else 0.0
	return {"name": "WANDA", "meter": lev, "meter_name": "LEVITATE", "charge": k, "ult_active": ult_t / ULT_TIME,
		"slots": [["LMB", "HEX BOLT", bolt_cd / BOLT_CD, charge >= 0.0], ["RMB", "HEX SPHERE", sphere_cd / SPHERE_CD, grow >= 0.0 or _bubble_enemy != null],
			["R", "SHIELD", sphere_cd / SPHERE_CD, shield_t > 0.0], ["E", "TELEKINESIS", ult_cd / ULT_CD, ult_t > 0.0]],
		"hint": ("LMB fling   ·   RMB turn to your side" if ult_t > 0.0 else ("Click to throw" if _bubble_enemy != null else ""))}


func cleanup() -> void:
	if ult_t > 0.0:
		end_ult()
	_end_bubble()
	for z: Array in _zones:
		if is_instance_valid(z[0]):
			(z[0] as Node).queue_free()
	_zones.clear()
	if is_instance_valid(_preview) and _preview.get_parent():
		_preview.get_parent().remove_child(_preview)
	charge = -1.0
	grow = -1.0
