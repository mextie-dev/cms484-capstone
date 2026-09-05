# Authored by Max Royer

extends Node

signal message_recieved(uname: String, color : Color, message : String)

const MAX_MESSAGE_LENGTH := 150


## called locally by chatUI when the player hits enter
func send_message(message: String) -> void:
	message = message.strip_edges()
	if message.is_empty():
		return

	# if in singleplayer, just show local
	if multiplayer.multiplayer_peer == null:
		message_recieved.emit(PlayerData.player_name, PlayerData.player_color, message)
		return

	submit_message.rpc_id(1, PlayerData.player_name, PlayerData.player_color, message)


## this only runs to the server
@rpc("any_peer", "call_local", "reliable")
func submit_message(uname : String, color : Color, message : String) -> void:
	if not multiplayer.is_server():
		return

	message = message.strip_edges()
	if message.is_empty():
		return
	if message.length() > MAX_MESSAGE_LENGTH:
		message = message.substr(0, MAX_MESSAGE_LENGTH)

	receive_message.rpc(uname, color, message)


## calls out to the clients
@rpc("authority", "call_local", "reliable")
func receive_message(uname: String, color: Color, message: String) -> void:
	print("%s says: %s" % [uname, message])
	message_recieved.emit(uname, color, message)
