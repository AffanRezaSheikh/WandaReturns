## EventBus (autoload): typed global signals only, zero logic.
extends Node

signal region_entered(region_id: StringName)
signal flag_set(key: StringName, value: Variant)
signal player_respawned
