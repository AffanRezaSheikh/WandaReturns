## WandaRig: the Blender-built, rigged Wanda (assets/models/wanda.glb).
## Picks and blends the animation clip from the player's movement state.
## Rebuild the model with tools/blender/build.sh.
extends Node3D

const B := preload("res://scripts/world/builder.gd")
const MODEL := "res://assets/models/wanda.glb"

var anim: AnimationPlayer
var aura: OmniLight3D
var _clips: Dictionary = {}
var _current := ""
var _t := 0.0


func _ready() -> void:
	var inst: Node3D = (load(MODEL) as PackedScene).instantiate()
	inst.rotation.y = PI                       # Blender front (-Y) arrives as +Z; the game faces -Z
	add_child(inst)
	anim = inst.find_child("AnimationPlayer", true, false)
	for n in anim.get_animation_list():
		var key := String(n).split("-")[0]
		_clips[key] = n
		if String(n).ends_with("loop"):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	aura = B.omni(self, Vector3(0, 0.9, 0.5), Color("ff5060"), 0.12, 2.5)
	B.omni(self, Vector3(0, 2.4, 1.6), Color("fff0e8"), 0.8, 5.0)      # soft key light so she always reads
	_play("idle", 0.0, 1.0)


func _play(key: String, blend: float, speed: float) -> void:
	if not _clips.has(key):
		return
	if _current != key:
		anim.play(_clips[key], blend)
		_current = key
	anim.speed_scale = speed


func animate(delta: float, speed: float, on_floor: bool, dashing := false) -> void:
	_t += delta
	if dashing:
		_play("dash", 0.06, 1.0)
	elif not on_floor:
		_play("air", 0.15, 1.0)
	elif speed > 4.6:
		_play("run", 0.18, clampf(speed / 6.6, 0.8, 1.4))
	elif speed > 0.35:
		_play("walk", 0.2, clampf(speed / 2.6, 0.6, 1.5))
	else:
		_play("idle", 0.25, 1.0)
	aura.light_energy = 0.12 + sin(_t * 2.2) * 0.04 + (0.2 if speed > 4.6 else 0.0)


func cast() -> void:
	_current = ""
	if _clips.has("cast"):
		anim.play(_clips["cast"], 0.1)
		_current = "cast"
