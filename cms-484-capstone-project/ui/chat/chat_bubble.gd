# Authored by Max Royer

extends Control

@onready var bubble_vbox: VBoxContainer = $BubbleVbox
@onready var bubble: PanelContainer = $BubbleVbox/Bubble
@onready var bubble_text: Label = $BubbleVbox/Bubble/BubbleText
@onready var bubble_spot: TextureRect = $BubbleVbox/BubbleSpot

@onready var delete_timer: Timer = $DeleteTimer

@onready var center_pos: Marker2D = $CenterPos


func show_bubble(message : String) -> void:
	_calculate_size(message)
	
	var m_array := message.split()
	
	for i in m_array.size():
		await get_tree().create_timer(.045).timeout
		
		if m_array[i] in [",", ".", "!", "?", ":"]:
			print(m_array[i])
			bubble_text.visible_characters += 1
			await get_tree().create_timer(.3).timeout
		
		bubble_text.visible_characters += 1
	
	delete_timer.start()

func _calculate_size(m : String):
	bubble_text.text = m
	
	bubble_text.visible_characters = 0
	#await get_tree().create_timer(2).timeout
	#
	#bubble_text.visible_characters = -1
	

func _on_button_pressed() -> void:
	show_bubble("this is the short test string. here is a few more.")

func delete():
	self.queue_free()
