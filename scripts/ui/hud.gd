## HUD: crosshair, health, ability slots with cooldowns, charge and levitation
## meters, boss bar, objective, toasts, dialogue box, clock and the Leonia minimap.
## Reads state from Game/player; holds no game data of its own.
extends Control

signal advanced

const CRIMSON := Color("e8374a")
const GOLD := Color("f0b04a")
const INK := Color(0.07, 0.03, 0.09, 0.82)
const IVORY := Color("f4ead8")

var font: SystemFont
var objective := ""
var title := ""
var subtitle := ""
var map_data: Dictionary = {}
var marker: Variant = null          # Vector3 or null
var marker_name := ""
var big_map := false
var clock_on := false
var _toast := ""
var _toast_t := 0.0
var _title_t := 0.0
var _hurt := 0.0
var _speaker := ""
var _line := ""
var _talking := false
var _shown := 0.0
var _talk_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Futura", "Helvetica Neue", "Arial"])
	font.font_weight = 700


func toast(msg: String, time := 3.0) -> void:
	_toast = msg
	_toast_t = time


func show_title(t: String, sub: String) -> void:
	title = t
	subtitle = sub
	_title_t = 4.5


func hurt() -> void:
	_hurt = 1.0


## Shows one line of dialogue and waits until the player advances it.
func say(speaker: String, line: String) -> void:
	_speaker = speaker
	_line = line
	_shown = 0.0
	_talk_t = 0.0
	_talking = true
	if Game.autotest:
		await get_tree().create_timer(0.12).timeout
		_talking = false
		return
	await advanced
	_talking = false


func talking() -> bool:
	return _talking


func _unhandled_input(e: InputEvent) -> void:
	if _talking and (e.is_action_pressed(&"advance") or e.is_action_pressed(&"bolt") or e.is_action_pressed(&"jump")):
		get_viewport().set_input_as_handled()
		if _shown < _line.length():
			_shown = _line.length()
		elif _talk_t > 0.25:
			advanced.emit()
	elif e.is_action_pressed(&"map") and not map_data.is_empty():
		big_map = not big_map


func _process(delta: float) -> void:
	_toast_t -= delta
	_title_t -= delta
	_hurt = maxf(0.0, _hurt - delta * 1.8)
	if _talking:
		_shown += delta * 55.0
		_talk_t += delta
	queue_redraw()


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, pos, s, align, width, size, maxi(3, size / 5), Color(0.05, 0.02, 0.07, col.a * 0.9))
	draw_string(font, pos, s, align, width, size, col)


func _bar(r: Rect2, frac: float, col: Color) -> void:
	draw_rect(r.grow(3), INK)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	draw_rect(r.grow(3), GOLD, false, 2.0)


