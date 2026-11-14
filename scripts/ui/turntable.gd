## Turntable: 360-degree character inspection. Lifts the hero into a neutral
## studio, spins the model and lets the camera orbit and zoom.
## Mouse orbits, wheel zooms, A/D change the pose, Space pauses the spin, I exits.
extends Node3D

const B := preload("res://scripts/world/builder.gd")
const CLIPS := ["apose", "idle", "walk", "run", "hover", "fly", "beam", "cast", "charge", "attack"]

var player: CharacterBody3D
var cam: Camera3D
var clip := 1
var spin := true
var yaw := 0.0
var cam_yaw := 0.0
var cam_pitch := -0.05
var dist := 3.4
var _home := Vector3.ZERO
var _home_yaw := 0.0


func _ready() -> void:
	player = Game.player
	_home = player.global_position
	_home_yaw = player.model.rotation.y
	player.inspecting = true
	player.powers.cleanup()
	player.global_position = _home + Vector3(0, 400, 0)
	global_position = player.global_position
	var m := StandardMaterial3D.new()                         # studio backdrop seen from inside
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.albedo_color = Color("3a3440")
	var s := SphereMesh.new()
	s.radius = 14.0
	s.height = 28.0
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	add_child(mi)
	B.cyl(self, 1.5, 1.6, 0.12, Vector3(0, -0.06, 0), B.mat(Color("57505e"), 0.7), false, 40)
	B.torus(self, 1.5, 1.58, Vector3(0, 0.01, 0), B.glow(Color("f0b04a"), 0.8), Vector3.ZERO, 48)
	B.omni(self, Vector3(-2.2, 2.6, -2.6), Color("fff2e0"), 1.3, 9.0)
	B.omni(self, Vector3(2.6, 1.4, -1.8), Color("cfe0ff"), 0.5, 8.0)
	B.omni(self, Vector3(1.2, 2.6, 2.6), Color("ffd0d8"), 0.8, 8.0)
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.make_current()
	player.rig.reset_cloth()


func close() -> void:
	player.global_position = _home
	player.model.rotation.y = _home_yaw
	player.inspecting = false
	player.cam.make_current()
	player.rig.anim.speed_scale = 1.0
	player.rig.reset_cloth()
	queue_free()


func clip_name() -> String:
	return CLIPS[clip]


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := e as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.004
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.004, -1.2, 0.6)
	elif e is InputEventMouseButton and e.pressed:
		var b := (e as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(0.7, dist - 0.25)
		elif b == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(7.0, dist + 0.25)
	elif e.is_action_pressed(&"move_right"):
		clip = (clip + 1) % CLIPS.size()
	elif e.is_action_pressed(&"move_left"):
		clip = (clip - 1 + CLIPS.size()) % CLIPS.size()
	elif e.is_action_pressed(&"jump"):
		spin = not spin


func _process(delta: float) -> void:
	if spin:
		yaw += delta * 0.7
	player.model.rotation.y = yaw
	var rig: Node3D = player.rig
	if rig.current() != CLIPS[clip] or not rig.anim.is_playing():
		rig.play(CLIPS[clip], 0.25, 1.0, not rig.anim.is_playing())
	var focus := global_position + Vector3(0, lerpf(1.0, 1.55, clampf((3.0 - dist) / 2.3, 0.0, 1.0)), 0)
	var dir := Basis(Vector3.UP, cam_yaw) * Basis(Vector3.RIGHT, cam_pitch) * Vector3(0, 0, -1)
	cam.global_position = focus + dir * dist
	cam.look_at(focus)
