extends CharacterBody3D

@export var npc_id: String = "FoxNPC"

func interact(player_peer_id: int):
	if not multiplayer.is_server():
		return
	
	print("Player %d interacted with %s" % [player_peer_id, npc_id])
	open_dialogue_client.rpc_id(player_peer_id, npc_id)

@rpc("authority", "call_local", "reliable")
func open_dialogue_client(id: String):
	Dialogic.start_dialogue(id)
	
