## FeelDirector (autoload): the only place that triggers camera shake.
## Hit-stop / time-scale tiers are added with the combat milestone.
extends Node

var _shake := 0.0
var _decay := 1.0


func shake(amount: float, dur: float) -> void:
	_shake = maxf(_shake, amount)
	_decay = amount / maxf(dur, 0.01)


func offset() -> Vector2:
	if _shake <= 0.0:
		return Vector2.ZERO
	return Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - _decay * delta)
