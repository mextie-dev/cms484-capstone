# Authored by:
# Max Royer, using outlines provided by Anthropic's Opus 5

extends Control

## handles EOS initialization and anonymous Device ID (PUID) authentication

signal server_started

## Forwarded up from ServerSetup when the host disappears, so Main can unload
## the world and put the menu back.
signal server_stopped


#func _on_eos_log_msg(msg: EOS.Logging.LogMessage) -> void:
	#print("EOS SDK [%s] | %s" % [msg.category, msg.message])


## EOSG's convenience anonymous-login helper deletes/recreates the Device ID.
## This version preserves an existing Device ID so the anonymous identity
## persists between launches.
func login_persistent_anonymous_async(user_display_name: String) -> bool:
	var create_opts := EOS.Connect.CreateDeviceIdOptions.new()
	create_opts.device_model = " ".join(
		PackedStringArray([
			OS.get_name(),
			OS.get_model_name()
		])
	)

	EOS.Connect.ConnectInterface.create_device_id(create_opts)

	var create_ret = await IEOS.connect_interface_create_device_id_callback

	# DuplicateNotAllowed means a Device ID already exists on this machine.
	# That is expected after the first launch, so dont do anything, but just lets us know
	# for debug purposes
	if not EOS.is_success(create_ret):
		if create_ret.result_code != EOS.Result.DuplicateNotAllowed:
			printerr(
				"Failed to create EOS Device ID: ",
				EOS.result_str(create_ret)
			)
			return false

	var login_opts := EOS.Connect.LoginOptions.new()

	login_opts.credentials = EOS.Connect.Credentials.new()
	login_opts.credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken
	login_opts.credentials.token = null

	login_opts.user_login_info = EOS.Connect.UserLoginInfo.new()
	login_opts.user_login_info.display_name = user_display_name

	HAuth.display_name = user_display_name
	HAuth.display_name_changed.emit()

	var success := await HAuth.login_game_services_async(login_opts)

	if success:
		print("========================================")
		print("EOS CONNECT AUTHENTICATION SUCCESS")
		print("Product User ID: ", HAuth.product_user_id)
		print("Display Name: ", HAuth.display_name)
		print("========================================")
	else:
		printerr("EOS Connect authentication failed.")

	return success


func _ready() -> void:
	#HPlatform.log_msg.connect(_on_eos_log_msg)

	# pass our defined EOS credentials in EOSCredentials.gd to the actual EOS service
	# DONT PUSH EOSCREDENTIALS.GD TO GIT
	var credentials := HCredentials.new()

	credentials.product_name = EOSCredentials.PRODUCT_NAME
	credentials.product_version = EOSCredentials.PRODUCT_VERSION
	credentials.product_id = EOSCredentials.PRODUCT_ID
	credentials.sandbox_id = EOSCredentials.SANDBOX_ID
	credentials.deployment_id = EOSCredentials.DEPLOYMENT_ID
	credentials.client_id = EOSCredentials.CLIENT_ID
	credentials.client_secret = EOSCredentials.CLIENT_SECRET
	credentials.encryption_key = EOSCredentials.ENCRYPTION_KEY

	print("Initializing EOS...")

	var setup_success := await HPlatform.setup_eos_async(credentials)

	if not setup_success:
		printerr("Failed to initialize EOS.")
		return

	print("EOS platform initialized successfully.")

	# we have to put this here because if we set this before we've confirmed that
	# EOS hears us, undefined behavior happens
	HP2P.set_relay_control(EOS.P2P.RelayControl.AllowRelays)

	# API call to EOS that sets the log level to very, very verbose, so all
	# log messages we get are extremely detailed
	HPlatform.set_eos_log_level(
		EOS.Logging.LogCategory.AllCategories,
		EOS.Logging.LogLevel.VeryVerbose
	)

	# HLobbies' high-level Presence behavior is independent of the
	# presence_enabled value passed to an individual CreateLobbyOptions.
	#
	# We are deliberately using Device ID / Connect authentication and
	# therefore do not want the lobby system attempting to advertise
	# Epic Account Presence.
	HLobbies.presence_enabled = false

	print("EOS lobby Presence advertising disabled.")

	print("Beginning anonymous Device ID authentication...")

	var logged_in := await login_persistent_anonymous_async("name_id")

	if not logged_in:
		printerr("Failed to authenticate with EOS.")
		return

	print("User data directory: ", OS.get_user_data_dir())
	print("Authenticated Product User ID: ", HAuth.product_user_id)

	$DeviceLabel.text = "PUID: " + HAuth.product_user_id

## util functions for logging, ignore
#func save_text_to_file(
	#content: String,
	#file_path: String = "user://save_game.txt"
#) -> void:
	#var file := FileAccess.open(file_path, FileAccess.WRITE)
#
	#if file:
		#file.store_string(content)
		#file.close()
		#print("File saved successfully.")
	#else:
		#printerr(
			#"Failed to open file. Error code: ",
			#FileAccess.get_open_error()
		#)
#
#
#func read_text_from_file(
	#file_path: String
#) -> String:
	#var file := FileAccess.open(file_path, FileAccess.READ)
#
	#if file == null:
		#printerr(
			#"Failed to open file. Error code: ",
			#FileAccess.get_open_error()
		#)
		#return ""
#
	#return file.get_as_text()

# if everything is successful, call out that we got a server spun up, server_setup.gd takes it from here
func _on_connection_established() -> void:
	server_started.emit()


# fired by ServerSetup.lost_connection when the host goes away
func _on_server_setup_lost_connection() -> void:
	server_stopped.emit()
