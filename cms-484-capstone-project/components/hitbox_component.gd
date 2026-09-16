# Authored by Max Royer

class_name HitboxComponent
extends Area3D

#@export var hitbox_path : CollisionShape3D

@export var interactable := true
@export var active := true

signal player_entered(player)

signal object_entered(object)

signal player_interacted(player)

func _ready() -> void:
	# Areas (other hitboxes) and bodies (RigidBody3D, CharacterBody3D) are
	# reported by separate signals, so both route into the same handler.
	# Which layers actually get detected is controlled by collision_mask
	# in the inspector.
	area_entered.connect(_on_something_entered)
	body_entered.connect(_on_something_entered)


func _on_something_entered(node: Node3D) -> void:
	if node is Player:
		player_entered.emit(node)
	else:
		object_entered.emit(node)


func player_interacted_area(body):
	player_interacted.emit(body)
