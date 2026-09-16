# Authored by Max Royer

class_name ChatBubble3D
extends Node3D

@onready var chat_bubble: ChatBubble = $Sprite3D/SubViewport/ChatBubble


func _ready() -> void:
	chat_bubble.finished.connect(queue_free)
