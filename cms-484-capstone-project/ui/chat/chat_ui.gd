# Authored by Max Royers

extends Control

@export var max_items := 30

@onready var chat_field: LineEdit = $ChatField
@onready var chat_message_container: VBoxContainer = $ChatBoxScrollContainer/ChatMessageContainer

const CHAT_MESSAGE_UI = preload("uid://dbgfsac2pfpto")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Chat.message_recieved.connect(add_to_box)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func add_to_box(mname, color, message, mcolor := Color.WHITE):
	var chat_message : ChatMessageUI = CHAT_MESSAGE_UI.instantiate()
	chat_message.create_message(mname, color, message, mcolor)
	#add_child(chat_message)
	chat_message_container.add_child(chat_message)
	
	if chat_message_container.get_child_count() > max_items:
		var oldest_child = chat_message_container.get_child(0) # Index 0 is the top/oldest item
		oldest_child.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat"):
		chat_field.grab_focus()

func _on_test_message_pressed() -> void:
	add_to_box("mname", Color(randf(), randf(), randf()), str(randi_range(1, 999)))
	


func _on_chat_field_text_submitted(new_text: String) -> void:
	chat_field.clear()
	chat_field.release_focus()
	
	## send to the chat autoload manager
	
	Chat.send_message(new_text)
	
