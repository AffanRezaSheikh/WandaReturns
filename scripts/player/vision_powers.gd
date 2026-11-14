## VisionPowers: Space toggles hover/flight, hold LMB fires the golden Mind
## Stone beam from his forehead, hold RMB phases (intangible), E Density Slam.
extends Node

const B := preload("res://scripts/world/builder.gd")
const Fx := preload("res://scripts/combat/fx.gd")
const SLAM_CD := 10.0
const GOLD := Color("ffe060")
const GEM_HEIGHT := 1.81

var player: CharacterBody3D
var phase := 1.0
var phasing := false
var slam_cd := 0.0
var diving := false
var flying := false
var beaming := false
var _rise := 0.0
var _beam: MeshInstance3D
var _core: MeshInstance3D
var _gem_light: OmniLight3D
var _hit_light: OmniLight3D
var _tick := 0.0


func _ready() -> void:
	_beam = B.cyl(player, 0.09, 0.09, 1.0, Vector3.ZERO, B.glow(GOLD, 5.0), false, 8)
	_core = B.cyl(player, 0.035, 0.035, 1.0, Vector3.ZERO, B.glow(Color("fffbe6"), 9.0), false, 6)
	for m: MeshInstance3D in [_beam, _core]:
		m.top_level = true
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gem_light = B.omni(player.model, Vector3(0, GEM_HEIGHT, -0.22), GOLD, 0.2, 1.6)
	_hit_light = B.omni(player, Vector3.ZERO, GOLD, 0.0, 9.0)
	_hit_light.top_level = true


func _exit_tree() -> void:
	for n: Node in [_beam, _core, _gem_light, _hit_light]:    # these hang off the player, not this node
		if is_instance_valid(n):
			n.queue_free()


func aiming() -> bool:
	return beaming


func anim_override() -> String:
	return "beam" if beaming else ""


func lift() -> float:
	return 3.6 if _rise > 0.0 else 0.0


func gem_position() -> Vector3:
	return player.global_position + Vector3(0, GEM_HEIGHT, 0) + Basis(Vector3.UP, player.model.rotation.y) * Vector3(0, 0, -0.18)


func tick(delta: float) -> void:
	slam_cd = maxf(0.0, slam_cd - delta)
	_rise -= delta
	var live: bool = player.control and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	beaming = live and Input.is_action_pressed(&"bolt") and not phasing
	_beam.visible = beaming
	_core.visible = beaming
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.04) * 0.25
	_gem_light.light_energy = lerpf(_gem_light.light_energy, 3.0 * pulse if beaming else 0.2, 0.25)
	_hit_light.light_energy = lerpf(_hit_light.light_energy, 3.5 if beaming else 0.0, 0.3)
	if beaming:
		var a := Game.aim(80.0)
		var from := gem_position()
		var to: Vector3 = a.pos
		for m: MeshInstance3D in [_beam, _core]:
			m.global_position = (from + to) * 0.5
			m.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT)
			m.rotate_object_local(Vector3.RIGHT, PI / 2)
			m.scale = Vector3(pulse, from.distance_to(to), pulse)
		_hit_light.global_position = to - (to - from).normalized() * 0.4
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.1
			var body: Node = a.body
			if body and body.has_method(&"take_damage") and body.is_in_group(&"enemy"):
				body.take_damage(6.0, player)
			if a.hit:
				Fx.burst(SceneManager.current, to, GOLD, 6, 3.0, 0.08, 0.35)
			FeelDirector.shake(0.012, 0.1)
	var want: bool = live and Input.is_action_pressed(&"sphere") and phase > 0.05
	if want != phasing:
		phasing = want
		player.invulnerable = phasing
		player.rig.set_ghost(phasing)
	phase = clampf(phase + (-delta / 5.0 if phasing else delta / 6.0), 0.0, 1.0)
	if live and Input.is_action_just_pressed(&"ult") and slam_cd <= 0.0:
		slam_cd = SLAM_CD
		if player.is_on_floor():
			_slam()
		else:
			diving = true
			flying = false
			player.velocity = Vector3(0, -42.0, 0)
	if diving and player.is_on_floor():
		diving = false
		_slam()


func _slam() -> void:
	FeelDirector.shake(0.35, 0.5)
	Fx.burst(SceneManager.current, player.global_position + Vector3(0, 0.3, 0), GOLD, 90, 11.0, 0.18, 0.8)
	player.play_once("attack", 0.5, 1.6)
	for e: Node3D in Game.enemies():
		if e.global_position.distance_to(player.global_position) < 7.0:
			e.take_damage(70.0, player)


## Space toggles flight: tap to lift off and hover, tap again to drop.
func levitate(_delta: float, _jump_held: bool, _on_floor: bool, _since_jump: float) -> bool:
	if player.control and not player.rooted and Input.is_action_just_pressed(&"jump") and not diving:
		set_flying(not flying)
	return flying and not diving


func set_flying(on: bool) -> void:
	flying = on
	if on:
		_rise = 0.45
		Game.hud.toast("Flight on  ·  move where you look  ·  Shift boosts  ·  Space lands", 3.0)


func hud_info() -> Dictionary:
	return {"name": "VISION", "meter": phase, "meter_name": "PHASE", "charge": 0.0, "ult_active": 0.0,
		"slots": [["LMB", "MIND BEAM", 0.0, beaming], ["RMB", "PHASE", 1.0 - phase if not phasing else 0.0, phasing],
			["SPACE", "FLIGHT " + ("ON" if flying else "OFF"), 0.0, flying], ["E", "DENSITY SLAM", slam_cd / SLAM_CD, diving]], "hint": ""}


func cleanup() -> void:
	_beam.visible = false
	_core.visible = false
	beaming = false
	if phasing:
		player.invulnerable = false
		player.rig.set_ghost(false)
		phasing = false
