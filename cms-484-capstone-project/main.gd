extends Node


const LOGIN = preload("uid://cnrms1p860xym")

const MULTIPLAYER_TEST_ROOM = preload("uid://ddbpmf5vs0cyu")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_login_server_started() -> void:
	var map = MULTIPLAYER_TEST_ROOM.instantiate()
	add_child(map)
	$Login.queue_free()
