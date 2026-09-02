extends Control

@onready var item_list: ItemList = $ItemList

## Socket name must match on host and client. Alphanumeric, max 32 chars.
const P2P_SOCKET := "game"

## How long to wait for the P2P handshake before giving up.
const CONNECT_TIMEOUT := 15.0

var selected_server
var _refresh_timer: Timer

###############################
### UI SETUP AND FUNCTION #####
###############################

signal hosted_lobby
signal joined_lobby

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
		# Don't hide the UI or announce hosting until host_lobby() has actually
		# succeeded - it's async, so firing the signal here was a lie.
		host_lobby(server_name)

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

	# create_server(socket_id) - one argument only.
	# NOTE: this returns a Godot Error, not an EOS result code. Compare
	# against OK, not with EOS.is_success().
	var result: int = peer.create_server(P2P_SOCKET)
	if result != OK:
		printerr("Failed to create EOSG P2P server. Error: ", result)
		return

	peer.set_auto_accept_connection_requests(true)
	multiplayer.multiplayer_peer = peer

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("========================================")
	print("HOSTING")
	print("Lobby ID:   ", lobby.lobby_id)
	print("Host PUID:  ", HAuth.product_user_id)
	print("Socket:     ", P2P_SOCKET)
	print("Godot peer: ", multiplayer.get_unique_id())
	print("========================================")

	hosted_lobby.emit()
	self.hide()
	# no manual item_list.add_item here anymore - the next _refresh_lobby_list
	# poll will pick this lobby up the same way it does for everyone else


func join_selected_lobby(chosen_lobby: HLobby) -> void:
	var lobby = await HLobbies.join_async(chosen_lobby)
	if not lobby:
		printerr("Failed to join lobby")
		return

	var host_id: String = lobby.owner_product_user_id

	print("========================================")
	print("JOINING")
	print("Lobby ID:    ", lobby.lobby_id)
	print("Host PUID:   ", host_id)
	print("Local PUID:  ", HAuth.product_user_id)
	print("Socket:      ", P2P_SOCKET)
	print("========================================")

	var peer = EOSGMultiplayerPeer.new()

	# ---------------------------------------------------------------------
	# THE FIX: create_client(socket_id, remote_user_id)
	#
	# Socket name FIRST, host PUID SECOND. The arguments used to be the other
	# way round, which made the SDK send connection requests to a "user" named
	# "game" over a socket named after the host's PUID. Nothing was listening
	# there, so every request timed out after 8 retries.
	#
	# Confirmed against the plugin source (src/eosg_multiplayer_peer.cpp):
	#   bind_method(D_METHOD("create_client", "socket_id", "remote_user_id"), ...)
	# The online docs showing create_client(user_id, socket) are wrong.
	# ---------------------------------------------------------------------
	var result: int = peer.create_client(P2P_SOCKET, host_id)

	# Returns a Godot Error, not an EOS result code.
	if result != OK:
		printerr("Failed to create EOSG P2P client. Error: ", result)
		return

	multiplayer.multiplayer_peer = peer

	# Wait for the actual handshake. create_client() returning OK only means
	# the request was queued, not that we're connected to anything.
	var connected := await _await_connection(CONNECT_TIMEOUT)

	if not connected:
		printerr("Lobby join succeeded but P2P connection did not establish.")
		multiplayer.multiplayer_peer = null
		await HLobbies.leave_async(lobby)
		return

	print("Connected to host. Godot peer ID: ", multiplayer.get_unique_id())

	$ConnectedLabel.text = "CONNECTED TO: " + host_id
	joined_lobby.emit()
	self.hide()


## Resolves true on connected_to_server, false on connection_failed or timeout.
func _await_connection(timeout: float) -> bool:
	var result := [false]
	var done := false

	var on_ok := func():
		result[0] = true
		done = true
	var on_fail := func():
		result[0] = false
		done = true

	multiplayer.connected_to_server.connect(on_ok, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(on_fail, CONNECT_ONE_SHOT)

	var elapsed := 0.0
	while not done and elapsed < timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	if multiplayer.connected_to_server.is_connected(on_ok):
		multiplayer.connected_to_server.disconnect(on_ok)
	if multiplayer.connection_failed.is_connected(on_fail):
		multiplayer.connection_failed.disconnect(on_fail)

	return result[0]


func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)
