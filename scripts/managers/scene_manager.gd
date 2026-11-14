## SceneManager (autoload): region loading, fade transitions, spawn points.
extends Node

var regions: Dictionary = {}          # id -> script path
var order: Array[StringName] = []
var host: Node3D
var player: CharacterBody3D
var fade: ColorRect
var current: Node3D
var busy := false


func register_region(id: StringName, path: String) -> void:
	regions[id] = path
	order.append(id)


func setup(world_host: Node3D, p: CharacterBody3D, fade_rect: ColorRect) -> void:
	host = world_host
	player = p
	fade = fade_rect


func go_to(id: StringName, spawn: StringName = &"start", instant := false) -> void:
	if busy or not regions.has(id):
		return
	busy = true
	player.control = false
	if not instant:
		var t := create_tween()
		t.tween_property(fade, "color:a", 1.0, 0.4)
		await t.finished
	if current:
		current.queue_free()
		await get_tree().process_frame
	var region: Node3D = (load(regions[id]) as GDScript).new()
	region.region_id = id
	host.add_child(region)
	current = region
	respawn(spawn)
	GameState.current_region = id
	GameState.spawn_id = spawn
	GameState.discover(id)
	EventBus.region_entered.emit(id)
	await get_tree().create_timer(0.25).timeout
	var t2 := create_tween()
	t2.tween_property(fade, "color:a", 0.0, 0.6)
	player.control = true
	busy = false


func respawn(spawn: StringName = &"") -> void:
	var sid := spawn if spawn != &"" else GameState.spawn_id
	var sp: Array = current.spawns.get(sid, current.spawns[&"start"])
	player.teleport(sp[0], sp[1])
