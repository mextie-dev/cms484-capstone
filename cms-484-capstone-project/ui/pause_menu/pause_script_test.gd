extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	_on_pause_button()

func _on_pause_button():
	get_tree().paused = true
	show()

func _on_pause_close():
	hide()
	get_tree().paused = false
