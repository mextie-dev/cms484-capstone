extends Node


func _on_eos_log_msg(msg: EOS.Logging.LogMessage) -> void:
	print("SDK %s | %s" % [msg.category, msg.message])


func login_persistent_anonymous_async(user_display_name: String) -> bool:
	print("Beginning anonymous Device ID authentication...")

	# Create a persistent Device ID.
	var create_opts = EOS.Connect.CreateDeviceIdOptions.new()
	create_opts.device_model = " ".join(
		PackedStringArray([
			OS.get_name(),
			OS.get_model_name()
		])
	)

	EOS.Connect.ConnectInterface.create_device_id(create_opts)

	var create_ret = await IEOS.connect_interface_create_device_id_callback

	if not EOS.is_success(create_ret) and \
		create_ret.result_code != EOS.Result.DuplicateNotAllowed:
		printerr(
			"Failed to create device id: ",
			EOS.result_str(create_ret)
		)
		return false

	# Log into EOS Connect using the Device ID.
	var login_opts = EOS.Connect.LoginOptions.new()

	login_opts.credentials = EOS.Connect.Credentials.new()
	login_opts.credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken
	login_opts.credentials.token = null

	login_opts.user_login_info = EOS.Connect.UserLoginInfo.new()
	login_opts.user_login_info.display_name = user_display_name

	HAuth.display_name = user_display_name
	HAuth.display_name_changed.emit()

	return await HAuth.login_game_services_async(login_opts)


func _ready() -> void:
	print("========================================")
	print("EOS P2P HOST TEST")
	print("========================================")

	# EOS logging.
	HPlatform.log_msg.connect(_on_eos_log_msg)

	# Build EOS credentials using the same credentials
	# as the existing login.gd.
	var credentials = HCredentials.new()

	credentials.product_name = EOSCredentials.PRODUCT_NAME
	credentials.product_version = EOSCredentials.PRODUCT_VERSION
	credentials.product_id = EOSCredentials.PRODUCT_ID
	credentials.sandbox_id = EOSCredentials.SANDBOX_ID
	credentials.deployment_id = EOSCredentials.DEPLOYMENT_ID
	credentials.client_id = EOSCredentials.CLIENT_ID
	credentials.client_secret = EOSCredentials.CLIENT_SECRET
	credentials.encryption_key = EOSCredentials.ENCRYPTION_KEY

	print("Initializing EOS...")

	var setup_success = await HPlatform.setup_eos_async(credentials)

	if not setup_success:
		printerr("FAILED TO INITIALIZE EOS")
		return

	print("EOS platform initialized successfully.")

	# Allow EOS to use relays.
	HP2P.set_relay_control(EOS.P2P.RelayControl.AllowRelays)

	# Very verbose logging is useful for this diagnostic.
	HPlatform.set_eos_log_level(
		EOS.Logging.LogCategory.AllCategories,
		EOS.Logging.LogLevel.VeryVerbose
	)

	# Log in with Device ID.
	var logged_in = await login_persistent_anonymous_async("P2P_TEST_HOST")

	if not logged_in:
		printerr("FAILED TO LOG INTO EOS")
		return

	print("========================================")
	print("EOS CONNECT AUTHENTICATION SUCCESS")
	print("Host PUID: ", HAuth.product_user_id)
	print("========================================")

	# -------------------------------------------------
	# CREATE EOS P2P SERVER
	# -------------------------------------------------

	print("Creating EOSG P2P server...")

	var peer = EOSGMultiplayerPeer.new()

	var result = peer.create_server("game")

	print("EOSG create_server result: ", result)

	if not EOS.is_success(result):
		printerr("FAILED TO CREATE EOSG P2P SERVER")
		return

	print("EOSG P2P server created successfully.")

	# Automatically accept incoming P2P connection requests.
	peer.set_auto_accept_connection_requests(true)

	# Install the EOS peer into Godot.
	multiplayer.multiplayer_peer = peer

	print("Godot MultiplayerPeer installed.")
	print("multiplayer.is_server(): ", multiplayer.is_server())
	print("Godot host peer ID: ", multiplayer.get_unique_id())

	# Listen for Godot-level connections.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	print("")
	print("========================================")
	print("          EOS P2P HOST READY")
	print("========================================")
	print("HOST PUID:")
	print(HAuth.product_user_id)
	print("")
	print("Give that PUID to the client.")
	print("========================================")


func _on_peer_connected(peer_id: int) -> void:
	print("")
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print("GODOT PEER CONNECTED")
	print("Peer ID: ", peer_id)
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print("")


func _on_peer_disconnected(peer_id: int) -> void:
	print("")
	print("GODOT PEER DISCONNECTED")
	print("Peer ID: ", peer_id)
	print("")
