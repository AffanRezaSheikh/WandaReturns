## Missions: Chapter 1, adapted from Vision and the Scarlet Witch (1985) #1 -
## same events and villains, newly written dialogue. Five missions, then free roam.
## Stage is kept in GameState.flags[&"ch1_stage"] (0-4 missions, 5 = free roam).
extends Node

const Roster := preload("res://scripts/characters/roster.gd")
const Citizen := preload("res://scripts/leonia/citizen.gd")
const Fx := preload("res://scripts/combat/fx.gd")
const B := preload("res://scripts/world/builder.gd")
const TITLES := ["The Hearing", "A Place of Our Own", "The Dead Walk", "Vision Alone", "Graveyard of the Unliving"]

var town: Node3D
var active := false
var stage := 0
var _cp := Vector3.ZERO
var _cp_yaw := 0.0
var _cp_set := false
var _beacon: Node3D
var _vision: Node3D
var _extras: Array = []
var _night_done := -1


func begin() -> void:
	stage = GameState.get_flag(&"ch1_stage", 0)
	_beacon = Node3D.new()
	B.cyl(_beacon, 0.9, 0.9, 40.0, Vector3(0, 20, 0), B.glass(Color("ffd060"), 0.22, 1.5), false, 10)
	B.torus(_beacon, 1.6, 1.8, Vector3(0, 0.15, 0), B.glow(Color("ffd060"), 3.0), Vector3.ZERO, 24)
	_beacon.visible = false
	town.add_child(_beacon)
	_offer()


func has_checkpoint() -> bool:
	return _cp_set and active


func restore_checkpoint() -> void:
	Game.player.teleport(_cp, _cp_yaw)


func _checkpoint(pos: Vector3, yaw := 0.0) -> void:
	_cp = pos
	_cp_yaw = yaw
	_cp_set = true


# ------------------------------------------------------------------ helpers
func _tick(t := 0.15) -> void:
	await get_tree().create_timer(t).timeout


func _goto(text: String, pos: Vector3, radius := 4.0, label := "") -> void:
	Game.hud.objective = text
	Game.hud.marker = pos
	Game.hud.marker_name = label
	_beacon.position = pos
	_beacon.visible = true
	if Game.autotest:
		await _tick(0.3)
		if Game.player.driving:
			Game.player.driving.global_position = pos + Vector3(0, 0.6, 0)
		else:
			Game.player.teleport(pos + Vector3(0, 0.5, 0), 0.0)
	while true:
		var p := Game.player.global_position
		if Vector2(p.x - pos.x, p.z - pos.z).length() < radius:
			break
		await _tick()
	_beacon.visible = false
	Game.hud.marker = null


func _say(lines: Array) -> void:
	var p := Game.player
	p.control = false
	p.powers.cleanup()
	for l: Array in lines:
		await Game.hud.say(l[0], l[1])
	p.control = true


func _fade(dark: bool, time := 0.7) -> void:
	var t := create_tween()
	t.tween_property(SceneManager.fade, "color:a", 1.0 if dark else 0.0, time)
	await t.finished


func _spawn(type: StringName, pos: Vector3) -> Node3D:
	Fx.burst(town, pos + Vector3(0, 0.6, 0), Color("60ff80"), 16, 3.0)
	return Roster.spawn(town, type, pos + Vector3(0, 0.4, 0))


func _fight(text: String, list: Array) -> void:
	Game.hud.objective = text
	var mine: Array = []
	for e: Array in list:
		mine.append(_spawn(e[0], e[1]))
	while true:
		if Game.autotest:                                       # kill in two batches so corpses are freed mid-fight
			await _tick(1.0)
			var foes := Game.enemies()
			for k in foes.size():
				if k % 2 == 0 or foes.size() < 3:
					foes[k].take_damage(99999.0)
			await _tick(6.5 if foes.size() >= 3 else 0.2)
		var alive := 0
		for m in mine:                                          # untyped: dead fighters are freed after a few seconds
			if is_instance_valid(m) and m.is_alive():
				alive += 1
		for e2: Node in Game.enemies():                       # summoned extras count too
			if not mine.has(e2) and e2.is_alive() and not e2.get(&"charmed"):
				alive += 1
		if alive == 0:
			break
		await _tick(0.3)


func _ring(c: Vector3, n: int, r: float, type: StringName = &"zombie") -> Array:
	var out: Array = []
	for i in n:
		var a := i * TAU / n + randf() * 0.5
		out.append([type, c + Vector3(cos(a) * r, 0, sin(a) * r)])
	return out


func _citizen(pos: Vector3, mood := "calm") -> Node3D:
	var c := Citizen.new()
	c.mood = mood
	town.add_child(c)
	c.global_position = pos
	_extras.append(c)
	return c


