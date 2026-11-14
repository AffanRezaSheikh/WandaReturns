## InputConfig (autoload): registers default actions in code (rebindable later).
extends Node

const KEYS := {
	&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
	&"sprint": [KEY_SHIFT], &"jump": [KEY_SPACE], &"dash": [KEY_CTRL], &"interact": [KEY_F],
	&"shield": [KEY_R], &"ult": [KEY_E], &"map": [KEY_M], &"advance": [KEY_ENTER, KEY_F],
	&"pause": [KEY_ESCAPE], &"fullscreen": [KEY_F11],
}
const MOUSE := {&"bolt": MOUSE_BUTTON_LEFT, &"sphere": MOUSE_BUTTON_RIGHT}


func _ready() -> void:
	reset_defaults()


func reset_defaults() -> void:
	for action: StringName in KEYS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		for code: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	for action: StringName in MOUSE:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE[action]
		InputMap.action_add_event(action, mb)
