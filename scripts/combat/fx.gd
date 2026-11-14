## Fx: one-shot visual effects (bursts, flashes, floating text).
extends RefCounted

const B := preload("res://scripts/world/builder.gd")


static func burst(parent: Node, pos: Vector3, color: Color, amount := 24, speed := 6.0, size := 0.12, life := 0.6) -> void:
	var c := B.motes(parent, pos, Vector3.ONE * 0.1, color, amount, life, Vector3.UP * speed, size, 0.8)
	c.spread = 180.0
	c.preprocess = 0.0
	c.one_shot = true
	c.explosiveness = 0.95
	c.gravity = Vector3(0, -6, 0)
	c.restart()
	var l := B.omni(parent, pos, color, 4.0, 7.0)
	var t := parent.create_tween()
	t.tween_property(l, "light_energy", 0.0, 0.35)
	t.tween_callback(l.queue_free)
	parent.get_tree().create_timer(life + 0.3).timeout.connect(c.queue_free)


static func text(parent: Node, pos: Vector3, msg: String, color := Color.WHITE, size := 40) -> void:
	var l := Label3D.new()
	l.text = msg
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.outline_size = 10
	l.modulate = color
	l.pixel_size = 0.006
	l.position = pos
	parent.add_child(l)
	var t := parent.create_tween()
	t.tween_property(l, "position:y", pos.y + 1.2, 0.9)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	t.tween_callback(l.queue_free)
