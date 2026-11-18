extends CharacterBody3D

@onready var animation_sprite = $AnimatedSprite3D
@onready var player = get_tree().root.get_node("Main/characters/NPCs")

@export var npc_name = " "

func _ready():
	animation_sprite.play("idle_down")
