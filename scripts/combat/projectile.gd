## Projectile: a glowing bolt that flies straight, hits the first thing in its
## path and can explode in a radius. Used by Hex Bolt, gunfire and boss blasts.
extends Node3D

const B := preload("res://scripts/world/builder.gd")
const Fx := preload("res://scripts/combat/fx.gd")

var velocity := Vector3.ZERO
var damage := 10.0
var aoe := 0.0
var radius := 0.15
var color := Color("ff3048")
var team: StringName = &"ally"
var shooter: Node3D
var life := 3.0


static func fire(parent: Node, from: Vector3, vel: Vector3, dmg: float, team_: StringName, shooter_: Node3D, col: Color, rad := 0.15, aoe_ := 0.0) -> Node3D:
	var p: Node3D = load("res://scripts/combat/projectile.gd").new()
	p.velocity = vel
	p.damage = dmg
	p.team = team_
	p.shooter = shooter_
	p.color = col
	p.radius = rad
	p.aoe = aoe_
	parent.add_child(p)
	p.global_position = from
	return p


func _ready() -> void:
	B.ball(self, radius, Vector3.ZERO, B.glow(color, 4.0), Vector3.ONE, false, 8)
	B.ball(self, radius * 0.55, Vector3.ZERO, B.glow(Color(1, 0.95, 0.9), 5.0), Vector3.ONE, false, 6)
	B.omni(self, Vector3.ZERO, color, 1.5 + radius * 6.0, 4.0 + radius * 10.0)
	var tr := B.motes(self, Vector3.ZERO, Vector3.ONE * radius * 0.5, color, 20, 0.35, Vector3.ZERO, 0.08 + radius * 0.4)
	tr.preprocess = 0.0


func _physics_process(delta: float) -> void:
	life -= delta
	var step := velocity * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step + velocity.normalized() * radius)
	if shooter and is_instance_valid(shooter) and shooter is CollisionObject3D:
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var hit: Node = null
	if not r.is_empty():
		hit = r.collider
		global_position = r.position
		if _friendly(hit):
			hit = null
			global_position += step
		else:
			_impact(hit)
			return
	else:
		global_position += step
	if radius > 0.25:                                      # fat bolts also catch targets they graze
		for e: Node3D in get_tree().get_nodes_in_group(&"enemy" if team == &"ally" else &"ally"):
			if e.global_position.distance_to(global_position - Vector3(0, 0.9, 0)) < radius + 0.7:
				_impact(e)
				return
	if life <= 0.0:
		queue_free()


func _friendly(n: Node) -> bool:
	return n != null and n.is_in_group(team)


func _impact(hit: Node) -> void:
	var done: Array = []
	if hit and hit.has_method(&"take_damage") and not _friendly(hit):
		hit.take_damage(damage, shooter)
		done.append(hit)
	if aoe > 0.0:
		for e: Node3D in get_tree().get_nodes_in_group(&"enemy" if team == &"ally" else &"ally"):
			if not done.has(e) and e.global_position.distance_to(global_position) < aoe:
				e.take_damage(damage * 0.6, shooter)
	Fx.burst(get_parent(), global_position, color, 14 + int(aoe * 12.0), 4.0 + aoe * 2.0, 0.1 + radius * 0.3)
	if aoe > 2.0:
		FeelDirector.shake(0.04 * aoe, 0.25)
	queue_free()
