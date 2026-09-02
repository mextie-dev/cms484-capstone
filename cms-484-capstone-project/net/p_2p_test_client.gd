extends Node


# =====================================================
# PUT THE HOST'S PUID HERE
# =====================================================

const HOST_PUID := "00020e8d529c4dcbbcfd686243ddf05d"


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
	print("EOS P2P CLIENT TEST")
	print("========================================")

	# Make sure the host PUID has been entered.
	if HOST_PUID == "" or HOST_PUID == "PUT_HOST_PUID_HERE":
		printerr("ERROR: You have not entered the host PUID.")
		printerr("Open p2p_test_client.gd and set HOST_PUID.")
		return

	print("Target host PUID: ", HOST_PUID)

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
	var logged_in = await login_persistent_anonymous_async("P2P_TEST_CLIENT")

	if not logged_in:
		printerr("FAILED TO LOG INTO EOS")
		return

	print("========================================")
	print("EOS CONNECT AUTHENTICATION SUCCESS")
	print("Client PUID: ", HAuth.product_user_id)
	print("========================================")

	# Don't connect to ourselves by accident.
	if HAuth.product_user_id == HOST_PUID:
		printerr("ERROR: Client PUID is the same as the host PUID.")
		printerr("The host and client must be different EOS users/devices.")
		return

	# Listen for Godot networking events BEFORE creating the client.
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)

	# -------------------------------------------------
	# CREATE EOS P2P CLIENT
	# -------------------------------------------------

	print("")
	print("========================================")
	print("CREATING EOSG P2P CLIENT")
	print("========================================")
	print("Local PUID: ", HAuth.product_user_id)
	print("Target PUID: ", HOST_PUID)
	print("Socket name: game")
	print("")

	var peer = EOSGMultiplayerPeer.new()

	var result = peer.create_client(HOST_PUID, "game")

	print("EOSG create_client result: ", result)

	if not EOS.is_success(result):
		printerr("FAILED TO CREATE EOSG P2P CLIENT")
		return

	print("EOSG P2P client created successfully.")

	# Install the EOS peer into Godot.
	multiplayer.multiplayer_peer = peer

	print("Godot MultiplayerPeer installed.")

	print("")
	print("========================================")
	print("WAITING FOR HOST CONNECTION...")
	print("========================================")
	print("")


func _on_connected_to_server() -> void:
	print("")
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print("       CONNECTED TO EOS P2P HOST")
	print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print("")


func _on_connection_failed() -> void:
	print("")
	printerr("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	printerr("       EOS P2P CONNECTION FAILED")
	printerr("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
	print("")


func _on_server_disconnected() -> void:
	print("")
	print("EOS P2P SERVER DISCONNECTED")
	print("")


func _on_peer_connected(peer_id: int) -> void:
	print("")
	print("GODOT PEER CONNECTED")
	print("Peer ID: ", peer_id)
	print("")
