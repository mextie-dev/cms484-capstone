# Authored by:
# Max Royer, using outlines provided by Anthropic's Opus 5

extends Control

@onready var item_list: ItemList = $ItemList

## Socket name must match on host and client. Alphanumeric, max 32 chars.
const P2P_SOCKET := "game"

## How long to wait for the P2P handshake before giving up.
const CONNECT_TIMEOUT := 20.0

## The lobby the user picked, tracked by ID rather than by object. The refresh
## timer rebuilds the ItemList every few seconds, so holding onto an HLobby
## from an older search means joining a stale snapshot.
var selected_lobby_id: String = ""

## Results of the most recent successful search. Used to resolve
## selected_lobby_id back into a live HLobby at join time.
var _latest_lobbies: Array = []

var _refresh_timer: Timer

## The lobby we created or joined, held so we can leave it cleanly when the
## session ends. Null while sitting in the menu.
var _current_lobby = null

## Guards against two searches running at once. search_by_bucket_id_async can
## take longer than the 4s timer interval, and two overlapping rebuilds will
## fight over item_list and _latest_lobbies.
var _refreshing := false

###############################
### UI SETUP AND FUNCTION #####
###############################

signal hosted_lobby
signal joined_lobby

## Raised when the host goes away. Login.gd forwards this to Main so the world
## can be torn down and the menu brought back.
signal lost_connection

func _ready() -> void:
	# Connected once, here, rather than inside host_lobby/join_selected_lobby.
	# Wiring them per attempt meant a failed join followed by a retry stacked
	# duplicate handlers, so every callback fired N times.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

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
	if selected_lobby_id == "":
		print("[net] no lobby selected")
		return

	# Resolve against the newest search results, not whatever object was on
	# screen when the user clicked. If the lobby closed or filled up between
	# the click and now, we find out here instead of failing inside EOS.
	var lobby = _find_lobby_by_id(selected_lobby_id)
	if lobby == null:
		printerr("[net] selected lobby is no longer available")
		selected_lobby_id = ""
		return

	var player_name = $"../PlayerName".text
	if player_name == "":
		print("ERR need player name")
		return

	print("[net] join button pressed")
	PlayerData.player_name = player_name
	join_selected_lobby(lobby)

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
		print("[net] host button pressed")
		PlayerData.player_name = player_name
		host_lobby(server_name)

func _on_item_list_item_selected(index: int) -> void:
	var lobby = item_list.get_item_metadata(index)
	if lobby == null:
		selected_lobby_id = ""
		return
	selected_lobby_id = lobby.lobby_id


###############################
### LOBBY LIST (polling) ######
###############################

func _refresh_lobby_list() -> void:
	if _refreshing:
		# Previous search still in flight - skip this tick entirely.
		return

	_refreshing = true
	var lobbies = await HLobbies.search_by_bucket_id_async("main_lobby")
	_refreshing = false

	if lobbies == null:
		return

	# Stopping the timer does not cancel a search that was already awaiting.
	# If host/join began while we were out, drop the result on the floor
	# rather than repopulating a list the user has left behind.
	if _refresh_timer.is_stopped():
		print("[net] discarding lobby search that finished after host/join began")
		return

	_latest_lobbies = lobbies

	item_list.clear()

	# clear() drops the visual selection, so remember which row to restore.
	var row_to_reselect := -1

	for lobby in lobbies:
		var server_name = "Lobby (%d/%d)" % [lobby.members.size(), lobby.max_members]
		var idx = item_list.add_item(server_name)
		item_list.set_item_metadata(idx, lobby)

		if selected_lobby_id != "" and lobby.lobby_id == selected_lobby_id:
			row_to_reselect = idx

	if row_to_reselect != -1:
		# select() does not re-emit item_selected, so this won't loop back
		# into _on_item_list_item_selected.
		item_list.select(row_to_reselect)
	elif selected_lobby_id != "":
		# The lobby the user had picked is gone from the results.
		print("[net] previously selected lobby disappeared from search results")
		selected_lobby_id = ""


## Looks up a live HLobby from the most recent search by its ID.
## Returns null if it is no longer listed.
func _find_lobby_by_id(lobby_id: String):
	for lobby in _latest_lobbies:
		if lobby.lobby_id == lobby_id:
			return lobby
	return null


###############################
### ACTUAL SERVER SETUP #######
###############################

