# Authored by Max Royer

class_name SoccerBall
extends RigidBody3D

@onready var hitbox_component: HitboxComponent = $HitboxComponent

func _process(delta: float) -> void:
	hitbox_component.global_basis = Basis.IDENTITY

func _on_hitbox_component_player_interacted(player: Player) -> void:
	var direction := player.visual_root.global_transform.basis.z.normalized()
	print("kicking in " + str(direction))
	apply_impulse((direction * 50 + Vector3(0,20,0)))
