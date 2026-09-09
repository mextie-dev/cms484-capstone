class_name ChatBubble3D
extends Node3D

## Billboarded wrapper that renders the 2D ChatBubble through a SubViewport.
## Parent this to a player's BubblePoint and call chat_bubble.show_bubble().

@onready var chat_bubble: ChatBubble = $Sprite3D/SubViewport/ChatBubble


func _ready() -> void:
	# The Control frees itself when its delete timer fires. Take the wrapper
	# and its SubViewport down with it rather than leaking a viewport per
	# message. Polling in _process is not needed for this.
	chat_bubble.finished.connect(queue_free)
