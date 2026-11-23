extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.hide() # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		self.hide()


func _on_option_button_item_selected(index: int) -> void:
	var mode := DisplayServer.window_get_mode()
	if index==0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if index==1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		
		
	
