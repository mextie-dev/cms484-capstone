extends Node3D

# game_world.gd
@onready var players := $Players

func _ready():
	print("MultiplayerTestRoom ready. is_server=", multiplayer.is_server(), " unique_id=", multiplayer.get_unique_id())
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_spawn_player)
		multiplayer.peer_disconnected.connect(_despawn_player)
		_spawn_player(multiplayer.get_unique_id())  # the host's own player
	else:
		multiplayer.connected_to_server.connect(func(): print("[client] connected_to_server fired"))
		multiplayer.connection_failed.connect(func(): print("[client] connection_failed fired"))
		multiplayer.peer_connected.connect(func(id): print("[client] peer_connected fired for: ", id))

func _spawn_player(id: int):
	print("_spawn_player called for id: ", id)
	var player = preload("res://characters/player/player.tscn").instantiate()
	player.name = str(id)
	players.add_child(player)
	print("Player node added. Players now has children: ", players.get_children())

func _despawn_player(id: int):
	print("_despawn_player called for id: ", id)
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()