func _clear_extras() -> void:
	for e in _extras:
		if is_instance_valid(e):
			e.queue_free()
	_extras.clear()


func _summon_vision(pos: Vector3, passive := false) -> void:
	if is_instance_valid(_vision):
		_vision.queue_free()
	_vision = Roster.spawn(town, &"vision_ally", pos)
	_vision.passive = passive


func _clear_enemies() -> void:
	for e: Node in Game.enemies():
		e.queue_free()


func _set_time(t: float, paused := true) -> void:
	Game.time_of_day = t
	Game.paused_time = paused


func _done(next_stage: int) -> void:
	stage = next_stage
	GameState.set_flag(&"ch1_stage", stage)
	active = false
	_cp_set = false
	Game.hud.objective = ""
	Game.hud.toast("MISSION COMPLETE", 3.0)
	await _tick(2.0)
	_offer()


func _begin_mission() -> void:
	active = true
	Game.hud.show_title(TITLES[stage].to_upper(), "Chapter 1  ·  Mission %d of 5" % (stage + 1))
	if Game.player.character != (&"vision" if stage == 3 else &"wanda"):
		Game.player.set_character(&"vision" if stage == 3 else &"wanda")


## Sets the world up for the current stage and starts (or offers) its mission.
func _offer() -> void:
	_clear_extras()
	match stage:
		0:
			_set_time(10.0)
			await _goto("Go to Borough Hall for Vision's hearing", town.P_HALL, 4.0, "Borough Hall")
			_m_hearing()
		1:
			_set_time(15.0)
			_m_house()
		2:
			_m_dead_walk()
		3:
			_m_vision_alone()
		4:
			_m_graveyard()
		_:
			_free_roam()


# ------------------------------------------------------------------ mission 1
func _m_hearing() -> void:
	_begin_mission()
	_checkpoint(town.P_HALL, PI)
	_summon_vision(town.P_HALL + Vector3(2.5, 0.3, -3.5), true)
	_citizen(town.P_HALL + Vector3(-1.5, 0.1, -5.0))
	_citizen(town.P_HALL + Vector3(0.5, 0.1, -5.6), "wary")
	await _tick(0.6)
	await _say([
		["Federal Agent", "For the record. Three weeks ago the Vision joined himself to every computer on Earth and tried to take charge of the world."],
		["Vision", "I did. A fault in my control crystal persuaded me that mankind would be safer in my keeping. The crystal is gone. The decision to stop was my own."],
		["Federal Agent", "And this committee is to take a machine's word for that?"],
		["Wanda", "You are to take my husband's word. He held the whole world in his hand and he put it down. Name me three men who would."],
		["Federal Agent", "...The matter will rest. For now. But the Avengers can no longer shelter him."],
		["Vision", "Then we shall not ask them to. Wanda and I leave active duty as of today."],
		["Wanda", "No more mansions. No more alarms at midnight. A house, a street, a life."],
		["Vision", "I am informed that New Jersey has all three."],
	])
	_done(1)


# ------------------------------------------------------------------ mission 2
func _m_house() -> void:
	_begin_mission()
	if is_instance_valid(_vision):
		_vision.queue_free()
	_checkpoint(town.P_SPAWN, PI / 2)
	Game.hud.toast("Vision is waiting in the passenger seat", 4.0)
	await _goto("Get into the red convertible (F)", town.car.global_position, 3.4, "Your car")
	Game.hud.objective = "Get into the red convertible (F)"
	while Game.player.driving == null:
		if Game.autotest:
			town.car.enter(Game.player)
		await _tick()
	await _goto("Drive to the house for sale on the north side", town.P_HOME + Vector3(0, 0, 10), 13.0, "House for sale")
	Game.hud.objective = "Get out of the car (F)"
	while Game.player.driving != null:
		if Game.autotest:
			town.car.leave()
		await _tick()
	_summon_vision(town.P_HOME + Vector3(3, 0.3, 2), true)
	_citizen(town.P_HOME + Vector3(-1.5, 0.1, -1.0), "fan")
	_citizen(town.P_HOME + Vector3(-9, 0.1, 6), "wary")
	await _goto("Meet the estate agent at the front gate", town.P_HOME, 3.5, "Estate agent")
	_checkpoint(town.P_HOME, PI)
	await _say([
		["Estate Agent", "A real colonial! Three bedrooms, good schools, and neighbours who are... well. They come around."],
		["Wanda", "It has a garden. Vision, it has a garden."],
		["Vision", "And walls that I am asked not to walk through. I find that I like the idea."],
		["Neighbour", "A witch and a robot on our street. You mark my words, Doris."],
		["Wanda", "We will take it."],
		["", "By evening the last box is indoors. For the first time in years, nobody anywhere needs saving."],
	])
	await _fade(true)
	_done(2)


