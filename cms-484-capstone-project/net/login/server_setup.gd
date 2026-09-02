
extends Control

@onready var item_list: ItemList = $ItemList

signal hosted_lobby
signal joined_lobby

var selected_server: HLobby = null
var _refresh_timer: Timer

var _network_starting := false
var _in_game := false


func _ready() -> void:
	_refresh_timer = Timer.new()
	add_child(_refresh_timer)

	_refresh_timer.wait_time = 4.0
	_refresh_timer.timeout.connect(_refresh_lobby_list)

	# Login.gd initializes EOS asynchronously.
	# Do not touch the lobby system until authentication has completed.
	if HAuth.product_user_id != "":
		_start_refreshing()
	else:
		HAuth.logged_in.connect(
			_start_refreshing,
			CONNECT_ONE_SHOT
		)


func _start_refreshing() -> void:
	if _in_game:
		return

	_refresh_timer.start()
	_refresh_lobby_list()


# ============================================================
# UI
# ============================================================

func _on_join_button_pressed() -> void:
	if _network_starting:
		print("Network operation already in progress.")
		return

	if selected_server == null:
		print("No lobby selected.")
		return

	print("Join button pressed.")

	_network_starting = true

	var success := await join_selected_lobby(selected_server)

	if success:
		print("Client connection established.")
	else:
		printerr("Failed to connect to selected lobby.")

	_network_starting = false


func _on_host_button_pressed() -> void:
	if _network_starting:
		print("Network operation already in progress.")
		return

	var player_name = $"../PlayerName".text.strip_edges()
	var server_name = $HostButton/ServerName.text.strip_edges()

	if player_name.is_empty():
		print("ERROR: Need player name.")
		return

	if server_name.is_empty():
		print("ERROR: Need server name.")
		return

	if HAuth.product_user_id == "":
		printerr("Cannot host: EOS authentication has not completed.")
		return

	print("Host button pressed.")

	_network_starting = true

	var success := await host_lobby(server_name)

	if success:
		print("========================================")
		print("HOST IS READY")
		print("========================================")

		_in_game = true
		hosted_lobby.emit()
		hide()
	else:
		printerr("Failed to start host.")

	_network_starting = false


func _on_item_list_item_selected(index: int) -> void:
	selected_server = item_list.get_item_metadata(index) as HLobby

	if selected_server:
		print(
			"Selected lobby: ",
			selected_server.lobby_id,
			" owner=",
			selected_server.owner_product_user_id
		)


# ============================================================
# LOBBY SEARCH
# ============================================================

func _refresh_lobby_list() -> void:
	if _in_game:
		return

	if HAuth.product_user_id == "":
		return

	var lobbies = await HLobbies.search_by_bucket_id_async("main_lobby")

	if lobbies == null:
		print("Lobby search returned null.")
		return

	item_list.clear()
	selected_server = null

	for lobby in lobbies:
		var server_name := "Lobby (%d/%d)" % [
			lobby.members.size(),
			lobby.max_members
		]

		var idx := item_list.add_item(server_name)
		item_list.set_item_metadata(idx, lobby)

	print("Lobby search found ", lobbies.size(), " lobby/lobbies.")


# ============================================================
# HOST
# ============================================================

func host_lobby(server_name: String) -> bool:
	print("========================================")
	print("STARTING EOS HOST")
	print("PUID: ", HAuth.product_user_id)
	print("Server name: ", server_name)
	print("========================================")

	# --------------------------------------------------------
	# Create EOS lobby
	# --------------------------------------------------------

	var opts := EOS.Lobby.CreateLobbyOptions.new()

	opts.max_lobby_members = 20
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.bucket_id = "main_lobby"

	# Do NOT attempt to use Epic Account Presence.
	opts.presence_enabled = false

	print("Creating EOS lobby...")

	var lobby := await HLobbies.create_lobby_async(opts)

	if lobby == null:
		printerr("EOS lobby creation failed.")
		return false

	print("EOS lobby created.")
	print("Lobby ID: ", lobby.lobby_id)
	print("Lobby owner PUID: ", lobby.owner_product_user_id)

	# --------------------------------------------------------
	# Add lobby metadata
	# --------------------------------------------------------

	lobby.add_attribute("server_name", server_name)

	var update_result = await lobby.update_async()

	print("Lobby metadata update result: ", update_result)

	# --------------------------------------------------------
	# Create EOS P2P server
	# --------------------------------------------------------

	print("Creating EOSG P2P server...")

	var peer := EOSGMultiplayerPeer.new()

	var create_result = peer.create_server("game")

	print("EOSG create_server result: ", create_result)

	if create_result != OK:
		printerr(
			"EOSG P2P server creation FAILED. Error: ",
			create_result
		)

		# Do not leave a lobby advertised if its P2P endpoint failed.
		await lobby.leave_async()

		return false

	print("EOSG P2P server created successfully.")

	peer.set_auto_accept_connection_requests(true)

	# --------------------------------------------------------
	# Install Godot multiplayer peer
	# --------------------------------------------------------

	# Install diagnostics BEFORE assigning the peer.
	# This lets us see when a client actually reaches this host.
	multiplayer.peer_connected.connect(
		_on_host_peer_connected
	)

	multiplayer.peer_disconnected.connect(
		_on_host_peer_disconnected
	)

	multiplayer.server_disconnected.connect(
		_on_server_disconnected
	)

	multiplayer.connection_failed.connect(
		_on_connection_failed
	)

	multiplayer.multiplayer_peer = peer

	print("Godot MultiplayerPeer installed.")
	print("multiplayer.is_server(): ", multiplayer.is_server())
	print("Godot host peer ID: ", multiplayer.get_unique_id())
	print("EOS host PUID: ", HAuth.product_user_id)

	print("========================================")
	print("EOS HOST READY")
	print("Lobby: ", lobby.lobby_id)
	print("PUID: ", HAuth.product_user_id)
	print("========================================")

	return true


