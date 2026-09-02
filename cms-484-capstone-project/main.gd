
extends Node


const LOGIN = preload("uid://cnrms1p860xym")
const MULTIPLAYER_TEST_ROOM = preload("uid://ddbpmf5vs0cyu")


var multiplayer_room: Node = null


func _ready() -> void:
	print("Main scene ready.")


func _process(_delta: float) -> void:
	pass


func _on_login_server_started() -> void:
	# This signal is now emitted only after:
	#
	# HOST:
	#   EOS lobby created
	#   EOSG P2P server created
	#   Godot MultiplayerPeer installed
	#
	# CLIENT:
	#   EOS lobby joined
	#   EOSG P2P client created
	#   connected_to_server fired
	#
	# Therefore the multiplayer scene can safely be created here.

	if multiplayer_room != null:
		printerr("Multiplayer room already exists.")
		return

	print("Entering multiplayer test room.")

	multiplayer_room = MULTIPLAYER_TEST_ROOM.instantiate()
	add_child(multiplayer_room)

	# The Login UI can now be removed or hidden.
	var login := get_node_or_null("Login")

	if login:
		login.hide()
