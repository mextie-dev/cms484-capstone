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
	area_entered.connect(_entered_area)

func _entered_area(body):
	pass


func player_interacted_area(body):
	player_interacted.emit(body)
