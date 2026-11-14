## VisionPowers: flight (hold jump), Solar Beam (hold LMB), Phase (hold RMB,
## intangible) and Density Slam (E).
extends Node

const B := preload("res://scripts/world/builder.gd")
const Fx := preload("res://scripts/combat/fx.gd")
const SLAM_CD := 10.0
const GOLD := Color("ffe060")

var player: CharacterBody3D
var phase := 1.0
var phasing := false
var slam_cd := 0.0
var diving := false
var levitating := false
var beaming := false
var _beam: MeshInstance3D
var _tick := 0.0


func _ready() -> void:
	_beam = B.cyl(player, 0.05, 0.05, 1.0, Vector3.ZERO, B.glow(GOLD, 6.0), false, 6)
	_beam.top_level = true
	_beam.visible = false


func aiming() -> bool:
	return beaming


func anim_override() -> String:
	return "cast_hold" if beaming else ""


func tick(delta: float) -> void:
	slam_cd = maxf(0.0, slam_cd - delta)
	var live: bool = player.control and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	beaming = live and Input.is_action_pressed(&"bolt") and not phasing
	_beam.visible = beaming
	if beaming:
		var a := Game.aim(70.0)
		var from := player.global_position + Vector3(0, 1.72, 0)
		var to: Vector3 = a.pos
		_beam.global_position = (from + to) * 0.5
		_beam.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT)
		_beam.rotate_object_local(Vector3.RIGHT, PI / 2)
		_beam.scale = Vector3(1.0 + sin(Time.get_ticks_msec() * 0.05) * 0.3, from.distance_to(to), 1.0)
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.1
			var body: Node = a.body
			if body and body.has_method(&"take_damage") and body.is_in_group(&"enemy"):
				body.take_damage(6.0, player)
			if a.hit:
				Fx.burst(SceneManager.current, to, GOLD, 4, 2.0, 0.07, 0.3)
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


## Vision flies for as long as jump is held (no energy limit).
func levitate(_delta: float, jump_held: bool, on_floor: bool, since_jump: float) -> bool:
	levitating = jump_held and not on_floor and since_jump > 0.15 and not diving
	return levitating


func hud_info() -> Dictionary:
	return {"name": "VISION", "meter": phase, "meter_name": "PHASE", "charge": 0.0, "ult_active": 0.0,
		"slots": [["LMB", "SOLAR BEAM", 0.0, beaming], ["RMB", "PHASE", 1.0 - phase if not phasing else 0.0, phasing],
			["SPACE", "FLIGHT", 0.0, levitating], ["E", "DENSITY SLAM", slam_cd / SLAM_CD, diving]], "hint": ""}


func cleanup() -> void:
	_beam.visible = false
	if phasing:
		player.invulnerable = false
		player.rig.set_ghost(false)
		phasing = false
