extends Node

const LOGIN = preload("uid://cnrms1p860xym")
const CHAT_UI = preload("uid://beywjhirqdn3r")

@onready var multiplayer_test_room: Node3D = $MultiplayerTestRoom
@onready var login_layer: CanvasLayer = $LoginLayer

## The chat panel instanced for this session. Held so it can be freed on
## teardown - otherwise rejoining stacks a second one on top of the first.
var _chat_ui: Control = null


## Fired by Login.server_started, which in turn fires on either hosted_lobby
## or joined_lobby. By the time we get here the peer is connected on both
## host and client.
func _on_login_server_started() -> void:
	print("[main] loading world. is_server=", multiplayer.is_server(),
		" unique_id=", multiplayer.get_unique_id())
	multiplayer_test_room.show()
	multiplayer_test_room.process_mode = Node.PROCESS_MODE_INHERIT

	_chat_ui = CHAT_UI.instantiate()
	add_child(_chat_ui)
	multiplayer_test_room.initialize()

	login_layer.hide()


## Fired by Login.server_stopped, which comes from ServerSetup.lost_connection.
func _on_login_server_stopped() -> void:
	printerr("[main] lost connection to host, unloading world")
	unload_world()


## Call this when returning to the menu (host left, disconnected, etc).
## The world node itself is NOT freed - it lives in main.tscn so that node
## paths stay identical on every peer from launch. Freeing it would break the
## next session's spawn replication and leave multiplayer_test_room null.
func unload_world() -> void:
	if _chat_ui != null:
		_chat_ui.queue_free()
		_chat_ui = null

	if multiplayer_test_room != null:
		multiplayer_test_room.hide()
		multiplayer_test_room.process_mode = Node.PROCESS_MODE_DISABLED
		if multiplayer_test_room.has_method("teardown"):
			multiplayer_test_room.teardown()

	multiplayer.multiplayer_peer = null

	login_layer.show()

	# ServerSetup hid itself when we hosted/joined, and it still owns the EOS
	# lobby membership - let it clean up and resume polling.
	if login_layer.has_node("Login/ServerSetup"):
		login_layer.get_node("Login/ServerSetup").return_to_menu()
