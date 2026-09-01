extends Control

@onready var item_list: ItemList = $ItemList

var selected_server
var _refresh_timer: Timer

###############################
### UI SETUP AND FUNCTION #####
###############################

signal hosted_lobby

func _ready() -> void:
	_refresh_timer = Timer.new()
	add_child(_refresh_timer)
	_refresh_timer.wait_time = 4.0
	_refresh_timer.timeout.connect(_refresh_lobby_list)

	# Login.gd (our parent) is still running its own _ready() at this point -
	# EOS isn't set up yet, so don't touch lobbies until login actually finishes.
	if HAuth.product_user_id != "":
		_start_refreshing()
	else:
		HAuth.logged_in.connect(_start_refreshing, CONNECT_ONE_SHOT)

func _start_refreshing() -> void:
	_refresh_timer.start()
	_refresh_lobby_list()  # do one immediately, don't wait for the first tick

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
		hosted_lobby.emit()
		self.hide()
		

func _on_item_list_item_selected(index: int) -> void:
	selected_server = item_list.get_item_metadata(index)


###############################
### LOBBY LIST (polling) ######
###############################

func _refresh_lobby_list() -> void:
	var lobbies = await HLobbies.search_by_bucket_id_async("main_lobby")
	if lobbies == null:
		return

	item_list.clear()
	for lobby in lobbies:
		var server_name = "Lobby (%d/%d)" % [lobby.members.size(), lobby.max_members]
		var idx = item_list.add_item(server_name)
		item_list.set_item_metadata(idx, lobby)


###############################
### ACTUAL SERVER SETUP #######
###############################

func host_lobby(server_name: String) -> void:
	var opts = EOS.Lobby.CreateLobbyOptions.new()
	opts.max_lobby_members = 20
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.bucket_id = "main_lobby"
	opts.presence_enabled = false

	var lobby = await HLobbies.create_lobby_async(opts)
	if not lobby:
		printerr("Failed to create lobby")
		return

	# Kept in case Epic's search ever starts returning custom attributes for
	# anonymous accounts - harmless either way, just not currently relied on
	# for display. See _refresh_lobby_list for the actual workaround in use.
	lobby.add_attribute("server_name", server_name)
	await lobby.update_async()

	var peer = EOSGMultiplayerPeer.new()
	peer.create_server("game")
	peer.set_auto_accept_connection_requests(true)
	multiplayer.multiplayer_peer = peer

	print("Hosting lobby: ", lobby.lobby_id, " : ", server_name)
	# no manual item_list.add_item here anymore - the next _refresh_lobby_list
	# poll will pick this lobby up the same way it does for everyone else

func join_selected_lobby(chosen_lobby: HLobby) -> void:
	var lobby = await HLobbies.join_async(chosen_lobby)
	if not lobby:
		printerr("Failed to join lobby")
		return

	var host_id = lobby.owner_product_user_id

	var peer = EOSGMultiplayerPeer.new()
	peer.create_client(host_id, "game")
	multiplayer.multiplayer_peer = peer
