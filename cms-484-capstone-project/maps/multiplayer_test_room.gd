extends Node3D

## Game world. Spawning is driven by an explicit client-ready handshake rather
## than by peer_connected, because the client builds this scene AFTER it
## connects - so on peer_connected the client has no Players node and no
## MultiplayerSpawner yet, and any spawn the server replicates at that moment
## is addressed to a path the client can't resolve. It gets silently dropped,
## which is why the host used to see everyone and the client saw nothing.

@onready var players: Node3D = $Players

const PLAYER_SCENE := preload("res://characters/player/player.tscn")


func _ready() -> void:
	print("[world] ready. is_server=", multiplayer.is_server(),
		" unique_id=", multiplayer.get_unique_id())

	if multiplayer.is_server():
		# Only despawn is event-driven now. Spawning waits for the client to
		# tell us its world exists.
		multiplayer.peer_disconnected.connect(_despawn_player)

		# The host's own player. Safe to do immediately - our tree is right here.
		_spawn_player(multiplayer.get_unique_id())

		# Any client that connected before this scene existed (shouldn't happen
		# in the normal flow, but harmless to cover) still gets picked up when
		# it sends its ready RPC.
	else:
		# Our Players node and MultiplayerSpawner are now in the tree, so it is
		# finally safe for the server to replicate spawns to us.
		print("[world] client world built, notifying server")
		_client_world_ready.rpc_id(1)


## Called BY the client, ON the server. This is the replacement for
## multiplayer.peer_connected.connect(_spawn_player).
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
	# Name must be set BEFORE add_child. player.gd reads it in _enter_tree to
	# decide multiplayer authority, and the name is what keeps the node paths
	# identical on every peer.
	player.name = str(id)
	players.add_child(player, true)

	print("[world] Players children now: ", players.get_children())


func _despawn_player(id: int) -> void:
	print("[world] despawning player for id: ", id)
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()
