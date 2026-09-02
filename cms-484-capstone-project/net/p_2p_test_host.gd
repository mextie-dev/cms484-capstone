extends Node

## Minimal EOSG P2P host test - no lobbies involved.
## Run this, copy the printed PUID, paste it into p2p_test_client.gd.

const P2P_SOCKET := "game"

var peer: EOSGMultiplayerPeer


func _ready() -> void:
	print("========================================")
	print("EOS P2P HOST TEST")
	print("========================================")

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

	if not await _login_async("host"):
		printerr("Device ID login failed")
		return

	print("========================================")
	print("EOS CONNECT AUTHENTICATION SUCCESS")
	print("Host PUID: ", HAuth.product_user_id)
	print("   ^ paste this into p2p_test_client.gd HOST_PUID")
	print("========================================")

	_start_server()


func _login_async(display_name: String) -> bool:
	print("Beginning anonymous Device ID authentication...")

	var create_opts = EOS.Connect.CreateDeviceIdOptions.new()
	create_opts.device_model = " ".join(PackedStringArray([OS.get_name(), OS.get_model_name()]))
	EOS.Connect.ConnectInterface.create_device_id(create_opts)

	var create_ret = await IEOS.connect_interface_create_device_id_callback
	# DuplicateNotAllowed just means a device id already exists locally.
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


func _start_server() -> void:
	print("Creating EOSG P2P server on socket '%s'..." % P2P_SOCKET)

	peer = EOSGMultiplayerPeer.new()

	# create_server(socket_id) - takes ONE argument.
	# Returns a Godot Error (OK == 0), NOT an EOS result code.
	var result: int = peer.create_server(P2P_SOCKET)
	if result != OK:
		printerr("!!! FAILED TO CREATE EOSG P2P SERVER. Error: ", result)
		return

	peer.set_auto_accept_connection_requests(true)
	multiplayer.multiplayer_peer = peer

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("========================================")
	print("P2P SERVER LISTENING")
	print("is_server:      ", multiplayer.is_server())
	print("Godot peer ID:  ", multiplayer.get_unique_id())
	print("Socket:         ", P2P_SOCKET)
	print("Host PUID:      ", HAuth.product_user_id)
	print("========================================")


func _on_peer_connected(peer_id: int) -> void:
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print("       PEER CONNECTED: ", peer_id)
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)
