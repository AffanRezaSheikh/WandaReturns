## Game (autoload): shared references (player, HUD, missions) and aim helpers.
extends Node

var main: Node
var player: CharacterBody3D
var hud: Control
var missions: Node
var time_of_day := 9.0          # hours, persists between regions
var paused_time := false
var autotest := false           # self-test: story plays itself


func enemies() -> Array:
	return get_tree().get_nodes_in_group(&"enemy")


func allies() -> Array:
	return get_tree().get_nodes_in_group(&"ally")


## World point under the crosshair: {pos, hit, body}.
func aim(max_dist := 60.0) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from + dir * 1.0, from + dir * max_dist)
	q.exclude = [player.get_rid()]
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {"pos": from + dir * max_dist, "hit": false, "body": null, "dir": dir}
	return {"pos": r.position, "hit": true, "body": r.collider, "dir": dir}


## Enemy closest to the crosshair (angle), optionally filtered.
func enemy_near_crosshair(filter: Callable, max_angle := 0.35) -> Node3D:
	var cam := get_viewport().get_camera_3d()
	var best: Node3D = null
	var best_a := max_angle
	for e: Node3D in enemies() + allies():
		if e == player or not filter.call(e):
			continue
		var to := (e.global_position + Vector3(0, 1.0, 0) - cam.global_position).normalized()
		var a := acos(clampf(to.dot(-cam.global_transform.basis.z), -1.0, 1.0))
		if a < best_a:
			best_a = a
			best = e
	return best
