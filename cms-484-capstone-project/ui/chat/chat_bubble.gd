# Authored by Max Royer

class_name ChatBubble
extends Control

## Emitted when the bubble has finished its lifetime and is about to free
## itself. ChatBubble3D listens for this so the whole 3D wrapper goes away too.
signal finished

@onready var bubble_vbox: VBoxContainer = $BubbleVbox
@onready var bubble: PanelContainer = $BubbleVbox/Bubble
@onready var bubble_text: Label = $BubbleVbox/Bubble/BubbleText
@onready var bubble_spot: TextureRect = $BubbleVbox/BubbleSpot

@onready var delete_timer: Timer = $DeleteTimer

## seconds between revealed characters
const CHAR_DELAY := 0.045
## extra beat after sentence punctuation
const PUNCTUATION_PAUSE := 0.3
const PUNCTUATION := [",", ".", "!", "?", ":"]


## Types [param message] out one character at a time, then starts the delete
## timer. Safe to abandon mid-type: if the bubble gets freed (a newer message
## replaced it, the player despawned) the loop bails instead of poking a
## dead node.
func show_bubble(message: String) -> void:
	# Set the full text first. visible_characters_behavior is set to
	# CHARS_AFTER_SHAPING in the scene, so the layout is measured against the
	# whole string once and the bubble does not resize as characters appear.
	bubble_text.text = message
	bubble_text.visible_characters = 0

	for i in message.length():
		await get_tree().create_timer(CHAR_DELAY).timeout
		if not is_inside_tree():
			return

		bubble_text.visible_characters += 1

		if message[i] in PUNCTUATION:
			await get_tree().create_timer(PUNCTUATION_PAUSE).timeout
			if not is_inside_tree():
				return

	delete_timer.start()


func _on_button_pressed() -> void:
	show_bubble("this is the short test string. here is a few more.")


## Wired to DeleteTimer.timeout in the scene.
func delete() -> void:
	finished.emit()
	queue_free()
