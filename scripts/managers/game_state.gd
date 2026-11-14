## GameState (autoload): single source of truth for runtime state.
## The world pass only needs region + flags; stats arrive with combat.
extends Node

var current_region: StringName = &""
var spawn_id: StringName = &"start"
var flags: Dictionary = {}
var discovered: Array[StringName] = []


func set_flag(k: StringName, v: Variant) -> void:
	flags[k] = v
	EventBus.flag_set.emit(k, v)


func get_flag(k: StringName, default: Variant = null) -> Variant:
	return flags.get(k, default)


func has_flag(k: StringName) -> bool:
	return flags.has(k)


func discover(region_id: StringName) -> void:
	if not discovered.has(region_id):
		discovered.append(region_id)
