## CharacterRig: loads a Blender-built character (assets/models/<name>.glb),
## swaps every surface to the cel-shaded toon material (+ ink outline) and
## exposes a small animation API. Clothes/skin/hair can be recoloured per instance.
extends Node3D

const TOON := preload("res://assets/shaders/toon.gdshader")
const OUTLINE := preload("res://assets/shaders/outline.gdshader")
const HARD := ["skin", "hair", "hair2", "eye_w", "iris", "pupil", "brow", "lips", "headgear"]
const NO_OUTLINE := ["eye_w", "iris", "pupil", "brow", "lips", "gem"]
const LOOPS := ["idle", "walk", "run", "shamble", "air", "hover", "fly", "charge", "talk", "held", "sit"]
static var _outline_mat: ShaderMaterial

var model_name := "wanda"
var recolor: Dictionary = {}
var anim: AnimationPlayer
var mats: Array[ShaderMaterial] = []
var _current := ""


static func make(model: String, colors: Dictionary = {}) -> Node3D:
	var r: Node3D = load("res://scripts/characters/character_rig.gd").new()
	r.model_name = model
	r.recolor = colors
	return r


func _ready() -> void:
	var inst: Node3D = (load("res://assets/models/%s.glb" % model_name) as PackedScene).instantiate()
	inst.rotation.y = PI                       # Blender front (-Y) arrives as +Z; the game faces -Z
	add_child(inst)
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = OUTLINE
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var nm := String(src.resource_name) if src else ""
			var m := ShaderMaterial.new()
			m.shader = TOON
			var col: Color = recolor.get(nm, src.albedo_color if src else Color.WHITE)
			m.set_shader_parameter("albedo", col)
			var hard := HARD.has(nm)
			m.set_shader_parameter("softness", 0.02 if hard else 0.24)
			m.set_shader_parameter("band", 0.42 if nm == "skin" else 0.5)
			m.set_shader_parameter("grad", 0.0 if hard else (0.9 if nm == "cape" else 0.45))
			m.set_shader_parameter("shade_tint", Color(0.78, 0.58, 0.6) if nm == "skin" else Color(0.55, 0.42, 0.6))
			if src and src.emission_enabled and (nm == "gem" or nm == "eye_w"):
				m.set_shader_parameter("glow", 1.0)
			if not NO_OUTLINE.has(nm):
				m.next_pass = _outline_mat
			mi.set_surface_override_material(s, m)
			mats.append(m)
	anim = inst.find_child("AnimationPlayer", true, false)
	for n in anim.get_animation_list():
		if LOOPS.has(String(n)):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	play("idle", 0.0)


func play(key: String, blend := 0.2, speed := 1.0, restart := false) -> void:
	if anim == null or not anim.has_animation(key):
		return
	if _current != key or restart:
		if restart:
			anim.stop()
		anim.play(key, blend)
		_current = key
	anim.speed_scale = speed


func current() -> String:
	return _current


func set_param(param: String, value: Variant) -> void:
	for m in mats:
		m.set_shader_parameter(param, value)


func flash(col := Color(1, 1, 1), strength := 0.9, time := 0.18) -> void:
	set_param("flash_color", col)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: set_param("flash", v), strength, 0.0, time)


func set_ghost(on: bool) -> void:
	set_param("ghost", on)