# ------------------------------------------------------------------ mission 3
func _m_dead_walk() -> void:
	_begin_mission()
	_set_time(23.5)
	var lawn: Vector3 = town.P_HOME + Vector3(0, 0, -3)
	if Game.player.driving:
		Game.player.driving.leave()
	Game.player.teleport(lawn, 0.0)
	_checkpoint(lawn, 0.0)
	_summon_vision(lawn + Vector3(3, 0.3, 1))
	await _fade(false)
	await _say([
		["", "Midnight. Something is scraping at the garden gate."],
		["Vision", "Wanda. There are people on the lawn. They have no heartbeats."],
		["Wanda", "Then they are not people any more. Stay close."],
	])
	Game.hud.toast("Hold LMB to charge a Hex Bolt  ·  release to fire", 6.0)
	await _fight("Drive the dead off your lawn", _ring(lawn + Vector3(0, 0, 9), 5, 11.0))
	Game.hud.toast("Hold RMB to grow a Hex Sphere  ·  on one enemy it traps and throws them  ·  R shields you", 8.0)
	await _fight("More are climbing the fence", _ring(lawn + Vector3(0, 0, 8), 7, 13.0))
	Game.hud.toast("E  -  Telekinesis: seize them all, then LMB to fling or RMB to turn them", 8.0)
	await _fight("They keep coming", _ring(lawn + Vector3(0, 0, 8), 9, 14.0))
	var talon := Roster.spawn(town, &"black_talon", lawn + Vector3(0, 0.4, 13))
	talon.passive = true
	talon.rig.rotation.y = 0.0
	await _tick(0.8)
	await _say([
		["Black Talon", "Do not trouble yourselves, Avengers. My children only came to collect."],
		["Wanda", "Collect what?"],
		["Vision", "Wanda - behind you!"],
		["", "Voodoo fire takes her between the shoulders. The street tilts, and goes dark."],
	])
	Fx.burst(town, Game.player.global_position + Vector3(0, 1, 0), Color("ff7a20"), 60, 8.0)
	FeelDirector.shake(0.3, 0.5)
	await _fade(true, 0.4)
	talon.queue_free()
	_done(3)


# ------------------------------------------------------------------ mission 4
func _m_vision_alone() -> void:
	_begin_mission()
	_set_time(0.5)
	if is_instance_valid(_vision):
		_vision.queue_free()
	_clear_enemies()
	var lawn: Vector3 = town.P_HOME + Vector3(0, 0, -3)
	Game.player.teleport(lawn, PI)
	_checkpoint(lawn, PI)
	await _fade(false)
	await _say([
		["", "Vision rises from the wreck of the porch. The dead are gone. So is Wanda."],
		["Vision", "They carried her south and east. The soil they shed is still warm with her magic. I can follow it."],
	])
	Game.hud.toast("Hold SPACE to fly  ·  LMB Solar Beam  ·  hold RMB to phase  ·  E Density Slam", 9.0)
	var a := Vector3(80, 0.2, -80)
	await _goto("Follow the trail of grave soil", a, 9.0, "Trail")
	_checkpoint(a + Vector3(0, 0, -8), PI)
	await _fight("The dead guard the crossroads", _ring(a, 5, 8.0))
	var b := Vector3(80, 0.2, 0)
	await _goto("Follow the trail south", b, 9.0, "Trail")
	_checkpoint(b + Vector3(0, 0, -8), PI)
	await _say([["Gunman", "The Reaper said the robot would come. Light him up!"]])
	Game.hud.toast("Hold RMB to phase - bullets pass straight through you", 6.0)
	await _fight("The Grim Reaper's hired guns", _ring(b, 4, 9.0, &"gunman"))
	var c := Vector3(80, 0.2, 80)
	await _goto("The trail leads to the cemetery", c, 9.0, "Trail")
	_checkpoint(c + Vector3(0, 0, -8), PI)
	await _fight("Break through", _ring(c, 4, 9.0) + _ring(c, 2, 12.0, &"gunman"))
	await _goto("Reach the cemetery gate", town.P_GATE, 6.0, "Cemetery gate")
	await _say([
		["Vision", "Green fire, from the crypt. And three voices that should not be together."],
		["", "Inside the cemetery walls, Wanda opens her eyes."],
	])
	await _fade(true)
	_done(4)


