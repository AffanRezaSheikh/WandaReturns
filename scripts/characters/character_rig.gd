## CharacterRig: loads a Blender-built character (assets/models/<name>.glb),
## swaps every surface to the cel-shaded toon material (+ ink outline) and
## exposes a small animation API. Clothes/skin/hair can be recoloured per instance.
extends Node3D

const TOON := preload("res://assets/shaders/toon.gdshader")
const OUTLINE := preload("res://assets/shaders/outline.gdshader")
const HARD := ["skin", "hair", "hair2", "eye_w", "iris", "pupil", "brow", "lips", "headgear", "headtex", "trim_teal", "line"]
const NO_OUTLINE := ["eye_w", "iris", "pupil", "brow", "lips", "gem", "line"]
const THIN_OUTLINE := ["vision"]            # detailed realistic meshes need a finer ink line
const LOOPS := ["idle", "walk", "run", "shamble", "air", "hover", "fly", "charge", "beam", "talk", "held", "sit", "apose"]
static var _outline_mats: Dictionary = {}

var model_name := "wanda"
var recolor: Dictionary = {}
var anim: AnimationPlayer
var mats: Array[ShaderMaterial] = []
var skeleton: Skeleton3D
var cloth: SpringBoneSimulator3D
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
	var ow := 0.0045 if THIN_OUTLINE.has(model_name) else 0.011
	if not _outline_mats.has(ow):
		var om := ShaderMaterial.new()
		om.shader = OUTLINE
		om.set_shader_parameter("width", ow)
		_outline_mats[ow] = om
	var _outline_mat: ShaderMaterial = _outline_mats[ow]
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var nm := String(src.resource_name) if src else ""
			var m := ShaderMaterial.new()
			m.shader = TOON
			var col: Color = recolor.get(nm, src.albedo_color if src else Color.WHITE)
			m.set_shader_parameter("albedo", col)
			var hard := HARD.has(nm)
			if src and src.albedo_texture and not recolor.has(nm):
				m.set_shader_parameter("use_tex", true)
				m.set_shader_parameter("tex", src.albedo_texture)
				m.set_shader_parameter("vcol", 1.0 if nm != "cape" else 0.0)
			m.set_shader_parameter("softness", 0.02 if hard else 0.24)
			m.set_shader_parameter("band", 0.42 if nm == "skin" else 0.5)
			m.set_shader_parameter("grad", 0.0 if (hard or nm == "bodytex") else (0.9 if nm == "cape" else 0.45))
			m.set_shader_parameter("shade_tint", Color(0.78, 0.58, 0.6) if nm == "skin" else Color(0.55, 0.42, 0.6))
			if src and src.emission_enabled and (nm == "gem" or nm == "eye_w"):
				m.set_shader_parameter("glow", 0.45 if model_name == "vision" else 1.0)
			if not NO_OUTLINE.has(nm):
				m.next_pass = _outline_mat
			mi.set_surface_override_material(s, m)
			mats.append(m)
	skeleton = inst.find_child("Skeleton3D", true, false)
	_setup_cloth()
	anim = inst.find_child("AnimationPlayer", true, false)
	for n in anim.get_animation_list():
		if LOOPS.has(String(n)):
			anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	play("idle", 0.0)


## Cape physics: five spring-bone chains follow the body with lag, drag and gravity.
func _setup_cloth() -> void:
	if skeleton == null or skeleton.find_bone("cape_0_1") < 0:
		return
	cloth = SpringBoneSimulator3D.new()
	skeleton.add_child(cloth)
	cloth.setting_count = 5
	for c in 5:
		cloth.set_root_bone_name(c, "cape_%d_1" % c)
		cloth.set_end_bone_name(c, "cape_%d_4" % c)
		cloth.set_extend_end_bone(c, true)
		cloth.set_end_bone_length(c, 0.3)
		cloth.set_stiffness(c, 1.6)
		cloth.set_drag(c, 0.32)
		cloth.set_gravity(c, 0.9)
		cloth.set_radius(c, 0.03)


func reset_cloth() -> void:
	if cloth:
		cloth.reset()


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