func _draw() -> void:
	var p := Game.player
	if p == null:
		return
	var w := size.x
	var h := size.y
	if _hurt > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.05, 0.1, _hurt * 0.25))
	var info: Dictionary = p.powers.hud_info()
	if p.driving == null and not _talking:
		var c := size * 0.5 + Vector2(p.cam.h_offset * 0.0, 0)
		draw_arc(c, 9.0, 0, TAU, 24, Color(1, 1, 1, 0.85), 2.0)
		draw_circle(c, 2.0, CRIMSON)
		if info.charge > 0.0:
			draw_arc(c, 22.0, -PI / 2, -PI / 2 + TAU * info.charge, 48, CRIMSON if info.charge < 1.0 else GOLD, 5.0)
		if info.hint != "":
			_text(c + Vector2(-300, 70), info.hint, 20, IVORY, HORIZONTAL_ALIGNMENT_CENTER, 600)
	# health + meter
	_text(Vector2(40, h - 96), info.name, 22, CRIMSON)
	_bar(Rect2(40, h - 84, 320, 18), p.hp / p.max_hp, CRIMSON)
	if p.shield_hp > 0.0:
		draw_rect(Rect2(40, h - 84, 320 * p.shield_hp / 70.0, 5), Color("ff9aa8"))
	_bar(Rect2(40, h - 52, 200, 9), info.meter, Color("d8c8ff"))
	_text(Vector2(252, h - 42), info.meter_name, 13, Color("d8c8ff"))
	# ability slots
	var slots: Array = info.slots
	var sw := 150.0
	var x0 := w * 0.5 - sw * slots.size() * 0.5
	for i in slots.size():
		var s: Array = slots[i]
		var r := Rect2(x0 + i * sw + 6, h - 96, sw - 12, 58)
		draw_rect(r, INK)
		if s[2] > 0.0:
			draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(s[2], 0.0, 1.0), r.size.y)), Color(0.25, 0.08, 0.14, 0.9))
		draw_rect(r, GOLD if s[3] else (CRIMSON if s[2] <= 0.0 else Color(0.4, 0.3, 0.4)), false, 3.0 if s[3] else 2.0)
		_text(r.position + Vector2(10, 22), s[0], 15, GOLD)
		_text(r.position + Vector2(10, 46), s[1], 16, IVORY if s[2] <= 0.0 else Color(0.6, 0.55, 0.6))
	if info.ult_active > 0.0:
		_bar(Rect2(w * 0.5 - 200, h - 122, 400, 10), info.ult_active, GOLD)
	# boss bar
	for e: Node in Game.enemies():
		if e.get(&"is_boss") and e.is_alive():
			_text(Vector2(w * 0.5 - 300, 62), e.display_name.to_upper(), 22, IVORY, HORIZONTAL_ALIGNMENT_CENTER, 600)
			_bar(Rect2(w * 0.5 - 300, 74, 600, 14), e.hp / e.max_hp, Color("9a3fd0"))
			break
	# objective, clock, toast, title
	if objective != "":
		draw_rect(Rect2(28, 28, 12, 44), GOLD)
		_text(Vector2(52, 48), "OBJECTIVE", 14, GOLD)
		_text(Vector2(52, 72), objective, 22, IVORY)
		if marker != null:
			var d := p.global_position.distance_to(marker)
			_text(Vector2(52, 96), "%s  ·  %d m" % [marker_name, int(d)], 15, Color("c4b8bd"))
	if clock_on:
		var hh := int(Game.time_of_day)
		var mm := int((Game.time_of_day - hh) * 60.0)
		_text(Vector2(w - 250, 262), "%02d:%02d" % [hh, mm], 20, IVORY, HORIZONTAL_ALIGNMENT_RIGHT, 220)
	if _toast_t > 0.0:
		_text(Vector2(w * 0.5 - 500, 150), _toast, 26, Color(GOLD.r, GOLD.g, GOLD.b, clampf(_toast_t, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 1000)
	if _title_t > 0.0:
		var a := clampf(minf(_title_t, 4.5 - _title_t) * 1.2, 0.0, 1.0)
		_text(Vector2(0, h * 0.3), title, 68, Color(0.96, 0.35, 0.35, a), HORIZONTAL_ALIGNMENT_CENTER, w)
		_text(Vector2(0, h * 0.3 + 44), subtitle, 24, Color(IVORY.r, IVORY.g, IVORY.b, a), HORIZONTAL_ALIGNMENT_CENTER, w)
	_draw_marker(p)
	if not map_data.is_empty():
		if big_map:
			_draw_map(Rect2(w * 0.5 - 380, h * 0.5 - 380, 760, 760), float(map_data.half), Vector2.ZERO, true)
		else:
			var pp := Vector2(p.global_position.x, p.global_position.z)
			_draw_map(Rect2(w - 250, 28, 220, 220), 95.0, pp, false)
	if _talking:
		var r := Rect2(w * 0.5 - 520, h - 250, 1040, 130)
		draw_rect(r, INK)
		draw_rect(r, CRIMSON, false, 3.0)
		draw_rect(Rect2(r.position + Vector2(24, -18), Vector2(maxf(160.0, _speaker.length() * 17.0), 36)), CRIMSON)
		_text(r.position + Vector2(36, 8), _speaker.to_upper(), 20, IVORY)
		draw_multiline_string(font, r.position + Vector2(36, 56), _line.substr(0, int(_shown)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 72, 23, 3, IVORY)
		_text(r.position + Vector2(r.size.x - 260, r.size.y - 14), "ENTER / CLICK  ▸", 14, GOLD)


func _draw_marker(p: Node3D) -> void:
	if marker == null or _talking or big_map:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var target: Vector3 = marker + Vector3(0, 2.5, 0)
	if cam.is_position_behind(target):
		return
	var sp := cam.unproject_position(target)
	sp = sp.clamp(Vector2(40, 40), size - Vector2(40, 140))
	draw_colored_polygon(PackedVector2Array([sp + Vector2(0, 14), sp + Vector2(-11, -6), sp + Vector2(11, -6)]), GOLD)
	_text(sp + Vector2(-100, -14), "%d m" % int(p.global_position.distance_to(marker)), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 200)


func _draw_map(r: Rect2, half: float, centre: Vector2, full: bool) -> void:
	draw_rect(r, Color(0.1, 0.16, 0.12, 0.92))
	var sc := r.size.x / (half * 2.0)
	var o := r.position + r.size * 0.5
	var to_map := func(v: Vector2) -> Vector2: return o + (v - centre) * sc
	for b: Array in map_data.blocks:
		var br: Rect2 = b[0]
		var q := Rect2(to_map.call(br.position), br.size * sc).intersection(r)
		if q.size.x > 0 and q.size.y > 0:
			draw_rect(q, b[1])
	for road: Rect2 in map_data.roads:
		var q2 := Rect2(to_map.call(road.position), road.size * sc).intersection(r)
		if q2.size.x > 0 and q2.size.y > 0:
			draw_rect(q2, Color(0.3, 0.29, 0.34))
	for poi: Array in map_data.pois:
		var pt: Vector2 = to_map.call(poi[0])
		if r.has_point(pt):
			draw_circle(pt, 5.0 if full else 4.0, poi[2])
			if full:
				_text(pt + Vector2(9, 5), poi[1], 14, IVORY)
	if marker != null:
		var mp: Vector2 = to_map.call(Vector2(marker.x, marker.z))
		mp = mp.clamp(r.position + Vector2(8, 8), r.end - Vector2(8, 8))
		draw_circle(mp, 8.0, GOLD)
		draw_circle(mp, 4.0, INK)
	var p := Game.player
	var pm: Vector2 = to_map.call(Vector2(p.global_position.x, p.global_position.z))
	var yaw: float = p.model.rotation.y
	var f := Vector2(-sin(yaw), -cos(yaw))
	var s := Vector2(-f.y, f.x)
	draw_colored_polygon(PackedVector2Array([pm + f * 11.0, pm - f * 7.0 + s * 7.0, pm - f * 7.0 - s * 7.0]), CRIMSON)
	draw_rect(r, GOLD, false, 2.0)
	if full:
		_text(r.position + Vector2(16, 30), "LEONIA, NEW JERSEY", 22, GOLD)
		_text(r.position + Vector2(16, r.size.y - 14), "M  close map", 14, IVORY)
