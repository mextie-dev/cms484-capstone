extends Node3D

@onready var chat_bubble: Control = $Sprite3D/SubViewport/ChatBubble

func _ready() -> void:
	print(chat_bubble.center_pos)

func _process(delta: float) -> void:
	if chat_bubble:
		pass
	else:
		print("deleted chat bubble")
		self.queue_free()
