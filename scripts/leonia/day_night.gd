## DayNight: advances Game.time_of_day and drives sun, sky, fog, window glow
## and street lights for Leonia. One game hour lasts HOUR_SECONDS real seconds.
extends Node

const HOUR_SECONDS := 40.0
const DAY_TOP := Color("2f6fd0")
const DAY_HOR := Color("b8dcff")
const NIGHT_TOP := Color("050818")
const NIGHT_HOR := Color("1a2748")
const DUSK_HOR := Color("ff9a5a")

var env: Environment
var sky: ProceduralSkyMaterial
var sun: DirectionalLight3D
var glow_mats: Array = []       # [[ShaderMaterial, max_energy], ...]
var lights: Array[OmniLight3D] = []
var night := 0.0


func _process(delta: float) -> void:
	if not Game.paused_time:
		Game.time_of_day = fmod(Game.time_of_day + delta / HOUR_SECONDS, 24.0)
	apply(Game.time_of_day)


func apply(t: float) -> void:
	var d := smoothstep(5.5, 7.5, t) * (1.0 - smoothstep(17.5, 19.8, t))
	var dusk := maxf(1.0 - absf(t - 6.6) / 1.4, 1.0 - absf(t - 18.6) / 1.6)
	dusk = clampf(dusk, 0.0, 1.0)
	night = 1.0 - d
	sky.sky_top_color = NIGHT_TOP.lerp(DAY_TOP, d)
	sky.sky_horizon_color = NIGHT_HOR.lerp(DAY_HOR, d).lerp(DUSK_HOR, dusk * 0.75)
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = sky.sky_top_color.darkened(0.5)
	var elev := sin(clampf((t - 6.0) / 12.0, 0.0, 1.0) * PI)
	if d > 0.02:
		sun.rotation_degrees = Vector3(-(8.0 + elev * 60.0), 40.0 + (t - 12.0) * 9.0, 0)
	else:
		sun.rotation_degrees = Vector3(-52.0, 130.0, 0)
	sun.light_energy = lerpf(0.28, 1.4, d)
	sun.light_color = Color("9db4ff").lerp(Color("fff2d8"), d).lerp(Color("ffb070"), dusk * 0.7)
	env.ambient_light_color = Color("5a6aa8").lerp(Color("dfe8ff"), d)
	env.ambient_light_energy = lerpf(0.55, 1.0, d)
	env.fog_light_color = Color("141c38").lerp(Color("c8dcf0"), d).lerp(DUSK_HOR, dusk * 0.4)
	for g: Array in glow_mats:
		(g[0] as ShaderMaterial).set_shader_parameter("emission_energy", night * g[1])
	var on := night > 0.3
	for l in lights:
		l.visible = on
