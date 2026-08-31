extends Control

@onready var item_list: ItemList = $ItemList

var selected_server

###############################
### UI SETUP AND FUNCTION #####
###############################

func _on_join_button_pressed() -> void:
	if selected_server:
		print("join button pressed")
		join_selected_lobby(selected_server)

func _on_host_button_pressed() -> void:
	var player_name = $"../PlayerName".text
	var server_name = $HostButton/ServerName.text
	if player_name == "":
		print("ERR need player name")
		return
	elif server_name == "": 
		print("err need server name")
		return
	else:
		print("host button pressed")
		host_lobby(server_name)

func _on_item_list_item_selected(index: int) -> void:
	selected_server = item_list.get_item_metadata(0)



###############################
### ACTUAL SERVER SETUP #######
###############################

func host_lobby(server_name: String) -> void:
	var opts = EOS.Lobby.CreateLobbyOptions.new()
	opts.max_lobby_members = 20
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.bucket_id = "main_lobby"

	var lobby = await HLobbies.create_lobby_async(opts)
	if not lobby:
		printerr("Failed to create lobby")
		return

	lobby.add_attribute("server_name", server_name)
	await lobby.update_async()

	# we ARE the hoste
	# HOSTE PARTY
	var peer = EOSGMultiplayerPeer.new()
	peer.create_server("game")
	peer.set_auto_accept_connection_requests(true)
	multiplayer.multiplayer_peer = peer

	print("Hosting lobby: ", lobby.lobby_id, " : ", server_name)
	item_list.add_item(server_name, null, true)
	item_list.set_item_metadata(0, lobby)

func join_selected_lobby(chosen_lobby: HLobby) -> void:
	var lobby = await HLobbies.join_async(chosen_lobby)
	if not lobby:
		printerr("Failed to join lobby")
		return

	var host_id = lobby.owner_product_user_id

	var peer = EOSGMultiplayerPeer.new()
	peer.create_client(host_id, "game")
	multiplayer.multiplayer_peer = peer
