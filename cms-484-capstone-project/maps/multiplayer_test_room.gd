
extends Node3D


const PLAYER_SCENE := preload("res://characters/player/player.tscn")

@onready var players: Node3D = $Players
@onready var player_spawner: MultiplayerSpawner = $MultiplayerSpawner


func _ready() -> void:
	print("========================================")
	print("MULTIPLAYER TEST ROOM READY")
	print("is_server: ", multiplayer.is_server())
	print("unique_id: ", multiplayer.get_unique_id())
	print("multiplayer_peer: ", multiplayer.multiplayer_peer)
	print("========================================")

	# Configure MultiplayerSpawner before spawning anything.
	player_spawner.spawn_function = _spawn_player

	if multiplayer.is_server():
		_setup_server()
	else:
		_setup_client()


# ============================================================
# SERVER
# ============================================================

func _setup_server() -> void:
	print("Setting up multiplayer server.")

	multiplayer.peer_connected.connect(
		_on_peer_connected
	)

	multiplayer.peer_disconnected.connect(
		_on_peer_disconnected
	)

	# Spawn the host's own player.
	_spawn_player_for_peer(multiplayer.get_unique_id())


func _on_peer_connected(id: int) -> void:
	print("========================================")
	print("PEER CONNECTED TO GAME")
	print("Peer ID: ", id)
	print("========================================")

	_spawn_player_for_peer(id)


func _on_peer_disconnected(id: int) -> void:
	print("========================================")
	print("PEER DISCONNECTED FROM GAME")
	print("Peer ID: ", id)
	print("========================================")

	var player := players.get_node_or_null(str(id))

	if player:
		player.queue_free()


func _spawn_player_for_peer(id: int) -> void:
	if players.has_node(str(id)):
		print(
			"Player already exists for peer ",
			id,
			", not spawning another."
		)
		return

	print("Spawning player for peer ", id)

	player_spawner.spawn({
		"peer_id": id
	})


# ============================================================
# CLIENT
# ============================================================

func _setup_client() -> void:
	print("Setting up multiplayer client.")

	multiplayer.connected_to_server.connect(
		_on_connected_to_server
	)

	multiplayer.connection_failed.connect(
		_on_connection_failed
	)

	multiplayer.server_disconnected.connect(
		_on_server_disconnected
	)


func _on_connected_to_server() -> void:
	print("========================================")
	print("MULTIPLAYER TEST ROOM: CONNECTED")
	print("My peer ID: ", multiplayer.get_unique_id())
	print("========================================")


func _on_connection_failed() -> void:
	printerr("========================================")
	printerr("MULTIPLAYER TEST ROOM: CONNECTION FAILED")
	printerr("========================================")


func _on_server_disconnected() -> void:
	printerr("========================================")
	printerr("MULTIPLAYER TEST ROOM: SERVER DISCONNECTED")
	printerr("========================================")


# ============================================================
# MULTIPLAYER SPAWNER
# ============================================================

## Called by MultiplayerSpawner on both server and clients.
##
## The server calls:
##
##     player_spawner.spawn({"peer_id": id})
##
## Godot replicates that spawn request to the other peers, which then
## execute this function locally with the same data.
func _spawn_player(data: Variant) -> Node:
	var peer_id: int = int(data["peer_id"])

	print(
		"MultiplayerSpawner creating player for peer ",
		peer_id
	)

	var player := PLAYER_SCENE.instantiate()

	# The name is deliberately the Godot peer ID.
	#
	# This gives us:
	#
	#   Player/1
	#   Player/2
	#   Player/3
	#
	# and lets Player.gd assign authority consistently.
	player.name = str(peer_id)

	return player