# ============================================================
# CLIENT
# ============================================================

func join_selected_lobby(chosen_lobby: HLobby) -> bool:
	if chosen_lobby == null:
		printerr("Cannot join null lobby.")
		return false

	if HAuth.product_user_id == "":
		printerr("Cannot join: EOS authentication has not completed.")
		return false

	print("========================================")
	print("JOINING EOS LOBBY")
	print("Client PUID: ", HAuth.product_user_id)
	print("Lobby ID: ", chosen_lobby.lobby_id)
	print("========================================")

	# --------------------------------------------------------
	# Join EOS lobby
	# --------------------------------------------------------

	print("Calling HLobbies.join_async()...")

	var lobby = await HLobbies.join_async(chosen_lobby)

	if lobby == null:
		printerr("EOS lobby join FAILED.")
		return false

	print("EOS lobby join succeeded.")
	print("Lobby ID: ", lobby.lobby_id)

	# --------------------------------------------------------
	# Determine P2P destination
	# --------------------------------------------------------

	var host_id = lobby.owner_product_user_id

	print("Lobby owner PUID: ", host_id)
	print("Local PUID: ", HAuth.product_user_id)

	if host_id == "":
		printerr("Lobby has no owner Product User ID.")
		return false

	if host_id == HAuth.product_user_id:
		printerr(
			"ERROR: Lobby owner PUID is identical to local PUID."
		)
		return false

	# --------------------------------------------------------
	# Prepare connection callbacks BEFORE create_client
	# --------------------------------------------------------

	var connected := false
	var failed := false

	var connected_callable := func() -> void:
		connected = true
		print("========================================")
		print("CLIENT CONNECTED TO EOS HOST")
		print("Local Godot peer ID: ", multiplayer.get_unique_id())
		print("Host PUID: ", host_id)
		print("========================================")

		$ConnectedLabel.text = "CONNECTED TO: " + host_id

	var failed_callable := func() -> void:
		failed = true

		printerr("========================================")
		printerr("CLIENT EOS/GODOT CONNECTION FAILED")
		printerr("Host PUID: ", host_id)
		printerr("Local PUID: ", HAuth.product_user_id)
		printerr("========================================")

		$ConnectedLabel.text = "CONNECTION FAILED"

	multiplayer.connected_to_server.connect(
		connected_callable,
		CONNECT_ONE_SHOT
	)

	multiplayer.connection_failed.connect(
		failed_callable,
		CONNECT_ONE_SHOT
	)

	# --------------------------------------------------------
	# Create EOS P2P client
	# --------------------------------------------------------

	print("Creating EOSG P2P client...")
	print("Target PUID: ", host_id)
	print("Socket name: game")

	var peer := EOSGMultiplayerPeer.new()

	var create_result = peer.create_client(host_id, "game")

	print("EOSG create_client result: ", create_result)

	if create_result != OK:
		printerr(
			"EOSG P2P client creation FAILED. Error: ",
			create_result
		)

		# Clean up lobby membership.
		await lobby.leave_async()

		return false

	print("EOSG P2P client created successfully.")

	# --------------------------------------------------------
	# Install peer
	# --------------------------------------------------------

	multiplayer.multiplayer_peer = peer

	print("Godot MultiplayerPeer installed.")
	print("Waiting for connected_to_server...")

	$ConnectedLabel.text = "CONNECTING TO: " + host_id

	# --------------------------------------------------------
	# Wait for actual Godot connection
	# --------------------------------------------------------

	var timeout := get_tree().create_timer(15.0)

	while not connected and not failed and timeout.time_left > 0.0:
		await get_tree().process_frame

	if connected:
		print("Actual network connection established.")
		_in_game = true
		joined_lobby.emit()
		hide()
		return true

	if failed:
		printerr("Godot reported connection_failed.")
	else:
		printerr(
			"Timed out waiting for connected_to_server."
		)

	printerr("The EOS lobby join succeeded, but the P2P connection did not.")

	return false


# ============================================================
# NETWORK DIAGNOSTICS
# ============================================================

func _on_host_peer_connected(id: int) -> void:
	print("========================================")
	print("CLIENT REACHED HOST")
	print("Godot peer ID: ", id)
	print("========================================")


func _on_host_peer_disconnected(id: int) -> void:
	print("========================================")
	print("CLIENT DISCONNECTED FROM HOST")
	print("Godot peer ID: ", id)
	print("========================================")


func _on_server_disconnected() -> void:
	print("========================================")
	print("SERVER DISCONNECTED")
	print("========================================")


func _on_connection_failed() -> void:
	printerr("========================================")
	printerr("GODOT CONNECTION FAILED")
	printerr("========================================")
