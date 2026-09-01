extends Node3D

# game_world.gd
@onready var players := $Players

func _ready():
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_spawn_player)
		multiplayer.peer_disconnected.connect(_despawn_player)
		_spawn_player(multiplayer.get_unique_id())  # the host's own player

func _spawn_player(id: int):
	var player = preload("res://characters/player/player.tscn").instantiate()
	player.name = str(id)
	players.add_child(player)

func _despawn_player(id: int):
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()
