## Citizen: a townsperson who walks a sidewalk loop (or stands chatting), reacts
## out loud when a hero comes near, and trades lines with a chat partner.
extends Node3D

const Rig := preload("res://scripts/characters/character_rig.gd")
const SKIN := ["f0c8a8", "e4b08e", "c98e6a", "8a5a40", "f4d4bc", "a8744e"]
const SHIRT := ["5a80b4", "b45a5a", "5aa070", "d0a040", "8a5ab0", "d8d0c0", "40686a", "c06a90", "7a4a30"]
const PANTS := ["3a4460", "2c2c34", "5a4a3a", "44506a", "6a6a70", "30403a"]
const HAIRC := ["2a1c10", "4a2c18", "8a5a2a", "c9a050", "1a1a1e", "9a9aa0", "7a2a14"]
const SEE_WANDA := {
	"fan": ["That's her. That's really the Scarlet Witch!", "You saved my cousin in Manhattan once. Thank you.", "Welcome to Leonia, Ms. Maximoff!", "Could you sign my newspaper? No pen? Never mind!", "An Avenger, on our street. Wait till I tell Marge."],
	"wary": ["A witch for a neighbour. There go the property values.", "Just... keep the hexes off my lawn, all right?", "Mutants in Leonia now. What next?", "I read about you. I am keeping my distance.", "No offence, lady, but trouble follows your kind."],
	"kid": ["Whoa! Is the cape real?", "Can you make my homework disappear?", "Do the glowy hand thing! Please!", "My brother says you can change luck. Change mine!", "Are you friends with Captain America?"],
	"calm": ["Morning. Lovely day for it.", "New in town? The diner on Broad does a fine pie.", "Mind the traffic on Fort Lee Road.", "You picked a quiet town. Mostly.", "Evening, neighbour."],
}
const SEE_VISION := ["Is that... the android Avenger?", "He walked straight through a door once. I saw it on the news.", "Sir, your skin is red. Are you well?", "Huh. He looks friendlier than the papers say.", "Do you... sleep? Sorry. Rude question."]
const CHATS := [
	["Did you hear? The Avengers couple bought the old place on the north side.", "The witch and the robot? In Leonia?", "Synthezoid, the paper said.", "Whatever he is, he waved at me. Polite fellow."],
	["Something was digging in the cemetery last night.", "Raccoons.", "Raccoons do not leave boot prints, Harold.", "...I'm locking the door tonight."],
	["The bridge traffic gets worse every year.", "You could take the ferry.", "And stand next to tourists? No, thank you."],
	["My Timmy says a man in a purple hood asked the way to the graveyard.", "Purple? In this heat?", "With a scythe for a hand, he says.", "That boy reads too many comic books."],
	["They say her hexes change the odds of things.", "So?", "So I'm buying a lottery ticket and standing near her."],
	["Borough Hall had government men in it all morning.", "About the android?", "They do not send that many suits for a parking dispute."],
]

var path: Array[Vector3] = []
var idx := 0
var dir := 1
var mood := "calm"
var partner: Node3D
var chat_lead := false
var chat: Array = []
var rig: Node3D
var _bubble: Label3D
var _bubble_t := 0.0
var _cool := 0.0
var _chat_i := 0
var _chat_t := 0.0
var _scan := 0.0


func _ready() -> void:
	var female := randf() < 0.5
	var shirt := Color(SHIRT.pick_random())
	var skin := Color(SKIN.pick_random())
	var pants := Color(PANTS.pick_random())
	var hair := Color(HAIRC.pick_random())
	var sleeves := skin if randf() < 0.5 else shirt
	rig = Rig.make("citizen_f" if female else "citizen_m", {"skin": skin, "torso": shirt, "sleeve": shirt, "forearm": sleeves, "hands": skin,
		"legs": pants, "trunks": pants, "boots": pants, "hair": hair, "hair2": hair.lightened(0.15)})
	if mood == "kid":
		rig.scale = Vector3.ONE * 0.68
	add_child(rig)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 30
	_bubble.outline_size = 10
	_bubble.pixel_size = 0.0055
	_bubble.width = 520.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.position.y = 2.35 if mood != "kid" else 1.75
	_bubble.modulate = Color("fff6e6")
	_bubble.visible = false
	add_child(_bubble)
	_scan = randf()
	if not path.is_empty():
		idx = randi() % path.size()
		global_position = path[idx]


func speak(line: String, time := 3.6) -> void:
	_bubble.text = line
	_bubble.visible = true
	_bubble_t = time


func _face(target: Vector3, delta: float) -> void:
	var to := target - global_position
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))


func _process(delta: float) -> void:
	_cool -= delta
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.visible = false
	var p := Game.player
	var d := p.global_position.distance_to(global_position)
	if d > 90.0:
		return
	var reacting := _bubble_t > 0.0 and _cool > 0.0 and partner == null
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.5
		if d < 6.5 and _cool <= 0.0 and p.driving == null and not Game.hud.talking():
			_cool = 22.0
			var pool: Array = SEE_VISION if p.character == &"vision" else SEE_WANDA[mood]
			speak(pool.pick_random())
			reacting = true
	if partner != null:                                     # standing conversation
		_face(p.global_position if (_cool > 18.0) else partner.global_position, delta)
		rig.play("talk" if _bubble_t > 0.0 else "idle", 0.25)
		if chat_lead and d < 22.0 and _cool < 18.0:
			_chat_t -= delta
			if _chat_t <= 0.0:
				_chat_t = 3.8
				var who: Node3D = self if _chat_i % 2 == 0 else partner
				who.speak(chat[_chat_i % chat.size()], 3.4)
				_chat_i += 1
				if _chat_i % chat.size() == 0:
					_chat_t = 9.0
		return
	if reacting:
		_face(p.global_position, delta)
		rig.play("talk", 0.2)
		return
	if path.is_empty():
		rig.play("idle", 0.3)
		return
	var target := path[idx]
	var to := target - global_position
	if to.length() < 0.6:
		idx = (idx + dir + path.size()) % path.size()
		return
	var step := to.normalized()
	global_position += step * (1.35 if mood != "kid" else 2.4) * delta
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-step.x, -step.z), 1.0 - exp(-6.0 * delta))
	rig.play("walk" if mood != "kid" else "run", 0.25, 0.95)
