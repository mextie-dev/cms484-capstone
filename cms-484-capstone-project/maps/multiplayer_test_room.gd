# Authored by:
# Max Royer

extends Node3D

## game world (for now) 

@onready var players: Node3D = $Players

const PLAYER_SCENE := preload("res://characters/player/player.tscn")


func _ready() -> void:
	print("[world] ready. is_server=", multiplayer.is_server(),
		" unique_id=", multiplayer.get_unique_id())

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_despawn_player)

		# configure the host
		_spawn_player(multiplayer.get_unique_id())

	else:
		# everything should be in the world, so we can now officially notify 
		# the lobby that its safe to display
		print("[world] client world built, notifying server")
		_client_world_ready.rpc_id(1)


## called BY the client, ON the server, this is the replacement for
## multiplayer.peer_connected.connect(_spawn_player)
@rpc("any_peer", "call_remote", "reliable")
func _client_world_ready() -> void:
	if not multiplayer.is_server():
		return

	var id := multiplayer.get_remote_sender_id()
	print("[world] client ", id, " reports world ready")

	if players.has_node(str(id)):
		print("[world] player ", id, " already exists, skipping spawn")
		return

	_spawn_player(id)


func _spawn_player(id: int) -> void:
	print("[world] spawning player for id: ", id)

	var player := PLAYER_SCENE.instantiate()
	# name must be set BEFORE add_child. player.gd reads it in _enter_tree to
	# decide multiplayer authority, and the name is what keeps the node paths
	# identical on every peer
	player.name = str(id)
	players.add_child(player, true)

	print("[world] Players children now: ", players.get_children())


func _despawn_player(id: int) -> void:
	print("[world] despawning player for id: ", id)
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()