# ------------------------------------------------------------------ mission 5
func _m_graveyard() -> void:
	_begin_mission()
	_set_time(2.0)
	_clear_enemies()
	var arena: Vector3 = town.P_CRYPT + Vector3(-9, 0, 0)
	Game.player.teleport(arena, -PI / 2)
	_checkpoint(arena, -PI / 2)
	Game.player.rooted = true
	var nekra := Roster.spawn(town, &"nekra", arena + Vector3(5, 0.4, -3))
	var talon := Roster.spawn(town, &"black_talon", arena + Vector3(5, 0.4, 3))
	nekra.passive = true
	talon.passive = true
	nekra.rig.rotation.y = PI / 2
	talon.rig.rotation.y = PI / 2
	await _fade(false)
	await _say([
		["Nekra", "She wakes. Good. The rite wants her eyes open."],
		["Black Talon", "The Reaper pays well for a witch. Your android will come for you, and when he does, his mind is ours to pour where we please."],
		["Wanda", "You carried a hex-witch into a graveyard and tied her up with rope. Shall I count the mistakes for you?"],
	])
	Game.hud.objective = "Burst your bonds: press R to wrap the Hex Sphere around yourself"
	while Game.player.powers.shield_t <= 0.0:
		if Game.autotest:
			Game.player.powers._cast_shield()
		await _tick(0.1)
	Game.player.rooted = false
	Fx.burst(town, arena + Vector3(0, 1, 0), Color("ff3048"), 70, 9.0)
	FeelDirector.shake(0.25, 0.4)
	nekra.passive = false
	talon.passive = false
	_summon_vision(town.P_GATE + Vector3(2, 0.3, 0))
	Game.hud.toast("Vision crashes through the gate to join you", 4.0)
	await _fight("Defeat Nekra and Black Talon", _ring(arena, 4, 10.0))
	await _tick(1.0)
	var reaper := Roster.spawn(town, &"grim_reaper", town.P_CRYPT + Vector3(-4, 0.4, 0))
	reaper.passive = true
	reaper.rig.rotation.y = PI / 2
	Fx.burst(town, reaper.global_position + Vector3(0, 1, 0), Color("b070ff"), 60, 8.0)
	await _say([
		["Grim Reaper", "Sloppy, both of them. I should have raised better help."],
		["Vision", "Eric Williams. Your quarrel is with me. It always was."],
		["Grim Reaper", "You wear my dead brother's mind like a borrowed coat, machine. Tonight I take it back."],
	])
	reaper.passive = false
	Game.hud.objective = "Defeat the Grim Reaper"
	while is_instance_valid(reaper) and reaper.is_alive() and reaper.hp > reaper.max_hp * 0.2:
		if Game.autotest:
			reaper.take_damage(reaper.max_hp * 0.3)
		await _tick(0.2)
	if is_instance_valid(reaper) and reaper.is_alive():
		reaper.passive = true
		await _say([["Grim Reaper", "Enjoy your little house, Vision. A dead man has all the time in the world."]])
		Fx.burst(town, reaper.global_position + Vector3(0, 1, 0), Color("b070ff"), 80, 10.0)
		reaper.queue_free()
	_clear_enemies()
	await _fade(true)
	_set_time(6.3)
	Game.player.teleport(town.P_HOME + Vector3(0, 0, -3), PI)
	if is_instance_valid(_vision):
		_vision.queue_free()
	_summon_vision(town.P_HOME + Vector3(2, 0.3, -3), true)
	await _fade(false)
	await _say([
		["Vision", "You are hurt."],
		["Wanda", "I am home. There is a difference."],
		["Vision", "The porch is destroyed. Also part of the fence, and Mrs. Bellweather's birdbath."],
		["Wanda", "Then tomorrow we fix a porch. Like anybody else on this street."],
		["", "Chapter 1 complete. Leonia is yours to explore."],
	])
	_done(5)


# ------------------------------------------------------------------ free roam
func _free_roam() -> void:
	active = false
	Game.paused_time = false
	Game.hud.objective = ""
	Game.hud.toast("Free roam  ·  Tab switches Wanda / Vision  ·  M map  ·  the cemetery stirs at night", 8.0)
	if not is_instance_valid(_vision) and Game.player.character == &"wanda":
		_summon_vision(town.P_HOME + Vector3(2, 0.3, -3), true)
	_night_watch()


func _night_watch() -> void:
	while is_inside_tree():
		await _tick(1.0)
		var night: bool = town.day.night > 0.8
		var day_index := int(Time.get_ticks_msec() / (24.0 * 40.0 * 1000.0))
		var p := Game.player.global_position
		if night and _night_done != day_index and Vector2(p.x - 120.0, p.z - 120.0).length() < 30.0 and not active:
			_night_done = day_index
			active = true
			_checkpoint(town.P_GATE, -PI / 2)
			Game.hud.show_title("THE RESTLESS DEAD", "Side activity")
			await _fight("Put the cemetery back to sleep", _ring(Vector3(112, 0.2, 120), 8, 12.0))
			active = false
			_cp_set = false
			Game.hud.objective = ""
			Game.hud.toast("The graveyard is quiet again", 4.0)
