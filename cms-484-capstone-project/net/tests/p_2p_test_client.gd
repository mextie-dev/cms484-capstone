extends Node

## Minimal EOSG P2P client test - no lobbies involved.
## Paste the PUID printed by p2p_test_host.gd into HOST_PUID below.

const HOST_PUID := "00020e8d529c4dcbbcfd686243ddf05d"
const P2P_SOCKET := "game"
const CONNECT_TIMEOUT := 20.0

var peer: EOSGMultiplayerPeer
var _connected := false
var _finished := false


func _ready() -> void:
	print("========================================")
	print("EOS P2P CLIENT TEST")
	print("========================================")
	print("Target host PUID: ", HOST_PUID)

	if HOST_PUID == "PUT_HOST_PUID_HERE" or HOST_PUID.length() != 32:
		printerr("HOST_PUID is not set to a real 32-character PUID. Aborting.")
		return

	HPlatform.log_msg.connect(func(msg): print("SDK %s | %s" % [msg.category, msg.message]))

	print("Initializing EOS...")
	var credentials = HCredentials.new()
	credentials.product_name = EOSCredentials.PRODUCT_NAME
	credentials.product_version = EOSCredentials.PRODUCT_VERSION
	credentials.product_id = EOSCredentials.PRODUCT_ID
	credentials.sandbox_id = EOSCredentials.SANDBOX_ID
	credentials.deployment_id = EOSCredentials.DEPLOYMENT_ID
	credentials.client_id = EOSCredentials.CLIENT_ID
	credentials.client_secret = EOSCredentials.CLIENT_SECRET
	credentials.encryption_key = EOSCredentials.ENCRYPTION_KEY

	if not await HPlatform.setup_eos_async(credentials):
		printerr("Failed to setup EOS")
		return

	print("EOS platform initialized successfully.")

	HP2P.set_relay_control(EOS.P2P.RelayControl.AllowRelays)
	HPlatform.set_eos_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.VeryVerbose)

	if not await _login_async("client"):
		printerr("Device ID login failed")
		return

	print("========================================")
	print("EOS CONNECT AUTHENTICATION SUCCESS")
	print("Client PUID: ", HAuth.product_user_id)
	print("========================================")

	_start_client()


func _login_async(display_name: String) -> bool:
	print("Beginning anonymous Device ID authentication...")

	var create_opts = EOS.Connect.CreateDeviceIdOptions.new()
	create_opts.device_model = " ".join(PackedStringArray([OS.get_name(), OS.get_model_name()]))
	EOS.Connect.ConnectInterface.create_device_id(create_opts)

	var create_ret = await IEOS.connect_interface_create_device_id_callback
	if not EOS.is_success(create_ret) and create_ret.result_code != EOS.Result.DuplicateNotAllowed:
		printerr("Failed to create device id: ", EOS.result_str(create_ret))
		return false

	var login_opts = EOS.Connect.LoginOptions.new()
	login_opts.credentials = EOS.Connect.Credentials.new()
	login_opts.credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken
	login_opts.credentials.token = null
	login_opts.user_login_info = EOS.Connect.UserLoginInfo.new()
	login_opts.user_login_info.display_name = display_name

	HAuth.display_name = display_name
	HAuth.display_name_changed.emit()

	return await HAuth.login_game_services_async(login_opts)


func _start_client() -> void:
	print("========================================")
	print("CREATING EOSG P2P CLIENT")
	print("Local PUID:  ", HAuth.product_user_id)
	print("Target PUID: ", HOST_PUID)
	print("Socket name: ", P2P_SOCKET)
	print("========================================")

	peer = EOSGMultiplayerPeer.new()

	# ---------------------------------------------------------------------
	# THE FIX: create_client(socket_id, remote_user_id)
	#
	# Socket name FIRST, host PUID SECOND.
	#
	# Confirmed against the plugin source (src/eosg_multiplayer_peer.cpp):
	#   bind_method(D_METHOD("create_client", "socket_id", "remote_user_id"), ...)
	#
	# With the arguments reversed, the SDK logs show:
	#   RemoteUserId=[g...e]   <- the literal string "game"
	#   SocketId=[<host puid>] <- the PUID used as a socket name
	# Both are structurally valid so no error is raised, but the connection
	# request is addressed to nobody and dies at SentTimes=[8/8].
	# ---------------------------------------------------------------------
	var result: int = peer.create_client(P2P_SOCKET, HOST_PUID)

	# Returns a Godot Error (OK == 0), NOT an EOS result code.
	# The old check `if not EOS.is_success(result)` only worked by coincidence.
	print("create_client returned: ", result)
	if result != OK:
		printerr("!!! FAILED TO CREATE EOSG P2P CLIENT. Error: ", result)
		return

	# Connect signals BEFORE installing the peer so nothing is missed.
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	multiplayer.multiplayer_peer = peer

	print("EOSG P2P client created. Godot MultiplayerPeer installed.")
	print("========================================")
	print("WAITING FOR HOST CONNECTION...")
	print("========================================")

	_watch_for_timeout()


func _watch_for_timeout() -> void:
	await get_tree().create_timer(CONNECT_TIMEOUT).timeout
	if _finished:
		return
	_finished = true
	printerr("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	printerr("  EOS P2P CONNECTION FAILED (timeout)")
	printerr("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	printerr("Check the SDK log lines for RemoteUserId and SocketId.")
	printerr("RemoteUserId should be the host PUID, SocketId should be '%s'." % P2P_SOCKET)
	multiplayer.multiplayer_peer = null


func _on_connected_to_server() -> void:
	_connected = true
	_finished = true
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print("       CONNECTED TO HOST")
	print("Godot peer ID: ", multiplayer.get_unique_id())
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")


func _on_connection_failed() -> void:
	_finished = true
	printerr("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	printerr("       EOS P2P CONNECTION FAILED")
	printerr("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	print("Server disconnected.")
	multiplayer.multiplayer_peer = null
