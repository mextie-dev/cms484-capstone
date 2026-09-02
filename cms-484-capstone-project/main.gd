extends Node

const LOGIN = preload("uid://cnrms1p860xym")
const MULTIPLAYER_TEST_ROOM = preload("uid://ddbpmf5vs0cyu")

var _world: Node = null


## Fired by Login.server_started, which in turn fires on either hosted_lobby
## or joined_lobby. By the time we get here the peer is connected on both
## host and client.
func _on_login_server_started() -> void:
	if _world != null:
		# Guard against the signal arriving twice (e.g. hosted_lobby and
		# joined_lobby both wired to _on_connection_established).
		print("[main] world already loaded, ignoring duplicate server_started")
		return

	print("[main] loading world. is_server=", multiplayer.is_server(),
		" unique_id=", multiplayer.get_unique_id())

	_world = MULTIPLAYER_TEST_ROOM.instantiate()
	add_child(_world)

	# Hide the login UI on BOTH host and client. Previously this was commented
	# out, so the Control stayed on top of the 3D viewport.
	if has_node("Login"):
		$Login.hide()


## Call this when returning to the menu (host left, disconnected, etc).
func unload_world() -> void:
	if _world != null:
		_world.queue_free()
		_world = null

	multiplayer.multiplayer_peer = null

	if has_node("Login"):
		$Login.show()
