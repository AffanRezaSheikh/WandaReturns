## Main: owns the world host, the player and the UI layer; boots the first region.
extends Node

const Player := preload("res://scripts/player/player.gd")
const REGION_DIR := "res://scripts/world/regions/"
const REGIONS: Array[StringName] = [&"grove", &"cinderwake", &"glassfen", &"archive", &"spire"]

var player: CharacterBody3D
var title: Label
var subtitle: Label
var _shots := false


func _ready() -> void:
	_shots = OS.get_cmdline_user_args().has("--shots")
	var host := Node3D.new()
	host.name = "WorldHost"
	add_child(host)
	player = Player.new()
	player.name = "Wanda"
	add_child(player)
	var ui := CanvasLayer.new()
	ui.name = "UIRoot"
	add_child(ui)
	title = _label(ui, 64, Color("f55a5a"), 0.30)
	subtitle = _label(ui, 22, Color("f4ead8"), 0.42)
	var hint := _label(ui, 15, Color("c4b8bd"), 0.955)
	hint.text = "WASD move   ·   Mouse look   ·   Shift sprint   ·   Space jump   ·   Ctrl dash   ·   1-5 travel   ·   Esc free mouse"
	hint.visible = not _shots
	var fade := ColorRect.new()
	fade.color = Color(0.05, 0.02, 0.07, 1.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	for id in REGIONS:
		SceneManager.register_region(id, REGION_DIR + String(id) + ".gd")
	SceneManager.setup(host, player, fade)
	EventBus.region_entered.connect(_on_region_entered)
	if _shots:
		_run_shots()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		SceneManager.go_to(&"grove", &"start", true)


func _label(parent: Node, size: int, col: Color, y: float) -> Label:
	var l := Label.new()
	var s := LabelSettings.new()
	s.font_size = size
	s.font_color = col
	s.outline_size = maxi(4, size / 6)
	s.outline_color = Color(0.05, 0.02, 0.07, 0.9)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_offset = Vector2(0, 3)
	l.label_settings = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y
	l.anchor_bottom = y
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _on_region_entered(_id: StringName) -> void:
	var r := SceneManager.current
	title.text = r.display_name
	subtitle.text = r.subtitle
	if _shots:
		title.modulate.a = 0.0
		subtitle.modulate.a = 0.0
		return
	for l: Label in [title, subtitle]:
		l.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.6)
		t.tween_property(l, "modulate:a", 1.0, 0.8)
		t.tween_interval(2.4)
		t.tween_property(l, "modulate:a", 0.0, 1.2)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_5:
			SceneManager.go_to(REGIONS[k - KEY_1])
		elif e.is_action("fullscreen"):
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


## Screenshot harness: `godot --path . -- --shots` saves views of every region.
func _run_shots() -> void:
	var cam := Camera3D.new()
	cam.fov = 65
	add_child(cam)
	for id in REGIONS:
		SceneManager.go_to(id, &"start", true)
		while SceneManager.busy:
			await get_tree().process_frame
		SceneManager.fade.color.a = 0.0
		var r := SceneManager.current
		for i in range(r.shots.size() + 1):
			if i == 0:
				player.cam.make_current()
			else:
				cam.make_current()
				cam.global_position = r.shots[i - 1][0]
				cam.look_at(r.shots[i - 1][1])
			for f in 50:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://documentation/screens/%s_%d.png" % [id, i])
		if id == &"grove":                                     # close-ups of Wanda
			for k in 4:
				var f := Basis(Vector3.UP, player.model.rotation.y + [0.5, 2.6, 0.9, 0.9][k]) * Vector3.FORWARD
				cam.global_position = player.global_position + f * (1.1 if k == 3 else 2.6) + Vector3(0, 1.65 if k == 3 else 1.25, 0)
				cam.look_at(player.global_position + Vector3(0, 1.6 if k == 3 else 1.0, 0))
				player.set_physics_process(k != 2)
				for fr in 24:
					if k == 2:
						player.model.animate(0.016, 7.0, true)
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://documentation/screens/wanda_%d.png" % k)
	get_tree().quit()
