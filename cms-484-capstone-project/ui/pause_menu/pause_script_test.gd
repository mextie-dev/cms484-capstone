extends Control
var vis_check: bool = false

# Called when the node enters the scene tree for the first time.
# Makes it so that the menu is hidden by default.
func _ready() -> void:
	hide()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
# Currently not used, but left in just in case it is needed for future work.
func _process(delta: float) -> void:
	pass


# This function determines how to handle the pause input.
# Utilizes the previously initialized vis_check variable.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Assuming it is not visible, it shows the menu
		# and sets vis_check to true.
		if vis_check == false:
			self.show()
			vis_check = true
		# Assuming it is visible, it hides the menu
		# and sets vis_check to false.
		elif vis_check == true:
			self.hide()
			vis_check = false