func host_lobby(server_name: String) -> void:
	# No more lobby searching once we commit to hosting.
	_refresh_timer.stop()

	var lobby_opts = EOS.Lobby.CreateLobbyOptions.new()
	lobby_opts.max_lobby_members = 20
	lobby_opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	lobby_opts.bucket_id = "main_lobby"
	lobby_opts.presence_enabled = false

	var lobby = await HLobbies.create_lobby_async(lobby_opts)
	if not lobby:
		printerr("[net] Failed to create lobby")
		_start_refreshing()
		return

	# epic's lobby system doesn't seem to relay lobby attributes
	# for lobbies, so for now we go to see _refresh_lobby_list for the actual workaround in use
	lobby.add_attribute("server_name", server_name)
	await lobby.update_async()

	var peer = EOSGMultiplayerPeer.new()

	# create_server(socket_id)
	# returns a Godot Error, not an EOS result code. Compare to OK.
	var result: int = peer.create_server(P2P_SOCKET)
	if result != OK:
		printerr("[net] Failed to create EOSG P2P server. Error: ", result)
		_start_refreshing()
		return

	peer.set_auto_accept_connection_requests(true)
	multiplayer.multiplayer_peer = peer

	print("========================================")
	print("HOSTING")
	print("Lobby ID:   ", lobby.lobby_id)
	print("Host PUID:  ", HAuth.product_user_id)
	print("Socket:     ", P2P_SOCKET)
	print("Godot peer: ", multiplayer.get_unique_id())
	print("========================================")

	_current_lobby = lobby
	hosted_lobby.emit()
	self.hide()


func join_selected_lobby(chosen_lobby: HLobby) -> void:
	# No more lobby searching once we commit to joining.
	_refresh_timer.stop()

	var lobby = await HLobbies.join_async(chosen_lobby)
	if not lobby:
		printerr("[net] Failed to join lobby")
		_start_refreshing()
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
	# create_client(socket_id, remote_user_id)
	#
	# Socket name FIRST, host PUID SECOND. Reversed, the SDK addresses the
	# connection request to a "user" named "game" over a socket named after
	# the host's PUID - both structurally valid, so no error is raised, but
	# nobody is listening and it dies at SentTimes=[8/8].
	#
	# Confirmed against src/eosg_multiplayer_peer.cpp:
	#   bind_method(D_METHOD("create_client", "socket_id", "remote_user_id"), ...)
	# ---------------------------------------------------------------------
	var result: int = peer.create_client(P2P_SOCKET, host_id)

	print("[net] create_client returned: ", result)
	if result != OK:
		printerr("[net] Failed to create EOSG P2P client. Error: ", result)
		await HLobbies.leave_async(lobby)
		_start_refreshing()
		return

	multiplayer.multiplayer_peer = peer

	# create_client() returning OK only means the request was queued. Wait for
	# the actual handshake before telling the rest of the game we're in.
	var connected := await _await_connection(CONNECT_TIMEOUT)

	if not connected:
		printerr("[net] Lobby join succeeded but P2P connection did not establish.")
		multiplayer.multiplayer_peer = null
		await HLobbies.leave_async(lobby)
		_start_refreshing()
		return

	print("[net] Connected to host. Godot peer ID: ", multiplayer.get_unique_id())

	_current_lobby = lobby
	$ConnectedLabel.text = "CONNECTED TO: " + host_id
	joined_lobby.emit()
	self.hide()


## Resolves true on connected_to_server, false on connection_failed or timeout.
## Also polls get_connection_status() directly, so if the signal is missed for
## any reason the status itself is treated as authoritative.
func _await_connection(timeout: float) -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		print("[net] already connected before wait started")
		return true

	var outcome := [false]
	var done := [false]

	var on_ok := func():
		print("[net] connected_to_server fired")
		outcome[0] = true
		done[0] = true
	var on_fail := func():
		printerr("[net] connection_failed fired")
		outcome[0] = false
		done[0] = true

	multiplayer.connected_to_server.connect(on_ok, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(on_fail, CONNECT_ONE_SHOT)

	var elapsed := 0.0
	var last_status := -1

	while not done[0] and elapsed < timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

		var p := multiplayer.multiplayer_peer
		if p == null:
			printerr("[net] multiplayer_peer went null at t=%.1fs" % elapsed)
			break

		var status := p.get_connection_status()
		if status != last_status:
			print("[net] connection_status -> %d (0=disconnected 1=connecting 2=connected) at t=%.1fs" % [status, elapsed])
			last_status = status
			if status == MultiplayerPeer.CONNECTION_CONNECTED:
				outcome[0] = true
				done[0] = true
			elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
				outcome[0] = false
				done[0] = true

	if multiplayer.connected_to_server.is_connected(on_ok):
		multiplayer.connected_to_server.disconnect(on_ok)
	if multiplayer.connection_failed.is_connected(on_fail):
		multiplayer.connection_failed.disconnect(on_fail)

	if not done[0]:
		printerr("[net] timed out after %.1fs waiting for connection" % elapsed)

	return outcome[0]


func _on_peer_connected(peer_id: int) -> void:
	print("[net] peer_connected: ", peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("[net] peer_disconnected: ", peer_id)

func _on_server_disconnected() -> void:
	printerr("[net] server_disconnected")
	lost_connection.emit()


## Called by Main once the world has been torn down. Puts this panel back into
## its menu state: leaves the EOS lobby, clears the selection, resumes polling.
func return_to_menu() -> void:
	if _current_lobby != null:
		await HLobbies.leave_async(_current_lobby)
		_current_lobby = null

	selected_lobby_id = ""
	_latest_lobbies = []
	item_list.clear()
	$ConnectedLabel.text = "CONNECTED TO SERVER: NO"

	self.show()
	_start_refreshing()
