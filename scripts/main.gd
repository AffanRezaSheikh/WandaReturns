## Main: owns the world host, the player and the UI layer; boots the Library hub.
extends Node

const Player := preload("res://scripts/player/player.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Roster := preload("res://scripts/characters/roster.gd")
const REGION_DIR := "res://scripts/world/regions/"
const Turntable := preload("res://scripts/ui/turntable.gd")
const REGIONS: Array[StringName] = [&"library", &"leonia", &"grove", &"cinderwake", &"glassfen", &"spire", &"arena"]

var player: CharacterBody3D
var hud: Control
var _shots := false


func _ready() -> void:
	_shots = OS.get_cmdline_user_args().has("--shots")
	Game.main = self
	var host := Node3D.new()
	host.name = "WorldHost"
	add_child(host)
	player = Player.new()
	player.name = "Player"
	Game.player = player
	add_child(player)
	var ui := CanvasLayer.new()
	ui.name = "UIRoot"
	add_child(ui)
	hud = Hud.new()
	Game.hud = hud
	ui.add_child(hud)
	hud.visible = not _shots
	var fade := ColorRect.new()
	fade.color = Color(0.05, 0.02, 0.07, 1.0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	for id in REGIONS:
		if ResourceLoader.exists(REGION_DIR + String(id) + ".gd"):
			SceneManager.register_region(id, REGION_DIR + String(id) + ".gd")
	SceneManager.setup(host, player, fade)
	EventBus.region_entered.connect(_on_region_entered)
	if OS.get_cmdline_user_args().has("--selftest"):
		_selftest()
	elif _shots:
		_run_shots()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		SceneManager.go_to(&"library", &"start", true)


func _on_region_entered(_id: StringName) -> void:
	var r := SceneManager.current
	hud.show_title(r.display_name, r.subtitle)
	hud.objective = ""
	hud.marker = null
	hud.map_data = {}
	hud.clock_on = false
	if r.has_method(&"on_enter"):
		r.on_enter()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).physical_keycode
		if k == KEY_I:
			toggle_inspect()
		elif Game.inspect:
			if k == KEY_TAB:
				player.set_character(&"vision" if player.character == &"wanda" else &"wanda")
		elif k >= KEY_1 and k <= KEY_7 and (Game.missions == null or not Game.missions.active):
			SceneManager.go_to(REGIONS[k - KEY_1])
		elif k == KEY_T:                                      # training: summon sparring dead
			for i in 4:
				var f := Basis(Vector3.UP, player.cam_yaw) * Vector3(randf_range(-5, 5), 0.5, -9 - i * 1.5)
				Roster.spawn(SceneManager.current, &"gunman" if i == 3 else &"zombie", player.global_position + f)
			hud.toast("Training: the dead rise")
		elif k == KEY_TAB and (Game.missions == null or not Game.missions.active) and player.driving == null:
			player.set_character(&"vision" if player.character == &"wanda" else &"wanda")
			hud.toast("Now playing: " + String(player.character).capitalize())
		elif e.is_action(&"fullscreen"):
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


## 360-degree inspection view (I). Not available mid-mission or while driving.
func toggle_inspect() -> void:
	if Game.inspect:
		Game.inspect.close()
		Game.inspect = null
	elif (Game.missions == null or not Game.missions.active) and player.driving == null and not SceneManager.busy:
		Game.inspect = Turntable.new()
		add_child(Game.inspect)


func _snap(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://documentation/screens/test_%s.png" % name_)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


## Self-test: `godot --path . -- --selftest` exercises every power and plays
## Chapter 1 on autopilot, printing SELFTEST OK or the stage it stalled on.
func _selftest() -> void:
	Game.autotest = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SceneManager.go_to(&"library", &"start", true)
	while SceneManager.busy:
		await get_tree().process_frame
	var w: Node = player.powers
	var foes: Array = []
	for i in 5:
		foes.append(Roster.spawn(SceneManager.current, &"gunman" if i == 4 else &"zombie", player.global_position + Vector3(-4 + i * 2.0, 0.5, -9)))
	await _wait(1.0)
	w.charge = 4.0
	w._tick_bolt(0.016, true)
	await _snap("charge")
	w._fire_bolt(0.6)
	await _wait(0.6)
	w._cast_shield()
	w._start_ult()
	await _wait(1.2)
	await _snap("ult")
	foes[0].throw(Vector3(0, 4, -20), 55.0)
	foes[1].release()
	foes[1].charm(true)
	await _wait(2.0)
	w.end_ult()
	foes[2].bubble_on(player)
	foes[2].throw(Vector3(6, 3, -18), 45.0)
	foes[4].disarm(3.0)
	await _wait(1.5)
	player.set_character(&"vision")
	await _wait(0.5)
	player.powers._slam()
	await _wait(0.5)
	await _snap("vision")
	player.set_character(&"wanda")
	for e: Node in Game.enemies():
		e.take_damage(9999.0)
	await _wait(0.5)
	SceneManager.go_to(&"arena", &"start", true)
	while SceneManager.busy:
		await get_tree().process_frame
	await _wait(0.5)
	var v: Node = player.powers
	v.set_flying(true)
	for i in 50:                                              # fly forward and up to stretch the cape
		player.velocity = Vector3(0, 3, -11)
		await get_tree().physics_frame
	await _snap("flight")
	v.set_flying(false)
	await _wait(1.5)
	toggle_inspect()
	for shot: Array in [["turn_front", 0.0, 3.4], ["turn_side", PI / 2, 3.4], ["turn_back", PI, 3.4], ["turn_face", 0.35, 1.1]]:
		Game.inspect.spin = false
		Game.inspect.clip = 0 if shot[0] != "turn_face" else 1
		Game.inspect.yaw = shot[1]
		Game.inspect.dist = shot[2]
		await _wait(0.9)
		await _snap(shot[0])
	Game.inspect.clip = 6
	Game.inspect.yaw = 0.7
	Game.inspect.dist = 3.4
	await _wait(0.9)
	await _snap("turn_beam")
	toggle_inspect()
	await _wait(0.3)
	player.set_character(&"wanda")
	print("SELFTEST powers ok")
	SceneManager.go_to(&"leonia", &"start", true)
	while SceneManager.busy:
		await get_tree().process_frame
	var last := -1
	var t0 := Time.get_ticks_msec()
	while GameState.get_flag(&"ch1_stage", 0) < 5 and Time.get_ticks_msec() - t0 < 240000:
		var st: int = GameState.get_flag(&"ch1_stage", 0)
		if st != last:
			last = st
			await _wait(2.5)
			await _snap("stage%d" % st)
		await _wait(0.5)
	await _wait(6.0)
	await _snap("free_roam")
	hud.big_map = true
	await _wait(0.3)
	await _snap("map")
	print("SELFTEST %s stage=%d" % ["OK" if GameState.get_flag(&"ch1_stage", 0) == 5 else "STALLED", GameState.get_flag(&"ch1_stage", 0)])
	get_tree().quit()


## Screenshot harness: `godot --path . -- --shots [region ...]` saves views of regions.
func _run_shots() -> void:
	var cam := Camera3D.new()
	cam.fov = 65
	cam.far = 1500.0
	add_child(cam)
	var want: Array = []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			want.append(StringName(a))
	for id: StringName in SceneManager.order:
		if not want.is_empty() and not want.has(id):
			continue
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
		if id == &"library":                                   # close-ups of both heroes
			for k in 4:
				if k == 2:
					player.set_character(&"vision")
				var f2 := Basis(Vector3.UP, player.model.rotation.y + (0.5 if k % 2 == 0 else 0.3)) * Vector3.FORWARD
				cam.make_current()
				cam.global_position = player.global_position + f2 * (2.7 if k % 2 == 0 else 1.2) + Vector3(0, 1.3 if k % 2 == 0 else 1.75, 0)
				cam.look_at(player.global_position + Vector3(0, 1.0 if k % 2 == 0 else 1.7, 0))
				for fr in 24:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://documentation/screens/hero_%d.png" % k)
			player.set_character(&"wanda")
	get_tree().quit()
