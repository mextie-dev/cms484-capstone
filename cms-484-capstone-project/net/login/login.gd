extends Control

## Basic login functionality for the client


func _on_eos_log_msg(msg: EOS.Logging.LogMessage) -> void:
	print("SDK %s | %s" % [msg.category, msg.message])


## HAuth.login_anonymous_async() deletes and recreates the device id on every
## call, which means it never persists identity between launches. This does
## the same job but keeps an existing device id if one is already there.
func login_persistent_anonymous_async(user_display_name: String) -> bool:
	var create_opts = EOS.Connect.CreateDeviceIdOptions.new()
	create_opts.device_model = " ".join(PackedStringArray([OS.get_name(), OS.get_model_name()]))
	EOS.Connect.ConnectInterface.create_device_id(create_opts)

	var create_ret = await IEOS.connect_interface_create_device_id_callback
	# DuplicateNotAllowed just means a device id already exists locally - that's
	# expected on every launch after the first, so treat it as success, not failure.
	if not EOS.is_success(create_ret) and create_ret.result_code != EOS.Result.DuplicateNotAllowed:
		printerr("Failed to create device id: ", EOS.result_str(create_ret))
		return false

	var login_opts = EOS.Connect.LoginOptions.new()
	login_opts.credentials = EOS.Connect.Credentials.new()
	login_opts.credentials.type = EOS.ExternalCredentialType.DeviceidAccessToken
	login_opts.credentials.token = null
	login_opts.user_login_info = EOS.Connect.UserLoginInfo.new()
	login_opts.user_login_info.display_name = user_display_name

	HAuth.display_name = user_display_name
	HAuth.display_name_changed.emit()

	return await HAuth.login_game_services_async(login_opts)


func _ready():
	HPlatform.log_msg.connect(_on_eos_log_msg)
	HLobbies.presence_enabled = false

	# creates an object of HCredentials that takes all our data from EOSCredentials
	var credentials = HCredentials.new()
	credentials.product_name = EOSCredentials.PRODUCT_NAME
	credentials.product_version = EOSCredentials.PRODUCT_VERSION
	credentials.product_id = EOSCredentials.PRODUCT_ID
	credentials.sandbox_id = EOSCredentials.SANDBOX_ID
	credentials.deployment_id = EOSCredentials.DEPLOYMENT_ID
	credentials.client_id = EOSCredentials.CLIENT_ID
	credentials.client_secret = EOSCredentials.CLIENT_SECRET
	credentials.encryption_key = EOSCredentials.ENCRYPTION_KEY

	# if the server spins up, then we win
	var setup_success := await HPlatform.setup_eos_async(credentials)
	if not setup_success:
		printerr("Failed to setup EOS")
		return

	# these both talk to the native platform/P2P interface, so they can only
	# run AFTER setup_eos_async has actually finished creating it
	HP2P.set_relay_control(EOS.P2P.RelayControl.AllowRelays)
	#HPlatform.set_eos_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.VeryVerbose)

	# if we establish a connection as this individual client to the server, then we win again
	var logged_in := await login_persistent_anonymous_async("name_id")
	if logged_in:
		print("User data dir: ", OS.get_user_data_dir())
		print("Logged in: ", HAuth.product_user_id)
		$DeviceLabel.text = "DEVICE ID: " + HAuth.product_user_id
	else:
		print("Failed to log in")
